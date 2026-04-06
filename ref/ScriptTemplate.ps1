<#
  .SYNOPSIS
    [One-line summary of what this script does.]

  .DESCRIPTION
    [Detailed explanation of the script's purpose, behavior,
    and any prerequisites or assumptions.]

    All scripts in this repo baseline PowerShell 5.1, which is
    the default on all officially supported Microsoft operating
    systems. PS 7+ features must NOT be used unless explicitly
    guarded with a version check.

  .PARAMETER LogLevel
    A 7-digit string controlling the ActionPreference for each
    output stream. Each digit (0-4) maps to an ActionPreference:
      0 = SilentlyContinue  (suppress output)
      1 = Stop              (halt on this stream)
      2 = Continue          (display and continue)
      3 = Inquire           (prompt the user)
      4 = Ignore            (suppress, not even in $Error)

    Digit positions map to streams in this order:
      [0] Verbose    — detailed trace info
      [1] Debug      — developer diagnostics
      [2] Information — operational messages
      [3] Warning    — non-fatal problems
      [4] Error      — custom error display level
      [5] Fatal      — custom fatal error level
      [6] Progress   — progress bar display

    Digits 0-3 map to standard PS preference variables
    ($VerbosePreference, $DebugPreference, etc.).
    Digits 4-5 map to CUSTOM preference variables
    ($ErrorPreference, $FatalPreference) used by application
    logic to control error severity — these are SEPARATE from
    the standard $ErrorActionPreference which controls PS
    engine behavior and is set by DebugLevel digit 0.
    Digit 6 maps to $ProgressPreference — set to 0 (Silent)
    in automated/remote scripts to avoid performance overhead
    and output stream corruption from progress bars.

    Default: '0022130'
      Verbose=Silent, Debug=Silent, Information=Continue,
      Warning=Continue, Error=Stop, Fatal=Inquire,
      Progress=Silent

  .PARAMETER DebugLevel
    A 3-digit string controlling debug/diagnostic behavior:
      Digit 0 — ErrorActionPreference (0=SilentlyContinue, 1=Stop)
        This is the STANDARD PS engine error behavior, separate
        from the custom $ErrorPreference set by LogLevel digit 4.
      Digit 1 — Set-PSDebug trace level:
        0 = Off
        1 = Trace 1, no stepping
        2 = Trace 1, with stepping
        3 = Trace 2, no stepping
        4 = Trace 2, with stepping
      Digit 2 — Set-StrictMode version:
        0 = Off
        1 = Version 1.0
        2 = Version 2.0
        3 = Version 3.0 (Latest)

    Default: '003' (ErrorAction=Silent, Trace=Off, Strict=v3)

  .EXAMPLE
    .\ScriptTemplate.ps1

  .EXAMPLE
    .\ScriptTemplate.ps1 -LogLevel:'2222130' -DebugLevel:'103'

  .NOTES
    Author  : HellBomb
    Version : 1.0.0

    PowerShell Compatibility:
      Baseline  : 5.1 (Windows PowerShell)
      Tested On : 5.1, 7.x
#>

#Requires -Version 5.1

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
  'PSUseProcessBlockForPipelineCommand', '',
  Justification = 'Script-level parameters do not require a process block.'
)]

[CmdletBinding(
  , ConfirmImpact = 'Low'
  , DefaultParameterSetName = 'Default'
  , HelpURI = ''
  , PositionalBinding = $False
  , SupportsShouldProcess = $False
)]

Param (
  [Parameter(
    , DontShow = $False
    , HelpMessage = '7-digit ActionPreference per output stream.'
    , Mandatory = $False
    , ParameterSetName = 'Default'
    , Position = 0
    , ValueFromPipeline = $False
    , ValueFromPipelineByPropertyName = $False
    , ValueFromRemainingArguments = $False
  )]
  [ValidatePattern('^[0-4]{7}$')]
  [System.String]
  $LogLevel = '0022130',

  [Parameter(
    , DontShow = $False
    , HelpMessage = '3-digit debug/trace/strict configuration.'
    , Mandatory = $False
    , ParameterSetName = 'Default'
    , Position = 1
    , ValueFromPipeline = $False
    , ValueFromPipelineByPropertyName = $False
    , ValueFromRemainingArguments = $False
  )]
  [ValidatePattern('^[01][0-4][0-3]$')]
  [System.String]
  $DebugLevel = '003'
)


#region ------ [ Initialization ] ---------------------------------------- #

# ── Static Constants ────────────────────────────────────────────────────

# Log level stream names — index maps to position in $LogLevel string.
# Indices 0-3, 6: standard PS preference variables
# Indices 4-5: CUSTOM preference variables for application logic
New-Variable -Verbose:$False -Force -Name:'LOG_LEVELS' -Option:('Private', 'ReadOnly') -Value:(
  [System.String[]]@(
    'Verbose',      # [0] → $VerbosePreference      (standard)
    'Debug',        # [1] → $DebugPreference        (standard)
    'Information',  # [2] → $InformationPreference  (standard)
    'Warning',      # [3] → $WarningPreference      (standard)
    'Error',        # [4] → $ErrorPreference        (CUSTOM)
    'Fatal',        # [5] → $FatalPreference        (CUSTOM)
    'Progress'      # [6] → $ProgressPreference     (standard)
  )
)

# Lookup table mapping digit characters to ActionPreference values.
# Makes the digit-to-enum mapping explicit and self-documenting
# rather than relying on implicit enum ordinal knowledge.
# NOTE: Limited to 0-4 for PS 5.1 compatibility.
#   Suspend (5) is deprecated (workflow only).
#   Break (6) is PS 7+ only.
New-Variable -Verbose:$False -Force -Name:'ACTION_PREFS' -Option:('Private', 'ReadOnly') -Value:(
  [System.Collections.Hashtable]@{
    '0' = [System.Management.Automation.ActionPreference]::SilentlyContinue
    '1' = [System.Management.Automation.ActionPreference]::Stop
    '2' = [System.Management.Automation.ActionPreference]::Continue
    '3' = [System.Management.Automation.ActionPreference]::Inquire
    '4' = [System.Management.Automation.ActionPreference]::Ignore
  }
)


# Script exit code — set to 0 (success) by default.
# Update this in the Execution region to indicate failure.
# The Cleanup region uses this to exit with the correct code.
New-Variable -Verbose:$False -Force -Name:'ExitCode' -Value:(
  [System.Int32](0)
)


# ── Trap (Script-Level Last Resort) ────────────────────────────────────

# Defined early so all subsequent initialization code is covered.
# Write-Host and Exit are prohibited in functions but are the ONLY
# reliable mechanism in a script-level trap where error streams may
# be compromised and $PSCmdlet is unavailable.
Trap {
  If ($PSItem.Exception.PSObject.Properties.Name -Contains 'ErrorRecord') {
    Write-Debug -Message:(
      'Failed to execute command: {0}' -f
        $PSItem.Exception.ErrorRecord.InvocationInfo.Line.Trim()
    )
  }

  # --- [ Line Continuation ] ————————————————————————————————————↴
  Write-Host -ForegroundColor:'Red' -Object:(                     `
    '[{0}] [{1:0000}] {2} [{3}]' -f                               `
      [System.DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss.fff'), `
      [System.Int64]$PSItem.InvocationInfo.ScriptLineNumber,      `
      [System.String]$PSItem.Exception.Message,                   `
      [System.String]$PSItem.Exception.GetBaseException().GetType().FullName
  )

  If ($PSItem.Exception.WasThrownFromThrowStatement -eq $True) {
    Exit 1
  }
}


# ── Log Level Configuration ────────────────────────────────────────────

# Configure all 7 stream preferences from the $LogLevel string.
# Loop variable $I is not declared via New-Variable because For
# loops manage their own iterator — this is the one exception.
#
# DUAL ERROR VARIABLE DESIGN:
#   $ErrorPreference (custom, LogLevel digit 4) — Controls how
#     application-level code displays/handles errors. Used by
#     functions to decide severity of error reporting.
#   $FatalPreference (custom, LogLevel digit 5) — Controls how
#     application-level code handles fatal/unrecoverable errors.
#     Functions check this to decide whether to use -IsFatal:$True
#     on New-ErrorRecord.
#   $ErrorActionPreference (standard PS, DebugLevel digit 0) —
#     Controls the PS engine's behavior when a non-terminating
#     error occurs (continue, stop, suppress, etc.).
#   These are intentionally separate: you may want errors to
#   DISPLAY as Continue (logged but not blocking) while the PS
#   engine behavior is set to Stop (all errors are terminating).
For ($I = 0; $I -lt $LOG_LEVELS.Count; $I++) {
  Set-Variable -Verbose:$False -Force -Name:(
    '{0}Preference' -f $LOG_LEVELS[$I]
  ) -Value:(
    $ACTION_PREFS[$LogLevel[$I].ToString()]
  )
}


# ── Debug Level Configuration ──────────────────────────────────────────

# Uses Switch fall-through — all matching cases execute on the
# same $DebugLevel value, configuring all three digits in one pass.
Switch ($DebugLevel) {
  # Digit 0: ErrorActionPreference (always runs — $PSItem is truthy)
  { $PSItem } {
    Set-Variable -Verbose:$False -Name:'ErrorActionPreference' -Value:(
      $ACTION_PREFS[$PSItem[0].ToString()]
    )
  }
  # Digit 1: Set-PSDebug (trace and step)
  { $PSItem[1] -eq '0' } { Set-PSDebug -Off }
  { $PSItem[1] -eq '1' } { Set-PSDebug -Trace:1 -Step:$False }
  { $PSItem[1] -eq '2' } { Set-PSDebug -Trace:1 -Step:$True }
  { $PSItem[1] -eq '3' } { Set-PSDebug -Trace:2 -Step:$False }
  { $PSItem[1] -eq '4' } { Set-PSDebug -Trace:2 -Step:$True }
  # Digit 2: Set-StrictMode
  { $PSItem[2] -eq '0' } { Set-StrictMode -Off }
  { $PSItem[2] -eq '1' } { Set-StrictMode -Version:'1.0' }
  { $PSItem[2] -eq '2' } { Set-StrictMode -Version:'2.0' }
  { $PSItem[2] -eq '3' } { Set-StrictMode -Version:'3.0' }
}


# ── Execution Context ──────────────────────────────────────────────────

# Initialize $ENV to store script/execution context properties.
# NOTE: $ENV intentionally shadows $env: — this is by design for
# this script's execution context tracking.
New-Variable -Verbose:$False -Force -Name:'ENV' -Value:(
  [PSCustomObject]@{
    RunMethod = [System.String]::Empty
    Script    = [System.IO.FileInfo]$Null
    PSPath    = [System.IO.FileInfo]$Null
  }
)

# Set PSPath from the current process — no PATH search needed.
$ENV.PSPath = New-Object -TypeName:'System.IO.FileInfo' -ArgumentList:(
  # [System.String] fileName
  [System.Diagnostics.Process]::GetCurrentProcess().Path
)

If (Test-Path -Path:'Variable:psISE') {
  # ISE is deprecated but still present in older environments
  $ENV.RunMethod = [System.String]'ISE'
  $ENV.Script = New-Object -TypeName:'System.IO.FileInfo' -ArgumentList:(
    # [System.String] fileName
    $psISE.CurrentFile.FullPath
  )
} ElseIf (Test-Path -Path:'Variable:psEditor') {
  $ENV.RunMethod = [System.String]'VSCode'
  $ENV.Script = New-Object -TypeName:'System.IO.FileInfo' -ArgumentList:(
    # [System.String] fileName
    $psEditor.GetEditorContext().CurrentFile.Path
  )
} Else {
  $ENV.RunMethod = [System.String]'Console'
  $ENV.Script = New-Object -TypeName:'System.IO.FileInfo' -ArgumentList:(
    # [System.String] fileName
    $MyInvocation.MyCommand.Path
  )
}

Set-Variable -Name:'ENV' -Option:('ReadOnly')

# Clean up initialization-only variables — lookup tables, loop
# iterator, and temporary config values are no longer needed.
Remove-Variable -Verbose:$False -Force -ErrorAction:'SilentlyContinue' -Name:([System.Array](
  'I', 'ACTION_PREFS'
))

#endregion --- [ Initialization ] ---------------------------------------- #


#region ------ [ Functions ] --------------------------------------------- #

# Dot-source functions here. Each function should be in its own
# file with a companion .strings.psd1:
#   . (Join-Path -Path:$ENV.Script.DirectoryName -ChildPath:'Start-ExampleFunction.ps1')

#endregion --- [ Functions ] --------------------------------------------- #


#region ------ [ Execution ] --------------------------------------------- #

# Script logic goes here.
#
# EXIT CODE CONVENTION:
#   0 = Success
#   1 = General failure (set by trap on unhandled throw)
#   2+ = Application-specific error codes
#
# To signal failure:
#   Set-Variable -Name:'ExitCode' -Value:([System.Int32](2))
#
# USING CUSTOM PREFERENCE VARIABLES:
#   Functions can check $ErrorPreference and $FatalPreference
#   to adjust their behavior:
#     If ($ErrorPreference -eq [System.Management.Automation.ActionPreference]::Stop) {
#       # Caller wants errors to halt — use -IsFatal:$True
#     }

#endregion --- [ Execution ] --------------------------------------------- #


#region ------ [ Cleanup ] ----------------------------------------------- #

# Release any resources acquired during execution.
# Remove script-scoped variables, close connections, dispose objects.
# This region runs on normal completion — for error cleanup, use
# Try/Finally blocks in the Execution region.

Remove-Variable -Verbose:$False -Force -ErrorAction:'SilentlyContinue' -Name:([System.Array](
  'ENV', 'LOG_LEVELS', 'ErrorPreference', 'FatalPreference'
))

Exit $ExitCode

#endregion --- [ Cleanup ] ----------------------------------------------- #

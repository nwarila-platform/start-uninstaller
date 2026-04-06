# ╔══════════════════════════════════════════════════════════════════════════╗
# ║ New-ErrorRecord — Structured Error Record Factory                      ║
# ║                                                                        ║
# ║ ALL errors in this repo MUST use this function to generate error       ║
# ║ records. Direct 'throw', bare 'Write-Error', and 'exit' are           ║
# ║ prohibited. Maximum effort should be made to AVOID fatal errors.       ║
# ╚══════════════════════════════════════════════════════════════════════════╝

Function New-ErrorRecord {
  <#
    .SYNOPSIS
      Creates a structured ErrorRecord for consistent error reporting.

    .DESCRIPTION
      Constructs a [System.Management.Automation.ErrorRecord] from the
      given exception type, message, error ID, and category. The result
      can be emitted as a non-terminating error (default) or raised as
      a fatal terminating error when -IsFatal is $True.

      This function is the ONLY approved way to generate errors in
      this repo. Direct 'throw' and bare 'Write-Error -Message' are
      prohibited.

    .PARAMETER ExceptionName
      The full .NET type name of the exception to create.
      Example: 'System.IO.FileNotFoundException'

    .PARAMETER ExceptionMessage
      The human-readable error message describing what went wrong.

    .PARAMETER TargetObject
      The object that was being processed when the error occurred.
      Provides context in the error record for debugging.

    .PARAMETER ErrorId
      A unique, searchable identifier for this specific error.
      Convention: 'FunctionName:ShortDescription'

    .PARAMETER ErrorCategory
      The [System.Management.Automation.ErrorCategory] classification.

    .PARAMETER IsFatal
      When $True, raises as a terminating error via
      $PSCmdlet.ThrowTerminatingError(). When $False (default),
      writes as a non-terminating error via Write-Error.

    .EXAMPLE
      # --- [ Line Continuation ] ————↴
      New-ErrorRecord                                              `
        -ExceptionName:'System.IO.FileNotFoundException'           `
        -ExceptionMessage:'Update file not found on disk.'         `
        -TargetObject:$UpdateFileInfo                              `
        -ErrorId:'Start-ExampleFunction:FileNotFound'              `
        -ErrorCategory:'ObjectNotFound'                            `
        -IsFatal:$False

    .OUTPUTS
      [System.Management.Automation.ErrorRecord]

    .NOTES
      Author  : HellBomb
      Version : 1.0.0
  #>

  [CmdletBinding(
    , ConfirmImpact = 'Low'
    , DefaultParameterSetName = 'Default'
    , HelpURI = ''
    , PositionalBinding = $False
    , RemotingCapability = 'None'
    , SupportsPaging = $False
    , SupportsShouldProcess = $False
  )]

  [OutputType([System.Management.Automation.ErrorRecord])]

  Param (
    [Parameter(
      , DontShow = $False
      , HelpMessage = 'Full .NET exception type name.'
      , HelpMessageBaseName = 'NewErrorRecord'
      , HelpMessageResourceId = 'ExceptionNameHelpMessage'
      , Mandatory = $True
      , ParameterSetName = 'Default'
      , Position = 0
      , ValueFromPipeline = $False
      , ValueFromPipelineByPropertyName = $False
      , ValueFromRemainingArguments = $False
    )]
    [ValidateNotNullOrEmpty()]
    [System.String]
    $ExceptionName,

    [Parameter(
      , DontShow = $False
      , HelpMessage = 'Human-readable error message.'
      , HelpMessageBaseName = 'NewErrorRecord'
      , HelpMessageResourceId = 'ExceptionMessageHelpMessage'
      , Mandatory = $True
      , ParameterSetName = 'Default'
      , Position = 1
      , ValueFromPipeline = $False
      , ValueFromPipelineByPropertyName = $False
      , ValueFromRemainingArguments = $False
    )]
    [ValidateNotNullOrEmpty()]
    [System.String]
    $ExceptionMessage,

    [Parameter(
      , DontShow = $False
      , HelpMessage = 'Object being processed when error occurred.'
      , HelpMessageBaseName = 'NewErrorRecord'
      , HelpMessageResourceId = 'TargetObjectHelpMessage'
      , Mandatory = $False
      , ParameterSetName = 'Default'
      , Position = 2
      , ValueFromPipeline = $False
      , ValueFromPipelineByPropertyName = $False
      , ValueFromRemainingArguments = $False
    )]
    [System.Object]
    $TargetObject = $Null,

    [Parameter(
      , DontShow = $False
      , HelpMessage = 'Unique, searchable error identifier.'
      , HelpMessageBaseName = 'NewErrorRecord'
      , HelpMessageResourceId = 'ErrorIdHelpMessage'
      , Mandatory = $True
      , ParameterSetName = 'Default'
      , Position = 3
      , ValueFromPipeline = $False
      , ValueFromPipelineByPropertyName = $False
      , ValueFromRemainingArguments = $False
    )]
    [ValidateNotNullOrEmpty()]
    [System.String]
    $ErrorId,

    [Parameter(
      , DontShow = $False
      , HelpMessage = 'ErrorCategory classification.'
      , HelpMessageBaseName = 'NewErrorRecord'
      , HelpMessageResourceId = 'ErrorCategoryHelpMessage'
      , Mandatory = $True
      , ParameterSetName = 'Default'
      , Position = 4
      , ValueFromPipeline = $False
      , ValueFromPipelineByPropertyName = $False
      , ValueFromRemainingArguments = $False
    )]
    [ValidateNotNullOrEmpty()]
    [System.Management.Automation.ErrorCategory]
    $ErrorCategory,

    [Parameter(
      , DontShow = $False
      , HelpMessage = 'When $True, raises a terminating error.'
      , HelpMessageBaseName = 'NewErrorRecord'
      , HelpMessageResourceId = 'IsFatalHelpMessage'
      , Mandatory = $False
      , ParameterSetName = 'Default'
      , Position = 5
      , ValueFromPipeline = $False
      , ValueFromPipelineByPropertyName = $False
      , ValueFromRemainingArguments = $False
    )]
    [System.Boolean]
    $IsFatal = $False
  )

  Begin {
    Write-Debug -Message:'[New-ErrorRecord] Entering Block: Begin'

    # Load companion localized string data
    # --- [ Line Continuation ] ————↴
    Import-LocalizedData                                           `
      -BindingVariable:'Strings'                                   `
      -FileName:'New-ErrorRecord.strings'                          `
      -BaseDirectory:$PSScriptRoot

    # DYNAMIC variables
    New-Variable -Force -Name:'Exception'   -Option:('Private') -Value:$Null
    New-Variable -Force -Name:'ErrorRecord' -Option:('Private') -Value:$Null

    Write-Debug -Message:'[New-ErrorRecord] Leaving Block: Begin'
  } Process {
    Write-Debug -Message:'[New-ErrorRecord] Entering Block: Process'

    Clear-Variable -Force -ErrorAction:'SilentlyContinue' -Name:([System.Array](
      'Exception', 'ErrorRecord'
    ))

    # ── Step 1: Create the .NET Exception object ────────────────────
    Try {
      Set-Variable -Name:'Exception' -Value:(
        New-Object -TypeName:($ExceptionName) -ArgumentList:(
          # [System.String] message
          $ExceptionMessage
        )
      )
    } Catch {
      # Fall back to RuntimeException so we never lose the message
      Write-Warning -Message:(
        $Strings.ExceptionTypeFallback_Warning -f
          $ExceptionName,
          $PSItem.Exception.Message
      )
      Set-Variable -Name:'Exception' -Value:(
        New-Object -TypeName:'System.Management.Automation.RuntimeException' -ArgumentList:(
          # [System.String] message
          $ExceptionMessage
        )
      )
    }

    # ── Step 2: Create the ErrorRecord ──────────────────────────────
    Set-Variable -Name:'ErrorRecord' -Value:(
      New-Object -TypeName:'System.Management.Automation.ErrorRecord' -ArgumentList:(
        # [System.Exception] exception
        $Exception,
        # [System.String] errorId
        $ErrorId,
        # [System.Management.Automation.ErrorCategory] errorCategory
        $ErrorCategory,
        # [System.Object] targetObject
        $TargetObject
      )
    )

    # ── Step 3: Emit or Terminate ───────────────────────────────────
    # NEVER use 'exit' — it kills the entire session.
    # $PSCmdlet.ThrowTerminatingError() is the correct way to raise
    # a fatal error that callers can still catch with Try/Catch.
    If ($IsFatal -eq $True) {
      $PSCmdlet.ThrowTerminatingError($ErrorRecord)
    } Else {
      Write-Error -ErrorRecord:$ErrorRecord
    }

    Write-Debug -Message:'[New-ErrorRecord] Leaving Block: Process'
  } End {
    Write-Debug -Message:'[New-ErrorRecord] Entering Block: End'

    Remove-Variable -Force -ErrorAction:'SilentlyContinue' -Name:([System.Array](
      'Exception', 'ErrorRecord',
      'Strings'  # Created by Import-LocalizedData
    ))

    Write-Debug -Message:'[New-ErrorRecord] Leaving Block: End'
  }
}

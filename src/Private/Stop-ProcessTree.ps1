#Requires -Version 5.1

Function Stop-ProcessTree {
  <#
    .SYNOPSIS
      Kills a process and all of its child processes.

    .DESCRIPTION
      Uses CIM to find child processes by ParentProcessId, then
      kills them recursively before killing the parent. This is
      best-effort timeout cleanup, so failures are reported via
      verbose output and then tolerated.

    .PARAMETER ProcessId
      The PID of the root process to kill.

    .EXAMPLE
      Stop-ProcessTree -ProcessId:1234

    .OUTPUTS
      None

    .NOTES
      Author  : HellBomb
      Version : 8.1.0
  #>

  [CmdletBinding(
    ConfirmImpact = 'Medium'
    , DefaultParameterSetName = 'Default'
    , HelpURI = ''
    , PositionalBinding = $False
    , RemotingCapability = 'None'
    , SupportsShouldProcess = $True
  )]
  [OutputType([System.Void])]
  Param (
    [Parameter(
      Mandatory = $True
      , ParameterSetName = 'Default'
      , DontShow = $False
      , HelpMessage = 'See function help.'
      , ValueFromPipeline = $False
      , ValueFromPipelineByPropertyName = $False
      , ValueFromRemainingArguments = $False
    )]
    [ValidateRange(1, [System.Int32]::MaxValue)]
    [System.Int32]
    $ProcessId
  )

  Begin {
    Write-Debug -Message:('[Stop-ProcessTree] Entering Begin')

    $Strings = @{
      ProcessKillFailed =
        'Process {0} could not be stopped cleanly: {1}'
      ProcessTreeCleanupFailed =
        'Process tree cleanup failed for PID {0}: {1}'
    }
    # --- [ Line Continuation ] ————↴
    Import-LocalizedData `
      -BindingVariable:'Strings' `
      -FileName:'Stop-ProcessTree.strings' `
      -BaseDirectory:$PSScriptRoot `
      -ErrorAction:'SilentlyContinue'

    Write-Debug -Message:('[Stop-ProcessTree] Exiting Begin')
  } Process {
    Write-Debug -Message:('[Stop-ProcessTree] Entering Process')

    Try {
      $CimArguments = @{
        ClassName = 'Win32_Process'
        Filter = (
          'ParentProcessId = {0}' -f $ProcessId
        )
        ErrorAction = 'SilentlyContinue'
      }
      $Children = Get-CimInstance @CimArguments

      $Children | & { Process {
        # --- [ Line Continuation ] ————↴
        Stop-ProcessTree `
          -ProcessId:([System.Int32]$PSItem.ProcessId)
      }}

      $Process = $Null
      Try {
        # --- [ Line Continuation ] ————↴
        $Process = `
          [System.Diagnostics.Process]::GetProcessById(
            $ProcessId
          )
        $Process.Kill()
      } Catch {
        # --- [ Line Continuation ] ————↴
        $ErrorRecord = New-ErrorRecord `
          -ExceptionName:'System.InvalidOperationException' `
          -ExceptionMessage:(
            $Strings['ProcessKillFailed'] -f
              $ProcessId,
              $PSItem.Exception.Message
          ) `
          -TargetObject:$ProcessId `
          -ErrorId:'StopProcessTreeKillFailed' `
          -ErrorCategory:(
            [System.Management.Automation.ErrorCategory]::OperationStopped
          )
        # --- [ Line Continuation ] ————↴
        Write-Verbose `
          -Message:$ErrorRecord.Exception.Message
      } Finally {
        $HasProcess = [System.Boolean](
          $Null -ne $Process
        )
        If ($HasProcess -eq $True) {
          $Process.Dispose()
        }
      }
    } Catch {
      # --- [ Line Continuation ] ————↴
      $ErrorRecord = New-ErrorRecord `
        -ExceptionName:'System.InvalidOperationException' `
        -ExceptionMessage:(
          $Strings['ProcessTreeCleanupFailed'] -f
            $ProcessId,
            $PSItem.Exception.Message
        ) `
        -TargetObject:$ProcessId `
        -ErrorId:'StopProcessTreeFailed' `
        -ErrorCategory:(
          [System.Management.Automation.ErrorCategory]::OperationStopped
        )
      # --- [ Line Continuation ] ————↴
      Write-Verbose `
        -Message:$ErrorRecord.Exception.Message
    }

    Write-Debug -Message:('[Stop-ProcessTree] Exiting Process')
  } End {
    Write-Debug -Message:('[Stop-ProcessTree] Entering End')
    Write-Debug -Message:('[Stop-ProcessTree] Exiting End')
  }
}

#Requires -Version 5.1

Function Invoke-SilentProcess {
  <#
    .SYNOPSIS
      Executes a process silently with hidden window, async
      stream draining, and configurable timeout.

    .DESCRIPTION
      Launches a process with redirected stdout/stderr, drains
      streams asynchronously to prevent buffer deadlock, waits
      up to `TimeoutSeconds`, then attempts to kill the full
      process tree on timeout.

      Returns a result object with `Outcome`, `ExitCode`, and
      `Message`.

      Success exit codes: 0, 1641, 3010.

    .PARAMETER FileName
      Path to the executable.

    .PARAMETER Arguments
      Command-line arguments.

    .PARAMETER TimeoutSeconds
      Maximum seconds to wait (1-3600, default 600).

    .EXAMPLE
      Invoke-SilentProcess -FileName:'cmd.exe' -Arguments:'/c exit 0'

    .OUTPUTS
      [System.Management.Automation.PSObject]

    .NOTES
      Author  : HellBomb
      Version : 8.1.0
  #>

  [CmdletBinding(
    DefaultParameterSetName = 'Default'
    , HelpURI = ''
    , PositionalBinding = $False
    , RemotingCapability = 'None'
  )]
  [OutputType([StartUninstallerProcessResult])]
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
    [ValidateNotNullOrEmpty()]
    [System.String]
    $FileName,

    [Parameter(
      Mandatory = $False
      , ParameterSetName = 'Default'
      , DontShow = $False
      , HelpMessage = 'See function help.'
      , ValueFromPipeline = $False
      , ValueFromPipelineByPropertyName = $False
      , ValueFromRemainingArguments = $False
    )]
    [AllowEmptyString()]
    [System.String]
    $Arguments = '',

    [Parameter(
      Mandatory = $False
      , ParameterSetName = 'Default'
      , DontShow = $False
      , HelpMessage = 'See function help.'
      , ValueFromPipeline = $False
      , ValueFromPipelineByPropertyName = $False
      , ValueFromRemainingArguments = $False
    )]
    [ValidateRange(1, 3600)]
    [System.Int32]
    $TimeoutSeconds = 600
  )

  Begin {
    Write-Debug -Message:('[Invoke-SilentProcess] Entering Begin')
    $Strings = @{
      TimeoutCleanupFailed =
        'Best-effort timeout cleanup failed: {0}'
      TimeoutWaitFailed =
        'Timed-out process did not report exit promptly: {0}'
      TimeoutDrainFailed =
        'Timed-out process stream drain did not finish cleanly: {0}'
      CompletedDrainFailed =
        'Completed process stream drain did not finish cleanly: {0}'
      ProcessTimedOut_Message =
        'Process timed out after {0} seconds.'
      ProcessStartFailed_Message =
        'Failed to start process ''{0}'': {1}'
      ProcessSuccess_Message =
        'Success.'
      ProcessSuccessRebootInitiated_Message =
        'Success (reboot initiated).'
      ProcessSuccessRebootRequired_Message =
        'Success (reboot required).'
      ProcessExitCode_Message =
        'Exit code {0}.'
    }
    # --- [ Line Continuation ] ————↴
    Import-LocalizedData `
      -BindingVariable:'Strings' `
      -FileName:'Invoke-SilentProcess.strings' `
      -BaseDirectory:$PSScriptRoot `
      -ErrorAction:'SilentlyContinue'

    Function Format-CapturedStreamText {
      Param (
        [AllowNull()]
        [System.String]
        $Text
      )

      $IsBlankText = [System.Boolean](
        [System.String]::IsNullOrWhiteSpace($Text) -eq $True
      )
      If ($IsBlankText -eq $True) {
        ''
      } Else {
        $Collapsed = [System.String]$Text
        $Collapsed = $Collapsed -replace '[\r\n\t]', ' '
        $Collapsed = $Collapsed -replace '\s{2,}', ' '
        $Collapsed = $Collapsed.Trim()

        $ExceedsMaxLength = [System.Boolean]($Collapsed.Length -gt 200)
        If ($ExceedsMaxLength -eq $True) {
          '{0}...' -f $Collapsed.Substring(0, 200)
        } Else {
          $Collapsed
        }
      }
    }

    Function Get-ResultMessage {
      Param (
        [System.String]
        $BaseMessage,

        [AllowNull()]
        [System.String]
        $Stdout,

        [AllowNull()]
        [System.String]
        $Stderr
      )

      $DetailParts = [System.Collections.Generic.List[System.String]]::new()
      $NormalizedStdErr = Format-CapturedStreamText -Text:$Stderr
      $NormalizedStdOut = Format-CapturedStreamText -Text:$Stdout

      $HasStdErrText = [System.Boolean](
        [System.String]::IsNullOrWhiteSpace($NormalizedStdErr) -eq $False
      )
      If ($HasStdErrText -eq $True) {
        $DetailParts.Add(('stderr: {0}' -f $NormalizedStdErr))
      }
      $HasStdOutText = [System.Boolean](
        [System.String]::IsNullOrWhiteSpace($NormalizedStdOut) -eq $False
      )
      If ($HasStdOutText -eq $True) {
        $DetailParts.Add(('stdout: {0}' -f $NormalizedStdOut))
      }

      $HasDetails = [System.Boolean]($DetailParts.Count -gt 0)
      If ($HasDetails -eq $True) {
        '{0} {1}' -f $BaseMessage, ($DetailParts -join ' | ')
      } Else {
        $BaseMessage
      }
    }
    $SuccessCodes = @(0, 1641, 3010)
    $DrainWaitMs = 5000

    Write-Debug -Message:('[Invoke-SilentProcess] Exiting Begin')
  }

  Process {
    Write-Debug -Message:('[Invoke-SilentProcess] Entering Process')

    $StartInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $StartInfo.FileName               = $FileName
    $StartInfo.Arguments              = $Arguments
    $StartInfo.WindowStyle            = [System.Diagnostics.ProcessWindowStyle]::Hidden
    $StartInfo.CreateNoWindow         = $True
    $StartInfo.UseShellExecute        = $False
    $StartInfo.RedirectStandardOutput = $True
    $StartInfo.RedirectStandardError  = $True

    $Process = $Null
    $StdoutTask = $Null
    $StderrTask = $Null
    $StdoutText = [System.String]::Empty
    $StderrText = [System.String]::Empty

    Try {
      $Process = [System.Diagnostics.Process]::Start($StartInfo)

      $StdoutTask = $Process.StandardOutput.ReadToEndAsync()
      $StderrTask = $Process.StandardError.ReadToEndAsync()

      $TimeoutMs = [System.Int32]($TimeoutSeconds * 1000)
      $Exited = [System.Boolean]$Process.WaitForExit($TimeoutMs)

      $TimedOut = [System.Boolean]($Exited -eq $False)
      If ($TimedOut -eq $True) {
        Try {
          Stop-ProcessTree -ProcessId:$Process.Id
        } Catch {
          $CleanupErrorRecord = New-ErrorRecord `
            -ExceptionName:'System.InvalidOperationException' `
            -ExceptionMessage:(
              $Strings['TimeoutCleanupFailed'] -f
                $PSItem.Exception.Message
            ) `
            -TargetObject:$Process.Id `
            -ErrorId:'InvokeSilentProcessTimeoutCleanupFailed' `
            -ErrorCategory:([System.Management.Automation.ErrorCategory]::OperationStopped)
          Write-Verbose -Message:$CleanupErrorRecord.Exception.Message
        }

        Try {
          $Null = $Process.WaitForExit($DrainWaitMs)
        } Catch {
          $DrainErrorRecord = New-ErrorRecord `
            -ExceptionName:'System.InvalidOperationException' `
            -ExceptionMessage:(
              $Strings['TimeoutWaitFailed'] -f
                $PSItem.Exception.Message
            ) `
            -TargetObject:$Process.Id `
            -ErrorId:'InvokeSilentProcessTimeoutWaitFailed' `
            -ErrorCategory:([System.Management.Automation.ErrorCategory]::OperationStopped)
          Write-Verbose -Message:$DrainErrorRecord.Exception.Message
        }

        Try {
          $Null = [System.Threading.Tasks.Task]::WaitAll(
            [System.Threading.Tasks.Task[]]@($StdoutTask, $StderrTask),
            $DrainWaitMs
          )
        } Catch {
          $StreamErrorRecord = New-ErrorRecord `
            -ExceptionName:'System.InvalidOperationException' `
            -ExceptionMessage:(
              $Strings['TimeoutDrainFailed'] -f
                $PSItem.Exception.Message
            ) `
            -TargetObject:$Process.Id `
            -ErrorId:'InvokeSilentProcessTimeoutDrainFailed' `
            -ErrorCategory:([System.Management.Automation.ErrorCategory]::OperationStopped)
          Write-Verbose -Message:$StreamErrorRecord.Exception.Message
        }

        $HasCompletedStdout = [System.Boolean](
          $StdoutTask.Status -eq
            [System.Threading.Tasks.TaskStatus]::RanToCompletion
        )
        If ($HasCompletedStdout -eq $True) {
          $StdoutText = [System.String]$StdoutTask.Result
        }
        $HasCompletedStderr = [System.Boolean](
          $StderrTask.Status -eq
            [System.Threading.Tasks.TaskStatus]::RanToCompletion
        )
        If ($HasCompletedStderr -eq $True) {
          $StderrText = [System.String]$StderrTask.Result
        }

        $ExitCode = $Null
        $HasExitedAfterCleanup = [System.Boolean]($Process.HasExited -eq $True)
        If ($HasExitedAfterCleanup -eq $True) {
          Try {
            $ExitCode = [System.Int32]$Process.ExitCode
          } Catch {
            $ExitCode = $Null
          }
        }

        [StartUninstallerProcessResult]::new(
          'TimedOut',
          $ExitCode,
          (Get-ResultMessage `
            -BaseMessage:(
              $Strings['ProcessTimedOut_Message'] -f $TimeoutSeconds
            ) `
            -Stdout:$StdoutText `
            -Stderr:$StderrText)
        )
      } Else {
        $Process.WaitForExit()

        Try {
          $Null = [System.Threading.Tasks.Task]::WaitAll(
            [System.Threading.Tasks.Task[]]@($StdoutTask, $StderrTask),
            $DrainWaitMs
          )
        } Catch {
          $DrainErrorRecord = New-ErrorRecord `
            -ExceptionName:'System.InvalidOperationException' `
            -ExceptionMessage:(
              $Strings['CompletedDrainFailed'] -f
                $PSItem.Exception.Message
            ) `
            -TargetObject:$Process.Id `
            -ErrorId:'InvokeSilentProcessDrainFailed' `
            -ErrorCategory:([System.Management.Automation.ErrorCategory]::OperationStopped)
          Write-Verbose -Message:$DrainErrorRecord.Exception.Message
        }

        $HasCompletedStdout = [System.Boolean](
          $StdoutTask.Status -eq
            [System.Threading.Tasks.TaskStatus]::RanToCompletion
        )
        If ($HasCompletedStdout -eq $True) {
          $StdoutText = [System.String]$StdoutTask.Result
        }
        $HasCompletedStderr = [System.Boolean](
          $StderrTask.Status -eq
            [System.Threading.Tasks.TaskStatus]::RanToCompletion
        )
        If ($HasCompletedStderr -eq $True) {
          $StderrText = [System.String]$StderrTask.Result
        }

        $Code = [System.Int32]$Process.ExitCode
        $IsSuccess = [System.Boolean]($SuccessCodes -contains $Code)

        $BaseMessage = Switch ($Code) {
          0    { $Strings['ProcessSuccess_Message'] }
          1641 { $Strings['ProcessSuccessRebootInitiated_Message'] }
          3010 { $Strings['ProcessSuccessRebootRequired_Message'] }
          Default { $Strings['ProcessExitCode_Message'] -f $Code }
        }

        $Outcome = If ($IsSuccess -eq $True) { 'Succeeded' } Else { 'Failed' }
        $Message = If ($IsSuccess -eq $True) {
          [System.String]$BaseMessage
        } Else {
          Get-ResultMessage `
            -BaseMessage:$BaseMessage `
            -Stdout:$StdoutText `
            -Stderr:$StderrText
        }
        [StartUninstallerProcessResult]::new(
          $Outcome,
          $Code,
          [System.String]$Message
        )
      }
    } Catch {
      $ErrorRecord = New-ErrorRecord `
        -ExceptionName:'System.InvalidOperationException' `
        -ExceptionMessage:(
          $Strings['ProcessStartFailed_Message'] -f
            $FileName,
            $PSItem.Exception.Message
        ) `
        -TargetObject:$FileName `
        -ErrorId:'InvokeSilentProcessStartFailed' `
        -ErrorCategory:([System.Management.Automation.ErrorCategory]::OpenError)
      [StartUninstallerProcessResult]::new(
        'Failed',
        $Null,
        $ErrorRecord.Exception.Message
      )
    } Finally {
      $HasProcess = [System.Boolean]($Null -ne $Process)
      If ($HasProcess -eq $True) { $Process.Dispose() }
    }

    Write-Debug -Message:('[Invoke-SilentProcess] Exiting Process')
  }

  End {
    Write-Debug -Message:('[Invoke-SilentProcess] Entering End')
    Write-Debug -Message:('[Invoke-SilentProcess] Exiting End')
  }
}

#Requires -Version 5.1

Function Resolve-UninstallCommand {
  <#
    .SYNOPSIS
      Parses a raw uninstall string into a normalized command
      record.

    .DESCRIPTION
      Supports the plan-approved uninstall families: MSI, EXE,
      CMD, and BAT. MSI commands are normalized to
      `%SystemRoot%\System32\msiexec.exe`, `/I` is converted to
      `/X` only when it is the MSI action token, and `/qn` is
      appended when no existing quiet/passive UI flag is
      present.

      Generic shell-wrapper families such as `rundll32.exe`,
      `cmd.exe`, `powershell.exe`, and `pwsh.exe` are rejected
      and return `$Null`.

    .PARAMETER UninstallString
      The raw uninstall command from the registry.

    .PARAMETER EXEFlags
      Custom silent flags for EXE installers. `$Null` means use
      the original arguments.

    .EXAMPLE
      Resolve-UninstallCommand `
        -UninstallString:'"C:\Program Files\App\unins000.exe" /SILENT'

    .OUTPUTS
      [System.Management.Automation.PSObject] or $Null

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
  [OutputType([StartUninstallerUninstallCommand])]
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
    [ValidatePattern('\S')]
    [System.String]
    $UninstallString,

    [Parameter(
      Mandatory = $False
      , ParameterSetName = 'Default'
      , DontShow = $False
      , HelpMessage = 'See function help.'
      , ValueFromPipeline = $False
      , ValueFromPipelineByPropertyName = $False
      , ValueFromRemainingArguments = $False
    )]
    [AllowNull()]
    [AllowEmptyString()]
    [System.Object]
    $EXEFlags = $Null
  )

  Begin {
    Write-Debug -Message:('[Resolve-UninstallCommand] Entering Begin')
    $Strings = @{
      UninstallStringParseFailed =
        'Unable to parse uninstall string ''{0}'': {1}'
    }
    # --- [ Line Continuation ] ————↴
    Import-LocalizedData `
      -BindingVariable:'Strings' `
      -FileName:'Resolve-UninstallCommand.strings' `
      -BaseDirectory:$PSScriptRoot `
      -ErrorAction:'SilentlyContinue'
    Write-Debug -Message:('[Resolve-UninstallCommand] Exiting Begin')
  } Process {
    Write-Debug -Message:('[Resolve-UninstallCommand] Entering Process')

    $UnsupportedExecutables = @(
      'cmd.exe',
      'powershell.exe',
      'pwsh.exe',
      'rundll32.exe'
    )

    Try {
      # --- [ Line Continuation ] ————↴
      $RegexOptions = `
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
      $RxMsiInstallFlag = `
        [System.Text.RegularExpressions.Regex]::new(
          '/I(?=\s*[\{"])',
          $RegexOptions
        )
      # --- [ Line Continuation ] ————↴
      $RxMsiQuietFlag = `
        [System.Text.RegularExpressions.Regex]::new(
          '(?i)(/quiet\b|/q[nbr]?\b|/passive\b)',
          $RegexOptions
        )
      # --- [ Line Continuation ] ————↴
      $RxMsiCommand = `
        [System.Text.RegularExpressions.Regex]::new(
          '^(?:"(?<exe>[^"]*\\)?msiexec(?:\.exe)?"|(?<exe>(?:[^"\s]+\\)?msiexec(?:\.exe)?))\s*(?<args>.*)$',
          $RegexOptions
        )
      # --- [ Line Continuation ] ————↴
      $RxQuotedBatchCommand = `
        [System.Text.RegularExpressions.Regex]::new(
          '^"(?<exe>[^"]+\.(?:cmd|bat))"\s*(?<args>.*)$',
          $RegexOptions
        )
      # --- [ Line Continuation ] ————↴
      $RxUnquotedBatchCommand = `
        [System.Text.RegularExpressions.Regex]::new(
          '^(?<exe>.+\.(?:cmd|bat))(?:\s+(?<args>.*))?$',
          $RegexOptions
        )
      # --- [ Line Continuation ] ————↴
      $RxQuotedExeCommand = `
        [System.Text.RegularExpressions.Regex]::new(
          '^"(?<exe>[^"]+\.exe)"\s*(?<args>.*)$',
          $RegexOptions
        )
      # --- [ Line Continuation ] ————↴
      $RxUnquotedExeCommand = `
        [System.Text.RegularExpressions.Regex]::new(
          '^(?<exe>.+\.exe)(?:\s+(?<args>.*))?$',
          $RegexOptions
        )

      $Command = $Null
      $MsiMatch = $RxMsiCommand.Match($UninstallString)
      $IsMsiCommand = [System.Boolean]($MsiMatch.Success)

      If ($IsMsiCommand -eq $True) {
        # --- [ Line Continuation ] ————↴
        $MsiArgsText = `
          [System.String]$MsiMatch.Groups['args'].Value
        $HasUsableMsiArgs = [System.Boolean](
          [System.String]::IsNullOrWhiteSpace(
            $MsiArgsText
          ) -eq $False
        )
        If ($HasUsableMsiArgs -eq $True) {
          $MsiArgs = [System.String](
            $RxMsiInstallFlag.Replace(
              $MsiArgsText, '/X'
            )
          ).Trim()

          $HasQuietFlag = [System.Boolean](
            $RxMsiQuietFlag.IsMatch($MsiArgs)
          )
          If ($HasQuietFlag -eq $False) {
            $MsiArgs = '{0} /qn' -f $MsiArgs
          }

          # --- [ Line Continuation ] ————↴
          $Command = `
            [StartUninstallerUninstallCommand]::new(
              [System.String](
                '{0}\System32\msiexec.exe' -f
                  $Env:SystemRoot
              ),
              [System.String]$MsiArgs.Trim()
            )
          # --- [ Line Continuation ] ————↴
          $Command.PSObject.TypeNames.Insert(
            0, 'StartUninstaller.UninstallCommand'
          )
        }
      } Else {
        # --- [ Line Continuation ] ————↴
        $QuotedBatchMatch = `
          $RxQuotedBatchCommand.Match($UninstallString)
        # --- [ Line Continuation ] ————↴
        $UnquotedBatchMatch = `
          $RxUnquotedBatchCommand.Match($UninstallString)
        $BatchMatch = $QuotedBatchMatch
        $HasQuotedBatchMatch = [System.Boolean](
          $QuotedBatchMatch.Success
        )
        $HasUnquotedBatchMatch = [System.Boolean](
          $UnquotedBatchMatch.Success
        )
        $UseUnquotedBatch = [System.Boolean](
          $HasQuotedBatchMatch -eq $False -and
          $HasUnquotedBatchMatch -eq $True
        )
        If ($UseUnquotedBatch -eq $True) {
          $BatchMatch = $UnquotedBatchMatch
        }

        $IsBatchCommand = [System.Boolean](
          $HasQuotedBatchMatch -eq $True -or
          $HasUnquotedBatchMatch -eq $True
        )
        If ($IsBatchCommand -eq $True) {
          # --- [ Line Continuation ] ————↴
          $Command = `
            [StartUninstallerUninstallCommand]::new(
              [System.String]$BatchMatch.Groups['exe'].Value,
              [System.String]$BatchMatch.Groups['args'].Value
            )
          # --- [ Line Continuation ] ————↴
          $Command.PSObject.TypeNames.Insert(
            0, 'StartUninstaller.UninstallCommand'
          )
        } Else {
          # --- [ Line Continuation ] ————↴
          $QuotedExeMatch = `
            $RxQuotedExeCommand.Match($UninstallString)
          # --- [ Line Continuation ] ————↴
          $UnquotedExeMatch = `
            $RxUnquotedExeCommand.Match($UninstallString)
          $ExeMatch = $QuotedExeMatch
          $HasQuotedExeMatch = [System.Boolean](
            $QuotedExeMatch.Success
          )
          $HasUnquotedExeMatch = [System.Boolean](
            $UnquotedExeMatch.Success
          )
          $UseUnquotedExe = [System.Boolean](
            $HasQuotedExeMatch -eq $False -and
            $HasUnquotedExeMatch -eq $True
          )
          If ($UseUnquotedExe -eq $True) {
            $ExeMatch = $UnquotedExeMatch
          }

          $IsExeCommand = [System.Boolean](
            $HasQuotedExeMatch -eq $True -or
            $HasUnquotedExeMatch -eq $True
          )
          If ($IsExeCommand -eq $True) {
            # --- [ Line Continuation ] ————↴
            $ExecutableLeaf = `
              [System.IO.Path]::GetFileName(
                [System.String]$ExeMatch.Groups['exe'].Value
              )
            $IsSupportedExecutable = [System.Boolean](
              $UnsupportedExecutables -inotcontains
                $ExecutableLeaf
            )
            If ($IsSupportedExecutable -eq $True) {
              $HasCustomExeFlags = [System.Boolean](
                $PSBoundParameters.ContainsKey(
                  'EXEFlags'
                ) -and
                $Null -ne $EXEFlags
              )
              $ExeArguments = If (
                $HasCustomExeFlags -eq $True
              ) {
                [System.String]$EXEFlags
              } Else {
                # --- [ Line Continuation ] ————↴
                [System.String]$ExeMatch.Groups[
                  'args'
                ].Value
              }

              # --- [ Line Continuation ] ————↴
              $Command = `
                [StartUninstallerUninstallCommand]::new(
                  [System.String]$ExeMatch.Groups[
                    'exe'
                  ].Value,
                  [System.String]$ExeArguments
                )
              # --- [ Line Continuation ] ————↴
              $Command.PSObject.TypeNames.Insert(
                0,
                'StartUninstaller.UninstallCommand'
              )
            }
          }
        }
      }

      $Command
    } Catch {
      # --- [ Line Continuation ] ————↴
      $ErrorRecord = New-ErrorRecord `
        -ExceptionName:'System.InvalidOperationException' `
        -ExceptionMessage:(
          $Strings['UninstallStringParseFailed'] -f
            $UninstallString,
            $PSItem.Exception.Message
        ) `
        -TargetObject:$UninstallString `
        -ErrorId:'ResolveUninstallCommandFailed' `
        -ErrorCategory:(
          [System.Management.Automation.ErrorCategory]::InvalidOperation
        )
      $PSCmdlet.ThrowTerminatingError($ErrorRecord)
    }

    Write-Debug -Message:('[Resolve-UninstallCommand] Exiting Process')
  } End {
    Write-Debug -Message:('[Resolve-UninstallCommand] Entering End')
    Write-Debug -Message:('[Resolve-UninstallCommand] Exiting End')
  }
}

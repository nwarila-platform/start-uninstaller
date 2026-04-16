#Requires -Version 5.1

Function Start-Uninstaller {
  <#
    .SYNOPSIS
      Discovers and uninstalls Windows applications using
      flexible registry-based filtering.

    .DESCRIPTION
      Searches HKLM and loaded per-user HKU uninstall registry
      locations. Filters results using AND logic across one or
      more filter definitions. Supports Simple, Wildcard, Regex,
      and DisplayVersion semantic-version operators.

      The function returns an internal run-result object that
      contains the line-oriented PDQ output plus the script exit
      code. The top-level entrypoint writes the lines and exits
      with that code.

    .PARAMETER Filter
      One or more filter hashtable definitions.

    .PARAMETER Architecture
      x86, x64, or Both (default).

    .PARAMETER Properties
      Additional raw registry value names to emit in output.

    .PARAMETER EXEFlags
      Custom silent flags for EXE-based uninstallers.

    .PARAMETER ListOnly
      Discovery-only mode that emits matches without
      uninstalling.

    .PARAMETER IncludeHidden
      Include entries where SystemComponent = 1.

    .PARAMETER IncludeNameless
      Include entries with empty or missing DisplayName.

    .PARAMETER AllowMultipleMatches
      Required to uninstall more than one match.

    .PARAMETER TimeoutSeconds
      Per-entry process timeout (1-3600, default 600).

    .EXAMPLE
      Start-Uninstaller -Filter:@(
        @{
          Property  = 'DisplayName'
          Value     = 'Node.js'
          MatchType = 'Simple'
        }
      )

    .OUTPUTS
      [StartUninstallerRunResult]

    .NOTES
      Author  : HellBomb
      Version : 8.1.0
  #>

  [CmdletBinding(
    DefaultParameterSetName = 'Default'
    , HelpUri = ''
    , PositionalBinding = $False
    , RemotingCapability = 'None'
    , SupportsPaging = $False
    , SupportsShouldProcess = $True
    , SupportsTransactions = $False
    , ConfirmImpact = 'Medium'
  )]
  [OutputType([StartUninstallerRunResult])]
  Param (
    [Parameter(
      Mandatory = $True
      , ParameterSetName = 'Default'
      , Position = [System.Int32]::MinValue
      , DontShow = $False
      , HelpMessage = 'See function help.'
      , HelpMessageBaseName = ''
      , HelpMessageResourceId = ''
      , ValueFromPipeline = $False
      , ValueFromPipelineByPropertyName = $False
      , ValueFromRemainingArguments = $False
    )]
    [ValidateNotNullOrEmpty()]
    [System.Collections.Hashtable[]]
    $Filter,

    [Parameter(
      Mandatory = $False
      , ParameterSetName = 'Default'
      , Position = [System.Int32]::MinValue
      , DontShow = $False
      , HelpMessage = 'See function help.'
      , HelpMessageBaseName = ''
      , HelpMessageResourceId = ''
      , ValueFromPipeline = $False
      , ValueFromPipelineByPropertyName = $False
      , ValueFromRemainingArguments = $False
    )]
    [ValidateSet('x86', 'x64', 'Both')]
    [System.String]
    $Architecture = 'Both',

    [Parameter(
      Mandatory = $False
      , ParameterSetName = 'Default'
      , Position = [System.Int32]::MinValue
      , DontShow = $False
      , HelpMessage = 'See function help.'
      , HelpMessageBaseName = ''
      , HelpMessageResourceId = ''
      , ValueFromPipeline = $False
      , ValueFromPipelineByPropertyName = $False
      , ValueFromRemainingArguments = $False
    )]
    [System.String[]]
    $Properties = @(),

    [Parameter(
      Mandatory = $False
      , ParameterSetName = 'Default'
      , Position = [System.Int32]::MinValue
      , DontShow = $False
      , HelpMessage = 'See function help.'
      , HelpMessageBaseName = ''
      , HelpMessageResourceId = ''
      , ValueFromPipeline = $False
      , ValueFromPipelineByPropertyName = $False
      , ValueFromRemainingArguments = $False
    )]
    [System.String]
    $EXEFlags,

    [Parameter(
      Mandatory = $False
      , ParameterSetName = 'Default'
      , Position = [System.Int32]::MinValue
      , DontShow = $False
      , HelpMessage = 'See function help.'
      , HelpMessageBaseName = ''
      , HelpMessageResourceId = ''
      , ValueFromPipeline = $False
      , ValueFromPipelineByPropertyName = $False
      , ValueFromRemainingArguments = $False
    )]
    [System.Management.Automation.SwitchParameter]
    $ListOnly,

    [Parameter(
      Mandatory = $False
      , ParameterSetName = 'Default'
      , Position = [System.Int32]::MinValue
      , DontShow = $False
      , HelpMessage = 'See function help.'
      , HelpMessageBaseName = ''
      , HelpMessageResourceId = ''
      , ValueFromPipeline = $False
      , ValueFromPipelineByPropertyName = $False
      , ValueFromRemainingArguments = $False
    )]
    [System.Management.Automation.SwitchParameter]
    $IncludeHidden,

    [Parameter(
      Mandatory = $False
      , ParameterSetName = 'Default'
      , Position = [System.Int32]::MinValue
      , DontShow = $False
      , HelpMessage = 'See function help.'
      , HelpMessageBaseName = ''
      , HelpMessageResourceId = ''
      , ValueFromPipeline = $False
      , ValueFromPipelineByPropertyName = $False
      , ValueFromRemainingArguments = $False
    )]
    [System.Management.Automation.SwitchParameter]
    $IncludeNameless,

    [Parameter(
      Mandatory = $False
      , ParameterSetName = 'Default'
      , Position = [System.Int32]::MinValue
      , DontShow = $False
      , HelpMessage = 'See function help.'
      , HelpMessageBaseName = ''
      , HelpMessageResourceId = ''
      , ValueFromPipeline = $False
      , ValueFromPipelineByPropertyName = $False
      , ValueFromRemainingArguments = $False
    )]
    [System.Management.Automation.SwitchParameter]
    $AllowMultipleMatches,

    [Parameter(
      Mandatory = $False
      , ParameterSetName = 'Default'
      , Position = [System.Int32]::MinValue
      , DontShow = $False
      , HelpMessage = 'See function help.'
      , HelpMessageBaseName = ''
      , HelpMessageResourceId = ''
      , ValueFromPipeline = $False
      , ValueFromPipelineByPropertyName = $False
      , ValueFromRemainingArguments = $False
    )]
    [ValidateRange(1, 3600)]
    [System.Int32]
    $TimeoutSeconds = 600
  )

  Begin {
    Write-Debug -Message:('[Start-Uninstaller] Entering Begin')
    Write-Debug -Message:('[Start-Uninstaller] Exiting Begin')
  } Process {
    Write-Debug -Message:('[Start-Uninstaller] Entering Process')
    $OutputLines = [System.Collections.Generic.List[System.String]]::new()
    $ExitCode = 0
    $AnyFailed = $False
    $HasStartedUninstallAttempts = $False

    $ListFields = @(
      'AppArch', 'DisplayName', 'DisplayVersion',
      'InstallScope', 'IsHidden', 'Publisher',
      'RegistryPath', 'UserIdentityStatus',
      'UserName', 'UserSid'
    )
    $UninstallFields = @(
      'AppArch', 'DisplayName', 'DisplayVersion',
      'ExitCode', 'InstallScope', 'IsHidden',
      'Message', 'Outcome', 'Publisher',
      'RegistryPath', 'UserIdentityStatus',
      'UserName', 'UserSid'
    )
    $InternalFields = @(
      '_ParsedDisplayVersion',
      '_RegistryHive',
      '_RegistryView',
      '_RegistrySource'
    )
    $SyntheticFields = @(
      'AppArch', 'InstallScope', 'IsHidden',
      'RegistryPath', 'UserIdentityStatus',
      'UserName', 'UserSid'
    )

    Foreach ($PropertyName in $Properties) {
      $IsBlankPropertyName = [System.Boolean](
        [System.String]::IsNullOrWhiteSpace($PropertyName)
      )
      If ($IsBlankPropertyName -eq $True) {
        $OutputLines.Add(
          'Message=Each -Properties value must be a ' +
          'named registry value.'
        )
        $ExitCode = 4
        Break
      }

      $ContainsNulCharacter = [System.Boolean](
        $PropertyName.Contains("`0")
      )
      If ($ContainsNulCharacter -eq $True) {
        $OutputLines.Add(
          'Message=Registry property names in ' +
          '-Properties cannot contain NUL.'
        )
        $ExitCode = 4
        Break
      }

      $IsSyntheticProperty = [System.Boolean](
        $SyntheticFields -icontains $PropertyName
      )
      If ($IsSyntheticProperty -eq $True) {
        $OutputLines.Add(
          (
            'Message=Synthetic field ''{0}'' is ' +
            'not valid in -Properties. Use it in ' +
            '-Filter instead.'
          ) -f $PropertyName
        )
        $ExitCode = 4
        Break
      }

      $IsInternalProperty = [System.Boolean](
        $InternalFields -icontains $PropertyName
      )
      If ($IsInternalProperty -eq $True) {
        $OutputLines.Add(
          (
            'Message=Internal field ''{0}'' is ' +
            'not valid in -Properties.'
          ) -f $PropertyName
        )
        $ExitCode = 4
        Break
      }
    }

    $CompiledFilters = [System.Management.Automation.PSObject[]]@()
    $CanValidateFilters = [System.Boolean]($ExitCode -eq 0)
    If ($CanValidateFilters -eq $True) {
      Try {
        $CompiledFilters = @(
          New-CompiledFilter -Filter:$Filter
        )
      } Catch {
        $OutputLines.Add(
          'Message=Filter validation failed: {0}' -f
            $PSItem.Exception.Message
        )
        $ExitCode = 4
      }
    }

    $CanContinueDiscovery = [System.Boolean](
      $ExitCode -eq 0
    )
    If ($CanContinueDiscovery -eq $True) {
      $FilterPropNames = @(
        $CompiledFilters | & {
          Process { [System.String]$PSItem.Property }
        }
      )

      Try {
        $RegistryPaths = @(Get-UninstallRegistryPath)
        $IncludesHidden = [System.Boolean](
          $IncludeHidden.IsPresent -eq $True
        )
        $IncludesNameless = [System.Boolean](
          $IncludeNameless.IsPresent -eq $True
        )

        $DiscoverParams = @{
          RegistryPaths   = $RegistryPaths
          CompiledFilters = $CompiledFilters
          Architecture    = $Architecture
        }
        If ($IncludesHidden -eq $True) {
          $DiscoverParams['IncludeHidden'] = $True
        }
        If ($IncludesNameless -eq $True) {
          $DiscoverParams['IncludeNameless'] = $True
        }

        $Applications = @(
          Get-InstalledApplication @DiscoverParams
        )

        $HasMatches = [System.Boolean](
          $Applications.Count -gt 0
        )
        If ($HasMatches -eq $False) {
          $OutputLines.Add(
            'Message=No applications matched the ' +
            'supplied filters. | MatchCount=0'
          )
          $ExitCode = 1
        } Else {
          $Sorted = @(
            $Applications |
              Sort-Object -Property:@(
                'InstallScope',
                'UserSid',
                'DisplayName',
                'RegistryPath'
              )
          )

          $IsListOnly = [System.Boolean](
            $ListOnly.IsPresent -eq $True
          )
          $HasMultipleMatches = [System.Boolean](
            $Sorted.Count -gt 1
          )
          $AllowsMultipleMatches = [System.Boolean](
            $AllowMultipleMatches.IsPresent -eq $True
          )
          $BlocksMultipleMatches = [System.Boolean](
            $HasMultipleMatches -eq $True -and
            $AllowsMultipleMatches -eq $False
          )
          If ($IsListOnly -eq $True) {
            $FieldList = ConvertTo-OutputFieldList `
              -MandatoryFields:$ListFields `
              -Properties:$Properties `
              -FilterPropertyNames:$FilterPropNames

            $Sorted | & { Process {
              $OutputLines.Add(
                (
                  Format-OutputLine `
                    -Record:$PSItem `
                    -FieldList:$FieldList
                )
              )
            }}
          } ElseIf ($BlocksMultipleMatches -eq $True) {
            $FieldList = ConvertTo-OutputFieldList `
              -MandatoryFields:$UninstallFields `
              -Properties:$Properties `
              -FilterPropertyNames:$FilterPropNames

            $Sorted | & { Process {
              $BlockedRecord = $PSItem
              $BlockedRecord | Add-Member `
                -MemberType:'NoteProperty' `
                -Name:'Outcome' `
                -Value:'Blocked' `
                -Force
              $BlockedRecord | Add-Member `
                -MemberType:'NoteProperty' `
                -Name:'ExitCode' `
                -Value:$Null `
                -Force
                $BlockedRecord | Add-Member `
                  -MemberType:'NoteProperty' `
                  -Name:'Message' `
                  -Value:(
                    'Multiple matches found ({0}). Use ' +
                    '-AllowMultipleMatches to proceed.'
                  ) -f $Sorted.Count `
                  -Force

              $OutputLines.Add(
                (
                  Format-OutputLine `
                    -Record:$BlockedRecord `
                    -FieldList:$FieldList
                )
              )
            }}
            $ExitCode = 2
          } Else {
            $HasCustomFlags = [System.Boolean](
              $PSBoundParameters.ContainsKey('EXEFlags')
            )
            $FieldList = ConvertTo-OutputFieldList `
              -MandatoryFields:$UninstallFields `
              -Properties:$Properties `
              -FilterPropertyNames:$FilterPropNames

            Foreach ($App in $Sorted) {
              $HasStartedUninstallAttempts = $True

              Try {
                $UninstallString = `
                  Resolve-UninstallString `
                    -Application:$App `
                    -HasCustomEXEFlags:$HasCustomFlags

                $HasUninstallString = [System.Boolean](
                  $Null -ne $UninstallString
                )
                If ($HasUninstallString -eq $False) {
                  $App | Add-Member `
                    -MemberType:'NoteProperty' `
                    -Name:'Outcome' `
                    -Value:'Failed' `
                    -Force
                  $App | Add-Member `
                    -MemberType:'NoteProperty' `
                    -Name:'ExitCode' `
                    -Value:$Null `
                    -Force
                  $App | Add-Member `
                    -MemberType:'NoteProperty' `
                    -Name:'Message' `
                    -Value:'No uninstall command available.' `
                    -Force
                  $AnyFailed = $True
                } Else {
                  $EXEFlagsToPass = $Null
                  If ($HasCustomFlags -eq $True) {
                    $EXEFlagsToPass = $EXEFlags
                  }
                  $ParsedCommand = `
                    Resolve-UninstallCommand `
                      -UninstallString:$UninstallString `
                      -EXEFlags:$EXEFlagsToPass

                  $HasParsedCommand = [System.Boolean](
                    $Null -ne $ParsedCommand
                  )
                  If ($HasParsedCommand -eq $False) {
                    $App | Add-Member `
                      -MemberType:'NoteProperty' `
                      -Name:'Outcome' `
                      -Value:'Failed' `
                      -Force
                    $App | Add-Member `
                      -MemberType:'NoteProperty' `
                      -Name:'ExitCode' `
                      -Value:$Null `
                      -Force
                    $App | Add-Member `
                      -MemberType:'NoteProperty' `
                      -Name:'Message' `
                      -Value:'Unsupported uninstall command format.' `
                      -Force
                    $AnyFailed = $True
                  } Else {
                    $ExecutionResult = `
                      Invoke-SilentProcess `
                        -FileName:$ParsedCommand.FileName `
                        -Arguments:$ParsedCommand.Arguments `
                        -TimeoutSeconds:$TimeoutSeconds

                    $App | Add-Member `
                      -MemberType:'NoteProperty' `
                      -Name:'Outcome' `
                      -Value:$ExecutionResult.Outcome `
                      -Force
                    $App | Add-Member `
                      -MemberType:'NoteProperty' `
                      -Name:'ExitCode' `
                      -Value:$ExecutionResult.ExitCode `
                      -Force
                    $App | Add-Member `
                      -MemberType:'NoteProperty' `
                      -Name:'Message' `
                      -Value:$ExecutionResult.Message `
                      -Force

                    $ExecutionSucceeded = [System.Boolean](
                      $ExecutionResult.Outcome -eq 'Succeeded'
                    )
                    If ($ExecutionSucceeded -eq $False) {
                      $AnyFailed = $True
                    }
                  }
                }
              } Catch {
                $App | Add-Member `
                  -MemberType:'NoteProperty' `
                  -Name:'Outcome' `
                  -Value:'Failed' `
                  -Force
                $App | Add-Member `
                  -MemberType:'NoteProperty' `
                  -Name:'ExitCode' `
                  -Value:$Null `
                  -Force
                $App | Add-Member `
                  -MemberType:'NoteProperty' `
                  -Name:'Message' `
                  -Value:('Uninstall processing failed: {0}' `
                    -f $PSItem.Exception.Message) `
                  -Force
                $AnyFailed = $True
              }

              $OutputLines.Add(
                (
                  Format-OutputLine `
                    -Record:$App `
                    -FieldList:$FieldList
                )
              )
            }

            $HasAnyFailure = [System.Boolean](
              $AnyFailed -eq $True
            )
            If ($HasAnyFailure -eq $True) {
              $ExitCode = 3
            }
          }
        }
      } Catch {
        $DidStartUninstallAttempts = [System.Boolean](
          $HasStartedUninstallAttempts -eq $True
        )
        If ($DidStartUninstallAttempts -eq $True) {
          $OutputLines.Add(
            (
              'Message=Uninstall processing ' +
              'failed after one or more ' +
              'attempts: {0}'
            ) -f $PSItem.Exception.Message
          )
          $AnyFailed = $True
          $ExitCode = 3
        } Else {
          $OutputLines.Clear()
          $OutputLines.Add(
            (
              'Message=Fatal pre-processing ' +
              'error: {0}'
            ) -f $PSItem.Exception.Message
          )
          $ExitCode = 4
        }
      }
    }

    $RunResult = [StartUninstallerRunResult]::new(
      [System.Int32]$ExitCode,
      [System.String[]]$OutputLines
    )
    $RunResult.PSObject.TypeNames.Insert(
      0, 'StartUninstaller.RunResult'
    )
    $RunResult
    Write-Debug -Message:('[Start-Uninstaller] Exiting Process')
  } End {
    Write-Debug -Message:('[Start-Uninstaller] Entering End')
    Write-Debug -Message:('[Start-Uninstaller] Exiting End')
  }
}

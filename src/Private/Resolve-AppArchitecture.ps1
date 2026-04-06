#Requires -Version 5.1

Function Resolve-AppArchitecture {
  <#
    .SYNOPSIS
      Determines x86 vs x64 for an application using weighted
      heuristic scoring.

    .DESCRIPTION
      Scores architecture hints from registry properties:
        DisplayName     - weight 100
        InstallSource   - weight 25
        InstallLocation - weight 10
        Registry view   - weight 10

      On a 32-bit OS, always returns `x86`. Ties also resolve
      to `x86`.

    .PARAMETER Application
      The application record to inspect.

    .PARAMETER IsWow
      Whether the registry entry came from the WOW6432Node view.

    .EXAMPLE
      Resolve-AppArchitecture -Application:$Application -IsWow:$False

    .OUTPUTS
      [System.String]

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
  [OutputType([System.String])]
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
    [ValidateNotNull()]
    [System.Management.Automation.PSObject]
    $Application,

    [Parameter(
      Mandatory = $True
      , ParameterSetName = 'Default'
      , DontShow = $False
      , HelpMessage = 'See function help.'
      , ValueFromPipeline = $False
      , ValueFromPipelineByPropertyName = $False
      , ValueFromRemainingArguments = $False
    )]
    [System.Boolean]
    $IsWow
  )

  Begin {
    Write-Debug -Message:('[Resolve-AppArchitecture] Entering Begin')
    Write-Debug -Message:('[Resolve-AppArchitecture] Exiting Begin')
  }

  Process {
    Write-Debug -Message:('[Resolve-AppArchitecture] Entering Process')

    Try {
      $Is64BitOperatingSystem = [System.Boolean](Get-Is64BitOperatingSystem)
      $Is32BitOperatingSystem = [System.Boolean](
        $Is64BitOperatingSystem -eq $False
      )
      If ($Is32BitOperatingSystem -eq $True) {
        'x86'
      } Else {
        $RegexOptions = (
          [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor
          [System.Text.RegularExpressions.RegexOptions]::Compiled
        )
        $RegexX86 = [System.Text.RegularExpressions.Regex]::new(
          'x86|x32|\b32-?bit\b',
          $RegexOptions
        )
        $RegexX64 = [System.Text.RegularExpressions.Regex]::new(
          'x64|\b64-?bit\b',
          $RegexOptions
        )
        $RegexProgramFilesX86 = [System.Text.RegularExpressions.Regex]::new(
          'Program Files \(x86\)',
          $RegexOptions
        )
        $RegexProgramFilesX64 = [System.Text.RegularExpressions.Regex]::new(
          'Program Files(?! \(x86\))',
          $RegexOptions
        )
        [System.Int32]$ScoreX86 = 0
        [System.Int32]$ScoreX64 = 0

        $DisplayNameValue = $Null
        $DisplayNameProperty = $Application.PSObject.Properties['DisplayName']
        $HasDisplayName = [System.Boolean](
          $Null -ne $DisplayNameProperty -and
          $Null -ne $DisplayNameProperty.Value
        )
        If ($HasDisplayName -eq $True) {
          $DisplayNameValue = [System.String]$DisplayNameProperty.Value
          $DisplayNameLooksX86 = [System.Boolean](
            $RegexX86.IsMatch($DisplayNameValue) -eq $True
          )
          $DisplayNameLooksX64 = [System.Boolean](
            $RegexX64.IsMatch($DisplayNameValue) -eq $True
          )
          If ($DisplayNameLooksX86 -eq $True) { $ScoreX86 += 100 }
          If ($DisplayNameLooksX64 -eq $True) { $ScoreX64 += 100 }
        }

        $InstallSourceValue = $Null
        $InstallSourceProperty = $Application.PSObject.Properties['InstallSource']
        $HasInstallSource = [System.Boolean](
          $Null -ne $InstallSourceProperty -and
          $Null -ne $InstallSourceProperty.Value
        )
        If ($HasInstallSource -eq $True) {
          $InstallSourceValue = [System.String]$InstallSourceProperty.Value
          $HasInstallSourceText = [System.Boolean](
            [System.String]::IsNullOrEmpty($InstallSourceValue) -eq $False
          )
          If ($HasInstallSourceText -eq $True) {
            $InstallSourceLooksX86 = [System.Boolean](
              $RegexX86.IsMatch($InstallSourceValue) -eq $True
            )
            $InstallSourceLooksX64 = [System.Boolean](
              $RegexX64.IsMatch($InstallSourceValue) -eq $True
            )
            If ($InstallSourceLooksX86 -eq $True) { $ScoreX86 += 25 }
            If ($InstallSourceLooksX64 -eq $True) { $ScoreX64 += 25 }
          }
        }

        $InstallLocationValue = $Null
        $InstallLocationProperty = $Application.PSObject.Properties['InstallLocation']
        $HasInstallLocation = [System.Boolean](
          $Null -ne $InstallLocationProperty -and
          $Null -ne $InstallLocationProperty.Value
        )
        If ($HasInstallLocation -eq $True) {
          $InstallLocationValue = [System.String]$InstallLocationProperty.Value
          $HasInstallLocationText = [System.Boolean](
            [System.String]::IsNullOrEmpty($InstallLocationValue) -eq $False
          )
          If ($HasInstallLocationText -eq $True) {
            $IsProgramFilesX86 = [System.Boolean](
              $RegexProgramFilesX86.IsMatch($InstallLocationValue) -eq $True
            )
            $IsProgramFilesX64 = [System.Boolean](
              $RegexProgramFilesX64.IsMatch($InstallLocationValue) -eq $True
            )
            If ($IsProgramFilesX86 -eq $True) {
              $ScoreX86 += 10
            } ElseIf ($IsProgramFilesX64 -eq $True) {
              $ScoreX64 += 10
            }
          }
        }

        $IsWowEntry = [System.Boolean]($IsWow -eq $True)
        If ($IsWowEntry -eq $True) {
          $ScoreX86 += 10
        } Else {
          $ScoreX64 += 10
        }

        $PrefersX86 = [System.Boolean]($ScoreX86 -ge $ScoreX64)
        If ($PrefersX86 -eq $True) { 'x86' } Else { 'x64' }
      }
    } Catch {
      $ErrorRecord = New-ErrorRecord `
        -ExceptionName:'System.InvalidOperationException' `
        -ExceptionMessage:(
          'Unable to resolve application architecture: {0}' -f
            $PSItem.Exception.Message
        ) `
        -TargetObject:$Application `
        -ErrorId:'ResolveAppArchitectureFailed' `
        -ErrorCategory:([System.Management.Automation.ErrorCategory]::InvalidOperation)
      $PSCmdlet.ThrowTerminatingError($ErrorRecord)
    }

    Write-Debug -Message:('[Resolve-AppArchitecture] Exiting Process')
  }

  End {
    Write-Debug -Message:('[Resolve-AppArchitecture] Entering End')
    Write-Debug -Message:('[Resolve-AppArchitecture] Exiting End')
  }
}

#Requires -Version 5.1

Function Resolve-UninstallString {
  <#
    .SYNOPSIS
      Selects the best uninstall string from an application
      record.

    .DESCRIPTION
      Prefers QuietUninstallString when available and
      `-HasCustomEXEFlags` is not supplied. Falls back to
      UninstallString. Returns `$Null` if neither property is
      available.

    .PARAMETER Application
      The application record to inspect.

    .PARAMETER HasCustomEXEFlags
      Whether the caller supplied custom EXE flags.

    .EXAMPLE
      Resolve-UninstallString -Application:$Application

    .OUTPUTS
      [System.String] or $Null

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
    [System.Management.Automation.PSObject]
    $Application,

    [Parameter(
      Mandatory = $False
      , ParameterSetName = 'Default'
      , DontShow = $False
      , HelpMessage = 'See function help.'
      , ValueFromPipeline = $False
      , ValueFromPipelineByPropertyName = $False
      , ValueFromRemainingArguments = $False
    )]
    [System.Boolean]
    $HasCustomEXEFlags = $False
  )

  Begin {
    Write-Debug -Message:('[Resolve-UninstallString] Entering Begin')
    Write-Debug -Message:('[Resolve-UninstallString] Exiting Begin')
  } Process {
    Write-Debug -Message:('[Resolve-UninstallString] Entering Process')

    $SelectedUninstallString = $Null

    If ($HasCustomEXEFlags -eq $False) {
      $QuietProperty = $Application.PSObject.Properties[
        'QuietUninstallString'
      ]
      $HasUsableQuietString = [System.Boolean](
        $Null -ne $QuietProperty -and
        $Null -ne $QuietProperty.Value -and
        [System.String]::IsNullOrWhiteSpace(
          [System.String]$QuietProperty.Value
        ) -eq $False
      )
      If ($HasUsableQuietString -eq $True) {
        $SelectedUninstallString = [System.String]$QuietProperty.Value
      }
    }

    $HasSelection = [System.Boolean](
      [System.String]::IsNullOrWhiteSpace(
        $SelectedUninstallString
      ) -eq $False
    )
    If ($HasSelection -eq $False) {
      $UninstallProperty = $Application.PSObject.Properties[
        'UninstallString'
      ]
      $HasUsableUninstallString = [System.Boolean](
        $Null -ne $UninstallProperty -and
        $Null -ne $UninstallProperty.Value -and
        [System.String]::IsNullOrWhiteSpace(
          [System.String]$UninstallProperty.Value
        ) -eq $False
      )
      If ($HasUsableUninstallString -eq $True) {
        # --- [ Line Continuation ] ————↴
        $SelectedUninstallString = `
          [System.String]$UninstallProperty.Value
      }
    }

    $SelectedUninstallString

    Write-Debug -Message:('[Resolve-UninstallString] Exiting Process')
  } End {
    Write-Debug -Message:('[Resolve-UninstallString] Entering End')
    Write-Debug -Message:('[Resolve-UninstallString] Exiting End')
  }
}

#Requires -Version 5.1

Function Get-RegistryValueNames {
  <#
    .SYNOPSIS
      Returns the names of all values under a registry key.

    .DESCRIPTION
      Thin seam around RegistryKey.GetValueNames so tests can
      mock registry value enumeration.

    .PARAMETER Key
      The RegistryKey to enumerate values from.

    .EXAMPLE
      Get-RegistryValueNames -Key:$SubKey

    .OUTPUTS
      [System.String[]]

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
  [OutputType([System.String[]])]
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
    [Microsoft.Win32.RegistryKey]
    $Key
  )

  Begin {
    Write-Debug -Message:('[Get-RegistryValueNames] Entering Begin')
    $Strings = @{
      RegistryValueNamesEnumerationFailed =
        'Unable to enumerate registry value names: {0}'
    }
    Import-LocalizedData `
      -BindingVariable:'Strings' `
      -FileName:'Get-RegistryValueNames.strings' `
      -BaseDirectory:$PSScriptRoot `
      -ErrorAction:'SilentlyContinue'
    Write-Debug -Message:('[Get-RegistryValueNames] Exiting Begin')
  } Process {
    Write-Debug -Message:('[Get-RegistryValueNames] Entering Process')
    Try {
      $Key.GetValueNames()
    } Catch {
      $ErrorRecord = New-ErrorRecord `
        -ExceptionName:'System.InvalidOperationException' `
        -ExceptionMessage:(
          $Strings['RegistryValueNamesEnumerationFailed'] -f
            $PSItem.Exception.Message
        ) `
        -TargetObject:$Key `
        -ErrorId:'GetRegistryValueNamesFailed' `
        -ErrorCategory:([System.Management.Automation.ErrorCategory]::ReadError)
      $PSCmdlet.ThrowTerminatingError($ErrorRecord)
    }
    Write-Debug -Message:('[Get-RegistryValueNames] Exiting Process')
  } End {
    Write-Debug -Message:('[Get-RegistryValueNames] Entering End')
    Write-Debug -Message:('[Get-RegistryValueNames] Exiting End')
  }
}

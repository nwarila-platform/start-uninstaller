#Requires -Version 5.1

Function Get-RegistrySubKeyNames {
  <#
    .SYNOPSIS
      Returns the names of all subkeys under a registry key.

    .DESCRIPTION
      Thin seam around RegistryKey.GetSubKeyNames so tests can
      mock registry enumeration.

    .PARAMETER Key
      The RegistryKey to enumerate.

    .EXAMPLE
      Get-RegistrySubKeyNames -Key:$ParentKey

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
    Write-Debug -Message:('[Get-RegistrySubKeyNames] Entering Begin')
    $Strings = @{
      SubKeyNamesEnumerationFailed =
        'Unable to enumerate subkey names: {0}'
    }
    # --- [ Line Continuation ] ————↴
    Import-LocalizedData `
      -BindingVariable:'Strings' `
      -FileName:'Get-RegistrySubKeyNames.strings' `
      -BaseDirectory:$PSScriptRoot `
      -ErrorAction:'SilentlyContinue'
    Write-Debug -Message:('[Get-RegistrySubKeyNames] Exiting Begin')
  } Process {
    Write-Debug -Message:('[Get-RegistrySubKeyNames] Entering Process')
    Try {
      $Key.GetSubKeyNames()
    } Catch {
      $ErrorRecord = New-ErrorRecord `
        -ExceptionName:'System.InvalidOperationException' `
        -ExceptionMessage:(
          $Strings['SubKeyNamesEnumerationFailed'] -f
            $PSItem.Exception.Message
        ) `
        -TargetObject:$Key `
        -ErrorId:'GetRegistrySubKeyNamesFailed' `
        -ErrorCategory:([System.Management.Automation.ErrorCategory]::ReadError)
      $PSCmdlet.ThrowTerminatingError($ErrorRecord)
    }
    Write-Debug -Message:('[Get-RegistrySubKeyNames] Exiting Process')
  } End {
    Write-Debug -Message:('[Get-RegistrySubKeyNames] Entering End')
    Write-Debug -Message:('[Get-RegistrySubKeyNames] Exiting End')
  }
}

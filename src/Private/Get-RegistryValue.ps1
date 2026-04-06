#Requires -Version 5.1

Function Get-RegistryValue {
  <#
    .SYNOPSIS
      Reads a single named value from a registry key.

    .DESCRIPTION
      Thin seam around RegistryKey.GetValue so tests can mock
      individual registry value reads.

    .PARAMETER Key
      The RegistryKey to read from.

    .PARAMETER Name
      The value name to read.

    .EXAMPLE
      Get-RegistryValue -Key:$SubKey -Name:'DisplayName'

    .OUTPUTS
      [System.Object] or $Null

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
  [OutputType([System.Object])]
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
    $Key,

    [Parameter(
      Mandatory = $True
      , ParameterSetName = 'Default'
      , DontShow = $False
      , HelpMessage = 'See function help.'
      , ValueFromPipeline = $False
      , ValueFromPipelineByPropertyName = $False
      , ValueFromRemainingArguments = $False
    )]
    [AllowEmptyString()]
    [System.String]
    $Name
  )

  Begin {
    Write-Debug -Message:('[Get-RegistryValue] Entering Begin')
    $Strings = @{
      RegistryValueReadFailed =
        'Unable to read registry value ''{0}'': {1}'
    }
    Import-LocalizedData `
      -BindingVariable:'Strings' `
      -FileName:'Get-RegistryValue.strings' `
      -BaseDirectory:$PSScriptRoot `
      -ErrorAction:'SilentlyContinue'
    Write-Debug -Message:('[Get-RegistryValue] Exiting Begin')
  } Process {
    Write-Debug -Message:('[Get-RegistryValue] Entering Process')
    Try {
      $Key.GetValue($Name)
    } Catch {
      $ErrorRecord = New-ErrorRecord `
        -ExceptionName:'System.InvalidOperationException' `
        -ExceptionMessage:(
          $Strings['RegistryValueReadFailed'] -f
            $Name,
            $PSItem.Exception.Message
        ) `
        -TargetObject:$Name `
        -ErrorId:'GetRegistryValueFailed' `
        -ErrorCategory:([System.Management.Automation.ErrorCategory]::ReadError)
      $PSCmdlet.ThrowTerminatingError($ErrorRecord)
    }
    Write-Debug -Message:('[Get-RegistryValue] Exiting Process')
  } End {
    Write-Debug -Message:('[Get-RegistryValue] Entering End')
    Write-Debug -Message:('[Get-RegistryValue] Exiting End')
  }
}

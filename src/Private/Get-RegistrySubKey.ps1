#Requires -Version 5.1

Function Get-RegistrySubKey {
  <#
    .SYNOPSIS
      Opens a registry subkey in read-only mode.

    .DESCRIPTION
      Thin seam around RegistryKey.OpenSubKey with the writable
      flag set to `$False` for least-privilege reads.

    .PARAMETER ParentKey
      The parent RegistryKey to open a subkey from.

    .PARAMETER Name
      The subkey name to open.

    .EXAMPLE
      Get-RegistrySubKey -ParentKey:$BaseKey -Name:'Software\Vendor\Product'

    .OUTPUTS
      [Microsoft.Win32.RegistryKey] or $Null

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
  [OutputType([Microsoft.Win32.RegistryKey])]
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
    $ParentKey,

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
    $Name
  )

  Begin {
    Write-Debug -Message:('[Get-RegistrySubKey] Entering Begin')
    Write-Debug -Message:('[Get-RegistrySubKey] Exiting Begin')
  } Process {
    Write-Debug -Message:('[Get-RegistrySubKey] Entering Process')
    Try {
      $ParentKey.OpenSubKey($Name, $False)
    } Catch {
      $ErrorRecord = New-ErrorRecord `
        -ExceptionName:'System.InvalidOperationException' `
        -ExceptionMessage:(
          'Unable to open subkey ''{0}'': {1}' -f
            $Name,
            $PSItem.Exception.Message
        ) `
        -TargetObject:$Name `
        -ErrorId:'GetRegistrySubKeyFailed' `
        -ErrorCategory:([System.Management.Automation.ErrorCategory]::OpenError)
      $PSCmdlet.ThrowTerminatingError($ErrorRecord)
    }
    Write-Debug -Message:('[Get-RegistrySubKey] Exiting Process')
  } End {
    Write-Debug -Message:('[Get-RegistrySubKey] Entering End')
    Write-Debug -Message:('[Get-RegistrySubKey] Exiting End')
  }
}

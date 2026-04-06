#Requires -Version 5.1

Function Get-RegistryBaseKey {
  <#
    .SYNOPSIS
      Opens a registry base key with the specified view.

    .DESCRIPTION
      Thin seam around
      [Microsoft.Win32.RegistryKey]::OpenBaseKey so tests can
      mock registry access.

    .PARAMETER Hive
      The registry hive to open.

    .PARAMETER View
      The registry view to open.

    .EXAMPLE
      Get-RegistryBaseKey `
        -Hive:([Microsoft.Win32.RegistryHive]::LocalMachine) `
        -View:([Microsoft.Win32.RegistryView]::Registry64)

    .OUTPUTS
      [Microsoft.Win32.RegistryKey]

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
    [Microsoft.Win32.RegistryHive]
    $Hive,

    [Parameter(
      Mandatory = $True
      , ParameterSetName = 'Default'
      , DontShow = $False
      , HelpMessage = 'See function help.'
      , ValueFromPipeline = $False
      , ValueFromPipelineByPropertyName = $False
      , ValueFromRemainingArguments = $False
    )]
    [Microsoft.Win32.RegistryView]
    $View
  )

  Begin {
    Write-Debug -Message:('[Get-RegistryBaseKey] Entering Begin')
    Write-Debug -Message:('[Get-RegistryBaseKey] Exiting Begin')
  } Process {
    Write-Debug -Message:('[Get-RegistryBaseKey] Entering Process')

    Try {
      [Microsoft.Win32.RegistryKey]::OpenBaseKey($Hive, $View)
    } Catch {
      $ErrorRecord = New-ErrorRecord `
        -ExceptionName:'System.InvalidOperationException' `
        -ExceptionMessage:(
          'Unable to open base hive ''{0}'' in view ''{1}'': {2}' -f
            $Hive,
            $View,
            $PSItem.Exception.Message
        ) `
        -TargetObject:$Hive `
        -ErrorId:'GetRegistryBaseKeyFailed' `
        -ErrorCategory:([System.Management.Automation.ErrorCategory]::OpenError)
      $PSCmdlet.ThrowTerminatingError($ErrorRecord)
    }

    Write-Debug -Message:('[Get-RegistryBaseKey] Exiting Process')
  } End {
    Write-Debug -Message:('[Get-RegistryBaseKey] Entering End')
    Write-Debug -Message:('[Get-RegistryBaseKey] Exiting End')
  }
}

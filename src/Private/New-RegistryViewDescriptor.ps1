#Requires -Version 5.1

Function New-RegistryViewDescriptor {
  <#
    .SYNOPSIS
      Creates registry view descriptor objects with correct
      32/64-bit view handling.

    .DESCRIPTION
      On a 64-bit OS, emits two descriptors: Registry64 native
      and Registry32 WOW. On a 32-bit OS, emits one descriptor
      in the Default view.

      Each descriptor carries metadata about the hive, path,
      view, install scope, identity, and user-facing registry
      root for downstream consumption.

    .PARAMETER Hive
      The registry hive (LocalMachine or Users).

    .PARAMETER Path
      The registry subkey path.

    .PARAMETER SourcePrefix
      Display label prefix such as HKLM or HKU\<SID>.

    .PARAMETER Is64BitOS
      Whether the OS is 64-bit.

    .PARAMETER InstallScope
      System for HKLM, User for HKU.

    .PARAMETER UserSid
      The user SID for HKU paths. `$Null` for HKLM.

    .PARAMETER UserName
      The resolved username. `$Null` for HKLM or unresolved.

    .PARAMETER UserIdentityStatus
      System, Resolved, or Unresolved.

    .EXAMPLE
      New-RegistryViewDescriptor `
        -Hive:([Microsoft.Win32.RegistryHive]::LocalMachine) `
        -Path:('Software\Microsoft\Windows\CurrentVersion\Uninstall') `
        -SourcePrefix:('HKLM') `
        -Is64BitOS:$True `
        -InstallScope:('System') `
        -UserIdentityStatus:('System')

    .OUTPUTS
      [StartUninstallerRegistryViewDescriptor[]]

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
  [OutputType([StartUninstallerRegistryViewDescriptor[]])]
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
    [ValidateNotNullOrEmpty()]
    [System.String]
    $Path,

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
    $SourcePrefix,

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
    $Is64BitOS,

    [Parameter(
      Mandatory = $True
      , ParameterSetName = 'Default'
      , DontShow = $False
      , HelpMessage = 'See function help.'
      , ValueFromPipeline = $False
      , ValueFromPipelineByPropertyName = $False
      , ValueFromRemainingArguments = $False
    )]
    [ValidateSet('System', 'User')]
    [System.String]
    $InstallScope,

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
    [System.String]
    $UserSid = $Null,

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
    [System.String]
    $UserName = $Null,

    [Parameter(
      Mandatory = $True
      , ParameterSetName = 'Default'
      , DontShow = $False
      , HelpMessage = 'See function help.'
      , ValueFromPipeline = $False
      , ValueFromPipelineByPropertyName = $False
      , ValueFromRemainingArguments = $False
    )]
    [ValidateSet('System', 'Resolved', 'Unresolved')]
    [System.String]
    $UserIdentityStatus
  )

  Begin {
    Write-Debug -Message:('[New-RegistryViewDescriptor] Entering Begin')
    $Strings = @{
      RegistryViewDescriptorCreationFailed =
        'Unable to create registry view descriptor: {0}'
    }
    Import-LocalizedData `
      -BindingVariable:'Strings' `
      -FileName:'New-RegistryViewDescriptor.strings' `
      -BaseDirectory:$PSScriptRoot `
      -ErrorAction:'SilentlyContinue'
    Write-Debug -Message:('[New-RegistryViewDescriptor] Exiting Begin')
  } Process {
    Write-Debug -Message:('[New-RegistryViewDescriptor] Entering Process')
    $IsLocalMachineHive = [System.Boolean](
      $Hive -eq [Microsoft.Win32.RegistryHive]::LocalMachine
    )
    $IsUsersHive = [System.Boolean](
      $Hive -eq [Microsoft.Win32.RegistryHive]::Users
    )
    $DisplayRoot = If ($IsLocalMachineHive -eq $True) {
      'HKLM'
    } ElseIf ($IsUsersHive -eq $True) {
      'HKU'
    } Else {
      [System.String]$Hive
    }

    $Descriptors = [System.Collections.Generic.List[
      StartUninstallerRegistryViewDescriptor
    ]]::new()
    $ShouldEmitDualViews = [System.Boolean]($Is64BitOS -eq $True)

    Try {
      If ($ShouldEmitDualViews -eq $True) {
        $Source64 = [System.String]('{0}64' -f $SourcePrefix)
        $Descriptor64 = [StartUninstallerRegistryViewDescriptor]::new(
          [System.String]$DisplayRoot,
          $Hive,
          [System.String]$Path,
          [Microsoft.Win32.RegistryView]::Registry64,
          $Source64,
          [System.String]$InstallScope,
          $UserSid,
          $UserName,
          [System.String]$UserIdentityStatus
        )
        $Descriptor64.PSObject.TypeNames.Insert(
          0,
          'StartUninstaller.RegistryViewDescriptor'
        )
        $Descriptors.Add($Descriptor64)

        $Source32 = [System.String]('{0}32' -f $SourcePrefix)
        $Descriptor32 = [StartUninstallerRegistryViewDescriptor]::new(
          [System.String]$DisplayRoot,
          $Hive,
          [System.String]$Path,
          [Microsoft.Win32.RegistryView]::Registry32,
          $Source32,
          [System.String]$InstallScope,
          $UserSid,
          $UserName,
          [System.String]$UserIdentityStatus
        )
        $Descriptor32.PSObject.TypeNames.Insert(
          0,
          'StartUninstaller.RegistryViewDescriptor'
        )
        $Descriptors.Add($Descriptor32)
      } Else {
        $Descriptor = [StartUninstallerRegistryViewDescriptor]::new(
          [System.String]$DisplayRoot,
          $Hive,
          [System.String]$Path,
          [Microsoft.Win32.RegistryView]::Default,
          [System.String]$SourcePrefix,
          [System.String]$InstallScope,
          $UserSid,
          $UserName,
          [System.String]$UserIdentityStatus
        )
        $Descriptor.PSObject.TypeNames.Insert(
          0,
          'StartUninstaller.RegistryViewDescriptor'
        )
        $Descriptors.Add($Descriptor)
      }

      [StartUninstallerRegistryViewDescriptor[]]$Descriptors
    } Catch {
      $ErrorRecord = New-ErrorRecord `
        -ExceptionName:'System.InvalidOperationException' `
        -ExceptionMessage:(
          $Strings['RegistryViewDescriptorCreationFailed'] -f
            $PSItem.Exception.Message
        ) `
        -TargetObject:$Path `
        -ErrorId:'NewRegistryViewDescriptorFailed' `
        -ErrorCategory:([System.Management.Automation.ErrorCategory]::InvalidOperation)
      $PSCmdlet.ThrowTerminatingError($ErrorRecord)
    }
    Write-Debug -Message:('[New-RegistryViewDescriptor] Exiting Process')
  } End {
    Write-Debug -Message:('[New-RegistryViewDescriptor] Entering End')
    Write-Debug -Message:('[New-RegistryViewDescriptor] Exiting End')
  }
}

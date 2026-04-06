#Requires -Version 5.1

Function Get-UninstallRegistryPath {
  <#
    .SYNOPSIS
      Builds registry view descriptors for all uninstall search
      locations.

    .DESCRIPTION
      Returns one descriptor per search location. On a 64-bit
      OS, each hive/path produces two descriptors (64-bit and
      32-bit views). On a 32-bit OS, each produces one Default
      view descriptor.

      HKU enumeration includes only supported loaded user SID
      hives. User identity is resolved once per SID during
      descriptor creation.

    .PARAMETER None
      This helper accepts no parameters.

    .EXAMPLE
      Get-UninstallRegistryPath

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
  [OutputType([StartUninstallerRegistryViewDescriptor])]
  Param()

  Begin {
    Write-Debug -Message:('[Get-UninstallRegistryPath] Entering Begin')
    $Strings = @{
      UninstallRegistryDescriptorBuildFailed =
        'Unable to build uninstall registry descriptors: {0}'
    }
    # --- [ Line Continuation ] ————↴
    Import-LocalizedData `
      -BindingVariable:'Strings' `
      -FileName:'Get-UninstallRegistryPath.strings' `
      -BaseDirectory:$PSScriptRoot `
      -ErrorAction:'SilentlyContinue'
    Write-Debug -Message:('[Get-UninstallRegistryPath] Exiting Begin')
  } Process {
    Write-Debug -Message:('[Get-UninstallRegistryPath] Entering Process')
    $SubPath = 'Software\Microsoft\Windows\CurrentVersion\Uninstall'

    Try {
      $Is64BitOperatingSystem = [System.Boolean](Get-Is64BitOperatingSystem)
      $SystemDescriptorParams = @{
        Hive = [Microsoft.Win32.RegistryHive]::LocalMachine
        Path = $SubPath
        SourcePrefix = 'HKLM'
        Is64BitOS = $Is64BitOperatingSystem
        InstallScope = 'System'
        UserSid = $Null
        UserName = $Null
        UserIdentityStatus = 'System'
      }
      $SystemDescriptors = @(New-RegistryViewDescriptor @SystemDescriptorParams)
      $SystemDescriptors

      $LoadedSids = @(
        Get-LoadedUserRegistrySid | & { Process { [System.String]$PSItem } }
      )
      [System.Array]::Sort(
        $LoadedSids,
        [System.StringComparer]::OrdinalIgnoreCase
      )

      $LoadedSids | & { Process {
        $Sid = [System.String]$PSItem
        $UserSid = [System.String]$Sid
        $ResolvedName = Resolve-SidIdentity -Sid:$UserSid
        $HasResolvedName = [System.Boolean]($Null -ne $ResolvedName)
        $IdentityStatus = If ($HasResolvedName -eq $True) {
          'Resolved'
        } Else {
          'Unresolved'
        }

        $UserDescriptorParams = @{
          Hive = [Microsoft.Win32.RegistryHive]::Users
          Path = '{0}\{1}' -f $UserSid, $SubPath
          SourcePrefix = 'HKU\{0}' -f $UserSid
          Is64BitOS = $Is64BitOperatingSystem
          InstallScope = 'User'
          UserSid = $UserSid
          UserName = $ResolvedName
          UserIdentityStatus = $IdentityStatus
        }
        New-RegistryViewDescriptor @UserDescriptorParams
      }}
    } Catch {
      $ErrorRecord = New-ErrorRecord `
        -ExceptionName:'System.InvalidOperationException' `
        -ExceptionMessage:(
          $Strings['UninstallRegistryDescriptorBuildFailed'] -f
            $PSItem.Exception.Message
        ) `
        -TargetObject:$SubPath `
        -ErrorId:'GetUninstallRegistryPathFailed' `
        -ErrorCategory:([System.Management.Automation.ErrorCategory]::InvalidOperation)
      $PSCmdlet.ThrowTerminatingError($ErrorRecord)
    }
    Write-Debug -Message:('[Get-UninstallRegistryPath] Exiting Process')
  } End {
    Write-Debug -Message:('[Get-UninstallRegistryPath] Entering End')
    Write-Debug -Message:('[Get-UninstallRegistryPath] Exiting End')
  }
}

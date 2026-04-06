#Requires -Version 5.1

Function Get-LoadedUserRegistrySid {
  <#
    .SYNOPSIS
      Returns the SIDs of loaded user registry hives, excluding
      service accounts and system entries.

    .DESCRIPTION
      Opens HKU, enumerates subkey names, and keeps only
      SID-shaped user hives. `.DEFAULT`, `*_Classes`, and the
      built-in service-account SIDs are excluded.

      This is a seam function. Tests can mock it to return
      controlled SID lists without touching the real registry.

    .PARAMETER None
      This helper accepts no parameters.

    .EXAMPLE
      Get-LoadedUserRegistrySid

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
  Param()

  Begin {
    Write-Debug -Message:('[Get-LoadedUserRegistrySid] Entering Begin')
    $Strings = @{
      LoadedUserRegistrySidEnumerationFailed =
        'Cannot enumerate loaded user registry hives: {0}'
    }
    Import-LocalizedData `
      -BindingVariable:'Strings' `
      -FileName:'Get-LoadedUserRegistrySid.strings' `
      -BaseDirectory:$PSScriptRoot `
      -ErrorAction:'SilentlyContinue'
    Write-Debug -Message:('[Get-LoadedUserRegistrySid] Exiting Begin')
  } Process {
    Write-Debug -Message:('[Get-LoadedUserRegistrySid] Entering Process')
    $BaseKey = $Null
    $ExcludedNames = @(
      '.DEFAULT',
      'S-1-5-18',
      'S-1-5-19',
      'S-1-5-20'
    )
    $LoadedSids = [System.Collections.Generic.List[System.String]]::new()

    Try {
      $BaseKeyParams = @{
        Hive = [Microsoft.Win32.RegistryHive]::Users
        View = [Microsoft.Win32.RegistryView]::Default
      }
      $BaseKey = Get-RegistryBaseKey @BaseKeyParams

      $AllNames = @(Get-RegistrySubKeyNames -Key:$BaseKey)
      $AllNames | & { Process {
        $Name = [System.String]$PSItem

        $IsExcludedName = [System.Boolean]($ExcludedNames -icontains $Name)
        If ($IsExcludedName -eq $True) { Return }

        $IsClassesHive = [System.Boolean]($Name.EndsWith(
              '_Classes',
              [System.StringComparison]::OrdinalIgnoreCase
            ) -eq $True)
        If ($IsClassesHive -eq $True) { Return }

        Try {
          $Null = [System.Security.Principal.SecurityIdentifier]::new($Name)
          $LoadedSids.Add($Name)
        } Catch {
          # Non-SID HKU entries are intentionally ignored.
        }
      }}
    } Catch {
      $ErrorRecord = New-ErrorRecord `
        -ExceptionName:'System.InvalidOperationException' `
        -ExceptionMessage:(
          $Strings['LoadedUserRegistrySidEnumerationFailed'] -f
            $PSItem.Exception.Message
        ) `
        -TargetObject:([Microsoft.Win32.RegistryHive]::Users) `
        -ErrorId:'GetLoadedUserRegistrySidFailed' `
        -ErrorCategory:([System.Management.Automation.ErrorCategory]::ReadError)
      Write-Warning -Message:$ErrorRecord.Exception.Message
    } Finally {
      $HasBaseKey = [System.Boolean]($Null -ne $BaseKey)
      If ($HasBaseKey -eq $True) { $BaseKey.Dispose() }
    }

    [System.String[]]$LoadedSids
    Write-Debug -Message:('[Get-LoadedUserRegistrySid] Exiting Process')
  } End {
    Write-Debug -Message:('[Get-LoadedUserRegistrySid] Entering End')
    Write-Debug -Message:('[Get-LoadedUserRegistrySid] Exiting End')
  }
}

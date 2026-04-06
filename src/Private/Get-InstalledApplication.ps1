#Requires -Version 5.1

Function Get-InstalledApplication {
  <#
    .SYNOPSIS
      Enumerates registry uninstall entries and returns
      normalized, filtered application records.

    .DESCRIPTION
      For each registry view descriptor, opens the uninstall
      parent key read-only, enumerates subkeys, reads and
      normalizes all named values, stamps synthetic metadata,
      applies hidden/nameless gates, and emits matching object
      application records.

      Filtering is applied early. Non-matching entries never
      incur later uninstall work. All registry access remains
      read-only.

    .PARAMETER RegistryPaths
      Array of registry view descriptor objects from
      Get-UninstallRegistryPath.

    .PARAMETER CompiledFilters
      Array of compiled filter objects from New-CompiledFilter.

    .PARAMETER Architecture
      x86, x64, or Both. Filters by detected app architecture.

    .PARAMETER IncludeHidden
      Include entries where SystemComponent = 1.

    .PARAMETER IncludeNameless
      Include entries with empty or missing DisplayName.

    .EXAMPLE
      Get-InstalledApplication `
        -RegistryPaths:$Descriptors `
        -CompiledFilters:$CompiledFilters

    .OUTPUTS
      [System.Management.Automation.PSObject[]]

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
  [OutputType([System.Management.Automation.PSCustomObject])]
  Param (
    [Parameter(
      Mandatory = $True
      , ParameterSetName = 'Default'
      , DontShow = $False
      , HelpMessage = 'See function help.'
      , Position = 0
      , ValueFromPipeline = $False
      , ValueFromPipelineByPropertyName = $False
      , ValueFromRemainingArguments = $False
    )]
    [System.Management.Automation.PSObject[]]
    $RegistryPaths,

    [Parameter(
      Mandatory = $True
      , ParameterSetName = 'Default'
      , DontShow = $False
      , HelpMessage = 'See function help.'
      , Position = 1
      , ValueFromPipeline = $False
      , ValueFromPipelineByPropertyName = $False
      , ValueFromRemainingArguments = $False
    )]
    [AllowEmptyCollection()]
    [System.Management.Automation.PSObject[]]
    $CompiledFilters,

    [Parameter(
      Mandatory = $False
      , ParameterSetName = 'Default'
      , DontShow = $False
      , HelpMessage = 'See function help.'
      , Position = 2
      , ValueFromPipeline = $False
      , ValueFromPipelineByPropertyName = $False
      , ValueFromRemainingArguments = $False
    )]
    [ValidateSet('x86', 'x64', 'Both')]
    [System.String]
    $Architecture = 'Both',

    [Parameter(
      Mandatory = $False
      , ParameterSetName = 'Default'
      , DontShow = $False
      , HelpMessage = 'See function help.'
      , Position = 3
      , ValueFromPipeline = $False
      , ValueFromPipelineByPropertyName = $False
      , ValueFromRemainingArguments = $False
    )]
    [System.Management.Automation.SwitchParameter]
    $IncludeHidden,

    [Parameter(
      Mandatory = $False
      , ParameterSetName = 'Default'
      , DontShow = $False
      , HelpMessage = 'See function help.'
      , Position = 4
      , ValueFromPipeline = $False
      , ValueFromPipelineByPropertyName = $False
      , ValueFromRemainingArguments = $False
    )]
    [System.Management.Automation.SwitchParameter]
    $IncludeNameless
  )

  Begin {
    Write-Debug -Message:('[Get-InstalledApplication] Entering Begin')
    $Strings = @{
      DescriptorAccessFailed =
        'Cannot access {0}: {1}'
      SubKeyReadFailed =
        'Cannot read subkey ''{0}'': {1}'
    }
    Import-LocalizedData `
      -BindingVariable:'Strings' `
      -FileName:'Get-InstalledApplication.strings' `
      -BaseDirectory:$PSScriptRoot `
      -ErrorAction:'SilentlyContinue'
    Write-Debug -Message:('[Get-InstalledApplication] Exiting Begin')
  } Process {
    Write-Debug -Message:('[Get-InstalledApplication] Entering Process')
    $RegistryPaths | & { Process {
      $Descriptor = $PSItem
      $BaseKey = $Null
      $ParentKey = $Null

      Try {
        $BaseKey = Get-RegistryBaseKey `
          -Hive:$Descriptor.Hive `
          -View:$Descriptor.View

        $ParentKey = Get-RegistrySubKey `
          -ParentKey:$BaseKey `
          -Name:$Descriptor.Path

        $MissingParentKey = [System.Boolean]($Null -eq $ParentKey)
        If ($MissingParentKey -eq $True) { Return }

        $SubKeyNames = @(Get-RegistrySubKeyNames -Key:$ParentKey)
        $SubKeyNames | & { Process {
          $SubKeyName = [System.String]$PSItem
          $SubKey = $Null

          Try {
            $SubKey = Get-RegistrySubKey `
              -ParentKey:$ParentKey `
              -Name:$SubKeyName

            $MissingSubKey = [System.Boolean]($Null -eq $SubKey)
            If ($MissingSubKey -eq $True) { Return }

            $ValueNames = @(Get-RegistryValueNames -Key:$SubKey)
            $Props = [System.Collections.Specialized.OrderedDictionary]::new(
              [System.StringComparer]::OrdinalIgnoreCase
            )

            $ValueNames | & { Process {
              $ValueName = [System.String]$PSItem
              $IsUnnamedDefaultValue = [System.Boolean]($ValueName.Length -eq 0)
              If ($IsUnnamedDefaultValue -eq $True) { Return }

              $RawValue = Get-RegistryValue -Key:$SubKey -Name:$ValueName
              $NormalizedValue = ConvertTo-NormalizedRegistryValue -Value:$RawValue

              $HasNormalizedValue = [System.Boolean]($Null -ne $NormalizedValue)
              If ($HasNormalizedValue -eq $True) {
                $Props[$ValueName] = $NormalizedValue
              }
            }}

            $DisplayName = $Null
            $HasDisplayNameProperty = [System.Boolean](
              $Props.Contains('DisplayName') -eq $True
            )
            If ($HasDisplayNameProperty -eq $True) {
              $DisplayName = [System.String]$Props['DisplayName']
            }
            $HasName = [System.Boolean](
              [System.String]::IsNullOrWhiteSpace($DisplayName) -eq $False
            )
            $AllowsNameless = [System.Boolean](
              $IncludeNameless.IsPresent -eq $True
            )
            $ExcludeNamelessEntry = [System.Boolean](
              $HasName -eq $False -and
              $AllowsNameless -eq $False
            )
            If ($ExcludeNamelessEntry -eq $True) {
              Return
            }

            $SystemComponent = $Null
            $HasSystemComponent = [System.Boolean](
              $Props.Contains('SystemComponent') -eq $True
            )
            If ($HasSystemComponent -eq $True) {
              $SystemComponent = $Props['SystemComponent']
            }
            $IsHidden = [System.Boolean](
              $Null -ne $SystemComponent -and
              [System.String]$SystemComponent -eq '1'
            )
            $AllowsHidden = [System.Boolean](
              $IncludeHidden.IsPresent -eq $True
            )
            $ExcludeHiddenEntry = [System.Boolean](
              $IsHidden -eq $True -and
              $AllowsHidden -eq $False
            )
            If ($ExcludeHiddenEntry -eq $True) {
              Return
            }

            $App = New-Object -TypeName:'System.Management.Automation.PSObject' -Property:$Props

            $App | Add-Member -MemberType:'NoteProperty' `
              -Name:'AppArch' -Value:$Null -Force
            $App | Add-Member -MemberType:'NoteProperty' `
              -Name:'InstallScope' -Value:$Descriptor.InstallScope -Force
            $App | Add-Member -MemberType:'NoteProperty' `
              -Name:'IsHidden' -Value:$IsHidden -Force
            $App | Add-Member -MemberType:'NoteProperty' `
              -Name:'RegistryPath' -Value:(
                Format-RegistryPath `
                  -DisplayRoot:$Descriptor.DisplayRoot `
                  -Path:$Descriptor.Path `
                  -SubKeyName:$SubKeyName
              ) -Force
            $App | Add-Member -MemberType:'NoteProperty' `
              -Name:'UserIdentityStatus' `
              -Value:$Descriptor.UserIdentityStatus -Force
            $App | Add-Member -MemberType:'NoteProperty' `
              -Name:'UserName' `
              -Value:$Descriptor.UserName -Force
            $App | Add-Member -MemberType:'NoteProperty' `
              -Name:'UserSid' `
              -Value:$Descriptor.UserSid -Force

            $ParsedVersion = $Null
            $DisplayVersion = $Null
            $DisplayVersionProperty = $App.PSObject.Properties['DisplayVersion']
            $HasDisplayVersion = [System.Boolean](
              $Null -ne $DisplayVersionProperty -and
              $Null -ne $DisplayVersionProperty.Value
            )
            If ($HasDisplayVersion -eq $True) {
              $DisplayVersion = [System.String]$DisplayVersionProperty.Value
              [System.Version]::TryParse(
                $DisplayVersion,
                [ref]$ParsedVersion
              ) | Out-Null
            }
            $App | Add-Member -MemberType:'NoteProperty' `
              -Name:'_ParsedDisplayVersion' `
              -Value:$ParsedVersion -Force
            $App | Add-Member -MemberType:'NoteProperty' `
              -Name:'_RegistryHive' `
              -Value:$Descriptor.Hive -Force
            $App | Add-Member -MemberType:'NoteProperty' `
              -Name:'_RegistryView' `
              -Value:$Descriptor.View -Force
            $App | Add-Member -MemberType:'NoteProperty' `
              -Name:'_RegistrySource' `
              -Value:$Descriptor.Source -Force

            $IsWow = [System.Boolean](
              $Descriptor.View -eq
                [Microsoft.Win32.RegistryView]::Registry32
            )
            $AppArch = Resolve-AppArchitecture `
              -Application:$App -IsWow:$IsWow
            $App.AppArch = $AppArch

            $ShouldFilterByArchitecture = [System.Boolean](
              $Architecture -ne 'Both'
            )
            $ArchitectureMismatch = [System.Boolean](
              $ShouldFilterByArchitecture -eq $True -and
              $AppArch -ne $Architecture
            )
            If ($ArchitectureMismatch -eq $True) {
              Return
            }

            $Matched = [System.Boolean](
              Test-ApplicationMatch `
                -Application:$App `
                -CompiledFilters:$CompiledFilters
            )
            If ($Matched -eq $False) { Return }

            $App
          } Catch {
            $RegistryPathText = Format-RegistryPath `
              -DisplayRoot:$Descriptor.DisplayRoot `
              -Path:$Descriptor.Path `
              -SubKeyName:$SubKeyName
            $ErrorRecord = New-ErrorRecord `
              -ExceptionName:'System.InvalidOperationException' `
              -ExceptionMessage:(
                $Strings['SubKeyReadFailed'] -f
                  $RegistryPathText,
                  $PSItem.Exception.Message
              ) `
              -TargetObject:$RegistryPathText `
              -ErrorId:'GetInstalledApplicationSubKeyReadFailed' `
              -ErrorCategory:([System.Management.Automation.ErrorCategory]::ReadError)
            Write-Warning -Message:$ErrorRecord.Exception.Message
          } Finally {
            $HasSubKey = [System.Boolean]($Null -ne $SubKey)
            If ($HasSubKey -eq $True) { $SubKey.Dispose() }
          }
        }}
      } Catch {
        $RegistryPathText = Format-RegistryPath `
          -DisplayRoot:$Descriptor.DisplayRoot `
          -Path:$Descriptor.Path
        $ErrorRecord = New-ErrorRecord `
          -ExceptionName:'System.InvalidOperationException' `
          -ExceptionMessage:(
            $Strings['DescriptorAccessFailed'] -f
              $RegistryPathText,
              $PSItem.Exception.Message
          ) `
          -TargetObject:$RegistryPathText `
          -ErrorId:'GetInstalledApplicationDescriptorAccessFailed' `
          -ErrorCategory:([System.Management.Automation.ErrorCategory]::ReadError)
        Write-Warning -Message:$ErrorRecord.Exception.Message
      } Finally {
        $HasParentKey = [System.Boolean]($Null -ne $ParentKey)
        $HasBaseKey = [System.Boolean]($Null -ne $BaseKey)
        If ($HasParentKey -eq $True) { $ParentKey.Dispose() }
        If ($HasBaseKey -eq $True) { $BaseKey.Dispose() }
      }
    }}
    Write-Debug -Message:('[Get-InstalledApplication] Exiting Process')
  } End {
    Write-Debug -Message:('[Get-InstalledApplication] Entering End')
    Write-Debug -Message:('[Get-InstalledApplication] Exiting End')
  }
}

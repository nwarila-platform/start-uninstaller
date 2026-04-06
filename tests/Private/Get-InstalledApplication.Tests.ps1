BeforeAll {
  . "$PSScriptRoot\..\..\build\Start-Uninstaller.Functions.ps1"
}

Describe 'Get-InstalledApplication' {

  # ── Shared mock infrastructure ─────────────────────────────────

  BeforeAll {
    # Track Dispose calls
    $Script:DisposeLog = [System.Collections.ArrayList]::new()

    Function New-MockRegistryKey {
      Param(
        [System.String]$Name = 'MockKey'
      )
      $Key = [PSCustomObject]@{ Name = $Name; Disposed = $False }
      $Key | Add-Member -MemberType:'ScriptMethod' -Name:'Dispose' -Value:{
        $This.Disposed = $True
        $Script:DisposeLog.Add($This.Name) | Out-Null
      } -Force
      Return $Key
    }

    Function New-TestDescriptor {
      Param(
        [System.String]$Source = 'HKLM64',
        [System.String]$DisplayRoot = 'HKLM',
        [Microsoft.Win32.RegistryHive]$Hive =
          [Microsoft.Win32.RegistryHive]::LocalMachine,
        [Microsoft.Win32.RegistryView]$View =
          [Microsoft.Win32.RegistryView]::Registry64,
        [System.String]$InstallScope = 'System',
        [System.String]$UserSid = $Null,
        [System.String]$UserName = $Null,
        [System.String]$UserIdentityStatus = 'System'
      )
      [PSCustomObject]@{
        PSTypeName         = 'StartUninstaller.RegistryViewDescriptor'
        DisplayRoot        = $DisplayRoot
        Hive               = $Hive
        Path               = 'Software\Microsoft\Windows\CurrentVersion\Uninstall'
        View               = $View
        Source             = $Source
        InstallScope       = $InstallScope
        UserSid            = $UserSid
        UserName           = $UserName
        UserIdentityStatus = $UserIdentityStatus
      }
    }
  }

  BeforeEach {
    $Script:DisposeLog.Clear()
  }

  # ── Basic happy path ───────────────────────────────────────────

  Context 'Basic discovery with one application' {
    BeforeAll {
      $MockBaseKey = New-MockRegistryKey -Name:'BaseKey'
      $MockParentKey = New-MockRegistryKey -Name:'ParentKey'
      $MockSubKey = New-MockRegistryKey -Name:'SubKey_App1'

      Mock Get-RegistryBaseKey { $MockBaseKey }
      Mock Get-RegistrySubKey -RemoveParameterType 'ParentKey' {
        Param($ParentKey, $Name)
        If ($Name -eq 'Software\Microsoft\Windows\CurrentVersion\Uninstall') {
          Return $MockParentKey
        }
        If ($Name -eq 'App1') {
          Return $MockSubKey
        }
        Return $Null
      }
      Mock Get-RegistrySubKeyNames -RemoveParameterType 'Key' { @('App1') }
      Mock Get-RegistryValueNames -RemoveParameterType 'Key' { @('DisplayName', 'DisplayVersion', 'Publisher') }
      Mock Get-RegistryValue -RemoveParameterType 'Key' {
        Param($Key, $Name)
        Switch ($Name) {
          'DisplayName'    { 'Test Application' }
          'DisplayVersion' { '2.1.0' }
          'Publisher'      { 'Test Corp' }
        }
      }
      Mock ConvertTo-NormalizedRegistryValue {
        Param($Value) Return $Value
      }
      Mock Get-Is64BitOperatingSystem { $True }
      Mock Resolve-AppArchitecture { 'x64' }

      $Descriptor = New-TestDescriptor
      $Filters = @()
      $Results = @(Get-InstalledApplication `
        -RegistryPaths:@($Descriptor) `
        -CompiledFilters:$Filters)
    }

    It 'Returns one application record' {
      $Results.Count | Should -Be 1
    }

    It 'Application has correct DisplayName' {
      $Results[0].DisplayName | Should -Be 'Test Application'
    }

    It 'Application has correct DisplayVersion' {
      $Results[0].DisplayVersion | Should -Be '2.1.0'
    }

    It 'Application has correct Publisher' {
      $Results[0].Publisher | Should -Be 'Test Corp'
    }

    It 'Uses the registry subkey seam for parent and child key opens' {
      $Null = Get-InstalledApplication `
        -RegistryPaths:@($Descriptor) `
        -CompiledFilters:$Filters

      Should -Invoke -CommandName 'Get-RegistrySubKey' -Times 2 -Exactly
    }
  }

  # ── Synthetic metadata stamped ─────────────────────────────────

  Context 'Synthetic metadata stamped on application record' {
    BeforeAll {
      $MockBaseKey = New-MockRegistryKey -Name:'BaseKey'
      $MockParentKey = New-MockRegistryKey -Name:'ParentKey'
      $MockSubKey = New-MockRegistryKey -Name:'SubKey'

      Mock Get-RegistryBaseKey { $MockBaseKey }
      Mock Get-RegistrySubKey -RemoveParameterType 'ParentKey' {
        Param($ParentKey, $Name)
        If ($Name -like '*Uninstall') { Return $MockParentKey }
        Return $MockSubKey
      }
      Mock Get-RegistrySubKeyNames -RemoveParameterType 'Key' { @('MyApp') }
      Mock Get-RegistryValueNames -RemoveParameterType 'Key' { @('DisplayName') }
      Mock Get-RegistryValue -RemoveParameterType 'Key' { 'SomeApp' }
      Mock ConvertTo-NormalizedRegistryValue { Param($Value) $Value }
      Mock Get-Is64BitOperatingSystem { $True }
      Mock Resolve-AppArchitecture { 'x86' }

      $Descriptor = New-TestDescriptor `
        -Source:'HKLM64' `
        -InstallScope:'System' `
        -UserIdentityStatus:'System'

      $Results = @(Get-InstalledApplication `
        -RegistryPaths:@($Descriptor) `
        -CompiledFilters:@())
    }

    It 'Stamps AppArch' {
      $Results[0].PSObject.Properties['AppArch'] | Should -Not -BeNullOrEmpty
      $Results[0].AppArch | Should -Be 'x86'
    }

    It 'Stamps InstallScope from descriptor' {
      $Results[0].InstallScope | Should -Be 'System'
    }

    It 'Stamps IsHidden' {
      $Results[0].PSObject.Properties['IsHidden'] | Should -Not -BeNullOrEmpty
      $Results[0].IsHidden | Should -BeFalse
    }

    It 'Stamps RegistryPath with DisplayRoot, Path, and SubKeyName' {
      $Results[0].RegistryPath | Should -BeLike '*HKLM*Uninstall*MyApp'
    }

    It 'Stamps UserIdentityStatus' {
      $Results[0].UserIdentityStatus | Should -Be 'System'
    }

    It 'Stamps UserName' {
      $Results[0].PSObject.Properties['UserName'] | Should -Not -BeNullOrEmpty
    }

    It 'Stamps UserSid' {
      $Results[0].PSObject.Properties['UserSid'] | Should -Not -BeNullOrEmpty
    }
  }

  # ── _ParsedDisplayVersion populated ────────────────────────────

  Context '_ParsedDisplayVersion populated' {
    BeforeAll {
      $MockBaseKey = New-MockRegistryKey -Name:'BaseKey'
      $MockParentKey = New-MockRegistryKey -Name:'ParentKey'
      $MockSubKey = New-MockRegistryKey -Name:'SubKey'

      Mock Get-RegistryBaseKey { $MockBaseKey }
      Mock Get-RegistrySubKey -RemoveParameterType 'ParentKey' {
        Param($ParentKey, $Name)
        If ($Name -like '*Uninstall') { Return $MockParentKey }
        Return $MockSubKey
      }
      Mock Get-RegistrySubKeyNames -RemoveParameterType 'Key' { @('App1') }
      Mock Get-RegistryValueNames -RemoveParameterType 'Key' { @('DisplayName', 'DisplayVersion') }
      Mock Get-RegistryValue -RemoveParameterType 'Key' {
        Param($Key, $Name)
        Switch ($Name) {
          'DisplayName'    { 'Test' }
          'DisplayVersion' { '3.2.1.0' }
        }
      }
      Mock ConvertTo-NormalizedRegistryValue { Param($Value) $Value }
      Mock Get-Is64BitOperatingSystem { $True }
      Mock Resolve-AppArchitecture { 'x64' }

      $Results = @(Get-InstalledApplication `
        -RegistryPaths:@(New-TestDescriptor) `
        -CompiledFilters:@())
    }

    It 'Populates _ParsedDisplayVersion as [version]' {
      $Results[0]._ParsedDisplayVersion | Should -BeOfType ([System.Version])
      $Results[0]._ParsedDisplayVersion | Should -Be ([System.Version]'3.2.1.0')
    }
  }

  Context '_ParsedDisplayVersion is null for unparseable version' {
    BeforeAll {
      $MockBaseKey = New-MockRegistryKey -Name:'BaseKey'
      $MockParentKey = New-MockRegistryKey -Name:'ParentKey'
      $MockSubKey = New-MockRegistryKey -Name:'SubKey'

      Mock Get-RegistryBaseKey { $MockBaseKey }
      Mock Get-RegistrySubKey -RemoveParameterType 'ParentKey' {
        Param($ParentKey, $Name)
        If ($Name -like '*Uninstall') { Return $MockParentKey }
        Return $MockSubKey
      }
      Mock Get-RegistrySubKeyNames -RemoveParameterType 'Key' { @('App1') }
      Mock Get-RegistryValueNames -RemoveParameterType 'Key' { @('DisplayName', 'DisplayVersion') }
      Mock Get-RegistryValue -RemoveParameterType 'Key' {
        Param($Key, $Name)
        Switch ($Name) {
          'DisplayName'    { 'Test' }
          'DisplayVersion' { 'beta-3.2' }
        }
      }
      Mock ConvertTo-NormalizedRegistryValue { Param($Value) $Value }
      Mock Get-Is64BitOperatingSystem { $True }
      Mock Resolve-AppArchitecture { 'x64' }

      $Results = @(Get-InstalledApplication `
        -RegistryPaths:@(New-TestDescriptor) `
        -CompiledFilters:@())
    }

    It '_ParsedDisplayVersion is $null' {
      $Results[0]._ParsedDisplayVersion | Should -BeNullOrEmpty
    }

    It 'DisplayVersion string is preserved' {
      $Results[0].DisplayVersion | Should -Be 'beta-3.2'
    }
  }

  # ── Nameless gate ──────────────────────────────────────────────

  Context 'Nameless gate: excluded by default' {
    BeforeAll {
      $MockBaseKey = New-MockRegistryKey -Name:'BaseKey'
      $MockParentKey = New-MockRegistryKey -Name:'ParentKey'
      $MockSubKey = New-MockRegistryKey -Name:'SubKey'

      Mock Get-RegistryBaseKey { $MockBaseKey }
      Mock Get-RegistrySubKey -RemoveParameterType 'ParentKey' {
        Param($ParentKey, $Name)
        If ($Name -like '*Uninstall') { Return $MockParentKey }
        Return $MockSubKey
      }
      Mock Get-RegistrySubKeyNames -RemoveParameterType 'Key' { @('Nameless1') }
      Mock Get-RegistryValueNames -RemoveParameterType 'Key' { @('Publisher') }
      Mock Get-RegistryValue -RemoveParameterType 'Key' { 'SomeCorp' }
      Mock ConvertTo-NormalizedRegistryValue { Param($Value) $Value }
      Mock Get-Is64BitOperatingSystem { $True }
      Mock Resolve-AppArchitecture { 'x64' }

      $Results = @(Get-InstalledApplication `
        -RegistryPaths:@(New-TestDescriptor) `
        -CompiledFilters:@())
    }

    It 'Excludes entry with no DisplayName' {
      $Results.Count | Should -Be 0
    }
  }

  Context 'Nameless gate: included with -IncludeNameless' {
    BeforeAll {
      $MockBaseKey = New-MockRegistryKey -Name:'BaseKey'
      $MockParentKey = New-MockRegistryKey -Name:'ParentKey'
      $MockSubKey = New-MockRegistryKey -Name:'SubKey'

      Mock Get-RegistryBaseKey { $MockBaseKey }
      Mock Get-RegistrySubKey -RemoveParameterType 'ParentKey' {
        Param($ParentKey, $Name)
        If ($Name -like '*Uninstall') { Return $MockParentKey }
        Return $MockSubKey
      }
      Mock Get-RegistrySubKeyNames -RemoveParameterType 'Key' { @('Nameless1') }
      Mock Get-RegistryValueNames -RemoveParameterType 'Key' { @('Publisher') }
      Mock Get-RegistryValue -RemoveParameterType 'Key' { 'SomeCorp' }
      Mock ConvertTo-NormalizedRegistryValue { Param($Value) $Value }
      Mock Get-Is64BitOperatingSystem { $True }
      Mock Resolve-AppArchitecture { 'x64' }

      $Results = @(Get-InstalledApplication `
        -RegistryPaths:@(New-TestDescriptor) `
        -CompiledFilters:@() `
        -IncludeNameless)
    }

    It 'Includes entry with no DisplayName' {
      $Results.Count | Should -Be 1
    }
  }

  Context 'Nameless gate: empty DisplayName excluded by default' {
    BeforeAll {
      $MockBaseKey = New-MockRegistryKey -Name:'BaseKey'
      $MockParentKey = New-MockRegistryKey -Name:'ParentKey'
      $MockSubKey = New-MockRegistryKey -Name:'SubKey'

      Mock Get-RegistryBaseKey { $MockBaseKey }
      Mock Get-RegistrySubKey -RemoveParameterType 'ParentKey' {
        Param($ParentKey, $Name)
        If ($Name -like '*Uninstall') { Return $MockParentKey }
        Return $MockSubKey
      }
      Mock Get-RegistrySubKeyNames -RemoveParameterType 'Key' { @('EmptyName') }
      Mock Get-RegistryValueNames -RemoveParameterType 'Key' { @('DisplayName') }
      Mock Get-RegistryValue -RemoveParameterType 'Key' { '' }
      Mock ConvertTo-NormalizedRegistryValue { Param($Value) $Value }
      Mock Get-Is64BitOperatingSystem { $True }

      $Results = @(Get-InstalledApplication `
        -RegistryPaths:@(New-TestDescriptor) `
        -CompiledFilters:@())
    }

    It 'Excludes entry with empty DisplayName' {
      $Results.Count | Should -Be 0
    }
  }

  Context 'Nameless gate: whitespace-only DisplayName excluded by default' {
    BeforeAll {
      $MockBaseKey = New-MockRegistryKey -Name:'BaseKey'
      $MockParentKey = New-MockRegistryKey -Name:'ParentKey'
      $MockSubKey = New-MockRegistryKey -Name:'SubKey'

      Mock Get-RegistryBaseKey { $MockBaseKey }
      Mock Get-RegistrySubKey -RemoveParameterType 'ParentKey' {
        Param($ParentKey, $Name)
        If ($Name -like '*Uninstall') { Return $MockParentKey }
        Return $MockSubKey
      }
      Mock Get-RegistrySubKeyNames -RemoveParameterType 'Key' { @('WhiteName') }
      Mock Get-RegistryValueNames -RemoveParameterType 'Key' { @('DisplayName') }
      Mock Get-RegistryValue -RemoveParameterType 'Key' { '   ' }
      Mock ConvertTo-NormalizedRegistryValue { Param($Value) $Value }
      Mock Get-Is64BitOperatingSystem { $True }

      $Results = @(Get-InstalledApplication `
        -RegistryPaths:@(New-TestDescriptor) `
        -CompiledFilters:@())
    }

    It 'Excludes entry with whitespace-only DisplayName' {
      $Results.Count | Should -Be 0
    }
  }

  # ── Hidden gate ────────────────────────────────────────────────

  Context 'Hidden gate: excluded by default' {
    BeforeAll {
      $MockBaseKey = New-MockRegistryKey -Name:'BaseKey'
      $MockParentKey = New-MockRegistryKey -Name:'ParentKey'
      $MockSubKey = New-MockRegistryKey -Name:'SubKey'

      Mock Get-RegistryBaseKey { $MockBaseKey }
      Mock Get-RegistrySubKey -RemoveParameterType 'ParentKey' {
        Param($ParentKey, $Name)
        If ($Name -like '*Uninstall') { Return $MockParentKey }
        Return $MockSubKey
      }
      Mock Get-RegistrySubKeyNames -RemoveParameterType 'Key' { @('Hidden1') }
      Mock Get-RegistryValueNames -RemoveParameterType 'Key' { @('DisplayName', 'SystemComponent') }
      Mock Get-RegistryValue -RemoveParameterType 'Key' {
        Param($Key, $Name)
        Switch ($Name) {
          'DisplayName'     { 'Hidden App' }
          'SystemComponent' { 1 }
        }
      }
      Mock ConvertTo-NormalizedRegistryValue {
        Param($Value)
        # Numeric normalization: convert to string
        If ($Value -is [System.Int32]) { Return [System.String]$Value }
        Return $Value
      }
      Mock Get-Is64BitOperatingSystem { $True }
      Mock Resolve-AppArchitecture { 'x64' }

      $Results = @(Get-InstalledApplication `
        -RegistryPaths:@(New-TestDescriptor) `
        -CompiledFilters:@())
    }

    It 'Excludes hidden entry when SystemComponent = 1' {
      $Results.Count | Should -Be 0
    }
  }

  Context 'Hidden gate: included with -IncludeHidden' {
    BeforeAll {
      $MockBaseKey = New-MockRegistryKey -Name:'BaseKey'
      $MockParentKey = New-MockRegistryKey -Name:'ParentKey'
      $MockSubKey = New-MockRegistryKey -Name:'SubKey'

      Mock Get-RegistryBaseKey { $MockBaseKey }
      Mock Get-RegistrySubKey -RemoveParameterType 'ParentKey' {
        Param($ParentKey, $Name)
        If ($Name -like '*Uninstall') { Return $MockParentKey }
        Return $MockSubKey
      }
      Mock Get-RegistrySubKeyNames -RemoveParameterType 'Key' { @('Hidden1') }
      Mock Get-RegistryValueNames -RemoveParameterType 'Key' { @('DisplayName', 'SystemComponent') }
      Mock Get-RegistryValue -RemoveParameterType 'Key' {
        Param($Key, $Name)
        Switch ($Name) {
          'DisplayName'     { 'Hidden App' }
          'SystemComponent' { 1 }
        }
      }
      Mock ConvertTo-NormalizedRegistryValue {
        Param($Value)
        If ($Value -is [System.Int32]) { Return [System.String]$Value }
        Return $Value
      }
      Mock Get-Is64BitOperatingSystem { $True }
      Mock Resolve-AppArchitecture { 'x64' }

      $Results = @(Get-InstalledApplication `
        -RegistryPaths:@(New-TestDescriptor) `
        -CompiledFilters:@() `
        -IncludeHidden)
    }

    It 'Includes hidden entry with -IncludeHidden' {
      $Results.Count | Should -Be 1
    }

    It 'Stamps IsHidden as $True' {
      $Results[0].IsHidden | Should -BeTrue
    }
  }

  Context 'Hidden gate: SystemComponent absent means not hidden' {
    BeforeAll {
      $MockBaseKey = New-MockRegistryKey -Name:'BaseKey'
      $MockParentKey = New-MockRegistryKey -Name:'ParentKey'
      $MockSubKey = New-MockRegistryKey -Name:'SubKey'

      Mock Get-RegistryBaseKey { $MockBaseKey }
      Mock Get-RegistrySubKey -RemoveParameterType 'ParentKey' {
        Param($ParentKey, $Name)
        If ($Name -like '*Uninstall') { Return $MockParentKey }
        Return $MockSubKey
      }
      Mock Get-RegistrySubKeyNames -RemoveParameterType 'Key' { @('NotHidden') }
      Mock Get-RegistryValueNames -RemoveParameterType 'Key' { @('DisplayName') }
      Mock Get-RegistryValue -RemoveParameterType 'Key' { 'Visible App' }
      Mock ConvertTo-NormalizedRegistryValue { Param($Value) $Value }
      Mock Get-Is64BitOperatingSystem { $True }
      Mock Resolve-AppArchitecture { 'x64' }

      $Results = @(Get-InstalledApplication `
        -RegistryPaths:@(New-TestDescriptor) `
        -CompiledFilters:@())
    }

    It 'Includes entry without SystemComponent' {
      $Results.Count | Should -Be 1
    }

    It 'IsHidden is $False' {
      $Results[0].IsHidden | Should -BeFalse
    }
  }

  # ── Architecture filter ────────────────────────────────────────

  Context 'Architecture filter: x64 only' {
    BeforeAll {
      $MockBaseKey = New-MockRegistryKey -Name:'BaseKey'
      $MockParentKey = New-MockRegistryKey -Name:'ParentKey'
      $MockSubKey = New-MockRegistryKey -Name:'SubKey'

      Mock Get-RegistryBaseKey { $MockBaseKey }
      Mock Get-RegistrySubKey -RemoveParameterType 'ParentKey' {
        Param($ParentKey, $Name)
        If ($Name -like '*Uninstall') { Return $MockParentKey }
        Return $MockSubKey
      }
      Mock Get-RegistrySubKeyNames -RemoveParameterType 'Key' { @('App1') }
      Mock Get-RegistryValueNames -RemoveParameterType 'Key' { @('DisplayName') }
      Mock Get-RegistryValue -RemoveParameterType 'Key' { 'Test App' }
      Mock ConvertTo-NormalizedRegistryValue { Param($Value) $Value }
      Mock Get-Is64BitOperatingSystem { $True }
      Mock Resolve-AppArchitecture { 'x86' }

      $Results = @(Get-InstalledApplication `
        -RegistryPaths:@(New-TestDescriptor) `
        -CompiledFilters:@() `
        -Architecture:'x64')
    }

    It 'Excludes x86 app when Architecture is x64' {
      $Results.Count | Should -Be 0
    }
  }

  Context 'Architecture filter: Both includes all' {
    BeforeAll {
      $MockBaseKey = New-MockRegistryKey -Name:'BaseKey'
      $MockParentKey = New-MockRegistryKey -Name:'ParentKey'
      $MockSubKey = New-MockRegistryKey -Name:'SubKey'

      Mock Get-RegistryBaseKey { $MockBaseKey }
      Mock Get-RegistrySubKey -RemoveParameterType 'ParentKey' {
        Param($ParentKey, $Name)
        If ($Name -like '*Uninstall') { Return $MockParentKey }
        Return $MockSubKey
      }
      Mock Get-RegistrySubKeyNames -RemoveParameterType 'Key' { @('App1') }
      Mock Get-RegistryValueNames -RemoveParameterType 'Key' { @('DisplayName') }
      Mock Get-RegistryValue -RemoveParameterType 'Key' { 'Test App' }
      Mock ConvertTo-NormalizedRegistryValue { Param($Value) $Value }
      Mock Get-Is64BitOperatingSystem { $True }
      Mock Resolve-AppArchitecture { 'x86' }

      $Results = @(Get-InstalledApplication `
        -RegistryPaths:@(New-TestDescriptor) `
        -CompiledFilters:@() `
        -Architecture:'Both')
    }

    It 'Includes app regardless of arch when Architecture is Both' {
      $Results.Count | Should -Be 1
    }
  }

  Context 'Architecture filter: matching architecture passes' {
    BeforeAll {
      $MockBaseKey = New-MockRegistryKey -Name:'BaseKey'
      $MockParentKey = New-MockRegistryKey -Name:'ParentKey'
      $MockSubKey = New-MockRegistryKey -Name:'SubKey'

      Mock Get-RegistryBaseKey { $MockBaseKey }
      Mock Get-RegistrySubKey -RemoveParameterType 'ParentKey' {
        Param($ParentKey, $Name)
        If ($Name -like '*Uninstall') { Return $MockParentKey }
        Return $MockSubKey
      }
      Mock Get-RegistrySubKeyNames -RemoveParameterType 'Key' { @('App1') }
      Mock Get-RegistryValueNames -RemoveParameterType 'Key' { @('DisplayName') }
      Mock Get-RegistryValue -RemoveParameterType 'Key' { 'Test App' }
      Mock ConvertTo-NormalizedRegistryValue { Param($Value) $Value }
      Mock Get-Is64BitOperatingSystem { $True }
      Mock Resolve-AppArchitecture { 'x86' }

      $Results = @(Get-InstalledApplication `
        -RegistryPaths:@(New-TestDescriptor) `
        -CompiledFilters:@() `
        -Architecture:'x86')
    }

    It 'Includes x86 app when Architecture is x86' {
      $Results.Count | Should -Be 1
    }
  }

  # ── Early filtering (compiled filters applied) ─────────────────

  Context 'Early filtering: compiled filters exclude non-matching' {
    BeforeAll {
      $MockBaseKey = New-MockRegistryKey -Name:'BaseKey'
      $MockParentKey = New-MockRegistryKey -Name:'ParentKey'
      $MockSubKey = New-MockRegistryKey -Name:'SubKey'

      Mock Get-RegistryBaseKey { $MockBaseKey }
      Mock Get-RegistrySubKey -RemoveParameterType 'ParentKey' {
        Param($ParentKey, $Name)
        If ($Name -like '*Uninstall') { Return $MockParentKey }
        Return $MockSubKey
      }
      Mock Get-RegistrySubKeyNames -RemoveParameterType 'Key' { @('App1') }
      Mock Get-RegistryValueNames -RemoveParameterType 'Key' { @('DisplayName') }
      Mock Get-RegistryValue -RemoveParameterType 'Key' { 'Wrong App' }
      Mock ConvertTo-NormalizedRegistryValue { Param($Value) $Value }
      Mock Get-Is64BitOperatingSystem { $True }
      Mock Resolve-AppArchitecture { 'x64' }

      $Filters = @(New-CompiledFilter -Filter:@(
        @{ Property = 'DisplayName'; Value = 'Right App'; MatchType = 'Simple' }
      ))

      $Results = @(Get-InstalledApplication `
        -RegistryPaths:@(New-TestDescriptor) `
        -CompiledFilters:$Filters)
    }

    It 'Excludes non-matching entry' {
      $Results.Count | Should -Be 0
    }
  }

  Context 'Early filtering: matching filter includes entry' {
    BeforeAll {
      $MockBaseKey = New-MockRegistryKey -Name:'BaseKey'
      $MockParentKey = New-MockRegistryKey -Name:'ParentKey'
      $MockSubKey = New-MockRegistryKey -Name:'SubKey'

      Mock Get-RegistryBaseKey { $MockBaseKey }
      Mock Get-RegistrySubKey -RemoveParameterType 'ParentKey' {
        Param($ParentKey, $Name)
        If ($Name -like '*Uninstall') { Return $MockParentKey }
        Return $MockSubKey
      }
      Mock Get-RegistrySubKeyNames -RemoveParameterType 'Key' { @('App1') }
      Mock Get-RegistryValueNames -RemoveParameterType 'Key' { @('DisplayName') }
      Mock Get-RegistryValue -RemoveParameterType 'Key' { 'Right App' }
      Mock ConvertTo-NormalizedRegistryValue { Param($Value) $Value }
      Mock Get-Is64BitOperatingSystem { $True }
      Mock Resolve-AppArchitecture { 'x64' }

      $Filters = @(New-CompiledFilter -Filter:@(
        @{ Property = 'DisplayName'; Value = 'Right App'; MatchType = 'Simple' }
      ))

      $Results = @(Get-InstalledApplication `
        -RegistryPaths:@(New-TestDescriptor) `
        -CompiledFilters:$Filters)
    }

    It 'Includes matching entry' {
      $Results.Count | Should -Be 1
    }
  }

  # ── Registry keys disposed ─────────────────────────────────────

  Context 'Registry keys are disposed after processing' {
    BeforeAll {
      $Script:TestBaseKey = New-MockRegistryKey -Name:'DisposeBase'
      $Script:TestParentKey = New-MockRegistryKey -Name:'DisposeParent'
      $Script:TestSubKey = New-MockRegistryKey -Name:'DisposeSub'

      Mock Get-RegistryBaseKey { $Script:TestBaseKey }
      Mock Get-RegistrySubKey -RemoveParameterType 'ParentKey' {
        Param($ParentKey, $Name)
        If ($Name -like '*Uninstall') { Return $Script:TestParentKey }
        Return $Script:TestSubKey
      }
      Mock Get-RegistrySubKeyNames -RemoveParameterType 'Key' { @('App1') }
      Mock Get-RegistryValueNames -RemoveParameterType 'Key' { @('DisplayName') }
      Mock Get-RegistryValue -RemoveParameterType 'Key' { 'App' }
      Mock ConvertTo-NormalizedRegistryValue { Param($Value) $Value }
      Mock Get-Is64BitOperatingSystem { $True }
      Mock Resolve-AppArchitecture { 'x64' }

      $Null = @(Get-InstalledApplication `
        -RegistryPaths:@(New-TestDescriptor) `
        -CompiledFilters:@())
    }

    It 'Disposes the base key' {
      $Script:TestBaseKey.Disposed | Should -BeTrue
    }

    It 'Disposes the parent key' {
      $Script:TestParentKey.Disposed | Should -BeTrue
    }

    It 'Disposes the subkey' {
      $Script:TestSubKey.Disposed | Should -BeTrue
    }
  }

  # ── Read failures → warning/verbose, continues ─────────────────

  Context 'Parent key read failure emits warning and continues' {
    BeforeAll {
      Mock Get-RegistryBaseKey { Throw 'Access denied' }
      Mock Get-Is64BitOperatingSystem { $True }

      $Descriptor1 = New-TestDescriptor -Source:'FAIL64'
      $Descriptor2 = New-TestDescriptor -Source:'OK64'

      # Second descriptor succeeds
      $CallCount = 0
      Mock Get-RegistryBaseKey {
        $Script:CallCount++
        If ($Script:CallCount -eq 1) { Throw 'Access denied' }
        New-MockRegistryKey -Name:'OKBase'
      }
      Mock Get-RegistrySubKey -RemoveParameterType 'ParentKey' {
        Param($ParentKey, $Name)
        If ($Name -like '*Uninstall') {
          Return (New-MockRegistryKey -Name:'OKParent')
        }
        Return (New-MockRegistryKey -Name:'OKSub')
      }
      Mock Get-RegistrySubKeyNames -RemoveParameterType 'Key' { @('App1') }
      Mock Get-RegistryValueNames -RemoveParameterType 'Key' { @('DisplayName') }
      Mock Get-RegistryValue -RemoveParameterType 'Key' { 'Surviving App' }
      Mock ConvertTo-NormalizedRegistryValue { Param($Value) $Value }
      Mock Resolve-AppArchitecture { 'x64' }

      $Results = @(Get-InstalledApplication `
        -RegistryPaths:@($Descriptor1, $Descriptor2) `
        -CompiledFilters:@() `
        -WarningAction:'SilentlyContinue')
    }

    It 'Still returns results from the successful descriptor' {
      $Results.Count | Should -Be 1
      $Results[0].DisplayName | Should -Be 'Surviving App'
    }
  }

  Context 'Subkey read failure emits warning and continues' {
    BeforeAll {
      $MockBaseKey = New-MockRegistryKey -Name:'BaseKey'
      $MockParentKey = New-MockRegistryKey -Name:'ParentKey'

      Mock Get-RegistryBaseKey { $MockBaseKey }
      Mock Get-RegistrySubKey -RemoveParameterType 'ParentKey' {
        Param($ParentKey, $Name)
        If ($Name -like '*Uninstall') { Return $MockParentKey }
        If ($Name -eq 'BadApp') { Throw 'Corrupted subkey' }
        Return (New-MockRegistryKey -Name:'GoodSub')
      }
      Mock Get-RegistrySubKeyNames -RemoveParameterType 'Key' { @('BadApp', 'GoodApp') }
      Mock Get-RegistryValueNames -RemoveParameterType 'Key' { @('DisplayName') }
      Mock Get-RegistryValue -RemoveParameterType 'Key' { 'Good Application' }
      Mock ConvertTo-NormalizedRegistryValue { Param($Value) $Value }
      Mock Get-Is64BitOperatingSystem { $True }
      Mock Resolve-AppArchitecture { 'x64' }

      $Results = @(Get-InstalledApplication `
        -RegistryPaths:@(New-TestDescriptor) `
        -CompiledFilters:@() `
        -WarningAction:'Continue' 3>&1 |
        Where-Object { $_ -is [PSCustomObject] -and
          $Null -ne $_.PSObject.Properties['DisplayName'] })
    }

    It 'Returns the good application, skipping the bad one' {
      $Results.Count | Should -Be 1
      $Results[0].DisplayName | Should -Be 'Good Application'
    }
  }

  # ── Null parent key returns nothing ────────────────────────────

  Context 'Null parent key returns nothing' {
    BeforeAll {
      $MockBaseKey = New-MockRegistryKey -Name:'BaseKey'

      Mock Get-RegistryBaseKey { $MockBaseKey }
      Mock Get-RegistrySubKey -RemoveParameterType 'ParentKey' { $Null }
      Mock Get-Is64BitOperatingSystem { $True }

      $Results = @(Get-InstalledApplication `
        -RegistryPaths:@(New-TestDescriptor) `
        -CompiledFilters:@())
    }

    It 'Returns no results when parent key is null' {
      $Results.Count | Should -Be 0
    }
  }

  # ── Null subkey returns nothing for that entry ─────────────────

  Context 'Null subkey skips that entry' {
    BeforeAll {
      $MockBaseKey = New-MockRegistryKey -Name:'BaseKey'
      $MockParentKey = New-MockRegistryKey -Name:'ParentKey'

      Mock Get-RegistryBaseKey { $MockBaseKey }
      Mock Get-RegistrySubKey -RemoveParameterType 'ParentKey' {
        Param($ParentKey, $Name)
        If ($Name -like '*Uninstall') { Return $MockParentKey }
        Return $Null
      }
      Mock Get-RegistrySubKeyNames -RemoveParameterType 'Key' { @('NullApp') }
      Mock Get-Is64BitOperatingSystem { $True }

      $Results = @(Get-InstalledApplication `
        -RegistryPaths:@(New-TestDescriptor) `
        -CompiledFilters:@())
    }

    It 'Returns no results for null subkey' {
      $Results.Count | Should -Be 0
    }
  }

  # ── Unnamed default value skipped ──────────────────────────────

  Context 'Unnamed default value is skipped' {
    BeforeAll {
      $MockBaseKey = New-MockRegistryKey -Name:'BaseKey'
      $MockParentKey = New-MockRegistryKey -Name:'ParentKey'
      $MockSubKey = New-MockRegistryKey -Name:'SubKey'

      Mock Get-RegistryBaseKey { $MockBaseKey }
      Mock Get-RegistrySubKey -RemoveParameterType 'ParentKey' {
        Param($ParentKey, $Name)
        If ($Name -like '*Uninstall') { Return $MockParentKey }
        Return $MockSubKey
      }
      Mock Get-RegistrySubKeyNames -RemoveParameterType 'Key' { @('App1') }
      # Return empty string (unnamed default) plus a real name
      Mock Get-RegistryValueNames -RemoveParameterType 'Key' { @('', 'DisplayName') }
      Mock Get-RegistryValue -RemoveParameterType 'Key' {
        Param($Key, $Name)
        Switch ($Name) {
          ''            { 'default value' }
          'DisplayName' { 'Real App' }
        }
      }
      Mock ConvertTo-NormalizedRegistryValue { Param($Value) $Value }
      Mock Get-Is64BitOperatingSystem { $True }
      Mock Resolve-AppArchitecture { 'x64' }

      $Results = @(Get-InstalledApplication `
        -RegistryPaths:@(New-TestDescriptor) `
        -CompiledFilters:@())
    }

    It 'Includes the app' {
      $Results.Count | Should -Be 1
    }

    It 'Does not include unnamed default property' {
      $Results[0].PSObject.Properties[''] | Should -BeNullOrEmpty
    }
  }

  # ── Normalized null values skipped ─────────────────────────────

  Context 'Values that normalize to $null are excluded' {
    BeforeAll {
      $MockBaseKey = New-MockRegistryKey -Name:'BaseKey'
      $MockParentKey = New-MockRegistryKey -Name:'ParentKey'
      $MockSubKey = New-MockRegistryKey -Name:'SubKey'

      Mock Get-RegistryBaseKey { $MockBaseKey }
      Mock Get-RegistrySubKey -RemoveParameterType 'ParentKey' {
        Param($ParentKey, $Name)
        If ($Name -like '*Uninstall') { Return $MockParentKey }
        Return $MockSubKey
      }
      Mock Get-RegistrySubKeyNames -RemoveParameterType 'Key' { @('App1') }
      Mock Get-RegistryValueNames -RemoveParameterType 'Key' { @('DisplayName', 'BinaryBlob') }
      Mock Get-RegistryValue -RemoveParameterType 'Key' {
        Param($Key, $Name)
        Switch ($Name) {
          'DisplayName' { 'Test' }
          'BinaryBlob'  { [byte[]]@(0,1,2) }
        }
      }
      Mock ConvertTo-NormalizedRegistryValue {
        Param($Value)
        If ($Null -eq $Value) { Return $Null }
        If ($Value -is [byte[]] -or $Value -is [System.Object[]]) { Return $Null }
        If ($Value -is [System.String]) { Return $Value }
        Return $Null
      }
      Mock Get-Is64BitOperatingSystem { $True }
      Mock Resolve-AppArchitecture { 'x64' }

      $Results = @(Get-InstalledApplication `
        -RegistryPaths:@(New-TestDescriptor) `
        -CompiledFilters:@())
    }

    It 'Does not include BinaryBlob property' {
      $Results[0].PSObject.Properties['BinaryBlob'] | Should -BeNullOrEmpty
    }

    It 'Includes DisplayName property' {
      $Results[0].DisplayName | Should -Be 'Test'
    }
  }

  # ── Internal-only fields stamped ───────────────────────────────

  Context 'Internal-only fields stamped' {
    BeforeAll {
      $MockBaseKey = New-MockRegistryKey -Name:'BaseKey'
      $MockParentKey = New-MockRegistryKey -Name:'ParentKey'
      $MockSubKey = New-MockRegistryKey -Name:'SubKey'

      Mock Get-RegistryBaseKey { $MockBaseKey }
      Mock Get-RegistrySubKey -RemoveParameterType 'ParentKey' {
        Param($ParentKey, $Name)
        If ($Name -like '*Uninstall') { Return $MockParentKey }
        Return $MockSubKey
      }
      Mock Get-RegistrySubKeyNames -RemoveParameterType 'Key' { @('App1') }
      Mock Get-RegistryValueNames -RemoveParameterType 'Key' { @('DisplayName') }
      Mock Get-RegistryValue -RemoveParameterType 'Key' { 'MyApp' }
      Mock ConvertTo-NormalizedRegistryValue { Param($Value) $Value }
      Mock Get-Is64BitOperatingSystem { $True }
      Mock Resolve-AppArchitecture { 'x64' }

      $Descriptor = New-TestDescriptor `
        -Source:'HKLM64' `
        -Hive:([Microsoft.Win32.RegistryHive]::LocalMachine) `
        -View:([Microsoft.Win32.RegistryView]::Registry64)

      $Results = @(Get-InstalledApplication `
        -RegistryPaths:@($Descriptor) `
        -CompiledFilters:@())
    }

    It 'Stamps _RegistryHive' {
      $Results[0]._RegistryHive | Should -Be ([Microsoft.Win32.RegistryHive]::LocalMachine)
    }

    It 'Stamps _RegistryView' {
      $Results[0]._RegistryView | Should -Be ([Microsoft.Win32.RegistryView]::Registry64)
    }

    It 'Stamps _RegistrySource' {
      $Results[0]._RegistrySource | Should -Be 'HKLM64'
    }
  }

  # ── User scope metadata passthrough ────────────────────────────

  Context 'User scope metadata from descriptor' {
    BeforeAll {
      $MockBaseKey = New-MockRegistryKey -Name:'BaseKey'
      $MockParentKey = New-MockRegistryKey -Name:'ParentKey'
      $MockSubKey = New-MockRegistryKey -Name:'SubKey'

      Mock Get-RegistryBaseKey { $MockBaseKey }
      Mock Get-RegistrySubKey -RemoveParameterType 'ParentKey' {
        Param($ParentKey, $Name)
        If ($Name -like '*Uninstall') { Return $MockParentKey }
        Return $MockSubKey
      }
      Mock Get-RegistrySubKeyNames -RemoveParameterType 'Key' { @('UserApp') }
      Mock Get-RegistryValueNames -RemoveParameterType 'Key' { @('DisplayName') }
      Mock Get-RegistryValue -RemoveParameterType 'Key' { 'User App' }
      Mock ConvertTo-NormalizedRegistryValue { Param($Value) $Value }
      Mock Get-Is64BitOperatingSystem { $True }
      Mock Resolve-AppArchitecture { 'x64' }

      $Descriptor = New-TestDescriptor `
        -Source:'HKU\S-1-5-21-123-456-789-100164' `
        -DisplayRoot:'HKU' `
        -Hive:([Microsoft.Win32.RegistryHive]::Users) `
        -View:([Microsoft.Win32.RegistryView]::Registry64) `
        -InstallScope:'User' `
        -UserSid:'S-1-5-21-123-456-789-1001' `
        -UserName:'CORP\jdoe' `
        -UserIdentityStatus:'Resolved'

      $Results = @(Get-InstalledApplication `
        -RegistryPaths:@($Descriptor) `
        -CompiledFilters:@())
    }

    It 'Passes through InstallScope' {
      $Results[0].InstallScope | Should -Be 'User'
    }

    It 'Passes through UserSid' {
      $Results[0].UserSid | Should -Be 'S-1-5-21-123-456-789-1001'
    }

    It 'Passes through UserName' {
      $Results[0].UserName | Should -Be 'CORP\jdoe'
    }

    It 'Passes through UserIdentityStatus' {
      $Results[0].UserIdentityStatus | Should -Be 'Resolved'
    }
  }

  # ── Multiple subkeys produce multiple records ──────────────────

  Context 'Multiple subkeys produce independent records (no dedupe)' {
    BeforeAll {
      $MockBaseKey = New-MockRegistryKey -Name:'BaseKey'
      $MockParentKey = New-MockRegistryKey -Name:'ParentKey'

      Mock Get-RegistryBaseKey { $MockBaseKey }
      Mock Get-RegistrySubKey -RemoveParameterType 'ParentKey' {
        Param($ParentKey, $Name)
        If ($Name -like '*Uninstall') { Return $MockParentKey }
        Return (New-MockRegistryKey -Name:$Name)
      }
      Mock Get-RegistrySubKeyNames -RemoveParameterType 'Key' { @('App1', 'App2', 'App3') }
      Mock Get-RegistryValueNames -RemoveParameterType 'Key' { @('DisplayName') }
      Mock Get-RegistryValue -RemoveParameterType 'Key' {
        Param($Key, $Name)
        # All apps have the same DisplayName — no dedupe should happen
        'Duplicate App'
      }
      Mock ConvertTo-NormalizedRegistryValue { Param($Value) $Value }
      Mock Get-Is64BitOperatingSystem { $True }
      Mock Resolve-AppArchitecture { 'x64' }

      $Results = @(Get-InstalledApplication `
        -RegistryPaths:@(New-TestDescriptor) `
        -CompiledFilters:@())
    }

    It 'Returns 3 separate records (no deduplication)' {
      $Results.Count | Should -Be 3
    }

    It 'Each record has a distinct RegistryPath' {
      $Paths = $Results | ForEach-Object { $_.RegistryPath }
      ($Paths | Select-Object -Unique).Count | Should -Be 3
    }
  }
}

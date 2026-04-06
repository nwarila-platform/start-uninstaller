BeforeAll {
  . "$PSScriptRoot\..\..\build\Start-Uninstaller.Functions.ps1"
}

Describe 'Get-UninstallRegistryPath' {

  BeforeAll {
    $Script:SubPath = 'Software\Microsoft\Windows\CurrentVersion\Uninstall'
  }

  # ── HKLM paths always present ──────────────────────────────────

  Context 'HKLM descriptors on 64-bit OS with no user SIDs' {
    BeforeAll {
      Mock Get-Is64BitOperatingSystem { $True }
      Mock Get-LoadedUserRegistrySid { @() }
      Mock Resolve-SidIdentity { $Null }

      $Results = @(Get-UninstallRegistryPath)
    }

    It 'Returns exactly 2 descriptors (64-bit + 32-bit)' {
      $Results.Count | Should -Be 2
    }

    It 'First descriptor is HKLM64' {
      $Results[0].Source | Should -Be 'HKLM64'
    }

    It 'Second descriptor is HKLM32' {
      $Results[1].Source | Should -Be 'HKLM32'
    }

    It 'Both descriptors use LocalMachine hive' {
      $Results[0].Hive | Should -Be ([Microsoft.Win32.RegistryHive]::LocalMachine)
      $Results[1].Hive | Should -Be ([Microsoft.Win32.RegistryHive]::LocalMachine)
    }

    It 'Both descriptors have System InstallScope' {
      $Results[0].InstallScope | Should -Be 'System'
      $Results[1].InstallScope | Should -Be 'System'
    }

    It 'Both descriptors have null UserSid' {
      $Results[0].UserSid | Should -BeNullOrEmpty
      $Results[1].UserSid | Should -BeNullOrEmpty
    }

    It 'Both descriptors have System UserIdentityStatus' {
      $Results[0].UserIdentityStatus | Should -Be 'System'
      $Results[1].UserIdentityStatus | Should -Be 'System'
    }

    It 'Both descriptors carry the uninstall subpath' {
      $Results[0].Path | Should -Be $Script:SubPath
      $Results[1].Path | Should -Be $Script:SubPath
    }
  }

  Context 'HKLM descriptors on 32-bit OS' {
    BeforeAll {
      Mock Get-Is64BitOperatingSystem { $False }
      Mock Get-LoadedUserRegistrySid { @() }

      $Results = @(Get-UninstallRegistryPath)
    }

    It 'Returns exactly 1 descriptor (Default view)' {
      $Results.Count | Should -Be 1
    }

    It 'Descriptor source is HKLM (no suffix)' {
      $Results[0].Source | Should -Be 'HKLM'
    }

    It 'Descriptor uses Default view' {
      $Results[0].View | Should -Be ([Microsoft.Win32.RegistryView]::Default)
    }
  }

  # ── HKU per-SID paths ─────────────────────────────────────────

  Context 'HKU per-SID paths on 64-bit OS' {
    BeforeAll {
      $TestSid = 'S-1-5-21-1234-5678-9012-1001'
      Mock Get-Is64BitOperatingSystem { $True }
      Mock Get-LoadedUserRegistrySid { @($TestSid) }
      Mock Resolve-SidIdentity { 'DOMAIN\TestUser' }

      $Results = @(Get-UninstallRegistryPath)
    }

    It 'Returns 4 descriptors total (2 HKLM + 2 HKU)' {
      $Results.Count | Should -Be 4
    }

    It 'HKU descriptors use Users hive' {
      $Results[2].Hive | Should -Be ([Microsoft.Win32.RegistryHive]::Users)
      $Results[3].Hive | Should -Be ([Microsoft.Win32.RegistryHive]::Users)
    }

    It 'HKU descriptors have User InstallScope' {
      $Results[2].InstallScope | Should -Be 'User'
      $Results[3].InstallScope | Should -Be 'User'
    }

    It 'HKU descriptors carry the SID' {
      $Results[2].UserSid | Should -Be $TestSid
      $Results[3].UserSid | Should -Be $TestSid
    }

    It 'HKU descriptors carry the resolved username' {
      $Results[2].UserName | Should -Be 'DOMAIN\TestUser'
      $Results[3].UserName | Should -Be 'DOMAIN\TestUser'
    }

    It 'HKU descriptors have Resolved UserIdentityStatus' {
      $Results[2].UserIdentityStatus | Should -Be 'Resolved'
      $Results[3].UserIdentityStatus | Should -Be 'Resolved'
    }

    It 'HKU path includes SID prefix' {
      $Results[2].Path | Should -Be "$TestSid\$Script:SubPath"
    }

    It 'HKU source includes SID' {
      $Results[2].Source | Should -BeLike "HKU\$TestSid*"
    }
  }

  # ── Multiple user SIDs ────────────────────────────────────────

  Context 'Multiple user SIDs on 64-bit OS' {
    BeforeAll {
      $Sid1 = 'S-1-5-21-111-222-333-1001'
      $Sid2 = 'S-1-5-21-111-222-333-1002'
      Mock Get-Is64BitOperatingSystem { $True }
      Mock Get-LoadedUserRegistrySid { @($Sid1, $Sid2) }
      Mock Resolve-SidIdentity {
        Param($Sid)
        Switch ($Sid) {
          $Sid1 { 'CORP\user1' }
          $Sid2 { 'CORP\user2' }
        }
      }

      $Results = @(Get-UninstallRegistryPath)
    }

    It 'Returns 6 descriptors total (2 HKLM + 2 per SID x 2)' {
      $Results.Count | Should -Be 6
    }

    It 'Third and fourth descriptors are for first SID' {
      $Results[2].UserSid | Should -Be $Sid1
      $Results[3].UserSid | Should -Be $Sid1
    }

    It 'Fifth and sixth descriptors are for second SID' {
      $Results[4].UserSid | Should -Be $Sid2
      $Results[5].UserSid | Should -Be $Sid2
    }
  }

  # ── User identity resolution ───────────────────────────────────

  Context 'HKU SID ordering is deterministic' {
    BeforeAll {
      $SidA = 'S-1-5-21-111-222-333-1001'
      $SidB = 'S-1-5-21-111-222-333-1002'
      Mock Get-Is64BitOperatingSystem { $True }
      Mock Get-LoadedUserRegistrySid { @($SidB, $SidA) }
      Mock Resolve-SidIdentity {
        Param($Sid)
        'USER\{0}' -f $Sid
      }

      $Results = @(Get-UninstallRegistryPath)
    }

    It 'Sorts HKU descriptor groups by SID regardless of enumeration order' {
      $Results[2].UserSid | Should -Be $SidA
      $Results[3].UserSid | Should -Be $SidA
      $Results[4].UserSid | Should -Be $SidB
      $Results[5].UserSid | Should -Be $SidB
    }
  }

  Context 'User identity resolution: SID resolves successfully' {
    BeforeAll {
      $Script:ResolveTestSid = 'S-1-5-21-999-888-777-500'
      Mock Get-Is64BitOperatingSystem { $False }
      Mock Get-LoadedUserRegistrySid { @($Script:ResolveTestSid) }
      Mock Resolve-SidIdentity -RemoveParameterValidation 'Sid' { 'BUILTIN\Admin' }

      $Results = @(Get-UninstallRegistryPath)
    }

    It 'Sets UserIdentityStatus to Resolved' {
      $HkuResult = $Results | Where-Object { $_.InstallScope -eq 'User' }
      $HkuResult.UserIdentityStatus | Should -Be 'Resolved'
    }

    It 'Sets UserName to resolved value' {
      $HkuResult = $Results | Where-Object { $_.InstallScope -eq 'User' }
      $HkuResult.UserName | Should -Be 'BUILTIN\Admin'
    }

    It 'Resolved username proves Resolve-SidIdentity was called' {
      # The UserName 'BUILTIN\Admin' can only come from the
      # Resolve-SidIdentity mock, proving it was invoked.
      $HkuResult = $Results | Where-Object { $_.InstallScope -eq 'User' }
      $HkuResult.UserName | Should -Be 'BUILTIN\Admin'
    }
  }

  Context 'User identity resolution: SID fails to resolve' {
    BeforeAll {
      $TestSid = 'S-1-5-21-000-000-000-9999'
      Mock Get-Is64BitOperatingSystem { $False }
      Mock Get-LoadedUserRegistrySid { @($TestSid) }
      Mock Resolve-SidIdentity { $Null }

      $Results = @(Get-UninstallRegistryPath)
    }

    It 'Sets UserIdentityStatus to Unresolved' {
      $HkuResult = $Results | Where-Object { $_.InstallScope -eq 'User' }
      $HkuResult.UserIdentityStatus | Should -Be 'Unresolved'
    }

    It 'Sets UserName to null' {
      $HkuResult = $Results | Where-Object { $_.InstallScope -eq 'User' }
      $HkuResult.UserName | Should -BeNullOrEmpty
    }
  }

  # ── HKU enumeration failure ───────────────────────────────────

  Context 'Get-LoadedUserRegistrySid returns empty array' {
    BeforeAll {
      Mock Get-Is64BitOperatingSystem { $True }
      Mock Get-LoadedUserRegistrySid { @() }

      $Results = @(Get-UninstallRegistryPath)
    }

    It 'Returns only HKLM descriptors' {
      $Results.Count | Should -Be 2
      $Results | ForEach-Object {
        $_.InstallScope | Should -Be 'System'
      }
    }
  }
}

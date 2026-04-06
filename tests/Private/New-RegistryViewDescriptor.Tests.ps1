BeforeAll {
  . "$PSScriptRoot\..\..\build\Start-Uninstaller.Functions.ps1"
}

Describe 'New-RegistryViewDescriptor' {

  BeforeAll {
    $Script:CommonParams = @{
      Hive               = [Microsoft.Win32.RegistryHive]::LocalMachine
      Path               = 'Software\Microsoft\Windows\CurrentVersion\Uninstall'
      SourcePrefix       = 'HKLM'
      InstallScope       = 'System'
      UserSid            = $Null
      UserName           = $Null
      UserIdentityStatus = 'System'
    }
  }

  # ── 64-bit OS ──────────────────────────────────────────────────

  Context '64-bit OS' {
    BeforeAll {
      $Results = @(New-RegistryViewDescriptor @Script:CommonParams -Is64BitOS:$True)
    }

    It 'Returns exactly 2 objects' {
      $Results.Count | Should -Be 2
    }

    It 'First object uses Registry64 view' {
      $Results[0].View | Should -Be ([Microsoft.Win32.RegistryView]::Registry64)
    }

    It 'Second object uses Registry32 view' {
      $Results[1].View | Should -Be ([Microsoft.Win32.RegistryView]::Registry32)
    }

    It 'First object Source has 64 suffix' {
      $Results[0].Source | Should -Be 'HKLM64'
    }

    It 'Second object Source has 32 suffix' {
      $Results[1].Source | Should -Be 'HKLM32'
    }

    It 'Both objects have correct PSTypeName' {
      $Results[0].PSTypeNames | Should -Contain 'StartUninstaller.RegistryViewDescriptor'
      $Results[1].PSTypeNames | Should -Contain 'StartUninstaller.RegistryViewDescriptor'
    }

    It 'Both objects carry the same Hive' {
      $Results[0].Hive | Should -Be ([Microsoft.Win32.RegistryHive]::LocalMachine)
      $Results[1].Hive | Should -Be ([Microsoft.Win32.RegistryHive]::LocalMachine)
    }

    It 'Both objects carry the same Path' {
      $Results[0].Path | Should -Be 'Software\Microsoft\Windows\CurrentVersion\Uninstall'
      $Results[1].Path | Should -Be 'Software\Microsoft\Windows\CurrentVersion\Uninstall'
    }

    It 'Both objects expose HKLM as the display root' {
      $Results[0].DisplayRoot | Should -Be 'HKLM'
      $Results[1].DisplayRoot | Should -Be 'HKLM'
    }
  }

  # ── 32-bit OS ──────────────────────────────────────────────────

  Context '32-bit OS' {
    BeforeAll {
      $Results = @(New-RegistryViewDescriptor @Script:CommonParams -Is64BitOS:$False)
    }

    It 'Returns exactly 1 object' {
      $Results.Count | Should -Be 1
    }

    It 'Uses Default view' {
      $Results[0].View | Should -Be ([Microsoft.Win32.RegistryView]::Default)
    }

    It 'Source has no suffix (uses raw prefix)' {
      $Results[0].Source | Should -Be 'HKLM'
    }

    It 'Has correct PSTypeName' {
      $Results[0].PSTypeNames | Should -Contain 'StartUninstaller.RegistryViewDescriptor'
    }

    It 'Exposes HKLM as the display root' {
      $Results[0].DisplayRoot | Should -Be 'HKLM'
    }
  }

  # ── HKU source suffix ─────────────────────────────────────────

  Context 'HKU source suffix on 64-bit OS' {
    BeforeAll {
      $Sid = 'S-1-5-21-1234567890-1234567890-1234567890-1001'
      $Results = @(New-RegistryViewDescriptor `
        -Hive:([Microsoft.Win32.RegistryHive]::Users) `
        -Path:("$Sid\Software\Microsoft\Windows\CurrentVersion\Uninstall") `
        -SourcePrefix:("HKU\$Sid") `
        -Is64BitOS:$True `
        -InstallScope:'User' `
        -UserSid:$Sid `
        -UserName:'DOMAIN\User1' `
        -UserIdentityStatus:'Resolved')
    }

    It 'First source ends with 64' {
      $Results[0].Source | Should -Be "HKU\S-1-5-21-1234567890-1234567890-1234567890-100164"
    }

    It 'Second source ends with 32' {
      $Results[1].Source | Should -Be "HKU\S-1-5-21-1234567890-1234567890-1234567890-100132"
    }

    It 'Both objects expose HKU as the display root' {
      $Results[0].DisplayRoot | Should -Be 'HKU'
      $Results[1].DisplayRoot | Should -Be 'HKU'
    }
  }

  # ── Passthrough properties ─────────────────────────────────────

  Context 'InstallScope, UserSid, UserName, UserIdentityStatus passthrough' {
    It 'Passes through System scope with null user fields' {
      $Result = @(New-RegistryViewDescriptor @Script:CommonParams -Is64BitOS:$False)
      $Result[0].InstallScope       | Should -Be 'System'
      $Result[0].UserSid            | Should -BeNullOrEmpty
      $Result[0].UserName           | Should -BeNullOrEmpty
      $Result[0].UserIdentityStatus | Should -Be 'System'
    }

    It 'Passes through User scope with resolved identity' {
      $Sid = 'S-1-5-21-999-999-999-1001'
      $Result = @(New-RegistryViewDescriptor `
        -Hive:([Microsoft.Win32.RegistryHive]::Users) `
        -Path:("$Sid\Software\Microsoft\Windows\CurrentVersion\Uninstall") `
        -SourcePrefix:("HKU\$Sid") `
        -Is64BitOS:$False `
        -InstallScope:'User' `
        -UserSid:$Sid `
        -UserName:'CONTOSO\jdoe' `
        -UserIdentityStatus:'Resolved')

      $Result[0].InstallScope       | Should -Be 'User'
      $Result[0].UserSid            | Should -Be $Sid
      $Result[0].UserName           | Should -Be 'CONTOSO\jdoe'
      $Result[0].UserIdentityStatus | Should -Be 'Resolved'
    }

    It 'Passes through User scope with unresolved identity' {
      $Sid = 'S-1-5-21-999-999-999-1002'
      $Result = @(New-RegistryViewDescriptor `
        -Hive:([Microsoft.Win32.RegistryHive]::Users) `
        -Path:("$Sid\Software\Microsoft\Windows\CurrentVersion\Uninstall") `
        -SourcePrefix:("HKU\$Sid") `
        -Is64BitOS:$False `
        -InstallScope:'User' `
        -UserSid:$Sid `
        -UserName:$Null `
        -UserIdentityStatus:'Unresolved')

      $Result[0].InstallScope       | Should -Be 'User'
      $Result[0].UserSid            | Should -Be $Sid
      $Result[0].UserName           | Should -BeNullOrEmpty
      $Result[0].UserIdentityStatus | Should -Be 'Unresolved'
    }
  }

  # ── All metadata on 64-bit duplicated correctly ────────────────

  Context 'Metadata duplication on 64-bit OS for User scope' {
    BeforeAll {
      $Sid = 'S-1-5-21-111-222-333-444'
      $Results = @(New-RegistryViewDescriptor `
        -Hive:([Microsoft.Win32.RegistryHive]::Users) `
        -Path:("$Sid\Software\Microsoft\Windows\CurrentVersion\Uninstall") `
        -SourcePrefix:("HKU\$Sid") `
        -Is64BitOS:$True `
        -InstallScope:'User' `
        -UserSid:$Sid `
        -UserName:'CORP\admin' `
        -UserIdentityStatus:'Resolved')
    }

    It 'Both descriptors carry the same InstallScope' {
      $Results[0].InstallScope | Should -Be 'User'
      $Results[1].InstallScope | Should -Be 'User'
    }

    It 'Both descriptors carry the same UserSid' {
      $Results[0].UserSid | Should -Be 'S-1-5-21-111-222-333-444'
      $Results[1].UserSid | Should -Be 'S-1-5-21-111-222-333-444'
    }

    It 'Both descriptors carry the same UserName' {
      $Results[0].UserName | Should -Be 'CORP\admin'
      $Results[1].UserName | Should -Be 'CORP\admin'
    }

    It 'Both descriptors carry the same UserIdentityStatus' {
      $Results[0].UserIdentityStatus | Should -Be 'Resolved'
      $Results[1].UserIdentityStatus | Should -Be 'Resolved'
    }
  }
}

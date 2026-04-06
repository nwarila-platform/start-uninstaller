#Requires -Module Pester

BeforeAll {
  . "$PSScriptRoot/../../build/Start-Uninstaller.Functions.ps1"
}

Describe 'Get-LoadedUserRegistrySid' {

  Context 'Function metadata' {
    It 'Exists as a command' {
      Get-Command -Name 'Get-LoadedUserRegistrySid' -ErrorAction 'SilentlyContinue' |
        Should -Not -BeNullOrEmpty
    }

    It 'Accepts no custom parameters' {
      $Command = Get-Command -Name 'Get-LoadedUserRegistrySid'
      $Custom = $Command.Parameters.Keys | Where-Object {
        $PSItem -notin [System.Management.Automation.PSCmdlet]::CommonParameters
      }
      $Custom | Should -HaveCount 0
    }
  }

  Context 'Filtering logic excludes non-user entries and keeps user SIDs' {
    BeforeAll {
      $Script:FakeSubKeys = @(
        '.DEFAULT'
        'S-1-5-18'
        'S-1-5-19'
        'S-1-5-20'
        'S-1-5-21-1234567890-1234567890-1234567890-1001'
        'S-1-5-21-1234567890-1234567890-1234567890-1001_Classes'
        'S-1-12-1-111111111-222222222-333333333-444444444'
        'S-1-12-1-111111111-222222222-333333333-444444444_Classes'
        'NotARealSid'
      )
    }

    BeforeEach {
      Mock -CommandName 'Get-RegistryBaseKey' -MockWith {
        [PSCustomObject]@{ PSTypeName = 'Microsoft.Win32.RegistryKey' } |
          Add-Member -MemberType 'ScriptMethod' -Name 'Dispose' -Value {} -PassThru
      }
      Mock -CommandName 'Get-RegistrySubKeyNames' -RemoveParameterType 'Key' -MockWith {
        $Script:FakeSubKeys
      }
    }

    It 'Excludes .DEFAULT and service-account SIDs' {
      $Result = Get-LoadedUserRegistrySid

      $Result | Should -Not -Contain '.DEFAULT'
      $Result | Should -Not -Contain 'S-1-5-18'
      $Result | Should -Not -Contain 'S-1-5-19'
      $Result | Should -Not -Contain 'S-1-5-20'
    }

    It 'Excludes _Classes hives' {
      $Result = Get-LoadedUserRegistrySid

      $Result | ForEach-Object {
        $PSItem | Should -Not -Match '_Classes$'
      }
    }

    It 'Keeps valid on-prem and Entra-style user SIDs' {
      $Result = Get-LoadedUserRegistrySid

      $Result | Should -Contain 'S-1-5-21-1234567890-1234567890-1234567890-1001'
      $Result | Should -Contain 'S-1-12-1-111111111-222222222-333333333-444444444'
      $Result | Should -HaveCount 2
    }
  }

  Context 'Empty hive' {
    It 'Returns nothing when no subkeys exist' {
      Mock -CommandName 'Get-RegistryBaseKey' -MockWith {
        [PSCustomObject]@{ PSTypeName = 'Microsoft.Win32.RegistryKey' } |
          Add-Member -MemberType 'ScriptMethod' -Name 'Dispose' -Value {} -PassThru
      }
      Mock -CommandName 'Get-RegistrySubKeyNames' -RemoveParameterType 'Key' -MockWith { @() }

      (Get-LoadedUserRegistrySid) | Should -BeNullOrEmpty
    }
  }

  Context 'Error handling' {
    It 'Writes a warning and does not throw when HKU enumeration fails' {
      Mock -CommandName 'Get-RegistryBaseKey' -MockWith {
        Throw 'Access denied'
      }

      $Result = Get-LoadedUserRegistrySid -WarningVariable 'Warnings' 3>$Null

      $Result | Should -BeNullOrEmpty
      $Warnings | Should -Match 'Cannot enumerate loaded user registry hives'
    }
  }

  Context 'Resource cleanup' {
    It 'Calls Dispose on the base key' {
      $Script:DisposeCallCount = 0
      Mock -CommandName 'Get-RegistryBaseKey' -MockWith {
        [PSCustomObject]@{ PSTypeName = 'Microsoft.Win32.RegistryKey' } |
          Add-Member -MemberType 'ScriptMethod' -Name 'Dispose' -Value {
            $Script:DisposeCallCount++
          } -PassThru
      }
      Mock -CommandName 'Get-RegistrySubKeyNames' -RemoveParameterType 'Key' -MockWith {
        @('S-1-5-21-1-2-3-1001')
      }

      $Null = Get-LoadedUserRegistrySid

      $Script:DisposeCallCount | Should -Be 1
    }
  }

  Context 'Read-only seam usage' {
    BeforeEach {
      Mock -CommandName 'Get-RegistryBaseKey' -MockWith {
        [PSCustomObject]@{ PSTypeName = 'Microsoft.Win32.RegistryKey' } |
          Add-Member -MemberType 'ScriptMethod' -Name 'Dispose' -Value {} -PassThru
      }
      Mock -CommandName 'Get-RegistrySubKeyNames' -RemoveParameterType 'Key' -MockWith {
        @('S-1-5-21-1-2-3-1001')
      }
      Mock -CommandName 'Get-RegistrySubKey' -RemoveParameterType 'ParentKey' -MockWith {
        Throw 'Get-RegistrySubKey should not be used by Get-LoadedUserRegistrySid.'
      }
    }

    It 'Opens HKU through the base-key seam with the default view' {
      $Null = Get-LoadedUserRegistrySid

      Should -Invoke -CommandName 'Get-RegistryBaseKey' -Times 1 -Exactly `
        -ParameterFilter {
          $Hive -eq [Microsoft.Win32.RegistryHive]::Users -and
          $View -eq [Microsoft.Win32.RegistryView]::Default
        }
    }

    It 'Enumerates child names through the subkey-name seam only' {
      $Null = Get-LoadedUserRegistrySid

      Should -Invoke -CommandName 'Get-RegistrySubKeyNames' -Times 1 -Exactly
      Should -Invoke -CommandName 'Get-RegistrySubKey' -Times 0 -Exactly
    }
  }
}

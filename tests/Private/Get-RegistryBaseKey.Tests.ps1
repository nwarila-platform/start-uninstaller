BeforeAll {
  . "$PSScriptRoot/../../build/Start-Uninstaller.Functions.ps1"
}

Describe 'Get-RegistryBaseKey' {

  Context 'Function metadata' {
    It 'Should exist as a command' {
      Get-Command -Name 'Get-RegistryBaseKey' -ErrorAction 'SilentlyContinue' |
        Should -Not -BeNullOrEmpty
    }

    It 'Should have a mandatory Hive parameter' {
      $Param = (Get-Command 'Get-RegistryBaseKey').Parameters['Hive']
      $Param | Should -Not -BeNullOrEmpty
      $Param.Attributes.Where({ $PSItem -is [System.Management.Automation.ParameterAttribute] }).Mandatory |
        Should -BeTrue
    }

    It 'Should have a mandatory View parameter' {
      $Param = (Get-Command 'Get-RegistryBaseKey').Parameters['View']
      $Param | Should -Not -BeNullOrEmpty
      $Param.Attributes.Where({ $PSItem -is [System.Management.Automation.ParameterAttribute] }).Mandatory |
        Should -BeTrue
    }
  }

  Context 'Parameter validation' {
    It 'Should reject invalid Hive values' {
      { Get-RegistryBaseKey -Hive 'NotAHive' -View 'Default' } |
        Should -Throw
    }

    It 'Should reject invalid View values' {
      { Get-RegistryBaseKey -Hive 'LocalMachine' -View 'NotAView' } |
        Should -Throw
    }

    It 'Should throw when Hive is missing' {
      { Get-RegistryBaseKey -View 'Default' } |
        Should -Throw
    }

    It 'Should throw when View is missing' {
      { Get-RegistryBaseKey -Hive 'LocalMachine' } |
        Should -Throw
    }
  }

  Context 'Successful delegation' {
    It 'Should return a RegistryKey for HKLM with Default view' {
      $Key = $Null
      Try {
        $Key = Get-RegistryBaseKey `
          -Hive ([Microsoft.Win32.RegistryHive]::LocalMachine) `
          -View ([Microsoft.Win32.RegistryView]::Default)
        $Key | Should -Not -BeNullOrEmpty
        $Key | Should -BeOfType [Microsoft.Win32.RegistryKey]
      } Finally {
        If ($Null -ne $Key) { $Key.Dispose() }
      }
    }

    It 'Should return a RegistryKey for HKU with Registry64 view' {
      $Key = $Null
      Try {
        $Key = Get-RegistryBaseKey `
          -Hive ([Microsoft.Win32.RegistryHive]::Users) `
          -View ([Microsoft.Win32.RegistryView]::Registry64)
        $Key | Should -Not -BeNullOrEmpty
        $Key | Should -BeOfType [Microsoft.Win32.RegistryKey]
      } Finally {
        If ($Null -ne $Key) { $Key.Dispose() }
      }
    }
  }
}

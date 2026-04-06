BeforeAll {
  . "$PSScriptRoot/../../build/Start-Uninstaller.Functions.ps1"
}

Describe 'Get-RegistrySubKeyNames' {

  Context 'Function metadata' {
    It 'Should exist as a command' {
      Get-Command -Name 'Get-RegistrySubKeyNames' -ErrorAction 'SilentlyContinue' |
        Should -Not -BeNullOrEmpty
    }

    It 'Should have a mandatory Key parameter typed as RegistryKey' {
      $Param = (Get-Command 'Get-RegistrySubKeyNames').Parameters['Key']
      $Param | Should -Not -BeNullOrEmpty
      $Param.ParameterType | Should -Be ([Microsoft.Win32.RegistryKey])
      $Param.Attributes.Where({ $PSItem -is [System.Management.Automation.ParameterAttribute] }).Mandatory |
        Should -BeTrue
    }
  }

  Context 'Delegation to GetSubKeyNames' {
    BeforeAll {
      $Script:BaseKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey(
        [Microsoft.Win32.RegistryHive]::LocalMachine,
        [Microsoft.Win32.RegistryView]::Default
      )
    }
    AfterAll {
      If ($Null -ne $Script:BaseKey) { $Script:BaseKey.Dispose() }
    }

    It 'Should return a string array' {
      $Names = Get-RegistrySubKeyNames -Key $Script:BaseKey
      $Names | Should -Not -BeNullOrEmpty
      # Each element should be a string
      $Names | ForEach-Object { $PSItem | Should -BeOfType [System.String] }
    }

    It 'Should include well-known HKLM subkeys like SOFTWARE' {
      $Names = Get-RegistrySubKeyNames -Key $Script:BaseKey
      $Names | Should -Contain 'SOFTWARE'
    }

    It 'Should include well-known HKLM subkeys like SYSTEM' {
      $Names = Get-RegistrySubKeyNames -Key $Script:BaseKey
      $Names | Should -Contain 'SYSTEM'
    }
  }
}

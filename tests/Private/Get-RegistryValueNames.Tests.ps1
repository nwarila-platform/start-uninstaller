BeforeAll {
  . "$PSScriptRoot/../../build/Start-Uninstaller.Functions.ps1"
}

Describe 'Get-RegistryValueNames' {

  Context 'Function metadata' {
    It 'Should exist as a command' {
      Get-Command -Name 'Get-RegistryValueNames' -ErrorAction 'SilentlyContinue' |
        Should -Not -BeNullOrEmpty
    }

    It 'Should have a mandatory Key parameter typed as RegistryKey' {
      $Param = (Get-Command 'Get-RegistryValueNames').Parameters['Key']
      $Param | Should -Not -BeNullOrEmpty
      $Param.ParameterType | Should -Be ([Microsoft.Win32.RegistryKey])
      $Param.Attributes.Where({ $PSItem -is [System.Management.Automation.ParameterAttribute] }).Mandatory |
        Should -BeTrue
    }
  }

  Context 'Delegation to GetValueNames' {
    BeforeAll {
      # HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion always has values
      $Script:BaseKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey(
        [Microsoft.Win32.RegistryHive]::LocalMachine,
        [Microsoft.Win32.RegistryView]::Default
      )
      $Script:SubKey = $Script:BaseKey.OpenSubKey(
        'SOFTWARE\Microsoft\Windows\CurrentVersion', $False
      )
    }
    AfterAll {
      If ($Null -ne $Script:SubKey)  { $Script:SubKey.Dispose()  }
      If ($Null -ne $Script:BaseKey) { $Script:BaseKey.Dispose() }
    }

    It 'Should return a string array' {
      $Names = Get-RegistryValueNames -Key $Script:SubKey
      $Names | Should -Not -BeNullOrEmpty
      $Names | ForEach-Object { $PSItem | Should -BeOfType [System.String] }
    }

    It 'Should include ProgramFilesDir value' {
      $Names = Get-RegistryValueNames -Key $Script:SubKey
      $Names | Should -Contain 'ProgramFilesDir'
    }
  }

  Context 'Error branch for disposed or invalid key' {
    It 'Should throw a terminating error when the key is disposed' {
      $BaseKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey(
        [Microsoft.Win32.RegistryHive]::LocalMachine,
        [Microsoft.Win32.RegistryView]::Default
      )
      $SubKey = $BaseKey.OpenSubKey(
        'SOFTWARE\Microsoft\Windows\CurrentVersion', $False
      )
      $SubKey.Dispose()
      $BaseKey.Dispose()

      { Get-RegistryValueNames -Key:$SubKey } | Should -Throw
    }
  }
}

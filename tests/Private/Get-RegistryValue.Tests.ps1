BeforeAll {
  . "$PSScriptRoot/../../build/Start-Uninstaller.Functions.ps1"
}

Describe 'Get-RegistryValue' {

  Context 'Function metadata' {
    It 'Should exist as a command' {
      Get-Command -Name 'Get-RegistryValue' -ErrorAction 'SilentlyContinue' |
        Should -Not -BeNullOrEmpty
    }

    It 'Should have a mandatory Key parameter typed as RegistryKey' {
      $Param = (Get-Command 'Get-RegistryValue').Parameters['Key']
      $Param | Should -Not -BeNullOrEmpty
      $Param.ParameterType | Should -Be ([Microsoft.Win32.RegistryKey])
      $Param.Attributes.Where({ $PSItem -is [System.Management.Automation.ParameterAttribute] }).Mandatory |
        Should -BeTrue
    }

    It 'Should have a mandatory Name parameter that allows empty string' {
      $Param = (Get-Command 'Get-RegistryValue').Parameters['Name']
      $Param | Should -Not -BeNullOrEmpty
      $Param.ParameterType | Should -Be ([System.String])
      $Param.Attributes.Where({ $PSItem -is [System.Management.Automation.ParameterAttribute] }).Mandatory |
        Should -BeTrue
      $Param.Attributes.Where({ $PSItem -is [System.Management.Automation.AllowEmptyStringAttribute] }) |
        Should -Not -BeNullOrEmpty
    }
  }

  Context 'Delegation to GetValue' {
    BeforeAll {
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

    It 'Should return a value for an existing registry value' {
      $Value = Get-RegistryValue -Key $Script:SubKey -Name 'ProgramFilesDir'
      $Value | Should -Not -BeNullOrEmpty
      $Value | Should -BeOfType [System.String]
    }

    It 'Should return $Null for a nonexistent value name' {
      $Value = Get-RegistryValue -Key $Script:SubKey -Name 'NoSuchValue_ZZZZZZ'
      $Value | Should -BeNullOrEmpty
    }

    It 'Should accept an empty string for the default value name' {
      # Should not throw even if the default value is empty
      { Get-RegistryValue -Key $Script:SubKey -Name '' } |
        Should -Not -Throw
    }

    It 'Wraps disposed key failures in InvalidOperationException' {
      $DisposedKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey(
        [Microsoft.Win32.RegistryHive]::LocalMachine,
        [Microsoft.Win32.RegistryView]::Default
      ).OpenSubKey('SOFTWARE\Microsoft\Windows\CurrentVersion', $False)
      $DisposedKey.Dispose()

      {
        Get-RegistryValue -Key $DisposedKey -Name 'ProgramFilesDir'
      } | Should -Throw -ExceptionType ([System.InvalidOperationException])
    }
  }
}

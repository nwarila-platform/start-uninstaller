BeforeAll {
  . "$PSScriptRoot/../../build/Start-Uninstaller.Functions.ps1"
}

Describe 'Get-RegistrySubKey' {

  Context 'Function metadata' {
    It 'Should exist as a command' {
      Get-Command -Name 'Get-RegistrySubKey' -ErrorAction 'SilentlyContinue' |
        Should -Not -BeNullOrEmpty
    }

    It 'Should have a mandatory ParentKey parameter typed as RegistryKey' {
      $Param = (Get-Command 'Get-RegistrySubKey').Parameters['ParentKey']
      $Param | Should -Not -BeNullOrEmpty
      $Param.ParameterType | Should -Be ([Microsoft.Win32.RegistryKey])
      $Param.Attributes.Where({ $PSItem -is [System.Management.Automation.ParameterAttribute] }).Mandatory |
        Should -BeTrue
    }

    It 'Should have a mandatory Name parameter typed as String' {
      $Param = (Get-Command 'Get-RegistrySubKey').Parameters['Name']
      $Param | Should -Not -BeNullOrEmpty
      $Param.ParameterType | Should -Be ([System.String])
      $Param.Attributes.Where({ $PSItem -is [System.Management.Automation.ParameterAttribute] }).Mandatory |
        Should -BeTrue
    }
  }

  Context 'Delegation to OpenSubKey' {
    BeforeAll {
      $Script:MockKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey(
        [Microsoft.Win32.RegistryHive]::LocalMachine,
        [Microsoft.Win32.RegistryView]::Default
      )
    }
    AfterAll {
      If ($Null -ne $Script:MockKey) { $Script:MockKey.Dispose() }
    }

    It 'Should return a RegistryKey for an existing subkey (SOFTWARE)' {
      $Sub = $Null
      Try {
        $Sub = Get-RegistrySubKey -ParentKey $Script:MockKey -Name 'SOFTWARE'
        $Sub | Should -Not -BeNullOrEmpty
        $Sub | Should -BeOfType [Microsoft.Win32.RegistryKey]
      } Finally {
        If ($Null -ne $Sub) { $Sub.Dispose() }
      }
    }

    It 'Should return $Null for a nonexistent subkey' {
      $Sub = Get-RegistrySubKey -ParentKey $Script:MockKey -Name 'This_Key_Does_Not_Exist_ZZZZZ'
      $Sub | Should -BeNullOrEmpty
    }

    It 'Should open the subkey as read-only (not writable)' {
      # Attempt to create a subkey under a read-only handle should throw
      $Sub = $Null
      Try {
        $Sub = Get-RegistrySubKey -ParentKey $Script:MockKey -Name 'SOFTWARE'
        { $Sub.CreateSubKey('__PesterTestWriteCheck__') } |
          Should -Throw
      } Finally {
        If ($Null -ne $Sub) { $Sub.Dispose() }
      }
    }

    It 'Wraps disposed parent-key failures in InvalidOperationException' {
      $BaseKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey(
        [Microsoft.Win32.RegistryHive]::LocalMachine,
        [Microsoft.Win32.RegistryView]::Default
      )
      Try {
        $DisposedKey = $BaseKey.OpenSubKey('SOFTWARE', $False)
        $DisposedKey.Dispose()

        {
          Get-RegistrySubKey -ParentKey $DisposedKey -Name 'Microsoft'
        } | Should -Throw -ExceptionType ([System.InvalidOperationException])
      } Finally {
        $BaseKey.Dispose()
      }
    }
  }
}

BeforeAll {
  . "$PSScriptRoot/../../build/Start-Uninstaller.Functions.ps1"
}

Describe 'Resolve-SidIdentity' {

  Context 'Function metadata' {
    It 'Should exist as a command' {
      Get-Command -Name 'Resolve-SidIdentity' -ErrorAction 'SilentlyContinue' |
        Should -Not -BeNullOrEmpty
    }

    It 'Should have a mandatory Sid parameter typed as String' {
      $Param = (Get-Command 'Resolve-SidIdentity').Parameters['Sid']
      $Param | Should -Not -BeNullOrEmpty
      $Param.ParameterType | Should -Be ([System.String])
      $Param.Attributes.Where({ $PSItem -is [System.Management.Automation.ParameterAttribute] }).Mandatory |
        Should -BeTrue
    }

    It 'Should have ValidateNotNullOrEmpty on the Sid parameter' {
      $Param = (Get-Command 'Resolve-SidIdentity').Parameters['Sid']
      $Param.Attributes.Where({ $PSItem -is [System.Management.Automation.ValidateNotNullOrEmptyAttribute] }) |
        Should -Not -BeNullOrEmpty
    }
  }

  Context 'Parameter validation' {
    It 'Should throw when Sid is missing' {
      { Resolve-SidIdentity } | Should -Throw
    }

    It 'Should throw when Sid is an empty string' {
      { Resolve-SidIdentity -Sid '' } | Should -Throw
    }

    It 'Should throw when Sid is $Null' {
      { Resolve-SidIdentity -Sid $Null } | Should -Throw
    }
  }

  Context 'Successful resolution' {
    It 'Should return a string for a well-known SID (S-1-5-18 = NT AUTHORITY\SYSTEM)' {
      $Result = Resolve-SidIdentity -Sid 'S-1-5-18'
      $Result | Should -Not -BeNullOrEmpty
      $Result | Should -BeOfType [System.String]
      $Result | Should -Match 'SYSTEM'
    }

    It 'Should return a string containing a backslash for domain-qualified names' {
      $Result = Resolve-SidIdentity -Sid 'S-1-5-18'
      # NT AUTHORITY\SYSTEM contains a backslash
      $Result | Should -Match '\\'
    }
  }

  Context 'Failed resolution' {
    It 'Should return $Null for an unresolvable SID' {
      # Fabricated SID that won't resolve to any account
      $Result = Resolve-SidIdentity -Sid 'S-1-5-21-0-0-0-99999'
      $Result | Should -BeNullOrEmpty
    }

    It 'Should not throw for an invalid SID format' {
      # The constructor itself throws for bad format, catch block returns $Null
      $Result = Resolve-SidIdentity -Sid 'NOT-A-VALID-SID'
      $Result | Should -BeNullOrEmpty
    }
  }
}

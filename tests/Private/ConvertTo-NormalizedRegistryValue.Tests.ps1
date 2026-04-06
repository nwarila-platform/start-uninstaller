BeforeAll {
  . "$PSScriptRoot/../../build/Start-Uninstaller.Functions.ps1"
}

Describe 'ConvertTo-NormalizedRegistryValue' {

  Context 'Function metadata' {
    It 'Should exist as a command' {
      Get-Command -Name 'ConvertTo-NormalizedRegistryValue' -ErrorAction 'SilentlyContinue' |
        Should -Not -BeNullOrEmpty
    }

    It 'Should have an optional Value parameter that allows $Null' {
      $Param = (Get-Command 'ConvertTo-NormalizedRegistryValue').Parameters['Value']
      $Param | Should -Not -BeNullOrEmpty
      $Param.ParameterType | Should -Be ([System.Object])
      $Param.Attributes.Where({ $PSItem -is [System.Management.Automation.AllowNullAttribute] }) |
        Should -Not -BeNullOrEmpty
    }
  }

  Context '$Null input' {
    It 'Should return $Null when Value is $Null' {
      $Result = ConvertTo-NormalizedRegistryValue -Value $Null
      $Result | Should -BeNullOrEmpty
    }

    It 'Should return $Null when Value is omitted' {
      $Result = ConvertTo-NormalizedRegistryValue
      $Result | Should -BeNullOrEmpty
    }
  }

  Context 'System.String input' {
    It 'Should return the string as-is' {
      $Result = ConvertTo-NormalizedRegistryValue -Value 'Hello World'
      $Result | Should -BeExactly 'Hello World'
      $Result | Should -BeOfType [System.String]
    }

    It 'Should preserve an empty string' {
      $Result = ConvertTo-NormalizedRegistryValue -Value ''
      $Result | Should -BeExactly ''
      $Result | Should -BeOfType [System.String]
    }

    It 'Should preserve strings with special characters' {
      $Input = 'C:\Program Files (x86)\Test & "Quoted"'
      $Result = ConvertTo-NormalizedRegistryValue -Value $Input
      $Result | Should -BeExactly $Input
    }
  }

  Context 'System.Int32 input' {
    It 'Should convert Int32 to invariant string' {
      $Result = ConvertTo-NormalizedRegistryValue -Value ([System.Int32]42)
      $Result | Should -BeExactly '42'
      $Result | Should -BeOfType [System.String]
    }

    It 'Should handle zero' {
      $Result = ConvertTo-NormalizedRegistryValue -Value ([System.Int32]0)
      $Result | Should -BeExactly '0'
    }

    It 'Should handle negative Int32' {
      $Result = ConvertTo-NormalizedRegistryValue -Value ([System.Int32]-1)
      $Result | Should -BeExactly '-1'
    }

    It 'Should handle Int32.MaxValue' {
      $Result = ConvertTo-NormalizedRegistryValue -Value ([System.Int32]::MaxValue)
      $Result | Should -BeExactly '2147483647'
    }
  }

  Context 'System.Int64 input' {
    It 'Should convert Int64 to invariant string' {
      $Result = ConvertTo-NormalizedRegistryValue -Value ([System.Int64]9876543210)
      $Result | Should -BeExactly '9876543210'
      $Result | Should -BeOfType [System.String]
    }

    It 'Should handle Int64.MaxValue' {
      $Result = ConvertTo-NormalizedRegistryValue -Value ([System.Int64]::MaxValue)
      $Result | Should -BeExactly '9223372036854775807'
    }

    It 'Should handle negative Int64' {
      $Result = ConvertTo-NormalizedRegistryValue -Value ([System.Int64]-9876543210)
      $Result | Should -BeExactly '-9876543210'
    }
  }

  Context 'System.UInt32 input' {
    It 'Should convert UInt32 to invariant string' {
      $Result = ConvertTo-NormalizedRegistryValue -Value ([System.UInt32]3000000000)
      $Result | Should -BeExactly '3000000000'
      $Result | Should -BeOfType [System.String]
    }
  }

  Context 'System.UInt64 input' {
    It 'Should convert UInt64 to invariant string' {
      $Result = ConvertTo-NormalizedRegistryValue -Value ([System.UInt64]18000000000000000000)
      $Result | Should -BeExactly '18000000000000000000'
      $Result | Should -BeOfType [System.String]
    }
  }

  Context 'System.String[] input (REG_MULTI_SZ)' {
    It 'Should join string array elements with semicolon-space' {
      $Input = [System.String[]]@('one', 'two', 'three')
      $Result = ConvertTo-NormalizedRegistryValue -Value $Input
      $Result | Should -BeExactly 'one; two; three'
      $Result | Should -BeOfType [System.String]
    }

    It 'Should handle a single-element string array' {
      $Input = [System.String[]]@('only')
      $Result = ConvertTo-NormalizedRegistryValue -Value $Input
      $Result | Should -BeExactly 'only'
    }

    It 'Should handle an empty string array' {
      $Input = [System.String[]]@()
      $Result = ConvertTo-NormalizedRegistryValue -Value $Input
      $Result | Should -BeExactly ''
    }

    It 'Should handle string array with empty elements' {
      $Input = [System.String[]]@('a', '', 'c')
      $Result = ConvertTo-NormalizedRegistryValue -Value $Input
      $Result | Should -BeExactly 'a; ; c'
    }
  }

  Context 'Unsupported types return $Null' {
    It 'Should return $Null for byte array (REG_BINARY)' {
      $Input = [System.Byte[]]@(0x01, 0x02, 0x03)
      $Result = ConvertTo-NormalizedRegistryValue -Value $Input
      $Result | Should -BeNullOrEmpty
    }

    It 'Should return $Null for a boolean' {
      $Result = ConvertTo-NormalizedRegistryValue -Value $True
      $Result | Should -BeNullOrEmpty
    }

    It 'Should return $Null for a DateTime' {
      $Result = ConvertTo-NormalizedRegistryValue -Value ([System.DateTime]::Now)
      $Result | Should -BeNullOrEmpty
    }

    It 'Should return $Null for a hashtable' {
      $Result = ConvertTo-NormalizedRegistryValue -Value @{ Key = 'Val' }
      $Result | Should -BeNullOrEmpty
    }

    It 'Should return $Null for a PSCustomObject' {
      $Result = ConvertTo-NormalizedRegistryValue -Value ([PSCustomObject]@{ A = 1 })
      $Result | Should -BeNullOrEmpty
    }

    It 'Should return $Null for a double' {
      $Result = ConvertTo-NormalizedRegistryValue -Value ([System.Double]3.14)
      $Result | Should -BeNullOrEmpty
    }
  }
}

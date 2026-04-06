BeforeAll {
  . "$PSScriptRoot/../../build/Start-Uninstaller.Functions.ps1"
}

Describe 'Get-Is64BitOperatingSystem' {

  Context 'Function metadata' {
    It 'Should exist as a command' {
      Get-Command -Name 'Get-Is64BitOperatingSystem' -ErrorAction 'SilentlyContinue' |
        Should -Not -BeNullOrEmpty
    }

    It 'Should accept no parameters (aside from common)' {
      $Cmd = Get-Command -Name 'Get-Is64BitOperatingSystem'
      # Only common parameters should exist
      $Custom = $Cmd.Parameters.Keys | Where-Object {
        $PSItem -notin [System.Management.Automation.PSCmdlet]::CommonParameters
      }
      $Custom | Should -HaveCount 0
    }
  }

  Context 'Return value' {
    It 'Should return a System.Boolean' {
      $Result = Get-Is64BitOperatingSystem
      $Result | Should -BeOfType [System.Boolean]
    }

    It 'Should return the same value as [System.Environment]::Is64BitOperatingSystem' {
      $Expected = [System.Boolean][System.Environment]::Is64BitOperatingSystem
      $Result   = Get-Is64BitOperatingSystem
      $Result | Should -Be $Expected
    }
  }

  Context 'Idempotency' {
    It 'Should return the same result on consecutive calls' {
      $First  = Get-Is64BitOperatingSystem
      $Second = Get-Is64BitOperatingSystem
      $First | Should -Be $Second
    }
  }
}

#Requires -Module Pester

Describe 'Invoke-SilentProcess' {

  BeforeAll {
    . "$PSScriptRoot\..\..\build\Start-Uninstaller.Functions.ps1"
  }

  Context 'Success exit codes' {
    It 'Returns Succeeded with ExitCode 0 for a successful process' {
      $Result = Invoke-SilentProcess `
        -FileName 'cmd.exe' `
        -Arguments '/c exit 0' `
        -TimeoutSeconds 30

      $Result.Outcome  | Should -Be 'Succeeded'
      $Result.ExitCode | Should -Be 0
      $Result.Message  | Should -Be 'Success.'
    }

    It 'Returns Succeeded with reboot initiated message for exit 1641' {
      $Result = Invoke-SilentProcess `
        -FileName 'cmd.exe' `
        -Arguments '/c exit 1641' `
        -TimeoutSeconds 30

      $Result.Outcome  | Should -Be 'Succeeded'
      $Result.ExitCode | Should -Be 1641
      $Result.Message  | Should -Be 'Success (reboot initiated).'
    }

    It 'Returns Succeeded with reboot required message for exit 3010' {
      $Result = Invoke-SilentProcess `
        -FileName 'cmd.exe' `
        -Arguments '/c exit 3010' `
        -TimeoutSeconds 30

      $Result.Outcome  | Should -Be 'Succeeded'
      $Result.ExitCode | Should -Be 3010
      $Result.Message  | Should -Be 'Success (reboot required).'
    }
  }

  Context 'Failure result enrichment' {
    It 'Includes captured stderr in failure messages when useful' {
      $Result = Invoke-SilentProcess `
        -FileName 'cmd.exe' `
        -Arguments '/c echo failure-text 1>&2 & exit 7' `
        -TimeoutSeconds 30

      $Result.Outcome  | Should -Be 'Failed'
      $Result.ExitCode | Should -Be 7
      $Result.Message  | Should -Match 'Exit code 7\.'
      $Result.Message  | Should -Match 'stderr: failure-text'
    }
  }

  Context 'Timeout handling' {
    It 'Returns TimedOut and enriches the message with captured output' {
      $Result = Invoke-SilentProcess `
        -FileName 'cmd.exe' `
        -Arguments '/c echo timeout-text 1>&2 & ping -n 120 127.0.0.1 > nul' `
        -TimeoutSeconds 1

      $Result.Outcome | Should -Be 'TimedOut'
      $Result.Message | Should -Match 'timed out'
      $Result.Message | Should -Match 'stderr: timeout-text'
      ($Null -eq $Result.ExitCode -or $Result.ExitCode -is [System.Int32]) |
        Should -BeTrue
    }

    It 'Returns promptly after timeout instead of waiting for natural exit' {
      $Elapsed = Measure-Command {
        $Result = Invoke-SilentProcess `
          -FileName 'cmd.exe' `
          -Arguments '/c ping -n 6 127.0.0.1 > nul' `
          -TimeoutSeconds 1
      }

      $Result.Outcome | Should -Be 'TimedOut'
      $Elapsed.TotalSeconds | Should -BeLessThan 15
    }
  }

  Context 'Start failure returns Failed outcome' {
    It 'Returns Failed when the executable does not exist' {
      $Result = Invoke-SilentProcess `
        -FileName 'C:\NonExistent\Totally_Fake_09f8a7d6.exe' `
        -Arguments '/S' `
        -TimeoutSeconds 30

      $Result.Outcome  | Should -Be 'Failed'
      $Result.ExitCode | Should -BeNullOrEmpty
      $Result.Message  | Should -Match 'Failed to start process'
      $Result.Message  | Should -Match 'Totally_Fake_09f8a7d6\.exe'
    }
  }

  Context 'Async stream handling' {
    It 'Completes successfully even when child produces large stdout' {
      $LargeOutputCommand = '/c for /L %i in (1,1,5000) do @echo Line %i'
      $Result = Invoke-SilentProcess `
        -FileName 'cmd.exe' `
        -Arguments $LargeOutputCommand `
        -TimeoutSeconds 60

      $Result.Outcome  | Should -Be 'Succeeded'
      $Result.ExitCode | Should -Be 0
    }

    It 'Completes successfully even when child produces large stderr' {
      $LargeErrorCommand = '/c for /L %i in (1,1,5000) do @echo Error %i 1>&2'
      $Result = Invoke-SilentProcess `
        -FileName 'cmd.exe' `
        -Arguments $LargeErrorCommand `
        -TimeoutSeconds 60

      $Result.Outcome  | Should -Be 'Succeeded'
      $Result.ExitCode | Should -Be 0
    }
  }

  Context 'Parameter validation' {
    It 'Rejects TimeoutSeconds below 1' {
      {
        Invoke-SilentProcess -FileName 'cmd.exe' -Arguments '' -TimeoutSeconds 0
      } | Should -Throw
    }

    It 'Rejects TimeoutSeconds above 3600' {
      {
        Invoke-SilentProcess -FileName 'cmd.exe' -Arguments '' -TimeoutSeconds 3601
      } | Should -Throw
    }

    It 'Rejects empty FileName' {
      {
        Invoke-SilentProcess -FileName '' -Arguments ''
      } | Should -Throw
    }
  }
}

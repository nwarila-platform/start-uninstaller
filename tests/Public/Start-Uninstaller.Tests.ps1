#Requires -Module Pester

Describe 'Start-Uninstaller (Orchestrator)' {

  BeforeAll {
    . "$PSScriptRoot\..\..\build\Start-Uninstaller.Functions.ps1"

    Function New-FakeApp {
      Param (
        [System.String] $DisplayName = 'TestApp',
        [System.String] $DisplayVersion = '1.0.0',
        [System.String] $Publisher = 'TestVendor',
        [System.String] $AppArch = 'x64',
        [System.String] $InstallScope = 'System',
        [System.Boolean] $IsHidden = $False,
        [System.String] $RegistryPath = 'HKLM:\Software\...\TestApp',
        [System.String] $UserSid = 'S-1-5-18',
        [System.String] $UserName = 'SYSTEM',
        [System.String] $UserIdentityStatus = 'System',
        [System.String] $UninstallString = '"C:\App\unins000.exe" /SILENT',
        [System.String] $QuietUninstallString = $Null
      )

      $Object = [PSCustomObject]@{
        DisplayName        = $DisplayName
        DisplayVersion     = $DisplayVersion
        Publisher          = $Publisher
        AppArch            = $AppArch
        InstallScope       = $InstallScope
        IsHidden           = $IsHidden
        RegistryPath       = $RegistryPath
        UserSid            = $UserSid
        UserName           = $UserName
        UserIdentityStatus = $UserIdentityStatus
        UninstallString    = $UninstallString
      }

      If ($Null -ne $QuietUninstallString) {
        $Object | Add-Member -NotePropertyName 'QuietUninstallString' `
          -NotePropertyValue $QuietUninstallString
      }

      $Object
    }

    $Script:DefaultFilter = @(
      @{ Property = 'DisplayName'; Value = 'TestApp'; MatchType = 'Simple' }
    )
  }

  BeforeEach {
    Mock -CommandName 'New-CompiledFilter' -MockWith {
      [PSCustomObject]@{
        Property  = 'DisplayName'
        Value     = 'TestApp'
        MatchType = 'Simple'
      }
    }

    Mock -CommandName 'Get-UninstallRegistryPath' -MockWith {
      @([PSCustomObject]@{
        Hive   = 'HKLM'
        Path   = 'Software\Microsoft\Windows\CurrentVersion\Uninstall'
        View   = 'Registry64'
        Source = 'HKLM64'
      })
    }

    Mock -CommandName 'Get-InstalledApplication' -MockWith {
      @(New-FakeApp)
    }

    Mock -CommandName 'Resolve-UninstallString' -MockWith {
      '"C:\App\unins000.exe" /SILENT'
    }

    Mock -CommandName 'Resolve-UninstallCommand' -MockWith {
      [PSCustomObject]@{
        PSTypeName = 'StartUninstaller.UninstallCommand'
        FileName   = 'C:\App\unins000.exe'
        Arguments  = '/SILENT'
      }
    }

    Mock -CommandName 'Invoke-SilentProcess' -MockWith {
      [PSCustomObject]@{
        Outcome  = 'Succeeded'
        ExitCode = 0
        Message  = 'Success.'
      }
    }
  }

  Context 'ListOnly with matches returns exit 0' {
    It 'Returns exit code 0 and one output line' {
      $Result = Start-Uninstaller -Filter $Script:DefaultFilter -ListOnly

      $Result.ExitCode | Should -Be 0
      $Result.Lines | Should -HaveCount 1
    }

    It 'Does not invoke uninstall helpers' {
      $Null = Start-Uninstaller -Filter $Script:DefaultFilter -ListOnly

      Should -Invoke -CommandName 'Invoke-SilentProcess' -Times 0 -Exactly
      Should -Invoke -CommandName 'Resolve-UninstallString' -Times 0 -Exactly
    }
  }

  Context 'No matches returns exit 1' {
    BeforeEach {
      Mock -CommandName 'Get-InstalledApplication' -MockWith { @() }
    }

    It 'Returns exit code 1 with a no-match line' {
      $Result = Start-Uninstaller -Filter $Script:DefaultFilter

      $Result.ExitCode | Should -Be 1
      $Result.Lines | Should -HaveCount 1
      $Result.Lines[0] | Should -Match 'No applications matched'
    }
  }

  Context 'Multiple matches without AllowMultipleMatches returns exit 2' {
    BeforeEach {
      Mock -CommandName 'Get-InstalledApplication' -MockWith {
        @(
          (New-FakeApp -RegistryPath 'Path1'),
          (New-FakeApp -RegistryPath 'Path2')
        )
      }
    }

    It 'Returns exit code 2 and emits one blocked line per match' {
      $Result = Start-Uninstaller -Filter $Script:DefaultFilter

      $Result.ExitCode | Should -Be 2
      $Result.Lines | Should -HaveCount 2
      $Result.Lines[0] | Should -Match 'Outcome=Blocked'
      $Result.Lines[1] | Should -Match 'Outcome=Blocked'
    }

    It 'Does not launch any uninstall processes' {
      $Null = Start-Uninstaller -Filter $Script:DefaultFilter

      Should -Invoke -CommandName 'Invoke-SilentProcess' -Times 0 -Exactly
    }
  }

  Context 'Multiple matches with AllowMultipleMatches uninstalls all' {
    BeforeEach {
      Mock -CommandName 'Get-InstalledApplication' -MockWith {
        @(
          (New-FakeApp -RegistryPath 'Path1'),
          (New-FakeApp -RegistryPath 'Path2')
        )
      }
    }

    It 'Returns exit code 0 when all succeed' {
      $Result = Start-Uninstaller `
        -Filter $Script:DefaultFilter `
        -AllowMultipleMatches

      $Result.ExitCode | Should -Be 0
      $Result.Lines | Should -HaveCount 2
    }

    It 'Invokes Invoke-SilentProcess once per match' {
      $Null = Start-Uninstaller `
        -Filter $Script:DefaultFilter `
        -AllowMultipleMatches

      Should -Invoke -CommandName 'Invoke-SilentProcess' -Times 2 -Exactly
    }
  }

  Context 'Single match returns exit 0 on success' {
    It 'Returns exit code 0 and one output line' {
      $Result = Start-Uninstaller -Filter $Script:DefaultFilter

      $Result.ExitCode | Should -Be 0
      $Result.Lines | Should -HaveCount 1
      $Result.Lines[0] | Should -Match 'Outcome=Succeeded'
    }
  }

  Context 'Failed uninstall returns exit 3' {
    BeforeEach {
      Mock -CommandName 'Invoke-SilentProcess' -MockWith {
        [PSCustomObject]@{
          Outcome  = 'Failed'
          ExitCode = 1603
          Message  = 'Exit code 1603.'
        }
      }
    }

    It 'Returns exit code 3' {
      (Start-Uninstaller -Filter $Script:DefaultFilter).ExitCode | Should -Be 3
    }
  }

  Context 'Post-attempt formatting failures still return exit 3' {
    BeforeEach {
      Mock -CommandName 'Invoke-SilentProcess' -MockWith {
        [PSCustomObject]@{
          Outcome  = 'Failed'
          ExitCode = 1603
          Message  = 'Exit code 1603.'
        }
      }

      Mock -CommandName 'Format-OutputLine' -MockWith {
        Throw [System.InvalidOperationException]::new('Formatting exploded.')
      }
    }

    It 'Classifies the failure as post-attempt instead of fatal pre-processing' {
      $Result = Start-Uninstaller -Filter $Script:DefaultFilter

      $Result.ExitCode | Should -Be 3
      $Result.Lines[-1] | Should -Match 'after one or more attempts'
    }
  }

  Context 'Timed out uninstall returns exit 3' {
    BeforeEach {
      Mock -CommandName 'Invoke-SilentProcess' -MockWith {
        [PSCustomObject]@{
          Outcome  = 'TimedOut'
          ExitCode = $Null
          Message  = 'Process timed out after 600 seconds.'
        }
      }
    }

    It 'Returns exit code 3' {
      (Start-Uninstaller -Filter $Script:DefaultFilter).ExitCode | Should -Be 3
    }
  }

  Context 'No uninstall string returns Failed, exit 3' {
    BeforeEach {
      Mock -CommandName 'Resolve-UninstallString' -MockWith { $Null }
    }

    It 'Returns exit code 3 without launching a process' {
      $Result = Start-Uninstaller -Filter $Script:DefaultFilter

      $Result.ExitCode | Should -Be 3
      Should -Invoke -CommandName 'Invoke-SilentProcess' -Times 0 -Exactly
    }
  }

  Context 'Unsupported command returns Failed, exit 3' {
    BeforeEach {
      Mock -CommandName 'Resolve-UninstallCommand' -MockWith { $Null }
    }

    It 'Returns exit code 3 without launching a process' {
      $Result = Start-Uninstaller -Filter $Script:DefaultFilter

      $Result.ExitCode | Should -Be 3
      Should -Invoke -CommandName 'Invoke-SilentProcess' -Times 0 -Exactly
    }
  }

  Context 'Invalid -Properties values return exit 4' {
    It 'Rejects synthetic fields' {
      $Result = Start-Uninstaller `
        -Filter $Script:DefaultFilter `
        -Properties @('AppArch')

      $Result.ExitCode | Should -Be 4
      $Result.Lines[0] | Should -Match 'Synthetic field.*AppArch'
    }

    It 'Rejects whitespace-only property names before discovery' {
      $Result = Start-Uninstaller `
        -Filter $Script:DefaultFilter `
        -Properties @('   ')

      $Result.ExitCode | Should -Be 4
      Should -Invoke -CommandName 'Get-UninstallRegistryPath' -Times 0 -Exactly
    }

    It 'Rejects NUL-containing property names' {
      $Result = Start-Uninstaller `
        -Filter $Script:DefaultFilter `
        -Properties @("Bad`0Name")

      $Result.ExitCode | Should -Be 4
      $Result.Lines[0] | Should -Match 'cannot contain NUL'
    }
  }

  Context 'Filter validation failure returns exit 4' {
    BeforeEach {
      Mock -CommandName 'New-CompiledFilter' -MockWith {
        Throw [System.ArgumentException]::new('Property is required.')
      }
    }

    It 'Returns exit code 4 with a fatal line' {
      $Result = Start-Uninstaller `
        -Filter @(@{ Value = 'X'; MatchType = 'Simple' })

      $Result.ExitCode | Should -Be 4
      $Result.Lines[0] | Should -Match 'Filter validation failed'
    }
  }

  Context 'Fatal pre-processing errors return exit 4' {
    BeforeEach {
      Mock -CommandName 'Get-UninstallRegistryPath' -MockWith {
        Throw [System.InvalidOperationException]::new('Registry unavailable.')
      }
    }

    It 'Emits one fatal line and does not start uninstall work' {
      $Result = Start-Uninstaller -Filter $Script:DefaultFilter

      $Result.ExitCode | Should -Be 4
      $Result.Lines | Should -HaveCount 1
      $Result.Lines[0] | Should -Match 'Fatal pre-processing error'
      Should -Invoke -CommandName 'Invoke-SilentProcess' -Times 0 -Exactly
    }
  }

  Context 'Output field ordering is delegated to ConvertTo-OutputFieldList' {
    It 'Calls ConvertTo-OutputFieldList for list mode' {
      Mock -CommandName 'ConvertTo-OutputFieldList' -MockWith {
        @('AppArch', 'DisplayName')
      }

      $Null = Start-Uninstaller -Filter $Script:DefaultFilter -ListOnly

      Should -Invoke -CommandName 'ConvertTo-OutputFieldList' -Times 1 -Exactly
    }

    It 'Calls ConvertTo-OutputFieldList for uninstall mode' {
      Mock -CommandName 'ConvertTo-OutputFieldList' -MockWith {
        @('AppArch', 'DisplayName', 'Outcome')
      }

      $Null = Start-Uninstaller -Filter $Script:DefaultFilter

      Should -Invoke -CommandName 'ConvertTo-OutputFieldList' -Times 1 -Exactly
    }
  }

  Context 'EXEFlags passthrough' {
    It 'Passes EXEFlags to Resolve-UninstallCommand when specified' {
      $Null = Start-Uninstaller `
        -Filter $Script:DefaultFilter `
        -EXEFlags '/VERYSILENT /NORESTART'

      Should -Invoke -CommandName 'Resolve-UninstallCommand' -Times 1 -Exactly `
        -ParameterFilter {
          $EXEFlags -eq '/VERYSILENT /NORESTART'
        }
    }

    It 'Sets HasCustomEXEFlags on Resolve-UninstallString when EXEFlags specified' {
      $Null = Start-Uninstaller `
        -Filter $Script:DefaultFilter `
        -EXEFlags '/VERYSILENT'

      Should -Invoke -CommandName 'Resolve-UninstallString' -Times 1 -Exactly `
        -ParameterFilter {
          $HasCustomEXEFlags -eq $True
        }
    }

    It 'Passes $Null EXEFlags to Resolve-UninstallCommand when not specified' {
      $Null = Start-Uninstaller -Filter $Script:DefaultFilter

      Should -Invoke -CommandName 'Resolve-UninstallCommand' -Times 1 -Exactly `
        -ParameterFilter {
          [System.String]::IsNullOrEmpty($EXEFlags)
        }
    }
  }

  Context 'Aggregate exit code with mixed outcomes' {
    BeforeEach {
      Mock -CommandName 'Get-InstalledApplication' -MockWith {
        @(
          (New-FakeApp -DisplayName 'App1' -RegistryPath 'Path1'),
          (New-FakeApp -DisplayName 'App2' -RegistryPath 'Path2')
        )
      }

      $Script:InvokeCallCount = 0
      Mock -CommandName 'Invoke-SilentProcess' -MockWith {
        $Script:InvokeCallCount++
        If ($Script:InvokeCallCount -eq 1) {
          [PSCustomObject]@{
            Outcome  = 'Succeeded'
            ExitCode = 0
            Message  = 'Success.'
          }
        } Else {
          [PSCustomObject]@{
            Outcome  = 'Failed'
            ExitCode = 1603
            Message  = 'Exit code 1603.'
          }
        }
      }
    }

    It 'Returns exit code 3 when any uninstall fails' {
      $Result = Start-Uninstaller `
        -Filter $Script:DefaultFilter `
        -AllowMultipleMatches

      $Result.ExitCode | Should -Be 3
    }
  }

  Context 'TimeoutSeconds passthrough' {
    It 'Passes TimeoutSeconds to Invoke-SilentProcess' {
      $Null = Start-Uninstaller `
        -Filter $Script:DefaultFilter `
        -TimeoutSeconds 120

      Should -Invoke -CommandName 'Invoke-SilentProcess' -Times 1 -Exactly `
        -ParameterFilter {
          $TimeoutSeconds -eq 120
        }
    }
  }

  Context 'Raw -Properties are emitted in output lines' {
    BeforeEach {
      Mock -CommandName 'Get-InstalledApplication' -MockWith {
        @(New-FakeApp `
          -DisplayName 'PropsApp' `
          -Publisher 'AcmeCorp' `
          -DisplayVersion '2.5.0')
      }
    }

    It 'Output lines contain the specified property values' {
      $Result = Start-Uninstaller `
        -Filter $Script:DefaultFilter `
        -Properties @('Publisher', 'DisplayVersion') `
        -ListOnly

      $Result.ExitCode | Should -Be 0
      $Result.Lines | Should -HaveCount 1
      $Result.Lines[0] | Should -Match 'Publisher=AcmeCorp'
      $Result.Lines[0] | Should -Match 'DisplayVersion=2\.5\.0'
    }
  }

  Context 'Missing property emits <null>' {
    It 'Shows NonExistentProp=<null> for missing properties' {
      $Result = Start-Uninstaller `
        -Filter $Script:DefaultFilter `
        -Properties @('NonExistentProp') `
        -ListOnly

      $Result.ExitCode | Should -Be 0
      $Result.Lines | Should -HaveCount 1
      $Result.Lines[0] | Should -Match 'NonExistentProp=<null>'
    }
  }

  Context 'Filter property auto-append' {
    BeforeEach {
      Mock -CommandName 'New-CompiledFilter' -MockWith {
        [PSCustomObject]@{
          Property  = 'Publisher'
          Value     = 'TestCorp'
          MatchType = 'Simple'
        }
      }

      Mock -CommandName 'ConvertTo-OutputFieldList' -MockWith {
        @('DisplayName', 'Publisher')
      }
    }

    It 'Passes filter property names to ConvertTo-OutputFieldList' {
      $Null = Start-Uninstaller `
        -Filter @(@{ Property = 'Publisher'; Value = 'TestCorp'; MatchType = 'Simple' }) `
        -ListOnly

      Should -Invoke -CommandName 'ConvertTo-OutputFieldList' -Times 1 -Exactly `
        -ParameterFilter {
          $FilterPropertyNames -contains 'Publisher'
        }
    }
  }

  Context 'Synthetic filter property auto-append' {
    BeforeEach {
      Mock -CommandName 'New-CompiledFilter' -MockWith {
        [PSCustomObject]@{
          Property  = 'AppArch'
          Value     = 'x64'
          MatchType = 'Simple'
        }
      }

      Mock -CommandName 'ConvertTo-OutputFieldList' -MockWith {
        @('DisplayName', 'AppArch')
      }
    }

    It 'Passes synthetic filter property names to ConvertTo-OutputFieldList' {
      $Null = Start-Uninstaller `
        -Filter @(@{ Property = 'AppArch'; Value = 'x64'; MatchType = 'Simple' }) `
        -ListOnly

      Should -Invoke -CommandName 'ConvertTo-OutputFieldList' -Times 1 -Exactly `
        -ParameterFilter {
          $FilterPropertyNames -contains 'AppArch'
        }
    }
  }
}

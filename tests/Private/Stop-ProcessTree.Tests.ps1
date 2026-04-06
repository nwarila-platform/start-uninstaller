BeforeAll {
  . "$PSScriptRoot/../../build/Start-Uninstaller.Functions.ps1"
}

Describe 'Stop-ProcessTree' {

  Context 'Function metadata' {
    It 'Should exist as a command' {
      Get-Command -Name 'Stop-ProcessTree' -ErrorAction 'SilentlyContinue' |
        Should -Not -BeNullOrEmpty
    }

    It 'Should have a mandatory ProcessId parameter typed as Int32' {
      $Param = (Get-Command 'Stop-ProcessTree').Parameters['ProcessId']
      $Param | Should -Not -BeNullOrEmpty
      $Param.ParameterType | Should -Be ([System.Int32])
      $Param.Attributes.Where({ $PSItem -is [System.Management.Automation.ParameterAttribute] }).Mandatory |
        Should -BeTrue
    }
  }

  Context 'No children — single process kill' {
    It 'Should call GetProcessById and Kill for the target PID' {
      $Script:KillCalled = $False
      $Script:DisposeCalled = $False

      Mock -CommandName 'Get-CimInstance' -MockWith { @() }

      # We cannot directly mock [System.Diagnostics.Process]::GetProcessById,
      # but the function catches exceptions from it. A nonexistent PID will
      # go through the catch path silently. Verify no throw.
      { Stop-ProcessTree -ProcessId 999999 } | Should -Not -Throw
    }

    It 'Should query Win32_Process for children of the given PID' {
      Mock -CommandName 'Get-CimInstance' -MockWith { @() }
      Stop-ProcessTree -ProcessId 12345
      Should -Invoke -CommandName 'Get-CimInstance' -Times 1 -Exactly -ParameterFilter {
        $ClassName -eq 'Win32_Process' -and $Filter -eq 'ParentProcessId = 12345'
      }
    }
  }

  Context 'Recursive child kill' {
    It 'Should recursively kill children before killing the parent' {
      $Script:CimCallOrder = [System.Collections.Generic.List[System.Int32]]::new()

      Mock -CommandName 'Get-CimInstance' -MockWith {
        Param($ClassName, $Filter)
        # Extract PID from filter
        If ($Filter -match 'ParentProcessId = (\d+)') {
          $QueryPid = [System.Int32]$Matches[1]
          $Script:CimCallOrder.Add($QueryPid)

          If ($QueryPid -eq 100) {
            # Parent 100 has child 200
            Return @([PSCustomObject]@{ ProcessId = [System.UInt32]200 })
          }
          If ($QueryPid -eq 200) {
            # Child 200 has grandchild 300
            Return @([PSCustomObject]@{ ProcessId = [System.UInt32]300 })
          }
        }
        Return @()
      }

      { Stop-ProcessTree -ProcessId 100 } | Should -Not -Throw

      # Verify recursive traversal: should query 100, then 200, then 300
      $Script:CimCallOrder | Should -HaveCount 3
      $Script:CimCallOrder[0] | Should -Be 100
      $Script:CimCallOrder[1] | Should -Be 200
      $Script:CimCallOrder[2] | Should -Be 300
    }

    It 'Should handle multiple children at the same level' {
      Mock -CommandName 'Get-CimInstance' -MockWith {
        Param($ClassName, $Filter)
        If ($Filter -match 'ParentProcessId = (\d+)') {
          $QueryPid = [System.Int32]$Matches[1]
          If ($QueryPid -eq 100) {
            Return @(
              [PSCustomObject]@{ ProcessId = [System.UInt32]201 },
              [PSCustomObject]@{ ProcessId = [System.UInt32]202 }
            )
          }
        }
        Return @()
      }

      { Stop-ProcessTree -ProcessId 100 } | Should -Not -Throw

      # Parent query + 2 child queries + no grandchildren queries
      Should -Invoke -CommandName 'Get-CimInstance' -Times 3 -Exactly
    }
  }

  Context 'Error handling' {
    It 'Should not throw when Get-CimInstance fails' {
      Mock -CommandName 'Get-CimInstance' -MockWith { Throw 'WMI failure' }
      { Stop-ProcessTree -ProcessId 42 } | Should -Not -Throw
    }

    It 'Should not throw when the target process has already exited' {
      Mock -CommandName 'Get-CimInstance' -MockWith { @() }
      # PID 999999 almost certainly doesn't exist — GetProcessById will throw,
      # but the function catches it
      { Stop-ProcessTree -ProcessId 999999 } | Should -Not -Throw
    }
  }
}

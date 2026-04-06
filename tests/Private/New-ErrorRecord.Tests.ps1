BeforeAll {
  . "$PSScriptRoot/../../build/Start-Uninstaller.Functions.ps1"
}

Describe 'New-ErrorRecord' {

  Context 'Function metadata' {
    It 'Should exist as a command' {
      Get-Command -Name:'New-ErrorRecord' -ErrorAction:'SilentlyContinue' |
        Should -Not -BeNullOrEmpty
    }

    It 'Should have mandatory ExceptionName parameter typed as String' {
      $Cmd = Get-Command -Name:'New-ErrorRecord'
      $Param = $Cmd.Parameters['ExceptionName']
      $Param | Should -Not -BeNullOrEmpty
      $Param.ParameterType.FullName | Should -Be 'System.String'
      $Param.Attributes.Where({ $PSItem -is [System.Management.Automation.ParameterAttribute] })[0].Mandatory |
        Should -BeTrue
    }

    It 'Should have mandatory ExceptionMessage parameter typed as String' {
      $Cmd = Get-Command -Name:'New-ErrorRecord'
      $Param = $Cmd.Parameters['ExceptionMessage']
      $Param | Should -Not -BeNullOrEmpty
      $Param.ParameterType.FullName | Should -Be 'System.String'
      $Param.Attributes.Where({ $PSItem -is [System.Management.Automation.ParameterAttribute] })[0].Mandatory |
        Should -BeTrue
    }

    It 'Should have mandatory ErrorId parameter typed as String' {
      $Cmd = Get-Command -Name:'New-ErrorRecord'
      $Param = $Cmd.Parameters['ErrorId']
      $Param | Should -Not -BeNullOrEmpty
      $Param.ParameterType.FullName | Should -Be 'System.String'
      $Param.Attributes.Where({ $PSItem -is [System.Management.Automation.ParameterAttribute] })[0].Mandatory |
        Should -BeTrue
    }

    It 'Should have mandatory ErrorCategory parameter typed as ErrorCategory' {
      $Cmd = Get-Command -Name:'New-ErrorRecord'
      $Param = $Cmd.Parameters['ErrorCategory']
      $Param | Should -Not -BeNullOrEmpty
      $Param.ParameterType.FullName |
        Should -Be 'System.Management.Automation.ErrorCategory'
      $Param.Attributes.Where({ $PSItem -is [System.Management.Automation.ParameterAttribute] })[0].Mandatory |
        Should -BeTrue
    }

    It 'Should have optional IsFatal parameter typed as Boolean' {
      $Cmd = Get-Command -Name:'New-ErrorRecord'
      $Param = $Cmd.Parameters['IsFatal']
      $Param | Should -Not -BeNullOrEmpty
      $Param.ParameterType.FullName | Should -Be 'System.Boolean'
      $Param.Attributes.Where({ $PSItem -is [System.Management.Automation.ParameterAttribute] })[0].Mandatory |
        Should -BeFalse
    }
  }

  Context 'Valid exception type' {
    BeforeAll {
      $Script:CommonParams = @{
        ExceptionName    = 'System.InvalidOperationException'
        ExceptionMessage = 'Test error message'
        ErrorId          = 'TestErrorId'
        ErrorCategory    = [System.Management.Automation.ErrorCategory]::InvalidOperation
      }
    }

    It 'Should return an ErrorRecord when given a valid exception type' {
      $Result = New-ErrorRecord @CommonParams
      $Result | Should -BeOfType [System.Management.Automation.ErrorRecord]
    }

    It 'Should set the exception message correctly' {
      $Result = New-ErrorRecord @CommonParams
      $Result.Exception.Message | Should -Be 'Test error message'
    }

    It 'Should set the ErrorId correctly' {
      $Result = New-ErrorRecord @CommonParams
      $Result.FullyQualifiedErrorId | Should -BeLike 'TestErrorId*'
    }

    It 'Should set the ErrorCategory correctly' {
      $Result = New-ErrorRecord @CommonParams
      $Result.CategoryInfo.Category |
        Should -Be ([System.Management.Automation.ErrorCategory]::InvalidOperation)
    }

    It 'Should set the TargetObject correctly' {
      $Target = 'SomeTargetValue'
      $Result = New-ErrorRecord @CommonParams -TargetObject:$Target
      $Result.TargetObject | Should -Be 'SomeTargetValue'
    }

    It 'Should set TargetObject to $Null when not specified' {
      $Result = New-ErrorRecord @CommonParams
      $Result.TargetObject | Should -BeNullOrEmpty
    }
  }

  Context 'Invalid exception type fallback' {
    BeforeAll {
      $Script:FallbackParams = @{
        ExceptionName    = 'Not.A.Real.Exception'
        ExceptionMessage = 'Fallback test message'
        ErrorId          = 'FallbackErrorId'
        ErrorCategory    = [System.Management.Automation.ErrorCategory]::InvalidOperation
      }
    }

    It 'Should fall back to RuntimeException when the exception type name is invalid' {
      $Result = New-ErrorRecord @FallbackParams -WarningAction:'SilentlyContinue'
      $Result | Should -BeOfType [System.Management.Automation.ErrorRecord]
      $Result.Exception | Should -BeOfType [System.Management.Automation.RuntimeException]
    }

    It 'Should still set the correct exception message in the fallback' {
      $Result = New-ErrorRecord @FallbackParams -WarningAction:'SilentlyContinue'
      $Result.Exception.Message | Should -Be 'Fallback test message'
    }

    It 'Should emit a warning when falling back' {
      $Result = New-ErrorRecord @FallbackParams -WarningVariable:'CapturedWarning' -WarningAction:'Continue'
      $CapturedWarning | Should -Not -BeNullOrEmpty
      $CapturedWarning[0] | Should -BeLike '*Not.A.Real.Exception*'
    }
  }

  Context 'Fatal behavior' {
    BeforeAll {
      $Script:FatalParams = @{
        ExceptionName    = 'System.InvalidOperationException'
        ExceptionMessage = 'Fatal test message'
        ErrorId          = 'FatalErrorId'
        ErrorCategory    = [System.Management.Automation.ErrorCategory]::InvalidOperation
      }
    }

    It 'Should throw a terminating error when IsFatal is $True' {
      { New-ErrorRecord @FatalParams -IsFatal:$True } | Should -Throw
    }

    It 'Should return an ErrorRecord (not throw) when IsFatal is $False' {
      $Result = New-ErrorRecord @FatalParams -IsFatal:$False
      $Result | Should -BeOfType [System.Management.Automation.ErrorRecord]
    }
  }
}

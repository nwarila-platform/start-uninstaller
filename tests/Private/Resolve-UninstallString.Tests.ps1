#Requires -Module Pester

Describe 'Resolve-UninstallString' {

  BeforeAll {
    . "$PSScriptRoot\..\..\build\Start-Uninstaller.Functions.ps1"

    # ── Helper to build a minimal application record ──────────
    Function New-AppRecord {
      Param (
        [System.String] $UninstallString,
        [System.String] $QuietUninstallString
      )
      $Obj = [PSCustomObject]@{}
      If ($PSBoundParameters.ContainsKey('UninstallString')) {
        $Obj | Add-Member -NotePropertyName 'UninstallString' `
          -NotePropertyValue $UninstallString
      }
      If ($PSBoundParameters.ContainsKey('QuietUninstallString')) {
        $Obj | Add-Member -NotePropertyName 'QuietUninstallString' `
          -NotePropertyValue $QuietUninstallString
      }
      $Obj
    }
  }

  Context 'QuietUninstallString preference' {

    It 'Returns QuietUninstallString when present and HasCustomEXEFlags is false' {
      $App = New-AppRecord `
        -UninstallString 'C:\Uninst.exe /S' `
        -QuietUninstallString 'C:\Uninst.exe /VERYSILENT'

      $Result = Resolve-UninstallString -Application $App -HasCustomEXEFlags $False
      $Result | Should -Be 'C:\Uninst.exe /VERYSILENT'
    }

    It 'Defaults HasCustomEXEFlags to $False (prefers QuietUninstallString)' {
      $App = New-AppRecord `
        -UninstallString 'C:\Uninst.exe /S' `
        -QuietUninstallString 'C:\Uninst.exe /VERYSILENT'

      $Result = Resolve-UninstallString -Application $App
      $Result | Should -Be 'C:\Uninst.exe /VERYSILENT'
    }
  }

  Context 'HasCustomEXEFlags bypasses QuietUninstallString' {

    It 'Returns UninstallString when HasCustomEXEFlags is $True' {
      $App = New-AppRecord `
        -UninstallString 'C:\Uninst.exe /S' `
        -QuietUninstallString 'C:\Uninst.exe /VERYSILENT'

      $Result = Resolve-UninstallString -Application $App -HasCustomEXEFlags $True
      $Result | Should -Be 'C:\Uninst.exe /S'
    }

    It 'Ignores QuietUninstallString entirely when HasCustomEXEFlags is $True' {
      $App = New-AppRecord `
        -UninstallString '"C:\Program Files\App\unins000.exe"' `
        -QuietUninstallString '"C:\Program Files\App\unins000.exe" /VERYSILENT'

      $Result = Resolve-UninstallString -Application $App -HasCustomEXEFlags $True
      $Result | Should -Be '"C:\Program Files\App\unins000.exe"'
    }
  }

  Context 'Fallback to UninstallString' {

    It 'Returns UninstallString when QuietUninstallString property is missing' {
      $App = New-AppRecord -UninstallString 'MsiExec.exe /X{GUID}'
      $Result = Resolve-UninstallString -Application $App
      $Result | Should -Be 'MsiExec.exe /X{GUID}'
    }

    It 'Returns UninstallString when QuietUninstallString is $Null' {
      $App = New-AppRecord `
        -UninstallString 'C:\Uninst.exe' `
        -QuietUninstallString $Null

      $Result = Resolve-UninstallString -Application $App
      $Result | Should -Be 'C:\Uninst.exe'
    }

    It 'Returns UninstallString when QuietUninstallString is empty string' {
      $App = New-AppRecord `
        -UninstallString 'C:\Uninst.exe /S' `
        -QuietUninstallString ''

      $Result = Resolve-UninstallString -Application $App
      $Result | Should -Be 'C:\Uninst.exe /S'
    }
  }

  Context 'Whitespace-only strings treated as missing' {

    It 'Treats whitespace-only QuietUninstallString as missing and falls back' {
      $App = New-AppRecord `
        -UninstallString 'C:\Uninst.exe /S' `
        -QuietUninstallString '   '

      $Result = Resolve-UninstallString -Application $App
      $Result | Should -Be 'C:\Uninst.exe /S'
    }

    It 'Treats tab-only QuietUninstallString as missing' {
      $App = New-AppRecord `
        -UninstallString 'C:\Uninst.exe' `
        -QuietUninstallString "`t`t"

      $Result = Resolve-UninstallString -Application $App
      $Result | Should -Be 'C:\Uninst.exe'
    }

    It 'Returns $Null when both strings are whitespace-only' {
      $App = New-AppRecord `
        -UninstallString '   ' `
        -QuietUninstallString '   '

      $Result = Resolve-UninstallString -Application $App
      $Result | Should -BeNullOrEmpty
    }

    It 'Returns $Null when UninstallString is whitespace and QuietUninstallString is missing' {
      $App = New-AppRecord -UninstallString '  '
      $Result = Resolve-UninstallString -Application $App
      $Result | Should -BeNullOrEmpty
    }
  }

  Context 'Neither string exists' {

    It 'Returns $Null when both properties are missing from the object' {
      $App = [PSCustomObject]@{}
      $Result = Resolve-UninstallString -Application $App
      $Result | Should -BeNullOrEmpty
    }

    It 'Returns $Null when both properties are explicitly $Null' {
      $App = New-AppRecord `
        -UninstallString $Null `
        -QuietUninstallString $Null

      $Result = Resolve-UninstallString -Application $App
      $Result | Should -BeNullOrEmpty
    }
  }

  Context 'Edge cases' {

    It 'Returns QuietUninstallString even when UninstallString is missing' {
      $App = New-AppRecord -QuietUninstallString 'C:\Uninst.exe /VERYSILENT'
      $Result = Resolve-UninstallString -Application $App
      $Result | Should -Be 'C:\Uninst.exe /VERYSILENT'
    }

    It 'Preserves the exact string value without trimming' {
      $App = New-AppRecord -UninstallString '  C:\Uninst.exe /S  '
      $Result = Resolve-UninstallString -Application $App
      $Result | Should -Be '  C:\Uninst.exe /S  '
    }

    It 'Handles a newline-only QuietUninstallString as whitespace' {
      $App = New-AppRecord `
        -UninstallString 'C:\Uninst.exe' `
        -QuietUninstallString "`r`n"

      $Result = Resolve-UninstallString -Application $App
      $Result | Should -Be 'C:\Uninst.exe'
    }
  }
}

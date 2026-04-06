#Requires -Module Pester

Describe 'Resolve-UninstallCommand' {

  BeforeAll {
    . "$PSScriptRoot\..\..\build\Start-Uninstaller.Functions.ps1"
    $MsiExePath = '{0}\System32\msiexec.exe' -f $Env:SystemRoot
  }

  # ── MSI Installer ────────────────────────────────────────
  Context 'MSI: /I to /X conversion' {

    It 'Converts /I to /X before a GUID' {
      $Result = Resolve-UninstallCommand `
        -UninstallString 'MsiExec.exe /I{ABCD-1234}'

      $Result.FileName  | Should -Be $MsiExePath
      $Result.Arguments | Should -Match '/X\{ABCD-1234\}'
      $Result.Arguments | Should -Not -Match '/I'
    }

    It 'Converts /i to /X (case-insensitive)' {
      $Result = Resolve-UninstallCommand `
        -UninstallString 'msiexec.exe /i{ABCD-1234}'

      $Result.Arguments | Should -Match '/X\{ABCD-1234\}'
    }

    It 'Does NOT convert /I inside property values like IGNOREFAILURES' {
      $Result = Resolve-UninstallCommand `
        -UninstallString 'msiexec.exe /X{ABCD-1234} IGNOREFAILURES=1'

      $Result.Arguments | Should -Match 'IGNOREFAILURES=1'
      $Result.Arguments | Should -Match '/X\{ABCD-1234\}'
    }

    It 'Does not corrupt REBOOTPROMPT or similar /I-containing property names' {
      $Result = Resolve-UninstallCommand `
        -UninstallString 'msiexec.exe /I{GUID-0001} REBOOTPROMPT="" /DISABLEROLLBACK'

      $Result.Arguments | Should -Match '/X\{GUID-0001\}'
      $Result.Arguments | Should -Match 'REBOOTPROMPT'
      $Result.Arguments | Should -Match '/DISABLEROLLBACK'
    }

    It 'Handles /I before a quoted GUID' {
      $Result = Resolve-UninstallCommand `
        -UninstallString 'MsiExec.exe /I"{ABCD-1234}"'

      $Result.Arguments | Should -Match '/X'
    }
  }

  Context 'MSI: /qn insertion and deduplication' {

    It 'Appends /qn when no quiet flag is present' {
      $Result = Resolve-UninstallCommand `
        -UninstallString 'msiexec.exe /X{GUID-0001}'

      $Result.Arguments | Should -Match '/qn'
    }

    It 'Does not duplicate /qn when already present' {
      $Result = Resolve-UninstallCommand `
        -UninstallString 'msiexec.exe /X{GUID-0001} /qn'

      # Count occurrences of /qn — should be exactly 1
      $Matches = [regex]::Matches($Result.Arguments, '(?i)/qn')
      $Matches.Count | Should -Be 1
    }

    It 'Does not append /qn when /qn already present (case-insensitive)' {
      $Result = Resolve-UninstallCommand `
        -UninstallString 'MsiExec.exe /X{GUID} /QN'

      $QnCount = [regex]::Matches($Result.Arguments, '(?i)/qn').Count
      $QnCount | Should -Be 1
    }
  }

  Context 'MSI: /passive detected as quiet flag' {

    It 'Does not append /qn when /passive is present' {
      $Result = Resolve-UninstallCommand `
        -UninstallString 'msiexec.exe /X{GUID-0001} /passive'

      $Result.Arguments | Should -Not -Match '(?i)/qn'
      $Result.Arguments | Should -Match '/passive'
    }

    It 'Does not append /qn when /quiet is present' {
      $Result = Resolve-UninstallCommand `
        -UninstallString 'msiexec.exe /X{GUID-0001} /quiet'

      $Result.Arguments | Should -Not -Match '(?i)/qn'
      $Result.Arguments | Should -Match '/quiet'
    }
  }

  Context 'MSI: /qb and /qr detected as quiet flags' {

    It 'Does not append /qn when /qb is present' {
      $Result = Resolve-UninstallCommand `
        -UninstallString 'msiexec.exe /X{GUID-0001} /qb'

      $Result.Arguments | Should -Not -Match '(?i)/qn(?!b)'
      $Result.Arguments | Should -Match '/qb'
    }

    It 'Does not append /qn when /qr is present' {
      $Result = Resolve-UninstallCommand `
        -UninstallString 'msiexec.exe /X{GUID-0001} /qr'

      $Result.Arguments | Should -Not -Match '(?i)/qn'
      $Result.Arguments | Should -Match '/qr'
    }
  }

  Context 'MSI: FileName normalization' {

    It 'Normalizes FileName to SystemRoot msiexec.exe' {
      $Result = Resolve-UninstallCommand `
        -UninstallString 'MsiExec.exe /X{GUID-0001}'

      $Result.FileName | Should -Be $MsiExePath
    }

    It 'Handles quoted msiexec path' {
      $Result = Resolve-UninstallCommand `
        -UninstallString '"C:\Windows\System32\msiexec.exe" /X{GUID-0001}'

      $Result.FileName | Should -Be $MsiExePath
    }
  }

  # ── EXE Installer ───────────────────────────────────────
  Context 'EXE: quoted path extraction' {

    It 'Extracts quoted executable path' {
      $Result = Resolve-UninstallCommand `
        -UninstallString '"C:\Program Files\App\unins000.exe" /SILENT'

      $Result.FileName  | Should -Be 'C:\Program Files\App\unins000.exe'
      $Result.Arguments | Should -Be '/SILENT'
    }

    It 'Handles quoted path with no arguments' {
      $Result = Resolve-UninstallCommand `
        -UninstallString '"C:\Program Files\App\unins000.exe"'

      $Result.FileName  | Should -Be 'C:\Program Files\App\unins000.exe'
      $Result.Arguments | Should -BeNullOrEmpty
    }
  }

  Context 'EXE: unquoted path with spaces (greedy to last .exe)' {

    It 'Greedily matches to the last .exe in an unquoted path' {
      $Result = Resolve-UninstallCommand `
        -UninstallString 'C:\Program Files\My App\unins000.exe /SILENT'

      $Result.FileName  | Should -Be 'C:\Program Files\My App\unins000.exe'
      $Result.Arguments | Should -Be '/SILENT'
    }

    It 'Handles deeply nested unquoted path' {
      $Result = Resolve-UninstallCommand `
        -UninstallString 'C:\Prog Files\Sub Dir\Another.exe --uninstall'

      $Result.FileName  | Should -Be 'C:\Prog Files\Sub Dir\Another.exe'
      $Result.Arguments | Should -Be '--uninstall'
    }

    It 'Greedily matches past a directory segment containing .exe' {
      $Result = Resolve-UninstallCommand `
        -UninstallString 'C:\Dir.exe Files\app.exe /S'

      $Result.FileName  | Should -Be 'C:\Dir.exe Files\app.exe'
      $Result.Arguments | Should -Be '/S'
    }

    It 'Greedily matches past multiple directory segments containing .exe' {
      $Result = Resolve-UninstallCommand `
        -UninstallString 'C:\Program.exe Files\Sub.exe Dir\uninstall.exe /quiet'

      $Result.FileName  | Should -Be 'C:\Program.exe Files\Sub.exe Dir\uninstall.exe'
      $Result.Arguments | Should -Be '/quiet'
    }
  }

  Context 'EXE: EXEFlags override' {

    It 'Replaces original arguments with custom EXEFlags' {
      $Result = Resolve-UninstallCommand `
        -UninstallString '"C:\App\unins000.exe" /SILENT' `
        -EXEFlags '/VERYSILENT /NORESTART'

      $Result.FileName  | Should -Be 'C:\App\unins000.exe'
      $Result.Arguments | Should -Be '/VERYSILENT /NORESTART'
    }

    It 'Uses EXEFlags even when original has no arguments' {
      $Result = Resolve-UninstallCommand `
        -UninstallString '"C:\App\unins000.exe"' `
        -EXEFlags '--silent'

      $Result.Arguments | Should -Be '--silent'
    }
  }

  Context 'EXE: null EXEFlags preserves original args' {

    It 'Preserves original arguments when EXEFlags is $Null' {
      $Result = Resolve-UninstallCommand `
        -UninstallString '"C:\App\unins000.exe" /SILENT /NORESTART' `
        -EXEFlags $Null

      $Result.Arguments | Should -Be '/SILENT /NORESTART'
    }

    It 'Preserves original arguments when EXEFlags is not specified' {
      $Result = Resolve-UninstallCommand `
        -UninstallString '"C:\App\unins000.exe" --uninstall --quiet'

      $Result.Arguments | Should -Be '--uninstall --quiet'
    }

    It 'Clears original arguments when EXEFlags is empty string' {
      $Result = Resolve-UninstallCommand `
        -UninstallString '"C:\App\unins000.exe" /S' `
        -EXEFlags ''

      $Result.Arguments | Should -Be ''
    }
  }

  # ── Batch File ──────────────────────────────────────────
  Context 'Batch: .cmd and .bat support' {

    It 'Parses a quoted .cmd path' {
      $Result = Resolve-UninstallCommand `
        -UninstallString '"C:\Scripts\cleanup.cmd" /force'

      $Result.FileName  | Should -Be 'C:\Scripts\cleanup.cmd'
      $Result.Arguments | Should -Be '/force'
    }

    It 'Parses a quoted .bat path' {
      $Result = Resolve-UninstallCommand `
        -UninstallString '"C:\Scripts\uninstall.bat" --yes'

      $Result.FileName  | Should -Be 'C:\Scripts\uninstall.bat'
      $Result.Arguments | Should -Be '--yes'
    }

    It 'Parses an unquoted .cmd path' {
      $Result = Resolve-UninstallCommand `
        -UninstallString 'C:\Scripts\cleanup.cmd /force'

      $Result.FileName  | Should -Be 'C:\Scripts\cleanup.cmd'
      $Result.Arguments | Should -Be '/force'
    }

    It 'Parses an unquoted .bat path' {
      $Result = Resolve-UninstallCommand `
        -UninstallString 'C:\Path With Spaces\remove.bat /q'

      $Result.FileName  | Should -Be 'C:\Path With Spaces\remove.bat'
      $Result.Arguments | Should -Be '/q'
    }

    It 'Greedily matches past a directory segment containing .cmd' {
      $Result = Resolve-UninstallCommand `
        -UninstallString 'C:\Dir.cmd Files\cleanup.cmd /force'

      $Result.FileName  | Should -Be 'C:\Dir.cmd Files\cleanup.cmd'
      $Result.Arguments | Should -Be '/force'
    }

    It 'Greedily matches past a directory segment containing .bat' {
      $Result = Resolve-UninstallCommand `
        -UninstallString 'C:\Dir.bat Files\remove.bat /q'

      $Result.FileName  | Should -Be 'C:\Dir.bat Files\remove.bat'
      $Result.Arguments | Should -Be '/q'
    }
  }

  Context 'Batch: EXEFlags never apply' {

    It 'Ignores EXEFlags for .cmd files' {
      $Result = Resolve-UninstallCommand `
        -UninstallString '"C:\Scripts\cleanup.cmd" /original' `
        -EXEFlags '/SHOULD-NOT-APPEAR'

      $Result.Arguments | Should -Be '/original'
    }

    It 'Ignores EXEFlags for .bat files' {
      $Result = Resolve-UninstallCommand `
        -UninstallString '"C:\Scripts\uninstall.bat" /original' `
        -EXEFlags '/SHOULD-NOT-APPEAR'

      $Result.Arguments | Should -Be '/original'
    }
  }

  # ── Unsupported ─────────────────────────────────────────
  Context 'Unsupported command families' {

    It 'Returns $Null for rundll32.exe' {
      $Result = Resolve-UninstallCommand `
        -UninstallString 'rundll32.exe setupapi.dll,InstallHinfSection ...'

      $Result | Should -BeNullOrEmpty
    }

    It 'Returns $Null for cmd.exe /c wrappers' {
      $Result = Resolve-UninstallCommand `
        -UninstallString 'cmd.exe /c "del /q C:\App"'

      $Result | Should -BeNullOrEmpty
    }

    It 'Returns $Null for powershell.exe wrappers' {
      $Result = Resolve-UninstallCommand `
        -UninstallString 'powershell.exe -Command "Remove-Item ..."'

      $Result | Should -BeNullOrEmpty
    }

    It 'Does not misclassify executables whose name only contains msiexec as a substring' {
      $Result = Resolve-UninstallCommand `
        -UninstallString 'C:\Tools\mymsiexec-wrapper.exe /remove'

      $Result.FileName | Should -Be 'C:\Tools\mymsiexec-wrapper.exe'
      $Result.Arguments | Should -Be '/remove'
    }

    It 'Returns $Null for a bare path with no recognized extension' {
      $Result = Resolve-UninstallCommand `
        -UninstallString 'C:\Tools\cleanup.vbs'

      $Result | Should -BeNullOrEmpty
    }
  }

  # ── PSTypeName ──────────────────────────────────────────
  Context 'PSTypeName assignment' {

    It 'MSI result has PSTypeName StartUninstaller.UninstallCommand' {
      $Result = Resolve-UninstallCommand `
        -UninstallString 'msiexec.exe /X{GUID}'

      $Result.PSTypeNames | Should -Contain 'StartUninstaller.UninstallCommand'
    }

    It 'EXE result has PSTypeName StartUninstaller.UninstallCommand' {
      $Result = Resolve-UninstallCommand `
        -UninstallString '"C:\App\unins000.exe" /S'

      $Result.PSTypeNames | Should -Contain 'StartUninstaller.UninstallCommand'
    }

    It 'Batch result has PSTypeName StartUninstaller.UninstallCommand' {
      $Result = Resolve-UninstallCommand `
        -UninstallString '"C:\Scripts\cleanup.cmd"'

      $Result.PSTypeNames | Should -Contain 'StartUninstaller.UninstallCommand'
    }
  }

  # ── Edge cases ──────────────────────────────────────────
  Context 'Edge cases' {

    It 'MSI with both /I and property containing I does not corrupt property' {
      $Result = Resolve-UninstallCommand `
        -UninstallString 'msiexec /I{GUID-0001} MSIFASTINSTALL=7'

      $Result.Arguments | Should -Match '/X\{GUID-0001\}'
      $Result.Arguments | Should -Match 'MSIFASTINSTALL=7'
    }

    It 'MSI with full path to msiexec.exe works' {
      $Result = Resolve-UninstallCommand `
        -UninstallString 'C:\Windows\System32\msiexec.exe /X{GUID}'

      $Result.FileName | Should -Be $MsiExePath
    }

    It 'EXE path is case-preserved' {
      $Result = Resolve-UninstallCommand `
        -UninstallString '"C:\MyApp\Uninstall.EXE" /S'

      $Result.FileName | Should -BeExactly 'C:\MyApp\Uninstall.EXE'
    }
  }
}

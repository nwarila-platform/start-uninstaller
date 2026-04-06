BeforeAll {
  . "$PSScriptRoot\..\..\build\Start-Uninstaller.Functions.ps1"
}

Describe 'Resolve-AppArchitecture' {

  # Helper to build a minimal app record
  BeforeAll {
    Function New-ArchTestApp {
      Param(
        [System.String]$DisplayName = $Null,
        [System.String]$InstallSource = $Null,
        [System.String]$InstallLocation = $Null
      )
      $Props = [ordered]@{}
      If ($Null -ne $DisplayName)    { $Props['DisplayName'] = $DisplayName }
      If ($Null -ne $InstallSource)  { $Props['InstallSource'] = $InstallSource }
      If ($Null -ne $InstallLocation){ $Props['InstallLocation'] = $InstallLocation }
      [PSCustomObject]$Props
    }
  }

  # ── 32-bit OS short-circuit ────────────────────────────────────

  Context '32-bit OS always returns x86' {
    BeforeAll {
      Mock Get-Is64BitOperatingSystem { $False }
    }

    It 'Returns x86 regardless of DisplayName hints' {
      $App = New-ArchTestApp -DisplayName:'MyApp x64 Edition'
      Resolve-AppArchitecture -Application:$App -IsWow:$False |
        Should -Be 'x86'
    }

    It 'Returns x86 regardless of InstallLocation hints' {
      $App = New-ArchTestApp -InstallLocation:'C:\Program Files\MyApp'
      Resolve-AppArchitecture -Application:$App -IsWow:$False |
        Should -Be 'x86'
    }

    It 'Returns x86 even when IsWow is False' {
      $App = New-ArchTestApp
      Resolve-AppArchitecture -Application:$App -IsWow:$False |
        Should -Be 'x86'
    }
  }

  # ── DisplayName scoring ────────────────────────────────────────

  Context 'DisplayName scoring on 64-bit OS' {
    BeforeAll {
      Mock Get-Is64BitOperatingSystem { $True }
    }

    It 'x86 in DisplayName scores toward x86' {
      $App = New-ArchTestApp -DisplayName:'MyApp x86'
      # DN x86 = +100 to Score32, registry non-WOW = +10 to Score64
      # Score32=100, Score64=10 -> x86
      Resolve-AppArchitecture -Application:$App -IsWow:$False |
        Should -Be 'x86'
    }

    It 'x64 in DisplayName scores toward x64' {
      $App = New-ArchTestApp -DisplayName:'MyApp x64'
      # DN x64 = +100 to Score64, registry non-WOW = +10 to Score64
      # Score32=0, Score64=110 -> x64
      Resolve-AppArchitecture -Application:$App -IsWow:$False |
        Should -Be 'x64'
    }

    It '32-bit in DisplayName scores toward x86' {
      $App = New-ArchTestApp -DisplayName:'MyApp 32-bit'
      Resolve-AppArchitecture -Application:$App -IsWow:$False |
        Should -Be 'x86'
    }

    It '64-bit in DisplayName scores toward x64' {
      $App = New-ArchTestApp -DisplayName:'MyApp 64-bit'
      Resolve-AppArchitecture -Application:$App -IsWow:$False |
        Should -Be 'x64'
    }

    It 'Both x86 and x64 in DisplayName: ties go to x86' {
      # Both mentioned: DN contributes +100 to each
      # Registry non-WOW = +10 to Score64
      # Score32=100, Score64=110 -> x64
      $App = New-ArchTestApp -DisplayName:'MyApp x86 and x64'
      Resolve-AppArchitecture -Application:$App -IsWow:$False |
        Should -Be 'x64'
    }

    It 'Both x86 and x64 in DisplayName with IsWow: x86 wins' {
      # DN: +100 each. IsWow = +10 to Score32
      # Score32=110, Score64=100 -> x86
      $App = New-ArchTestApp -DisplayName:'MyApp x86 and x64'
      Resolve-AppArchitecture -Application:$App -IsWow:$True |
        Should -Be 'x86'
    }

    It 'x32 in DisplayName scores toward x86' {
      $App = New-ArchTestApp -DisplayName:'MyApp x32'
      Resolve-AppArchitecture -Application:$App -IsWow:$False |
        Should -Be 'x86'
    }
  }

  # ── InstallLocation scoring ────────────────────────────────────

  Context 'InstallLocation scoring on 64-bit OS' {
    BeforeAll {
      Mock Get-Is64BitOperatingSystem { $True }
    }

    It 'Program Files (x86) in InstallLocation scores toward x86' {
      $App = New-ArchTestApp -InstallLocation:'C:\Program Files (x86)\MyApp'
      # IL PfX86 = +10 to Score32, registry non-WOW = +10 to Score64
      # Score32=10, Score64=10 -> tie -> x86
      Resolve-AppArchitecture -Application:$App -IsWow:$False |
        Should -Be 'x86'
    }

    It 'Program Files (without x86) in InstallLocation scores toward x64' {
      $App = New-ArchTestApp -InstallLocation:'C:\Program Files\MyApp'
      # IL Pf64 = +10 to Score64, registry non-WOW = +10 to Score64
      # Score32=0, Score64=20 -> x64
      Resolve-AppArchitecture -Application:$App -IsWow:$False |
        Should -Be 'x64'
    }

    It 'No Program Files path contributes nothing' {
      $App = New-ArchTestApp -InstallLocation:'D:\Apps\MyApp'
      # Only registry non-WOW = +10 to Score64
      # Score32=0, Score64=10 -> x64
      Resolve-AppArchitecture -Application:$App -IsWow:$False |
        Should -Be 'x64'
    }
  }

  # ── IsWow scoring ─────────────────────────────────────────────

  Context 'IsWow scoring on 64-bit OS' {
    BeforeAll {
      Mock Get-Is64BitOperatingSystem { $True }
    }

    It 'IsWow=$True adds 10 to x86 score' {
      $App = New-ArchTestApp
      # No hints. IsWow = +10 to Score32
      # Score32=10, Score64=0 -> x86
      Resolve-AppArchitecture -Application:$App -IsWow:$True |
        Should -Be 'x86'
    }

    It 'IsWow=$False adds 10 to x64 score' {
      $App = New-ArchTestApp
      # No hints. Non-WOW = +10 to Score64
      # Score32=0, Score64=10 -> x64
      Resolve-AppArchitecture -Application:$App -IsWow:$False |
        Should -Be 'x64'
    }
  }

  # ── Tie goes to x86 ───────────────────────────────────────────

  Context 'Tie handling' {
    BeforeAll {
      Mock Get-Is64BitOperatingSystem { $True }
    }

    It 'Equal scores result in x86' {
      # PfX86 in InstallLocation = +10 Score32, non-WOW = +10 Score64
      # Score32=10, Score64=10 -> tie -> x86
      $App = New-ArchTestApp -InstallLocation:'C:\Program Files (x86)\MyApp'
      Resolve-AppArchitecture -Application:$App -IsWow:$False |
        Should -Be 'x86'
    }

    It 'Zero-zero tie results in x86 (WOW view with 64-bit IL)' {
      # IsWow=True = +10 Score32, Pf64 in IL = +10 Score64
      # Score32=10, Score64=10 -> tie -> x86
      $App = New-ArchTestApp -InstallLocation:'C:\Program Files\MyApp'
      Resolve-AppArchitecture -Application:$App -IsWow:$True |
        Should -Be 'x86'
    }
  }

  # ── InstallSource scoring ─────────────────────────────────────

  Context 'InstallSource scoring on 64-bit OS' {
    BeforeAll {
      Mock Get-Is64BitOperatingSystem { $True }
    }

    It 'x86 in InstallSource scores toward x86' {
      $App = New-ArchTestApp -InstallSource:'\\server\share\x86\setup.exe'
      # IS x86 = +25 Score32, non-WOW = +10 Score64
      # Score32=25, Score64=10 -> x86
      Resolve-AppArchitecture -Application:$App -IsWow:$False |
        Should -Be 'x86'
    }

    It 'x64 in InstallSource scores toward x64' {
      $App = New-ArchTestApp -InstallSource:'\\server\share\x64\setup.exe'
      # IS x64 = +25 Score64, non-WOW = +10 Score64
      # Score32=0, Score64=35 -> x64
      Resolve-AppArchitecture -Application:$App -IsWow:$False |
        Should -Be 'x64'
    }
  }

  # ── Combined scoring scenarios ─────────────────────────────────

  Context 'Combined scoring scenarios' {
    BeforeAll {
      Mock Get-Is64BitOperatingSystem { $True }
    }

    It 'DisplayName x64 overrides WOW and PfX86 location' {
      # DN x64 = +100 Score64, IL PfX86 = +10 Score32, IsWow = +10 Score32
      # Score32=20, Score64=100 -> x64
      $App = New-ArchTestApp `
        -DisplayName:'MyApp x64' `
        -InstallLocation:'C:\Program Files (x86)\MyApp'
      Resolve-AppArchitecture -Application:$App -IsWow:$True |
        Should -Be 'x64'
    }

    It 'DisplayName x86 overrides non-WOW and Pf64 location' {
      # DN x86 = +100 Score32, IL Pf64 = +10 Score64, non-WOW = +10 Score64
      # Score32=100, Score64=20 -> x86
      $App = New-ArchTestApp `
        -DisplayName:'MyApp x86' `
        -InstallLocation:'C:\Program Files\MyApp'
      Resolve-AppArchitecture -Application:$App -IsWow:$False |
        Should -Be 'x86'
    }

    It 'No properties and no WOW returns x64' {
      $App = New-ArchTestApp
      # Only non-WOW = +10 Score64
      Resolve-AppArchitecture -Application:$App -IsWow:$False |
        Should -Be 'x64'
    }

    It 'No properties and WOW returns x86' {
      $App = New-ArchTestApp
      # Only WOW = +10 Score32
      Resolve-AppArchitecture -Application:$App -IsWow:$True |
        Should -Be 'x86'
    }
  }

  # ── Case insensitivity of regex patterns ───────────────────────

  Context 'Case insensitivity' {
    BeforeAll {
      Mock Get-Is64BitOperatingSystem { $True }
    }

    It 'Detects X86 (uppercase) in DisplayName' {
      $App = New-ArchTestApp -DisplayName:'MyApp X86'
      Resolve-AppArchitecture -Application:$App -IsWow:$False |
        Should -Be 'x86'
    }

    It 'Detects X64 (uppercase) in DisplayName' {
      $App = New-ArchTestApp -DisplayName:'MyApp X64'
      Resolve-AppArchitecture -Application:$App -IsWow:$False |
        Should -Be 'x64'
    }

    It 'Detects "program files (x86)" (lowercase) in InstallLocation' {
      $App = New-ArchTestApp -InstallLocation:'c:\program files (x86)\app'
      Resolve-AppArchitecture -Application:$App -IsWow:$False |
        Should -Be 'x86'
    }
  }
}

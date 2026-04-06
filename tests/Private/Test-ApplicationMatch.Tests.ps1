BeforeAll {
  . "$PSScriptRoot\..\..\build\Start-Uninstaller.Functions.ps1"
}

Describe 'Test-ApplicationMatch' {

  # Helper: build a minimal application record
  BeforeAll {
    Function New-TestApp {
      Param(
        [System.String]$DisplayName = 'Node.js',
        [System.String]$Publisher = 'OpenJS Foundation',
        [System.String]$DisplayVersion = '18.20.0',
        [System.Version]$ParsedVersion = $Null,
        [System.String]$AppArch = 'x64',
        [System.String]$InstallScope = 'System'
      )
      $App = [PSCustomObject]@{
        DisplayName    = $DisplayName
        Publisher      = $Publisher
        DisplayVersion = $DisplayVersion
        AppArch        = $AppArch
        InstallScope   = $InstallScope
      }
      If ($Null -eq $ParsedVersion -and $Null -ne $DisplayVersion) {
        [System.Version]::TryParse($DisplayVersion, [ref]$ParsedVersion) | Out-Null
      }
      $App | Add-Member -MemberType:'NoteProperty' `
        -Name:'_ParsedDisplayVersion' -Value:$ParsedVersion -Force
      Return $App
    }
  }

  # ── Empty filter array ─────────────────────────────────────────

  Context 'Empty filter array' {
    It 'Returns $True when filter array is empty' {
      $App = New-TestApp
      $Result = Test-ApplicationMatch `
        -Application:$App `
        -CompiledFilters:@()
      $Result | Should -BeTrue
    }
  }

  # ── Simple match type ──────────────────────────────────────────

  Context 'Simple match (exact, case-insensitive)' {
    BeforeAll {
      $Filters = @(New-CompiledFilter -Filter:@(
        @{ Property = 'DisplayName'; Value = 'Node.js'; MatchType = 'Simple' }
      ))
    }

    It 'Matches exact string' {
      $App = New-TestApp -DisplayName:'Node.js'
      Test-ApplicationMatch -Application:$App -CompiledFilters:$Filters |
        Should -BeTrue
    }

    It 'Matches case-insensitively' {
      $App = New-TestApp -DisplayName:'NODE.JS'
      Test-ApplicationMatch -Application:$App -CompiledFilters:$Filters |
        Should -BeTrue
    }

    It 'Does not match partial string' {
      $App = New-TestApp -DisplayName:'Node.js v18'
      Test-ApplicationMatch -Application:$App -CompiledFilters:$Filters |
        Should -BeFalse
    }

    It 'Does not match different string' {
      $App = New-TestApp -DisplayName:'Python'
      Test-ApplicationMatch -Application:$App -CompiledFilters:$Filters |
        Should -BeFalse
    }
  }

  # ── Wildcard match type ────────────────────────────────────────

  Context 'Wildcard match (case-insensitive)' {
    BeforeAll {
      $Filters = @(New-CompiledFilter -Filter:@(
        @{ Property = 'DisplayName'; Value = 'Node*'; MatchType = 'Wildcard' }
      ))
    }

    It 'Matches wildcard pattern' {
      $App = New-TestApp -DisplayName:'Node.js'
      Test-ApplicationMatch -Application:$App -CompiledFilters:$Filters |
        Should -BeTrue
    }

    It 'Matches case-insensitively' {
      $App = New-TestApp -DisplayName:'node.js 18.20'
      Test-ApplicationMatch -Application:$App -CompiledFilters:$Filters |
        Should -BeTrue
    }

    It 'Does not match non-matching pattern' {
      $App = New-TestApp -DisplayName:'Python 3.12'
      Test-ApplicationMatch -Application:$App -CompiledFilters:$Filters |
        Should -BeFalse
    }
  }

  Context 'Wildcard with question mark' {
    It 'Matches single-character wildcard' {
      $Filters = @(New-CompiledFilter -Filter:@(
        @{ Property = 'AppArch'; Value = 'x?6'; MatchType = 'Wildcard' }
      ))
      $App = New-TestApp -AppArch:'x86'
      Test-ApplicationMatch -Application:$App -CompiledFilters:$Filters |
        Should -BeTrue
    }

    It 'Matches culture-invariant wildcard behavior under tr-TR' {
      $OriginalCulture = [System.Threading.Thread]::CurrentThread.CurrentCulture
      $OriginalUICulture = [System.Threading.Thread]::CurrentThread.CurrentUICulture

      Try {
        $TurkishCulture = [System.Globalization.CultureInfo]::GetCultureInfo('tr-TR')
        [System.Threading.Thread]::CurrentThread.CurrentCulture = $TurkishCulture
        [System.Threading.Thread]::CurrentThread.CurrentUICulture = $TurkishCulture

        $Filters = @(New-CompiledFilter -Filter:@(
          @{ Property = 'DisplayName'; Value = 'i*'; MatchType = 'Wildcard' }
        ))
        $App = New-TestApp -DisplayName:'Istanbul'

        Test-ApplicationMatch -Application:$App -CompiledFilters:$Filters |
          Should -BeTrue
      } Finally {
        [System.Threading.Thread]::CurrentThread.CurrentCulture = $OriginalCulture
        [System.Threading.Thread]::CurrentThread.CurrentUICulture = $OriginalUICulture
      }
    }
  }

  # ── Regex match type ───────────────────────────────────────────

  Context 'Regex match (case-insensitive, culture-invariant)' {
    BeforeAll {
      $Filters = @(New-CompiledFilter -Filter:@(
        @{ Property = 'DisplayName'; Value = '^Node\.\w+'; MatchType = 'Regex' }
      ))
    }

    It 'Matches regex pattern' {
      $App = New-TestApp -DisplayName:'Node.js'
      Test-ApplicationMatch -Application:$App -CompiledFilters:$Filters |
        Should -BeTrue
    }

    It 'Matches case-insensitively' {
      $App = New-TestApp -DisplayName:'node.JS'
      Test-ApplicationMatch -Application:$App -CompiledFilters:$Filters |
        Should -BeTrue
    }

    It 'Does not match non-matching regex' {
      $App = New-TestApp -DisplayName:'MyNode.js'
      Test-ApplicationMatch -Application:$App -CompiledFilters:$Filters |
        Should -BeFalse
    }
  }

  # ── Version operators ──────────────────────────────────────────

  Context 'Version operator EQ' {
    BeforeAll {
      $Filters = @(New-CompiledFilter -Filter:@(
        @{ Property = 'DisplayVersion'; Value = '18.20.0'; MatchType = 'EQ' }
      ))
    }

    It 'Returns $True when version equals' {
      $App = New-TestApp -DisplayVersion:'18.20.0'
      Test-ApplicationMatch -Application:$App -CompiledFilters:$Filters |
        Should -BeTrue
    }

    It 'Returns $False when version does not equal' {
      $App = New-TestApp -DisplayVersion:'18.20.1'
      Test-ApplicationMatch -Application:$App -CompiledFilters:$Filters |
        Should -BeFalse
    }
  }

  Context 'Version operator GT' {
    BeforeAll {
      $Filters = @(New-CompiledFilter -Filter:@(
        @{ Property = 'DisplayVersion'; Value = '18.0.0'; MatchType = 'GT' }
      ))
    }

    It 'Returns $True when app version is greater' {
      $App = New-TestApp -DisplayVersion:'18.20.0'
      Test-ApplicationMatch -Application:$App -CompiledFilters:$Filters |
        Should -BeTrue
    }

    It 'Returns $False when app version is equal' {
      $App = New-TestApp -DisplayVersion:'18.0.0'
      Test-ApplicationMatch -Application:$App -CompiledFilters:$Filters |
        Should -BeFalse
    }

    It 'Returns $False when app version is less' {
      $App = New-TestApp -DisplayVersion:'17.9.0'
      Test-ApplicationMatch -Application:$App -CompiledFilters:$Filters |
        Should -BeFalse
    }
  }

  Context 'Version operator GTE' {
    BeforeAll {
      $Filters = @(New-CompiledFilter -Filter:@(
        @{ Property = 'DisplayVersion'; Value = '18.0.0'; MatchType = 'GTE' }
      ))
    }

    It 'Returns $True when app version is greater' {
      $App = New-TestApp -DisplayVersion:'19.0.0'
      Test-ApplicationMatch -Application:$App -CompiledFilters:$Filters |
        Should -BeTrue
    }

    It 'Returns $True when app version is equal' {
      $App = New-TestApp -DisplayVersion:'18.0.0'
      Test-ApplicationMatch -Application:$App -CompiledFilters:$Filters |
        Should -BeTrue
    }

    It 'Returns $False when app version is less' {
      $App = New-TestApp -DisplayVersion:'17.0.0'
      Test-ApplicationMatch -Application:$App -CompiledFilters:$Filters |
        Should -BeFalse
    }
  }

  Context 'Version operator LT' {
    BeforeAll {
      $Filters = @(New-CompiledFilter -Filter:@(
        @{ Property = 'DisplayVersion'; Value = '19.0.0'; MatchType = 'LT' }
      ))
    }

    It 'Returns $True when app version is less' {
      $App = New-TestApp -DisplayVersion:'18.20.0'
      Test-ApplicationMatch -Application:$App -CompiledFilters:$Filters |
        Should -BeTrue
    }

    It 'Returns $False when app version is equal' {
      $App = New-TestApp -DisplayVersion:'19.0.0'
      Test-ApplicationMatch -Application:$App -CompiledFilters:$Filters |
        Should -BeFalse
    }

    It 'Returns $False when app version is greater' {
      $App = New-TestApp -DisplayVersion:'20.0.0'
      Test-ApplicationMatch -Application:$App -CompiledFilters:$Filters |
        Should -BeFalse
    }
  }

  Context 'Version operator LTE' {
    BeforeAll {
      $Filters = @(New-CompiledFilter -Filter:@(
        @{ Property = 'DisplayVersion'; Value = '19.0.0'; MatchType = 'LTE' }
      ))
    }

    It 'Returns $True when app version is less' {
      $App = New-TestApp -DisplayVersion:'18.0.0'
      Test-ApplicationMatch -Application:$App -CompiledFilters:$Filters |
        Should -BeTrue
    }

    It 'Returns $True when app version is equal' {
      $App = New-TestApp -DisplayVersion:'19.0.0'
      Test-ApplicationMatch -Application:$App -CompiledFilters:$Filters |
        Should -BeTrue
    }

    It 'Returns $False when app version is greater' {
      $App = New-TestApp -DisplayVersion:'20.0.0'
      Test-ApplicationMatch -Application:$App -CompiledFilters:$Filters |
        Should -BeFalse
    }
  }

  # ── Missing property ───────────────────────────────────────────

  Context 'Missing property on application record' {
    It 'Returns $False without throwing for Simple' {
      $Filters = @(New-CompiledFilter -Filter:@(
        @{ Property = 'NoSuchProperty'; Value = 'Foo'; MatchType = 'Simple' }
      ))
      $App = New-TestApp
      Test-ApplicationMatch -Application:$App -CompiledFilters:$Filters |
        Should -BeFalse
    }

    It 'Returns $False without throwing for Wildcard' {
      $Filters = @(New-CompiledFilter -Filter:@(
        @{ Property = 'NoSuchProperty'; Value = 'Foo*'; MatchType = 'Wildcard' }
      ))
      $App = New-TestApp
      Test-ApplicationMatch -Application:$App -CompiledFilters:$Filters |
        Should -BeFalse
    }

    It 'Returns $False without throwing for Regex' {
      $Filters = @(New-CompiledFilter -Filter:@(
        @{ Property = 'NoSuchProperty'; Value = 'Foo'; MatchType = 'Regex' }
      ))
      $App = New-TestApp
      Test-ApplicationMatch -Application:$App -CompiledFilters:$Filters |
        Should -BeFalse
    }

    It 'Returns $False without throwing for version operator' {
      $Filters = @(New-CompiledFilter -Filter:@(
        @{ Property = 'DisplayVersion'; Value = '1.0'; MatchType = 'GTE' }
      ))
      # App with no _ParsedDisplayVersion
      $App = [PSCustomObject]@{ DisplayName = 'Test' }
      $App | Add-Member -MemberType:'NoteProperty' `
        -Name:'_ParsedDisplayVersion' -Value:$Null -Force
      Test-ApplicationMatch -Application:$App -CompiledFilters:$Filters |
        Should -BeFalse
    }
  }

  # ── Unparseable DisplayVersion with version operator ───────────

  Context 'Unparseable DisplayVersion with version operator' {
    It 'Returns $False (non-match) when DisplayVersion is not a valid version' {
      $Filters = @(New-CompiledFilter -Filter:@(
        @{ Property = 'DisplayVersion'; Value = '1.0'; MatchType = 'EQ' }
      ))
      $App = [PSCustomObject]@{
        DisplayName    = 'Test App'
        DisplayVersion = 'not-a-version'
      }
      $App | Add-Member -MemberType:'NoteProperty' `
        -Name:'_ParsedDisplayVersion' -Value:$Null -Force
      Test-ApplicationMatch -Application:$App -CompiledFilters:$Filters |
        Should -BeFalse
    }
  }

  # ── AND logic ──────────────────────────────────────────────────

  Context 'AND logic: all filters must match' {
    It 'Returns $True when all filters match' {
      $Filters = @(New-CompiledFilter -Filter:@(
        @{ Property = 'DisplayName'; Value = 'Node.js'; MatchType = 'Simple' },
        @{ Property = 'Publisher'; Value = 'OpenJS Foundation'; MatchType = 'Simple' }
      ))
      $App = New-TestApp -DisplayName:'Node.js' -Publisher:'OpenJS Foundation'
      Test-ApplicationMatch -Application:$App -CompiledFilters:$Filters |
        Should -BeTrue
    }

    It 'Returns $False when one filter does not match' {
      $Filters = @(New-CompiledFilter -Filter:@(
        @{ Property = 'DisplayName'; Value = 'Node.js'; MatchType = 'Simple' },
        @{ Property = 'Publisher'; Value = 'Microsoft'; MatchType = 'Simple' }
      ))
      $App = New-TestApp -DisplayName:'Node.js' -Publisher:'OpenJS Foundation'
      Test-ApplicationMatch -Application:$App -CompiledFilters:$Filters |
        Should -BeFalse
    }

    It 'Returns $False when first filter does not match' {
      $Filters = @(New-CompiledFilter -Filter:@(
        @{ Property = 'DisplayName'; Value = 'Python'; MatchType = 'Simple' },
        @{ Property = 'Publisher'; Value = 'OpenJS Foundation'; MatchType = 'Simple' }
      ))
      $App = New-TestApp -DisplayName:'Node.js' -Publisher:'OpenJS Foundation'
      Test-ApplicationMatch -Application:$App -CompiledFilters:$Filters |
        Should -BeFalse
    }
  }

  # ── Short-circuit behavior ─────────────────────────────────────

  Context 'Short-circuit: fails on first non-match' {
    It 'Returns $False immediately when first filter fails' {
      # Create a filter that cannot match, followed by one that could.
      # The function should return $False without evaluating the second.
      # We verify by checking the result is $False (cannot directly
      # observe short-circuit, but we confirm correctness).
      $Filters = @(New-CompiledFilter -Filter:@(
        @{ Property = 'DisplayName'; Value = 'ZZZ_NO_MATCH'; MatchType = 'Simple' },
        @{ Property = 'Publisher'; Value = 'OpenJS Foundation'; MatchType = 'Simple' }
      ))
      $App = New-TestApp -DisplayName:'Node.js' -Publisher:'OpenJS Foundation'
      Test-ApplicationMatch -Application:$App -CompiledFilters:$Filters |
        Should -BeFalse
    }
  }

  # ── Version range (GTE + LT combined) ──────────────────────────

  Context 'Version range filter (GTE + LT)' {
    BeforeAll {
      $Filters = @(New-CompiledFilter -Filter:@(
        @{ Property = 'DisplayVersion'; Value = '18.0.0'; MatchType = 'GTE' },
        @{ Property = 'DisplayVersion'; Value = '19.0.0'; MatchType = 'LT' }
      ))
    }

    It 'Matches version within range' {
      $App = New-TestApp -DisplayVersion:'18.20.0'
      Test-ApplicationMatch -Application:$App -CompiledFilters:$Filters |
        Should -BeTrue
    }

    It 'Matches lower bound exactly' {
      $App = New-TestApp -DisplayVersion:'18.0.0'
      Test-ApplicationMatch -Application:$App -CompiledFilters:$Filters |
        Should -BeTrue
    }

    It 'Does not match upper bound' {
      $App = New-TestApp -DisplayVersion:'19.0.0'
      Test-ApplicationMatch -Application:$App -CompiledFilters:$Filters |
        Should -BeFalse
    }

    It 'Does not match below range' {
      $App = New-TestApp -DisplayVersion:'17.9.9'
      Test-ApplicationMatch -Application:$App -CompiledFilters:$Filters |
        Should -BeFalse
    }
  }

  # ── Synthetic property matching ────────────────────────────────

  Context 'Matching against synthetic properties' {
    It 'Matches AppArch with Simple' {
      $Filters = @(New-CompiledFilter -Filter:@(
        @{ Property = 'AppArch'; Value = 'x64'; MatchType = 'Simple' }
      ))
      $App = New-TestApp -AppArch:'x64'
      Test-ApplicationMatch -Application:$App -CompiledFilters:$Filters |
        Should -BeTrue
    }

    It 'Matches InstallScope with Simple' {
      $Filters = @(New-CompiledFilter -Filter:@(
        @{ Property = 'InstallScope'; Value = 'System'; MatchType = 'Simple' }
      ))
      $App = New-TestApp -InstallScope:'System'
      Test-ApplicationMatch -Application:$App -CompiledFilters:$Filters |
        Should -BeTrue
    }
  }

  # ── Case-insensitive property lookup ───────────────────────────

  Context 'Case-insensitive property name lookup' {
    It 'Matches when filter property has different casing' {
      $Filters = @(New-CompiledFilter -Filter:@(
        @{ Property = 'displayname'; Value = 'Node.js'; MatchType = 'Simple' }
      ))
      $App = New-TestApp -DisplayName:'Node.js'
      Test-ApplicationMatch -Application:$App -CompiledFilters:$Filters |
        Should -BeTrue
    }
  }
}

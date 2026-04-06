BeforeAll {
  . "$PSScriptRoot\..\..\build\Start-Uninstaller.Functions.ps1"
}

Describe 'New-CompiledFilter' {

  # ── Validation: Missing / Invalid Inputs ───────────────────────

  Context 'Property validation' {
    It 'Throws when Property key is missing' {
      { New-CompiledFilter -Filter:@(
          @{ Value = 'Foo'; MatchType = 'Simple' }
      ) } | Should -Throw '*Property*'
    }

    It 'Throws when Property is empty string' {
      { New-CompiledFilter -Filter:@(
          @{ Property = ''; Value = 'Foo'; MatchType = 'Simple' }
      ) } | Should -Throw '*Property*'
    }

    It 'Throws when Property is whitespace-only' {
      { New-CompiledFilter -Filter:@(
          @{ Property = '   '; Value = 'Foo'; MatchType = 'Simple' }
      ) } | Should -Throw '*Property*'
    }

    It 'Throws when Property is $null' {
      { New-CompiledFilter -Filter:@(
          @{ Property = $Null; Value = 'Foo'; MatchType = 'Simple' }
      ) } | Should -Throw '*Property*'
    }

    It 'Throws when Property contains NUL character' {
      { New-CompiledFilter -Filter:@(
          @{ Property = "Display`0Name"; Value = 'Foo'; MatchType = 'Simple' }
      ) } | Should -Throw '*NUL*'
    }

    It 'Throws when Property targets an internal-only field' {
      { New-CompiledFilter -Filter:@(
          @{ Property = '_RegistryHive'; Value = 'HKLM'; MatchType = 'Simple' }
      ) } | Should -Throw '*never valid in filters*'
    }
  }

  Context 'Value validation' {
    It 'Throws when Value key is missing' {
      { New-CompiledFilter -Filter:@(
          @{ Property = 'DisplayName'; MatchType = 'Simple' }
      ) } | Should -Throw '*Value*'
    }

    It 'Throws when Value is $null for Simple' {
      { New-CompiledFilter -Filter:@(
          @{ Property = 'DisplayName'; Value = $Null; MatchType = 'Simple' }
      ) } | Should -Throw '*null or empty*'
    }

    It 'Throws when Value is empty string for Wildcard' {
      { New-CompiledFilter -Filter:@(
          @{ Property = 'DisplayName'; Value = ''; MatchType = 'Wildcard' }
      ) } | Should -Throw '*null or empty*'
    }

    It 'Throws when Value is empty string for Regex' {
      { New-CompiledFilter -Filter:@(
          @{ Property = 'DisplayName'; Value = ''; MatchType = 'Regex' }
      ) } | Should -Throw '*null or empty*'
    }
  }

  Context 'MatchType validation' {
    It 'Throws when MatchType key is missing' {
      { New-CompiledFilter -Filter:@(
          @{ Property = 'DisplayName'; Value = 'Foo' }
      ) } | Should -Throw '*MatchType*'
    }

    It 'Throws when MatchType is empty string' {
      { New-CompiledFilter -Filter:@(
          @{ Property = 'DisplayName'; Value = 'Foo'; MatchType = '' }
      ) } | Should -Throw '*MatchType*'
    }

    It 'Throws when MatchType is invalid' {
      { New-CompiledFilter -Filter:@(
          @{ Property = 'DisplayName'; Value = 'Foo'; MatchType = 'Glob' }
      ) } | Should -Throw '*MatchType must be one of*'
    }

    It 'Throws when MatchType is $null' {
      { New-CompiledFilter -Filter:@(
          @{ Property = 'DisplayName'; Value = 'Foo'; MatchType = $Null }
      ) } | Should -Throw '*MatchType*'
    }
  }

  Context 'Version operator constraints' {
    It 'Throws when version operator is used on non-DisplayVersion property' {
      { New-CompiledFilter -Filter:@(
          @{ Property = 'Publisher'; Value = '1.0.0'; MatchType = 'GT' }
      ) } | Should -Throw '*DisplayVersion*'
    }

    It 'Throws for EQ on Publisher' {
      { New-CompiledFilter -Filter:@(
          @{ Property = 'Publisher'; Value = '1.0'; MatchType = 'EQ' }
      ) } | Should -Throw '*DisplayVersion*'
    }

    It 'Throws for GTE on DisplayName' {
      { New-CompiledFilter -Filter:@(
          @{ Property = 'DisplayName'; Value = '1.0'; MatchType = 'GTE' }
      ) } | Should -Throw '*DisplayVersion*'
    }

    It 'Throws for LT on InstallScope' {
      { New-CompiledFilter -Filter:@(
          @{ Property = 'InstallScope'; Value = '1.0'; MatchType = 'LT' }
      ) } | Should -Throw '*DisplayVersion*'
    }

    It 'Throws for LTE on AppArch' {
      { New-CompiledFilter -Filter:@(
          @{ Property = 'AppArch'; Value = '1.0'; MatchType = 'LTE' }
      ) } | Should -Throw '*DisplayVersion*'
    }

    It 'Throws when Value is not a valid version for version operator' {
      { New-CompiledFilter -Filter:@(
          @{ Property = 'DisplayVersion'; Value = 'notaversion'; MatchType = 'GT' }
      ) } | Should -Throw '*valid version*'
    }

    It 'Throws when Value is empty for version operator' {
      { New-CompiledFilter -Filter:@(
          @{ Property = 'DisplayVersion'; Value = ''; MatchType = 'EQ' }
      ) } | Should -Throw '*valid version*'
    }
  }

  Context 'Regex validation' {
    It 'Throws when regex pattern is invalid' {
      { New-CompiledFilter -Filter:@(
          @{ Property = 'DisplayName'; Value = '(unclosed'; MatchType = 'Regex' }
      ) } | Should -Throw '*Invalid regex*'
    }

    It 'Throws for unbalanced brackets in regex' {
      { New-CompiledFilter -Filter:@(
          @{ Property = 'DisplayName'; Value = '[invalid'; MatchType = 'Regex' }
      ) } | Should -Throw '*Invalid regex*'
    }
  }

  # ── Compiled Artifact Tests ────────────────────────────────────

  Context 'Simple match type' {
    BeforeAll {
      $Result = New-CompiledFilter -Filter:@(
        @{ Property = 'DisplayName'; Value = 'Node.js'; MatchType = 'Simple' }
      )
    }

    It 'Creates no compiled wildcard' {
      $Result.CompiledWildcard | Should -BeNullOrEmpty
    }

    It 'Creates no compiled regex' {
      $Result.CompiledRegex | Should -BeNullOrEmpty
    }

    It 'Creates no compiled version' {
      $Result.CompiledVersion | Should -BeNullOrEmpty
    }

    It 'Sets Property correctly' {
      $Result.Property | Should -Be 'DisplayName'
    }

    It 'Sets Value correctly' {
      $Result.Value | Should -Be 'Node.js'
    }

    It 'Sets MatchType to Simple' {
      $Result.MatchType | Should -Be 'Simple'
    }
  }

  Context 'Wildcard match type' {
    BeforeAll {
      $Result = New-CompiledFilter -Filter:@(
        @{ Property = 'DisplayName'; Value = 'Node*'; MatchType = 'Wildcard' }
      )
    }

    It 'Creates a WildcardPattern' {
      $Result.CompiledWildcard | Should -BeOfType ([System.Management.Automation.WildcardPattern])
    }

    It 'Creates no compiled regex' {
      $Result.CompiledRegex | Should -BeNullOrEmpty
    }

    It 'Creates no compiled version' {
      $Result.CompiledVersion | Should -BeNullOrEmpty
    }

    It 'WildcardPattern matches expected input' {
      $Result.CompiledWildcard.IsMatch('Node.js') | Should -BeTrue
    }

    It 'WildcardPattern is case-insensitive' {
      $Result.CompiledWildcard.IsMatch('node.js') | Should -BeTrue
    }

    It 'WildcardPattern is culture-invariant' {
      $Result.CompiledWildcard.Options.HasFlag(
        [System.Management.Automation.WildcardOptions]::CultureInvariant
      ) | Should -BeTrue
    }
  }

  Context 'Regex match type' {
    BeforeAll {
      $Result = New-CompiledFilter -Filter:@(
        @{ Property = 'DisplayName'; Value = '^Node\.js$'; MatchType = 'Regex' }
      )
    }

    It 'Creates a compiled Regex' {
      $Result.CompiledRegex | Should -BeOfType ([System.Text.RegularExpressions.Regex])
    }

    It 'Creates no compiled wildcard' {
      $Result.CompiledWildcard | Should -BeNullOrEmpty
    }

    It 'Creates no compiled version' {
      $Result.CompiledVersion | Should -BeNullOrEmpty
    }

    It 'Regex has Compiled option' {
      $Result.CompiledRegex.Options.HasFlag(
        [System.Text.RegularExpressions.RegexOptions]::Compiled
      ) | Should -BeTrue
    }

    It 'Regex has IgnoreCase option' {
      $Result.CompiledRegex.Options.HasFlag(
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
      ) | Should -BeTrue
    }

    It 'Regex has CultureInvariant option' {
      $Result.CompiledRegex.Options.HasFlag(
        [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
      ) | Should -BeTrue
    }
  }

  Context 'Version operators' {
    It 'EQ stores parsed [version]' {
      $Result = New-CompiledFilter -Filter:@(
        @{ Property = 'DisplayVersion'; Value = '1.2.3'; MatchType = 'EQ' }
      )
      $Result.CompiledVersion | Should -BeOfType ([System.Version])
      $Result.CompiledVersion | Should -Be ([System.Version]'1.2.3')
    }

    It 'GT stores parsed [version]' {
      $Result = New-CompiledFilter -Filter:@(
        @{ Property = 'DisplayVersion'; Value = '2.0.0.1'; MatchType = 'GT' }
      )
      $Result.CompiledVersion | Should -Be ([System.Version]'2.0.0.1')
    }

    It 'GTE stores parsed [version]' {
      $Result = New-CompiledFilter -Filter:@(
        @{ Property = 'DisplayVersion'; Value = '10.0'; MatchType = 'GTE' }
      )
      $Result.CompiledVersion | Should -Be ([System.Version]'10.0')
    }

    It 'LT stores parsed [version]' {
      $Result = New-CompiledFilter -Filter:@(
        @{ Property = 'DisplayVersion'; Value = '3.1.4'; MatchType = 'LT' }
      )
      $Result.CompiledVersion | Should -Be ([System.Version]'3.1.4')
    }

    It 'LTE stores parsed [version]' {
      $Result = New-CompiledFilter -Filter:@(
        @{ Property = 'DisplayVersion'; Value = '0.9'; MatchType = 'LTE' }
      )
      $Result.CompiledVersion | Should -Be ([System.Version]'0.9')
    }

    It 'Version operators create no wildcard or regex' {
      $Result = New-CompiledFilter -Filter:@(
        @{ Property = 'DisplayVersion'; Value = '1.0'; MatchType = 'EQ' }
      )
      $Result.CompiledWildcard | Should -BeNullOrEmpty
      $Result.CompiledRegex | Should -BeNullOrEmpty
    }
  }

  # ── PSTypeName ─────────────────────────────────────────────────

  Context 'Output type' {
    It 'Has PSTypeName StartUninstaller.CompiledFilter' {
      $Result = New-CompiledFilter -Filter:@(
        @{ Property = 'DisplayName'; Value = 'Foo'; MatchType = 'Simple' }
      )
      $Result.PSTypeNames | Should -Contain 'StartUninstaller.CompiledFilter'
    }
  }

  # ── MatchType case normalization ───────────────────────────────

  Context 'MatchType case normalization' {
    It 'Normalizes "simple" to "Simple"' {
      $Result = New-CompiledFilter -Filter:@(
        @{ Property = 'DisplayName'; Value = 'Foo'; MatchType = 'simple' }
      )
      $Result.MatchType | Should -BeExactly 'Simple'
    }

    It 'Normalizes "WILDCARD" to "Wildcard"' {
      $Result = New-CompiledFilter -Filter:@(
        @{ Property = 'DisplayName'; Value = 'Foo*'; MatchType = 'WILDCARD' }
      )
      $Result.MatchType | Should -BeExactly 'Wildcard'
    }

    It 'Normalizes "regex" to "Regex"' {
      $Result = New-CompiledFilter -Filter:@(
        @{ Property = 'DisplayName'; Value = 'Foo'; MatchType = 'regex' }
      )
      $Result.MatchType | Should -BeExactly 'Regex'
    }

    It 'Normalizes "eq" to "EQ"' {
      $Result = New-CompiledFilter -Filter:@(
        @{ Property = 'DisplayVersion'; Value = '1.0'; MatchType = 'eq' }
      )
      $Result.MatchType | Should -BeExactly 'EQ'
    }

    It 'Normalizes "gte" to "GTE"' {
      $Result = New-CompiledFilter -Filter:@(
        @{ Property = 'DisplayVersion'; Value = '1.0'; MatchType = 'gte' }
      )
      $Result.MatchType | Should -BeExactly 'GTE'
    }
  }

  # ── Multiple filters ──────────────────────────────────────────

  Context 'Multiple filters in one call' {
    BeforeAll {
      $Results = @(New-CompiledFilter -Filter:@(
        @{ Property = 'DisplayName'; Value = 'Node*'; MatchType = 'Wildcard' },
        @{ Property = 'DisplayVersion'; Value = '18.0'; MatchType = 'GTE' },
        @{ Property = 'Publisher'; Value = 'OpenJS'; MatchType = 'Simple' }
      ))
    }

    It 'Returns one object per input hashtable' {
      $Results.Count | Should -Be 3
    }

    It 'First filter is Wildcard' {
      $Results[0].MatchType | Should -Be 'Wildcard'
      $Results[0].CompiledWildcard | Should -Not -BeNullOrEmpty
    }

    It 'Second filter is GTE with version' {
      $Results[1].MatchType | Should -Be 'GTE'
      $Results[1].CompiledVersion | Should -Be ([System.Version]'18.0')
    }

    It 'Third filter is Simple' {
      $Results[2].MatchType | Should -Be 'Simple'
    }
  }

  # ── Edge cases ────────────────────────────────────────────────

  Context 'Edge cases' {
    It 'Allows synthetic metadata property names in filters' {
      $Result = New-CompiledFilter -Filter:@(
        @{ Property = 'AppArch'; Value = 'x64'; MatchType = 'Simple' }
      )
      $Result.Property | Should -Be 'AppArch'
    }

    It 'Allows filtering on InstallScope' {
      $Result = New-CompiledFilter -Filter:@(
        @{ Property = 'InstallScope'; Value = 'User'; MatchType = 'Simple' }
      )
      $Result.Property | Should -Be 'InstallScope'
    }

    It 'DisplayVersion supports Simple match type' {
      $Result = New-CompiledFilter -Filter:@(
        @{ Property = 'DisplayVersion'; Value = '1.0.0-beta'; MatchType = 'Simple' }
      )
      $Result.MatchType | Should -Be 'Simple'
      $Result.CompiledVersion | Should -BeNullOrEmpty
    }

    It 'DisplayVersion supports Wildcard match type' {
      $Result = New-CompiledFilter -Filter:@(
        @{ Property = 'DisplayVersion'; Value = '1.*'; MatchType = 'Wildcard' }
      )
      $Result.MatchType | Should -Be 'Wildcard'
      $Result.CompiledWildcard | Should -Not -BeNullOrEmpty
    }

    It 'DisplayVersion supports Regex match type' {
      $Result = New-CompiledFilter -Filter:@(
        @{ Property = 'DisplayVersion'; Value = '^\d+\.\d+'; MatchType = 'Regex' }
      )
      $Result.MatchType | Should -Be 'Regex'
      $Result.CompiledRegex | Should -Not -BeNullOrEmpty
    }

    It 'Four-part version parses correctly' {
      $Result = New-CompiledFilter -Filter:@(
        @{ Property = 'DisplayVersion'; Value = '1.2.3.4'; MatchType = 'EQ' }
      )
      $Result.CompiledVersion | Should -Be ([System.Version]'1.2.3.4')
    }
  }
}

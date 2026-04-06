#Requires -Version 5.1

<#
  .SYNOPSIS
    Builds, analyzes, and tests the Start-Uninstaller project.

  .PARAMETER Task
    One or more tasks: Build, Test, Analyze, Clean, All.
    Default: Build.

  .EXAMPLE
    .\build.ps1
    .\build.ps1 -Task All
#>
Param (
  [ValidateSet('Build', 'Test', 'Analyze', 'Clean', 'All')]
  [System.String[]]
  $Task = 'Build'
)

$ErrorActionPreference = 'Stop'

$ProjectRoot = $PSScriptRoot
$SrcDir      = Join-Path -Path:$ProjectRoot -ChildPath:'src'
$BuildDir    = Join-Path -Path:$ProjectRoot -ChildPath:'build'
$OutputFile  = Join-Path -Path:$BuildDir -ChildPath:'Start-Uninstaller.ps1'
$TestsDir    = Join-Path -Path:$ProjectRoot -ChildPath:'tests'

#region ------ [ Task Functions ] ---------------------------------------- #

Function Get-LatestAvailableModule {
  Param (
    [Parameter(Mandatory = $True)]
    [System.String]
    $Name
  )

  Get-Module -ListAvailable $Name |
    Sort-Object -Property:'Version' -Descending |
    Select-Object -First:1
}

Function Assert-SyntaxValid {
  Param (
    [Parameter(Mandatory = $True)]
    [System.String[]]
    $Path
  )

  $Messages = [System.Collections.Generic.List[System.String]]::new()

  $Path | & { Process {
    $ScriptPath = [System.String]$PSItem
    If (-not (Test-Path -Path:$ScriptPath)) { Return }

    $Tokens = $Null
    $Errors = $Null
    $Null = [System.Management.Automation.Language.Parser]::ParseFile(
      $ScriptPath,
      [ref]$Tokens,
      [ref]$Errors
    )

    If ($Errors.Count -gt 0) {
      $Errors | & { Process {
        $Messages.Add(
          '{0}: line {1}: {2}' -f
            $ScriptPath,
            $PSItem.Extent.StartLineNumber,
            $PSItem.Message
        )
      }}
    }
  }}

  If ($Messages.Count -gt 0) {
    Throw ('Syntax errors detected:{0}{1}' -f
      [System.Environment]::NewLine,
      ($Messages -join [System.Environment]::NewLine))
  }
}

Function Invoke-SmokeTests {
  $SmokeDir = Join-Path -Path:$TestsDir -ChildPath:'Smoke'
  $SmokeFiles = Get-ChildItem -Path:(
    Join-Path -Path:$SmokeDir -ChildPath:'*.ps1'
  ) -ErrorAction:'SilentlyContinue' | Sort-Object -Property:'Name'

  If (-not $SmokeFiles) {
    Write-Warning -Message:'No smoke tests found.'
    Return
  }

  $SmokeFiles | & { Process {
    Write-Host -Object:('Smoke: {0}' -f $PSItem.Name) `
      -ForegroundColor:'DarkCyan'
    & $PSItem.FullName
  }}

  Write-Host -Object:'Smoke tests passed.' -ForegroundColor:'Green'
}

Function Invoke-Build {
  If (-not (Test-Path -Path:$BuildDir)) {
    $Null = New-Item -Path:$BuildDir -ItemType:'Directory'
  }

  # ── Parse entry point into param block + invocation ───────
  $EntryFile = Join-Path -Path:$SrcDir -ChildPath:'EntryPoint.ps1'
  $EntryLines = @()
  $ParamEnd = -1
  $InvocationLines = [System.Collections.Generic.List[System.String]]::new()

  If (Test-Path -Path:$EntryFile) {
    $EntryContent = (Get-Content -Path:$EntryFile -Raw).Trim()
    $EntryLines = $EntryContent -split "`n"

    $InParamBlock = $False
    $ParenDepth = 0
    For ($I = 0; $I -lt $EntryLines.Count; $I++) {
      $Line = [System.String]$EntryLines[$I]
      $TrimmedLine = $Line.Trim()

      If ($InParamBlock -eq $False -and
          $TrimmedLine -match '^Param\s*\(') {
        $InParamBlock = $True
      }

      If ($InParamBlock -eq $True) {
        $OpenParenCount = ([regex]::Matches($Line, '\(')).Count
        $CloseParenCount = ([regex]::Matches($Line, '\)')).Count
        $ParenDepth += ($OpenParenCount - $CloseParenCount)

        If ($ParenDepth -eq 0) {
          $ParamEnd = $I
          Break
        }
      }
    }

    If ($ParamEnd -ge 0) {
      For ($I = $ParamEnd + 1; $I -lt $EntryLines.Count; $I++) {
        $InvocationLines.Add($EntryLines[$I])
      }
    }
  }

  # ── Build functions-only (no param block, no invocation) ──
  $SB = [System.Text.StringBuilder]::new(65536)
  $Null = $SB.AppendLine('#Requires -Version 5.1')
  $Null = $SB.AppendLine('')

  # ── Tier 1: Private functions (alpha-sorted) ────────────
  $PrivateDir = Join-Path -Path:$SrcDir -ChildPath:'Private'
  $PrivateFiles = Get-ChildItem -Path:(
    Join-Path -Path:$PrivateDir -ChildPath:'*.ps1'
  ) -ErrorAction:'SilentlyContinue' | Sort-Object -Property:'Name'

  If ($PrivateFiles) {
    $Null = $SB.AppendLine('#region Private Functions')
    $Null = $SB.AppendLine('')

    $PrivateFiles | & { Process {
      $Content = (Get-Content -Path:$PSItem.FullName -Raw).Trim()
      $Null = $SB.AppendLine($Content)
      $Null = $SB.AppendLine('')
    }}

    $Null = $SB.AppendLine('#endregion')
    $Null = $SB.AppendLine('')
  }

  # ── Tier 2: Public functions (alpha-sorted) ─────────────
  $PublicDir = Join-Path -Path:$SrcDir -ChildPath:'Public'
  $PublicFiles = Get-ChildItem -Path:(
    Join-Path -Path:$PublicDir -ChildPath:'*.ps1'
  ) -ErrorAction:'SilentlyContinue' | Sort-Object -Property:'Name'

  If ($PublicFiles) {
    $Null = $SB.AppendLine('#region Public Functions')
    $Null = $SB.AppendLine('')

    $PublicFiles | & { Process {
      $Content = (Get-Content -Path:$PSItem.FullName -Raw).Trim()
      $Null = $SB.AppendLine($Content)
      $Null = $SB.AppendLine('')
    }}

    $Null = $SB.AppendLine('#endregion')
    $Null = $SB.AppendLine('')
  }

  # ── Save functions-only (for test dot-sourcing) ──────────
  $FunctionsOnly = $SB.ToString().TrimEnd() +
    [System.Environment]::NewLine
  $FunctionsFile = Join-Path -Path:$BuildDir `
    -ChildPath:'Start-Uninstaller.Functions.ps1'
  [System.IO.File]::WriteAllText(
    $FunctionsFile,
    $FunctionsOnly,
    [System.Text.UTF8Encoding]::new($True)
  )
  $StringFiles = Get-ChildItem -Path:$SrcDir -Recurse `
    -Filter:'*.strings.psd1' `
    -ErrorAction:'SilentlyContinue'
  $StringFiles | & { Process {
    $TargetPath = Join-Path -Path:$BuildDir -ChildPath:$PSItem.Name
    Copy-Item -Path:$PSItem.FullName -Destination:$TargetPath -Force
  }}

  # ── Build full script (param block + functions + invoke) ──
  $FullSB = [System.Text.StringBuilder]::new(65536)
  $Null = $FullSB.AppendLine('#Requires -Version 5.1')
  $Null = $FullSB.AppendLine('')

  # Param block from entry point (skip #Requires lines)
  For ($J = 0; $J -le $ParamEnd; $J++) {
    $Line = $EntryLines[$J]
    If ($Line.Trim() -match '^#Requires') { Continue }
    $Null = $FullSB.AppendLine($Line)
  }
  $Null = $FullSB.AppendLine('')

  # Function definitions (strip leading #Requires + blank)
  $FuncBody = $FunctionsOnly -replace `
    '(?s)^#Requires[^\r\n]*\r?\n\r?\n', ''
  $Null = $FullSB.Append($FuncBody)

  # Invocation
  If ($Null -ne $InvocationLines -and
      $InvocationLines.Count -gt 0) {
    $Null = $FullSB.AppendLine('#region Entry Point')
    $Null = $FullSB.AppendLine('')
    $InvocationLines | & { Process {
      $Null = $FullSB.AppendLine($PSItem)
    }}
    $Null = $FullSB.AppendLine('')
    $Null = $FullSB.AppendLine('#endregion')
  }

  $FullContent = $FullSB.ToString().TrimEnd() +
    [System.Environment]::NewLine
  [System.IO.File]::WriteAllText(
    $OutputFile,
    $FullContent,
    [System.Text.UTF8Encoding]::new($True)
  )

  # Validate both build artifacts
  Assert-SyntaxValid -Path:@($FunctionsFile, $OutputFile)

  Write-Host -Object:('Build complete: {0}' -f $OutputFile) `
    -ForegroundColor:'Green'
}

Function Invoke-Analyze {
  If (-not (Test-Path -Path:$OutputFile)) { Invoke-Build }

  $SyntaxTargets = @(
    (Join-Path -Path:$ProjectRoot -ChildPath:'build.ps1'),
    $OutputFile
  )
  $SyntaxTargets += @(
    Get-ChildItem -Path:$SrcDir -Recurse -Filter:'*.ps1' |
      Select-Object -ExpandProperty:'FullName'
  )
  $SyntaxTargets += @(
    Get-ChildItem -Path:$TestsDir -Recurse -Filter:'*.ps1' `
      -ErrorAction:'SilentlyContinue' |
      Select-Object -ExpandProperty:'FullName'
  )

  Assert-SyntaxValid -Path:$SyntaxTargets

  $AnalyzerModule = Get-LatestAvailableModule -Name:'PSScriptAnalyzer'
  If (-not $AnalyzerModule) {
    Write-Warning -Message:(
      'PSScriptAnalyzer not installed. Syntax validation passed.'
    )
    Return
  }

  Import-Module -Name:$AnalyzerModule.Path -Force

  $SettingsFile = Join-Path -Path:$ProjectRoot `
    -ChildPath:'PSScriptAnalyzerSettings.psd1'
  $Settings = If (Test-Path -Path:$SettingsFile) {
    $SettingsFile
  } Else {
    $Null
  }

  $Results = @(
    Invoke-ScriptAnalyzer -Path:$OutputFile -Settings:$Settings
  )
  $Results += @(
    Invoke-ScriptAnalyzer -Path:(
      Join-Path -Path:$ProjectRoot -ChildPath:'build.ps1'
    ) -Settings:$Settings
  )

  If ($Results.Count -gt 0) {
    $Results | Format-Table -Property:@(
      'RuleName', 'Severity', 'ScriptName', 'Line', 'Message'
    ) -AutoSize
    Throw ('PSScriptAnalyzer found {0} issue(s).' -f $Results.Count)
  }

  Write-Host -Object:'Analysis passed.' -ForegroundColor:'Green'
}

Function Invoke-Test {
  If (-not (Test-Path -Path:$OutputFile)) { Invoke-Build }

  Invoke-SmokeTests

  $PesterModule = Get-LatestAvailableModule -Name:'Pester'
  If (-not $PesterModule -or
      $PesterModule.Version.Major -lt 5) {
    Write-Warning -Message:(
      'Pester 5 or newer is not installed. Smoke tests ran; Pester suite skipped.'
    )
    Return
  }

  Import-Module -Name:$PesterModule.Path -Force

  $PesterConfig = [PesterConfiguration]::Default
  $PesterConfig.Run.Path = $TestsDir
  $PesterConfig.Run.Exit = $True
  $PesterConfig.Output.Verbosity = 'Detailed'
  $PesterConfig.TestResult.Enabled = $True
  $PesterConfig.TestResult.OutputPath = Join-Path `
    -Path:$BuildDir -ChildPath:'testResults.xml'

  Invoke-Pester -Configuration:$PesterConfig
}

Function Invoke-Clean {
  If (Test-Path -Path:$BuildDir) {
    Remove-Item -Path:$BuildDir -Recurse -Force
  }
  Write-Host -Object:'Clean complete.' -ForegroundColor:'Green'
}

#endregion --- [ Task Functions ] ---------------------------------------- #

If ('All' -in $Task) {
  $Task = @('Clean', 'Build', 'Analyze', 'Test')
}

$Task | & { Process {
  Write-Host -Object:('{0}=== {1} ===' -f
    [System.Environment]::NewLine, $PSItem
  ) -ForegroundColor:'Cyan'
  & "Invoke-$PSItem"
}}

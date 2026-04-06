$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

$ProjectRoot = Split-Path -Path:(
  Split-Path -Path:$PSScriptRoot -Parent
) -Parent
$FunctionsFile = Join-Path -Path:$ProjectRoot -ChildPath:'build\Start-Uninstaller.Functions.ps1'
$BuiltScript = Join-Path -Path:$ProjectRoot -ChildPath:'build\Start-Uninstaller.ps1'

. $FunctionsFile

Function Assert-Equal {
  Param (
    $Actual,
    $Expected,
    [Parameter(Mandatory = $True)]
    [System.String]
    $Message
  )

  If ($Actual -ne $Expected) {
    Throw ('{0} Expected: {1}. Actual: {2}.' -f
      $Message,
      $Expected,
      $Actual)
  }
}

Function Assert-True {
  Param (
    [Parameter(Mandatory = $True)]
    [System.Boolean]
    $Condition,

    [Parameter(Mandatory = $True)]
    [System.String]
    $Message
  )

  If ($Condition -eq $False) {
    Throw $Message
  }
}

Function Assert-Match {
  Param (
    [Parameter(Mandatory = $True)]
    [AllowNull()]
    [System.String]
    $Actual,

    [Parameter(Mandatory = $True)]
    [System.String]
    $Pattern,

    [Parameter(Mandatory = $True)]
    [System.String]
    $Message
  )

  If ($Actual -notmatch $Pattern) {
    Throw ('{0} Pattern: {1}. Actual: {2}.' -f
      $Message,
      $Pattern,
      $Actual)
  }
}

Function Invoke-PowerShellChild {
  Param (
    [Parameter(Mandatory = $True)]
    [System.String]
    $Command
  )

  $TempScriptPath = Join-Path -Path:(
    Join-Path -Path:$ProjectRoot -ChildPath:'build'
  ) -ChildPath:('Smoke_{0}.ps1' -f
      [System.Guid]::NewGuid().ToString('N'))
  [System.IO.File]::WriteAllText(
    $TempScriptPath,
    (
      $Command +
      [System.Environment]::NewLine +
      'Exit ([System.Int32]$LASTEXITCODE)' +
      [System.Environment]::NewLine
    ),
    [System.Text.UTF8Encoding]::new($True)
  )
  Try {
    $StartInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $StartInfo.FileName = (Join-Path -Path:$PSHOME -ChildPath:'powershell.exe')
    $StartInfo.Arguments = (
      '-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $TempScriptPath
    )
    $StartInfo.UseShellExecute = $False
    $StartInfo.RedirectStandardOutput = $True
    $StartInfo.RedirectStandardError = $True

    $Process = [System.Diagnostics.Process]::Start($StartInfo)
    Try {
      $StdOut = $Process.StandardOutput.ReadToEnd()
      $StdErr = $Process.StandardError.ReadToEnd()
      $Process.WaitForExit()

      [PSCustomObject]@{
        ExitCode = $Process.ExitCode
        StdOut   = $StdOut
        StdErr   = $StdErr
      }
    } Finally {
      $Process.Dispose()
    }
  } Finally {
    If (Test-Path -LiteralPath:$TempScriptPath) {
      Remove-Item -LiteralPath:$TempScriptPath -Force
    }
  }
}

$ImpossibleName = 'AuditRegression_NoMatch_7B3CF7A6'

$InvalidPropertyCommand = @"
& '$BuiltScript' -Filter @(@{ Property = 'DisplayName'; Value = '$ImpossibleName'; MatchType = 'Simple' }) -ListOnly -Properties @('AppArch')
"@
$InvalidPropertyResult = Invoke-PowerShellChild -Command:$InvalidPropertyCommand
Assert-Equal `
  -Actual:$InvalidPropertyResult.ExitCode `
  -Expected:4 `
  -Message:'Built script should exit 4 for synthetic -Properties input.'
Assert-Match `
  -Actual:$InvalidPropertyResult.StdOut `
  -Pattern:'Synthetic field ''AppArch'' is not valid in -Properties' `
  -Message:'Built script should emit a validation line for synthetic -Properties input.'
Assert-Equal `
  -Actual:$InvalidPropertyResult.StdErr.Trim() `
  -Expected:'' `
  -Message:'Built script should not write stderr for synthetic -Properties input.'

$NoMatchCommand = @"
& '$BuiltScript' -Filter @(@{ Property = 'DisplayName'; Value = '$ImpossibleName'; MatchType = 'Simple' }) -ListOnly
"@
$NoMatchResult = Invoke-PowerShellChild -Command:$NoMatchCommand
Assert-Equal `
  -Actual:$NoMatchResult.ExitCode `
  -Expected:1 `
  -Message:'Built script should exit 1 when no applications match.'
Assert-Match `
  -Actual:$NoMatchResult.StdOut `
  -Pattern:'Message=No applications matched the supplied filters\.\s+\|\s+MatchCount=0' `
  -Message:'Built script should emit the no-match PDQ line.'
Assert-Equal `
  -Actual:$NoMatchResult.StdErr.Trim() `
  -Expected:'' `
  -Message:'Built script should not write stderr for a no-match result.'

$EmptyPropertyResult = Start-Uninstaller `
  -Filter @(@{ Property = 'DisplayName'; Value = $ImpossibleName; MatchType = 'Simple' }) `
  -Properties @('')
Assert-Equal `
  -Actual:$EmptyPropertyResult.ExitCode `
  -Expected:4 `
  -Message:'Start-Uninstaller should reject empty -Properties values.'

$FormattedRegistryPath = Format-RegistryPath `
  -DisplayRoot:'HKU' `
  -Path:'S-1-5-21-123-456-789-1001\Software\Microsoft\Windows\CurrentVersion\Uninstall' `
  -SubKeyName:'{ABC-123}'
Assert-Equal `
  -Actual:$FormattedRegistryPath `
  -Expected:'HKU\S-1-5-21-123-456-789-1001\Software\Microsoft\Windows\CurrentVersion\Uninstall\{ABC-123}' `
  -Message:'Registry path formatting should not duplicate the SID or append view suffixes.'

$Descriptors = @(New-RegistryViewDescriptor `
  -Hive:([Microsoft.Win32.RegistryHive]::Users) `
  -Path:'S-1-5-21-123-456-789-1001\Software\Microsoft\Windows\CurrentVersion\Uninstall' `
  -SourcePrefix:'HKU\S-1-5-21-123-456-789-1001' `
  -Is64BitOS:$True `
  -InstallScope:'User' `
  -UserSid:'S-1-5-21-123-456-789-1001' `
  -UserName:$Null `
  -UserIdentityStatus:'Unresolved')
Assert-True `
  -Condition:(@(
      $Descriptors | Where-Object { $PSItem.DisplayRoot -ne 'HKU' }
    ).Count -eq 0) `
  -Message:'User registry descriptors should expose HKU as the display root.'

$TimeoutResult = $Null
$Elapsed = Measure-Command {
  $TimeoutResult = Invoke-SilentProcess `
    -FileName:'cmd.exe' `
    -Arguments:'/c ping -n 6 127.0.0.1 > nul' `
    -TimeoutSeconds:1
}
Assert-Equal `
  -Actual:$TimeoutResult.Outcome `
  -Expected:'TimedOut' `
  -Message:'Invoke-SilentProcess should report TimedOut after the timeout expires.'
Assert-True `
  -Condition:($Elapsed.TotalSeconds -lt 15) `
  -Message:'Invoke-SilentProcess should return promptly after timeout.'

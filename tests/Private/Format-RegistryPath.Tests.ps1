#Requires -Module Pester

Describe 'Format-RegistryPath' {

  BeforeAll {
    . "$PSScriptRoot\..\..\build\Start-Uninstaller.Functions.ps1"
  }

  It 'Builds an HKLM path without adding view suffixes' {
    $Result = Format-RegistryPath `
      -DisplayRoot 'HKLM' `
      -Path 'Software\Microsoft\Windows\CurrentVersion\Uninstall' `
      -SubKeyName '{ABC-123}'

    $Result | Should -Be 'HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall\{ABC-123}'
  }

  It 'Builds an HKU path without duplicating the SID' {
    $Result = Format-RegistryPath `
      -DisplayRoot 'HKU' `
      -Path 'S-1-5-21-123-456-789-1001\Software\Microsoft\Windows\CurrentVersion\Uninstall' `
      -SubKeyName '{ABC-123}'

    $Result | Should -Be 'HKU\S-1-5-21-123-456-789-1001\Software\Microsoft\Windows\CurrentVersion\Uninstall\{ABC-123}'
  }

  It 'Omits SubKeyName when none is supplied' {
    $Result = Format-RegistryPath `
      -DisplayRoot 'HKU' `
      -Path 'S-1-5-21-123-456-789-1001\Software\Microsoft\Windows\CurrentVersion\Uninstall'

    $Result | Should -Be 'HKU\S-1-5-21-123-456-789-1001\Software\Microsoft\Windows\CurrentVersion\Uninstall'
  }
}

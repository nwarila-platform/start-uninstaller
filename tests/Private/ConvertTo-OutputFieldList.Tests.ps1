#Requires -Module Pester

Describe 'ConvertTo-OutputFieldList' {

  BeforeAll {
    . "$PSScriptRoot\..\..\build\Start-Uninstaller.Functions.ps1"
  }

  Context 'Mandatory fields are always included and sorted deterministically' {
    It 'Returns mandatory fields in ordinal case-insensitive order' {
      $Result = ConvertTo-OutputFieldList `
        -MandatoryFields @('zebra', 'Apple', 'Mango')

      $Result | Should -HaveCount 3
      $Result[0] | Should -Be 'Apple'
      $Result[1] | Should -Be 'Mango'
      $Result[2] | Should -Be 'zebra'
    }
  }

  Context 'Additional fields are appended after mandatory fields' {
    It 'Merges Properties and FilterPropertyNames into one sorted suffix' {
      $Result = ConvertTo-OutputFieldList `
        -MandatoryFields @('B', 'A') `
        -Properties @('Z') `
        -FilterPropertyNames @('F')

      $Result | Should -HaveCount 4
      $Result[0] | Should -Be 'A'
      $Result[1] | Should -Be 'B'
      $Result[2] | Should -Be 'F'
      $Result[3] | Should -Be 'Z'
    }
  }

  Context 'Deduplication is case-insensitive' {
    It 'Deduplicates matching names across mandatory and additional groups' {
      $Result = ConvertTo-OutputFieldList `
        -MandatoryFields @('DisplayName', 'Publisher') `
        -Properties @('displayname') `
        -FilterPropertyNames @('PUBLISHER')

      $Result | Should -HaveCount 2
      $Result[0] | Should -Be 'DisplayName'
      $Result[1] | Should -Be 'Publisher'
    }
  }

  Context 'Validation is fail-fast' {
    It 'Rejects whitespace-only -Properties entries' {
      {
        ConvertTo-OutputFieldList `
          -MandatoryFields @('DisplayName') `
          -Properties @('   ')
      } | Should -Throw '*named registry value*'
    }

    It 'Rejects NUL in -Properties entries' {
      {
        ConvertTo-OutputFieldList `
          -MandatoryFields @('DisplayName') `
          -Properties @("Bad`0Name")
      } | Should -Throw '*cannot contain NUL*'
    }

    It 'Rejects synthetic -Properties entries' {
      {
        ConvertTo-OutputFieldList `
          -MandatoryFields @('DisplayName') `
          -Properties @('AppArch')
      } | Should -Throw '*not valid in -Properties*'
    }

    It 'Rejects internal -Properties entries' {
      {
        ConvertTo-OutputFieldList `
          -MandatoryFields @('DisplayName') `
          -Properties @('_RegistryHive')
      } | Should -Throw '*Internal field*'
    }

    It 'Rejects internal filter-driven fields' {
      {
        ConvertTo-OutputFieldList `
          -MandatoryFields @('DisplayName') `
          -FilterPropertyNames @('_RegistryHive')
      } | Should -Throw '*never valid in output field selection*'
    }

    It 'Allows synthetic filter-driven fields' {
      $Result = ConvertTo-OutputFieldList `
        -MandatoryFields @('DisplayName') `
        -FilterPropertyNames @('AppArch')

      $Result | Should -Contain 'AppArch'
    }
  }
}

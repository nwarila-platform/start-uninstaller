#Requires -Module Pester

Describe 'Format-OutputLine' {

  BeforeAll {
    . "$PSScriptRoot\..\..\build\Start-Uninstaller.Functions.ps1"
  }

  Context 'Pipe-delimited Key=Value format' {

    It 'Produces Key=Value pairs separated by pipe with spaces' {
      $Record = [PSCustomObject]@{
        Name    = 'TestApp'
        Version = '1.0'
      }
      $Result = Format-OutputLine `
        -Record $Record `
        -FieldList @('Name', 'Version')

      $Result | Should -Be 'Name=TestApp | Version=1.0'
    }

    It 'Produces single Key=Value when only one field' {
      $Record = [PSCustomObject]@{ Name = 'App' }
      $Result = Format-OutputLine -Record $Record -FieldList @('Name')

      $Result | Should -Be 'Name=App'
    }

    It 'Preserves field order from FieldList' {
      $Record = [PSCustomObject]@{
        Zebra = 'Z'
        Alpha = 'A'
      }
      $Result = Format-OutputLine `
        -Record $Record `
        -FieldList @('Zebra', 'Alpha')

      $Result | Should -Be 'Zebra=Z | Alpha=A'
    }
  }

  Context '$Null values become <null>' {

    It 'Renders $Null property value as <null>' {
      $Record = [PSCustomObject]@{ ExitCode = $Null }
      $Result = Format-OutputLine `
        -Record $Record `
        -FieldList @('ExitCode')

      $Result | Should -Be 'ExitCode=<null>'
    }
  }

  Context 'CR/LF/TAB replaced with space' {

    It 'Replaces carriage return with space' {
      $Record = [PSCustomObject]@{
        Msg = "Hello`rWorld"
      }
      $Result = Format-OutputLine -Record $Record -FieldList @('Msg')

      $Result | Should -Be 'Msg=Hello World'
    }

    It 'Replaces line feed with space' {
      $Record = [PSCustomObject]@{
        Msg = "Hello`nWorld"
      }
      $Result = Format-OutputLine -Record $Record -FieldList @('Msg')

      $Result | Should -Be 'Msg=Hello World'
    }

    It 'Replaces tab with space' {
      $Record = [PSCustomObject]@{
        Msg = "Hello`tWorld"
      }
      $Result = Format-OutputLine -Record $Record -FieldList @('Msg')

      $Result | Should -Be 'Msg=Hello World'
    }

    It 'Replaces CRLF with space (collapses to single space)' {
      $Record = [PSCustomObject]@{
        Msg = "Hello`r`nWorld"
      }
      $Result = Format-OutputLine -Record $Record -FieldList @('Msg')

      $Result | Should -Be 'Msg=Hello World'
    }
  }

  Context 'Repeated whitespace collapsed' {

    It 'Collapses multiple spaces to single space' {
      $Record = [PSCustomObject]@{
        Msg = 'Hello     World'
      }
      $Result = Format-OutputLine -Record $Record -FieldList @('Msg')

      $Result | Should -Be 'Msg=Hello World'
    }

    It 'Collapses mixed whitespace (tabs and spaces)' {
      $Record = [PSCustomObject]@{
        Msg = "Hello`t  `t World"
      }
      $Result = Format-OutputLine -Record $Record -FieldList @('Msg')

      $Result | Should -Be 'Msg=Hello World'
    }
  }

  Context 'Literal pipe escaped as \|' {

    It 'Escapes a single pipe character' {
      $Record = [PSCustomObject]@{
        Val = 'A|B'
      }
      $Result = Format-OutputLine -Record $Record -FieldList @('Val')

      $Result | Should -Be 'Val=A\|B'
    }

    It 'Escapes multiple pipe characters' {
      $Record = [PSCustomObject]@{
        Val = 'A|B|C'
      }
      $Result = Format-OutputLine -Record $Record -FieldList @('Val')

      $Result | Should -Be 'Val=A\|B\|C'
    }
  }

  Context 'Leading/trailing whitespace trimmed' {

    It 'Trims leading whitespace from values' {
      $Record = [PSCustomObject]@{
        Val = '   Hello'
      }
      $Result = Format-OutputLine -Record $Record -FieldList @('Val')

      $Result | Should -Be 'Val=Hello'
    }

    It 'Trims trailing whitespace from values' {
      $Record = [PSCustomObject]@{
        Val = 'Hello   '
      }
      $Result = Format-OutputLine -Record $Record -FieldList @('Val')

      $Result | Should -Be 'Val=Hello'
    }

    It 'Trims both leading and trailing whitespace' {
      $Record = [PSCustomObject]@{
        Val = '  Hello  '
      }
      $Result = Format-OutputLine -Record $Record -FieldList @('Val')

      $Result | Should -Be 'Val=Hello'
    }
  }

  Context 'Missing properties become <null>' {

    It 'Renders <null> for a property not on the record' {
      $Record = [PSCustomObject]@{ Name = 'App' }
      $Result = Format-OutputLine `
        -Record $Record `
        -FieldList @('Name', 'MissingField')

      $Result | Should -Be 'Name=App | MissingField=<null>'
    }

    It 'Renders <null> for multiple missing properties' {
      $Record = [PSCustomObject]@{}
      $Result = Format-OutputLine `
        -Record $Record `
        -FieldList @('A', 'B')

      $Result | Should -Be 'A=<null> | B=<null>'
    }
  }

  Context 'Combined sanitization' {

    It 'Applies all sanitization rules together' {
      $Record = [PSCustomObject]@{
        Msg = "  Hello`r`n`tWorld  |  test  "
      }
      $Result = Format-OutputLine -Record $Record -FieldList @('Msg')

      # CR/LF/TAB -> space, collapse, escape pipe, trim
      $Result | Should -Be 'Msg=Hello World \| test'
    }

    It 'Handles value that is entirely whitespace' {
      $Record = [PSCustomObject]@{
        Val = '    '
      }
      $Result = Format-OutputLine -Record $Record -FieldList @('Val')

      # After trim, becomes empty string
      $Result | Should -Be 'Val='
    }
  }

  Context 'Numeric and boolean values' {

    It 'Converts numeric values to string' {
      $Record = [PSCustomObject]@{
        ExitCode = 0
      }
      $Result = Format-OutputLine -Record $Record -FieldList @('ExitCode')

      $Result | Should -Be 'ExitCode=0'
    }

    It 'Converts boolean values to string' {
      $Record = [PSCustomObject]@{
        IsHidden = $True
      }
      $Result = Format-OutputLine -Record $Record -FieldList @('IsHidden')

      $Result | Should -Be 'IsHidden=True'
    }
  }
}

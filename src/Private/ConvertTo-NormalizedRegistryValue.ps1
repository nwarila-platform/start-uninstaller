#Requires -Version 5.1

Function ConvertTo-NormalizedRegistryValue {
  <#
    .SYNOPSIS
      Normalizes a raw registry value to a string-safe
      representation.

    .DESCRIPTION
      Converts supported registry value types to strings:
        - [System.String] -> as-is
        - numeric scalars -> invariant string
        - [System.String[]] -> joined with '; '
        - all other types -> returns $Null (ignored)

      The unnamed default registry value is excluded by the
      caller, not here.

    .PARAMETER Value
      The raw value returned by RegistryKey.GetValue().

    .EXAMPLE
      ConvertTo-NormalizedRegistryValue -Value:@('One', 'Two')

    .OUTPUTS
      [System.String] or $Null

    .NOTES
      Author  : HellBomb
      Version : 8.1.0
  #>

  [CmdletBinding(
    DefaultParameterSetName = 'Default'
    , HelpURI = ''
    , PositionalBinding = $False
    , RemotingCapability = 'None'
  )]
  [OutputType([System.String])]
  Param (
    [Parameter(
      Mandatory = $False
      , ParameterSetName = 'Default'
      , DontShow = $False
      , HelpMessage = 'See function help.'
      , ValueFromPipeline = $False
      , ValueFromPipelineByPropertyName = $False
      , ValueFromRemainingArguments = $False
    )]
    [AllowNull()]
    [System.Object]
    $Value
  )

  Begin {
    Write-Debug -Message:('[ConvertTo-NormalizedRegistryValue] Entering Begin')
    Write-Debug -Message:('[ConvertTo-NormalizedRegistryValue] Exiting Begin')
  } Process {
    Write-Debug -Message:('[ConvertTo-NormalizedRegistryValue] Entering Process')

    $HasNullValue = [System.Boolean]($Null -eq $Value)
    If ($HasNullValue -eq $True) {
      $Null
    } Else {
      $ValueType = $Value.GetType()
      $IsStringValue = [System.Boolean]($ValueType -eq [System.String])
      If ($IsStringValue -eq $True) {
        [System.String]$Value
      } Else {
        $IsNumericValue = [System.Boolean](
          $ValueType -eq [System.Int32] -or
          $ValueType -eq [System.Int64] -or
          $ValueType -eq [System.UInt32] -or
          $ValueType -eq [System.UInt64]
        )
        If ($IsNumericValue -eq $True) {
          [System.String]$Value.ToString(
            [System.Globalization.CultureInfo]::InvariantCulture
          )
        } Else {
          $IsStringArrayValue = [System.Boolean](
            $ValueType -eq [System.String[]]
          )
          If ($IsStringArrayValue -eq $True) {
            [System.String]($Value -join '; ')
          } Else {
            $Null
          }
        }
      }
    }

    Write-Debug -Message:('[ConvertTo-NormalizedRegistryValue] Exiting Process')
  } End {
    Write-Debug -Message:('[ConvertTo-NormalizedRegistryValue] Entering End')
    Write-Debug -Message:('[ConvertTo-NormalizedRegistryValue] Exiting End')
  }
}

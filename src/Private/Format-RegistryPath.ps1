#Requires -Version 5.1

Function Format-RegistryPath {
  <#
    .SYNOPSIS
      Builds a user-facing registry path string.

    .DESCRIPTION
      Combines a display root (for example HKLM or HKU), a
      registry subkey path, and an optional child key name into
      a single backslash-delimited path string for logging and
      PDQ output.

    .PARAMETER DisplayRoot
      The user-facing registry root name.

    .PARAMETER Path
      The registry subkey path beneath the root.

    .PARAMETER SubKeyName
      Optional child key name to append.

    .EXAMPLE
      Format-RegistryPath -DisplayRoot:'HKLM' -Path:'Software\Vendor\Product'

    .OUTPUTS
      [System.String]

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
      Mandatory = $True
      , ParameterSetName = 'Default'
      , DontShow = $False
      , HelpMessage = 'See function help.'
      , ValueFromPipeline = $False
      , ValueFromPipelineByPropertyName = $False
      , ValueFromRemainingArguments = $False
    )]
    [ValidateNotNullOrEmpty()]
    [System.String]
    $DisplayRoot,

    [Parameter(
      Mandatory = $True
      , ParameterSetName = 'Default'
      , DontShow = $False
      , HelpMessage = 'See function help.'
      , ValueFromPipeline = $False
      , ValueFromPipelineByPropertyName = $False
      , ValueFromRemainingArguments = $False
    )]
    [ValidateNotNullOrEmpty()]
    [System.String]
    $Path,

    [Parameter(
      Mandatory = $False
      , ParameterSetName = 'Default'
      , DontShow = $False
      , HelpMessage = 'See function help.'
      , ValueFromPipeline = $False
      , ValueFromPipelineByPropertyName = $False
      , ValueFromRemainingArguments = $False
    )]
    [AllowEmptyString()]
    [System.String]
    $SubKeyName = ''
  )

  Begin {
    Write-Debug -Message:('[Format-RegistryPath] Entering Begin')
    Write-Debug -Message:('[Format-RegistryPath] Exiting Begin')
  } Process {
    Write-Debug -Message:('[Format-RegistryPath] Entering Process')

    $Parts = [System.Collections.Generic.List[System.String]]::new()
    $Parts.Add($DisplayRoot)
    $Parts.Add($Path)

    $HasSubKeyName = [System.Boolean](
      [System.String]::IsNullOrWhiteSpace($SubKeyName) -eq $False
    )
    If ($HasSubKeyName -eq $True) {
      $Parts.Add($SubKeyName)
    }

    [System.String]($Parts -join '\')

    Write-Debug -Message:('[Format-RegistryPath] Exiting Process')
  } End {
    Write-Debug -Message:('[Format-RegistryPath] Entering End')
    Write-Debug -Message:('[Format-RegistryPath] Exiting End')
  }
}

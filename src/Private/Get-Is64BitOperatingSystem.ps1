#Requires -Version 5.1

Function Get-Is64BitOperatingSystem {
  <#
    .SYNOPSIS
      Returns whether the operating system is 64-bit.

    .DESCRIPTION
      Thin seam around
      [System.Environment]::Is64BitOperatingSystem so tests can
      mock OS bitness without modifying static .NET state.

    .EXAMPLE
      Get-Is64BitOperatingSystem

    .OUTPUTS
      [System.Boolean]

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
  [OutputType([System.Boolean])]
  Param()

  Begin {
    Write-Debug -Message:('[Get-Is64BitOperatingSystem] Entering Begin')
    Write-Debug -Message:('[Get-Is64BitOperatingSystem] Exiting Begin')
  } Process {
    Write-Debug -Message:('[Get-Is64BitOperatingSystem] Entering Process')

    [System.Boolean][System.Environment]::Is64BitOperatingSystem

    Write-Debug -Message:('[Get-Is64BitOperatingSystem] Exiting Process')
  } End {
    Write-Debug -Message:('[Get-Is64BitOperatingSystem] Entering End')
    Write-Debug -Message:('[Get-Is64BitOperatingSystem] Exiting End')
  }
}

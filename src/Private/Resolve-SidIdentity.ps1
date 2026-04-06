#Requires -Version 5.1

Function Resolve-SidIdentity {
  <#
    .SYNOPSIS
      Translates a SID string to a username.

    .DESCRIPTION
      Attempts to resolve a SID to `DOMAIN\Username` using
      [System.Security.Principal.SecurityIdentifier]. Returns
      `$Null` on failure because SID translation is best-effort.

      This is a seam function for testability.

    .PARAMETER Sid
      The SID string to resolve.

    .EXAMPLE
      Resolve-SidIdentity -Sid:'S-1-5-18'

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
    $Sid
  )

  Begin {
    Write-Debug -Message:('[Resolve-SidIdentity] Entering Begin')
    Write-Debug -Message:('[Resolve-SidIdentity] Exiting Begin')
  }

  Process {
    Write-Debug -Message:('[Resolve-SidIdentity] Entering Process')

    Try {
      $SecurityIdentifier = [System.Security.Principal.SecurityIdentifier]::new($Sid)
      $Account = $SecurityIdentifier.Translate(
        [System.Security.Principal.NTAccount]
      )
      [System.String]$Account.Value
    } Catch [System.ArgumentException] {
      $Null
    } Catch [System.Security.Principal.IdentityNotMappedException] {
      $Null
    } Catch [System.SystemException] {
      $Null
    }

    Write-Debug -Message:('[Resolve-SidIdentity] Exiting Process')
  }

  End {
    Write-Debug -Message:('[Resolve-SidIdentity] Entering End')
    Write-Debug -Message:('[Resolve-SidIdentity] Exiting End')
  }
}

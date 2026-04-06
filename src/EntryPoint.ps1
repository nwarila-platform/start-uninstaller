# EntryPoint.ps1 - Top-level script wrapper for PDQ Deploy.
# In the built artifact, this becomes the outer script body.
# It exposes the param() block, calls Start-Uninstaller,
# writes the returned PDQ lines, and exits with the returned
# script exit code.
#
# This file is NOT a function. It is the script entry point.

#Requires -Version 5.1

[CmdletBinding(
  DefaultParameterSetName = 'Default'
  , PositionalBinding = $False
)]
Param (
  [Parameter(
    Mandatory = $True
    , ParameterSetName = 'Default'
    , DontShow = $False
    , HelpMessage = 'See script help.'
    , ValueFromPipeline = $False
    , ValueFromPipelineByPropertyName = $False
    , ValueFromRemainingArguments = $False
  )]
  [ValidateNotNullOrEmpty()]
  [System.Collections.Hashtable[]]
  $Filter,

  [Parameter(
    Mandatory = $False
    , ParameterSetName = 'Default'
    , DontShow = $False
    , HelpMessage = 'See script help.'
    , ValueFromPipeline = $False
    , ValueFromPipelineByPropertyName = $False
    , ValueFromRemainingArguments = $False
  )]
  [ValidateSet('x86', 'x64', 'Both')]
  [System.String]
  $Architecture = 'Both',

  [Parameter(
    Mandatory = $False
    , ParameterSetName = 'Default'
    , DontShow = $False
    , HelpMessage = 'See script help.'
    , ValueFromPipeline = $False
    , ValueFromPipelineByPropertyName = $False
    , ValueFromRemainingArguments = $False
  )]
  [System.String[]]
  $Properties = @(),

  [Parameter(
    Mandatory = $False
    , ParameterSetName = 'Default'
    , DontShow = $False
    , HelpMessage = 'See script help.'
    , ValueFromPipeline = $False
    , ValueFromPipelineByPropertyName = $False
    , ValueFromRemainingArguments = $False
  )]
  [System.String]
  $EXEFlags,

  [Parameter(
    Mandatory = $False
    , ParameterSetName = 'Default'
    , DontShow = $False
    , HelpMessage = 'See script help.'
    , ValueFromPipeline = $False
    , ValueFromPipelineByPropertyName = $False
    , ValueFromRemainingArguments = $False
  )]
  [System.Management.Automation.SwitchParameter]
  $ListOnly,

  [Parameter(
    Mandatory = $False
    , ParameterSetName = 'Default'
    , DontShow = $False
    , HelpMessage = 'See script help.'
    , ValueFromPipeline = $False
    , ValueFromPipelineByPropertyName = $False
    , ValueFromRemainingArguments = $False
  )]
  [System.Management.Automation.SwitchParameter]
  $IncludeHidden,

  [Parameter(
    Mandatory = $False
    , ParameterSetName = 'Default'
    , DontShow = $False
    , HelpMessage = 'See script help.'
    , ValueFromPipeline = $False
    , ValueFromPipelineByPropertyName = $False
    , ValueFromRemainingArguments = $False
  )]
  [System.Management.Automation.SwitchParameter]
  $IncludeNameless,

  [Parameter(
    Mandatory = $False
    , ParameterSetName = 'Default'
    , DontShow = $False
    , HelpMessage = 'See script help.'
    , ValueFromPipeline = $False
    , ValueFromPipelineByPropertyName = $False
    , ValueFromRemainingArguments = $False
  )]
  [System.Management.Automation.SwitchParameter]
  $AllowMultipleMatches,

  [Parameter(
    Mandatory = $False
    , ParameterSetName = 'Default'
    , DontShow = $False
    , HelpMessage = 'See script help.'
    , ValueFromPipeline = $False
    , ValueFromPipelineByPropertyName = $False
    , ValueFromRemainingArguments = $False
  )]
  [ValidateRange(1, 3600)]
  [System.Int32]
  $TimeoutSeconds = 600
)

Write-Debug -Message:('[EntryPoint] Entering script body')
$RunResult = Start-Uninstaller @PSBoundParameters
$RunResult.Lines | & { Process {
  Write-Output $PSItem
}}
Write-Debug -Message:('[EntryPoint] Exiting script body')
Exit ([System.Int32]$RunResult.ExitCode)

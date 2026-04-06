#Requires -Version 5.1

Function New-ErrorRecord {
  <#
    .SYNOPSIS
      Creates a structured error record for consistent error handling.

    .DESCRIPTION
      Instantiates a .NET exception, wraps it in a
      `System.Management.Automation.ErrorRecord`, and returns the
      record to the caller. When `-IsFatal` is `$True`, the helper
      raises the record as a terminating error instead.

    .PARAMETER ExceptionName
      Full .NET exception type name to instantiate.

    .PARAMETER ExceptionMessage
      Human-readable error message for the exception instance.

    .PARAMETER TargetObject
      Context object that was being processed when the error
      occurred.

    .PARAMETER ErrorId
      Stable, searchable identifier for the error condition.

    .PARAMETER ErrorCategory
      PowerShell error category classification.

    .PARAMETER IsFatal
      When `$True`, raises the created error record as a
      terminating error instead of returning it.

    .EXAMPLE
      New-ErrorRecord `
        -ExceptionName:'System.InvalidOperationException' `
        -ExceptionMessage:'The operation failed.' `
        -TargetObject:$Path `
        -ErrorId:'ExampleFailed' `
        -ErrorCategory:([System.Management.Automation.ErrorCategory]::InvalidOperation)

    .OUTPUTS
      [System.Management.Automation.ErrorRecord]

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
  [OutputType([System.Management.Automation.ErrorRecord])]
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
    $ExceptionName,

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
    $ExceptionMessage,

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
    $TargetObject = $Null,

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
    $ErrorId,

    [Parameter(
      Mandatory = $True
      , ParameterSetName = 'Default'
      , DontShow = $False
      , HelpMessage = 'See function help.'
      , ValueFromPipeline = $False
      , ValueFromPipelineByPropertyName = $False
      , ValueFromRemainingArguments = $False
    )]
    [System.Management.Automation.ErrorCategory]
    $ErrorCategory,

    [Parameter(
      Mandatory = $False
      , ParameterSetName = 'Default'
      , DontShow = $False
      , HelpMessage = 'See function help.'
      , ValueFromPipeline = $False
      , ValueFromPipelineByPropertyName = $False
      , ValueFromRemainingArguments = $False
    )]
    [System.Boolean]
    $IsFatal = $False
  )

  Begin {
    Write-Debug -Message:('[New-ErrorRecord] Entering Begin')

    $Strings = @{
      ExceptionTypeFallbackWarning =
        'Could not create exception type ''{0}''. Falling back to RuntimeException. Inner error: {1}'
    }
    Import-LocalizedData `
      -BindingVariable:'Strings' `
      -FileName:'New-ErrorRecord.strings' `
      -BaseDirectory:$PSScriptRoot `
      -ErrorAction:'SilentlyContinue'

    Write-Debug -Message:('[New-ErrorRecord] Exiting Begin')
  }

  Process {
    Write-Debug -Message:('[New-ErrorRecord] Entering Process')

    Try {
      $Exception = New-Object `
        -TypeName:$ExceptionName `
        -ArgumentList:@($ExceptionMessage)
    } Catch {
      Write-Warning -Message:(
        $Strings['ExceptionTypeFallbackWarning'] -f
          $ExceptionName,
          $PSItem.Exception.Message
      )
      $Exception = [System.Management.Automation.RuntimeException]::new(
        $ExceptionMessage
      )
    }

    $ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
      $Exception,
      $ErrorId,
      $ErrorCategory,
      $TargetObject
    )

    If ($IsFatal -eq $True) {
      $PSCmdlet.ThrowTerminatingError($ErrorRecord)
    }

    $ErrorRecord

    Write-Debug -Message:('[New-ErrorRecord] Exiting Process')
  }

  End {
    Write-Debug -Message:('[New-ErrorRecord] Entering End')
    Write-Debug -Message:('[New-ErrorRecord] Exiting End')
  }
}

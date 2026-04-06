#Requires -Version 5.1

Function Format-OutputLine {
  <#
    .SYNOPSIS
      Renders a single PDQ-friendly output line from a record
      and an ordered field list.

    .DESCRIPTION
      Produces a pipe-delimited `Key=Value` line for PDQ Deploy
      consumption. Values are sanitized as follows:
        - `$Null` becomes `<null>`
        - CR, LF, and TAB become spaces
        - repeated whitespace is collapsed
        - literal `|` is escaped as `\|`
        - leading/trailing whitespace is trimmed

    .PARAMETER Record
      The object containing the data to emit.

    .PARAMETER FieldList
      Ordered array of field names to include in the output.

    .EXAMPLE
      Format-OutputLine -Record:$Record -FieldList:@('DisplayName', 'Outcome')

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
    [System.Management.Automation.PSObject]
    $Record,

    [Parameter(
      Mandatory = $True
      , ParameterSetName = 'Default'
      , DontShow = $False
      , HelpMessage = 'See function help.'
      , ValueFromPipeline = $False
      , ValueFromPipelineByPropertyName = $False
      , ValueFromRemainingArguments = $False
    )]
    [System.String[]]
    $FieldList
  )

  Begin {
    Write-Debug -Message:('[Format-OutputLine] Entering Begin')

    $Strings = @{
      OutputLineFormatFailed =
        'Unable to format output field ''{0}'': {1}'
    }
    Import-LocalizedData `
      -BindingVariable:'Strings' `
      -FileName:'Format-OutputLine.strings' `
      -BaseDirectory:$PSScriptRoot `
      -ErrorAction:'SilentlyContinue'

    Write-Debug -Message:('[Format-OutputLine] Exiting Begin')
  } Process {
    Write-Debug -Message:('[Format-OutputLine] Entering Process')

    $Parts = [System.Collections.Generic.List[System.String]]::new()

    $FieldList | & { Process {
      $FieldName = [System.String]$PSItem

      Try {
        $PropertyInfo = $Record.PSObject.Properties[$FieldName]
        $RawValue = $Null
        $HasPropertyInfo = [System.Boolean]($Null -ne $PropertyInfo)
        If ($HasPropertyInfo -eq $True) {
          $RawValue = $PropertyInfo.Value
        }

        $HasNullRawValue = [System.Boolean]($Null -eq $RawValue)
        $Sanitized = If ($HasNullRawValue -eq $True) {
          '<null>'
        } Else {
          $RenderedValue = [System.String]$RawValue
          $RenderedValue = $RenderedValue -replace '[\r\n\t]', ' '
          $RenderedValue = $RenderedValue -replace '\s{2,}', ' '
          $RenderedValue = $RenderedValue -replace '\|', '\|'
          $RenderedValue.Trim()
        }

        $Parts.Add(('{0}={1}' -f $FieldName, $Sanitized))
      } Catch {
        $ErrorRecord = New-ErrorRecord `
          -ExceptionName:'System.InvalidOperationException' `
          -ExceptionMessage:(
            $Strings['OutputLineFormatFailed'] -f
              $FieldName,
              $PSItem.Exception.Message
          ) `
          -TargetObject:$FieldName `
          -ErrorId:'FormatOutputLineFailed' `
          -ErrorCategory:([System.Management.Automation.ErrorCategory]::InvalidData)
        $PSCmdlet.ThrowTerminatingError($ErrorRecord)
      }
    }}

    [System.String]($Parts -join ' | ')

    Write-Debug -Message:('[Format-OutputLine] Exiting Process')
  } End {
    Write-Debug -Message:('[Format-OutputLine] Entering End')
    Write-Debug -Message:('[Format-OutputLine] Exiting End')
  }
}

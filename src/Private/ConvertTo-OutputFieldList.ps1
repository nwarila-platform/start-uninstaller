#Requires -Version 5.1

Function ConvertTo-OutputFieldList {
  <#
    .SYNOPSIS
      Builds the final ordered list of output field names for
      PDQ line emission.

    .DESCRIPTION
      Merges mandatory fields, `-Properties` values, and filter
      property names into a single deduplicated ordered list.
      Mandatory fields come first, followed by additional
      fields. Both groups are sorted with ordinal,
      case-insensitive comparison so output ordering is stable
      across session culture.

    .PARAMETER MandatoryFields
      The base set of fields that are always emitted.

    .PARAMETER Properties
      Additional raw registry value names requested by the user.

    .PARAMETER FilterPropertyNames
      Property names from the compiled filters that should
      auto-append to output if not already present.

    .EXAMPLE
      ConvertTo-OutputFieldList `
        -MandatoryFields:@('DisplayName', 'Publisher') `
        -Properties:@('InstallLocation')

    .OUTPUTS
      [System.String[]]

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
  [OutputType([System.String[]])]
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
    [System.String[]]
    $MandatoryFields,

    [Parameter(
      Mandatory = $False
      , ParameterSetName = 'Default'
      , DontShow = $False
      , HelpMessage = 'See function help.'
      , ValueFromPipeline = $False
      , ValueFromPipelineByPropertyName = $False
      , ValueFromRemainingArguments = $False
    )]
    [AllowEmptyCollection()]
    [System.String[]]
    $Properties = @(),

    [Parameter(
      Mandatory = $False
      , ParameterSetName = 'Default'
      , DontShow = $False
      , HelpMessage = 'See function help.'
      , ValueFromPipeline = $False
      , ValueFromPipelineByPropertyName = $False
      , ValueFromRemainingArguments = $False
    )]
    [AllowEmptyCollection()]
    [System.String[]]
    $FilterPropertyNames = @()
  )

  Begin {
    Write-Debug -Message:('[ConvertTo-OutputFieldList] Entering Begin')
    $Strings = @{
      AdditionalFieldsBuildFailed =
        'Unable to build additional output fields: {0}'
      FilterFieldContainsNul =
        'Filter-driven property names cannot contain NUL.'
      FilterFieldEmpty =
        'Filter-driven property names must be non-empty.'
      InternalFilterFieldInvalid =
        'Internal field ''{0}'' is never valid in output field selection.'
      InternalPropertyFieldInvalid =
        'Internal field ''{0}'' is not valid in -Properties.'
      MandatoryFieldContainsNul =
        'Mandatory field names cannot contain NUL.'
      MandatoryFieldEmpty =
        'Mandatory field names must be non-empty.'
      MandatoryFieldsBuildFailed =
        'Unable to build mandatory output fields: {0}'
      OutputFieldSortFailed =
        'Unable to finalize output field ordering: {0}'
      PropertyFieldContainsNul =
        'Registry property names in -Properties cannot contain NUL.'
      PropertyFieldEmpty =
        'Each -Properties value must be a named registry value.'
      SyntheticPropertyFieldInvalid =
        'Synthetic field ''{0}'' is not valid in -Properties. Use it in -Filter instead.'
    }
    Import-LocalizedData `
      -BindingVariable:'Strings' `
      -FileName:'ConvertTo-OutputFieldList.strings' `
      -BaseDirectory:$PSScriptRoot `
      -ErrorAction:'SilentlyContinue'

    $ThrowArgumentError = {
      Param(
        [System.String]$Message,
        [System.Object]$TargetObject,
        [System.String]$ErrorId
      )

      $ErrorRecord = New-ErrorRecord `
        -ExceptionName:'System.ArgumentException' `
        -ExceptionMessage:$Message `
        -TargetObject:$TargetObject `
        -ErrorId:$ErrorId `
        -ErrorCategory:([System.Management.Automation.ErrorCategory]::InvalidArgument)
      $PSCmdlet.ThrowTerminatingError($ErrorRecord)
    }
    Write-Debug -Message:('[ConvertTo-OutputFieldList] Exiting Begin')
  } Process {
    Write-Debug -Message:('[ConvertTo-OutputFieldList] Entering Process')
    $SyntheticFields = @(
      'AppArch',
      'InstallScope',
      'IsHidden',
      'RegistryPath',
      'UserIdentityStatus',
      'UserName',
      'UserSid'
    )
    $InternalFields = @(
      '_ParsedDisplayVersion',
      '_RegistryHive',
      '_RegistryView',
      '_RegistrySource'
    )
    $Comparer = [System.StringComparer]::OrdinalIgnoreCase
    $Seen = [System.Collections.Generic.HashSet[System.String]]::new(
      $Comparer
    )
    $MandatoryBuffer = [System.Collections.Generic.List[System.String]]::new()
    $MandatorySorted = [System.Collections.Generic.List[System.String]]::new()
    $AdditionalBuffer = [System.Collections.Generic.List[System.String]]::new()
    $AdditionalSorted = [System.Collections.Generic.List[System.String]]::new()

    $MandatoryFields | & { Process {
      $FieldName = [System.String]$PSItem
      $IsEmptyFieldName = [System.Boolean](
        [System.String]::IsNullOrWhiteSpace($FieldName) -eq $True
      )
      If ($IsEmptyFieldName -eq $True) {
        & $ThrowArgumentError `
          $Strings['MandatoryFieldEmpty'] `
          $FieldName `
          'ConvertToOutputFieldListMandatoryFieldEmpty'
      }

      $ContainsNulCharacter = [System.Boolean]($FieldName.Contains("`0"))
      If ($ContainsNulCharacter -eq $True) {
        & $ThrowArgumentError `
          $Strings['MandatoryFieldContainsNul'] `
          $FieldName `
          'ConvertToOutputFieldListMandatoryFieldContainsNul'
      }

      $Null = $MandatoryBuffer.Add($FieldName)
    }}

    $Properties | & { Process {
      $FieldName = [System.String]$PSItem
      $IsEmptyFieldName = [System.Boolean](
        [System.String]::IsNullOrWhiteSpace($FieldName) -eq $True
      )
      If ($IsEmptyFieldName -eq $True) {
        & $ThrowArgumentError `
          $Strings['PropertyFieldEmpty'] `
          $FieldName `
          'ConvertToOutputFieldListPropertyFieldEmpty'
      }

      $ContainsNulCharacter = [System.Boolean]($FieldName.Contains("`0"))
      If ($ContainsNulCharacter -eq $True) {
        & $ThrowArgumentError `
          $Strings['PropertyFieldContainsNul'] `
          $FieldName `
          'ConvertToOutputFieldListPropertyFieldContainsNul'
      }

      $IsSyntheticField = [System.Boolean](
        $SyntheticFields -icontains $FieldName
      )
      If ($IsSyntheticField -eq $True) {
        & $ThrowArgumentError `
          ($Strings['SyntheticPropertyFieldInvalid'] -f $FieldName) `
          $FieldName `
          'ConvertToOutputFieldListSyntheticPropertyFieldInvalid'
      }

      $IsInternalField = [System.Boolean](
        $InternalFields -icontains $FieldName
      )
      If ($IsInternalField -eq $True) {
        & $ThrowArgumentError `
          ($Strings['InternalPropertyFieldInvalid'] -f $FieldName) `
          $FieldName `
          'ConvertToOutputFieldListInternalPropertyFieldInvalid'
      }

      $Null = $AdditionalBuffer.Add($FieldName)
    }}

    $FilterPropertyNames | & { Process {
      $FieldName = [System.String]$PSItem
      $IsEmptyFieldName = [System.Boolean](
        [System.String]::IsNullOrWhiteSpace($FieldName) -eq $True
      )
      If ($IsEmptyFieldName -eq $True) {
        & $ThrowArgumentError `
          $Strings['FilterFieldEmpty'] `
          $FieldName `
          'ConvertToOutputFieldListFilterFieldEmpty'
      }

      $ContainsNulCharacter = [System.Boolean]($FieldName.Contains("`0"))
      If ($ContainsNulCharacter -eq $True) {
        & $ThrowArgumentError `
          $Strings['FilterFieldContainsNul'] `
          $FieldName `
          'ConvertToOutputFieldListFilterFieldContainsNul'
      }

      $IsInternalField = [System.Boolean](
        $InternalFields -icontains $FieldName
      )
      If ($IsInternalField -eq $True) {
        & $ThrowArgumentError `
          ($Strings['InternalFilterFieldInvalid'] -f $FieldName) `
          $FieldName `
          'ConvertToOutputFieldListInternalFilterFieldInvalid'
      }

      $Null = $AdditionalBuffer.Add($FieldName)
    }}

    Try {
      $MandatoryBuffer.Sort($Comparer)
      $AdditionalBuffer.Sort($Comparer)

      $MandatoryBuffer | & { Process {
        $WasAdded = [System.Boolean]($Seen.Add($PSItem) -eq $True)
        If ($WasAdded -eq $True) {
          $Null = $MandatorySorted.Add([System.String]$PSItem)
        }
      }}

      $AdditionalBuffer | & { Process {
        $WasAdded = [System.Boolean]($Seen.Add($PSItem) -eq $True)
        If ($WasAdded -eq $True) {
          $Null = $AdditionalSorted.Add([System.String]$PSItem)
        }
      }}
    } Catch {
      $ErrorRecord = New-ErrorRecord `
        -ExceptionName:'System.InvalidOperationException' `
        -ExceptionMessage:(
          $Strings['OutputFieldSortFailed'] -f
            $PSItem.Exception.Message
        ) `
        -TargetObject:$Null `
        -ErrorId:'ConvertToOutputFieldListSortFailed' `
        -ErrorCategory:([System.Management.Automation.ErrorCategory]::InvalidOperation)
      $PSCmdlet.ThrowTerminatingError($ErrorRecord)
    }

    [System.String[]](@($MandatorySorted) + @($AdditionalSorted))
    Write-Debug -Message:('[ConvertTo-OutputFieldList] Exiting Process')
  } End {
    Write-Debug -Message:('[ConvertTo-OutputFieldList] Entering End')
    Write-Debug -Message:('[ConvertTo-OutputFieldList] Exiting End')
  }
}

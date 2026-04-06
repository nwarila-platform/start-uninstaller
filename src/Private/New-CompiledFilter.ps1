#Requires -Version 5.1

Function New-CompiledFilter {
  <#
    .SYNOPSIS
      Validates and compiles one or more filter hashtable
      definitions into typed filter objects.

    .DESCRIPTION
      Each filter hashtable must contain `Property`, `Value`,
      and `MatchType` keys. Supported match types:

        Simple   - Case-insensitive exact string match.
        Wildcard - Case-insensitive PowerShell wildcard.
        Regex    - Case-insensitive .NET regex.
        EQ/GT/GTE/LT/LTE - Semantic version operators that are
                           valid only on DisplayVersion.

      Returns one compiled filter object per input hashtable
      with pre-compiled matching artifacts for fast evaluation.

    .PARAMETER Filter
      One or more hashtable definitions.

    .EXAMPLE
      New-CompiledFilter -Filter @(
        @{ Property = 'DisplayName'; Value = 'Node.js'; MatchType = 'Simple' }
      )

    .OUTPUTS
      [System.Management.Automation.PSObject[]]

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
  [OutputType([StartUninstallerCompiledFilter])]
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
    [System.Collections.Hashtable[]]
    $Filter
  )

  Begin {
    Write-Debug -Message:('[New-CompiledFilter] Entering Begin')

    $Strings = @{
      CompiledFilterCreationFailed =
        'Unable to compile filter on property ''{0}'': {1}'
      FilterMatchTypeInvalid =
        'MatchType must be one of: {0}. Got: ''{1}''.'
      FilterMatchTypeMissing =
        'Each filter must contain a ''MatchType'' key.'
      FilterPropertyContainsNul =
        'Filter property name cannot contain NUL.'
      FilterPropertyInternalOnly =
        'Internal field ''{0}'' is never valid in filters.'
      FilterPropertyMissing =
        'Each filter must contain a non-empty ''Property'' key.'
      FilterStringValueMissing =
        'Filter value cannot be null or empty for MatchType ''{0}''.'
      FilterValueMissing =
        'Each filter must contain a ''Value'' key.'
      InvalidRegexPattern =
        'Invalid regex for property ''{0}'': {1}'
      InvalidVersionValue =
        'Version operator ''{0}'' requires a valid version string. Got: ''{1}''.'
      InvalidWildcardPattern =
        'Invalid wildcard for property ''{0}'': {1}'
      VersionOperatorWrongProperty =
        'Version operator ''{0}'' is valid only on ''DisplayVersion'', not ''{1}''.'
    }
    Import-LocalizedData `
      -BindingVariable:'Strings' `
      -FileName:'New-CompiledFilter.strings' `
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

    Write-Debug -Message:('[New-CompiledFilter] Exiting Begin')
  }

  Process {
    Write-Debug -Message:('[New-CompiledFilter] Entering Process')

    $StringMatchTypes = @('Simple', 'Wildcard', 'Regex')
    $VersionMatchTypes = @('EQ', 'GT', 'GTE', 'LT', 'LTE')
    $AllMatchTypes = $StringMatchTypes + $VersionMatchTypes
    $InternalOnlyFields = @(
      '_ParsedDisplayVersion',
      '_RegistryHive',
      '_RegistryView',
      '_RegistrySource'
    )

    $RegexOpts = (
      [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor
      [System.Text.RegularExpressions.RegexOptions]::CultureInvariant -bor
      [System.Text.RegularExpressions.RegexOptions]::Compiled
    )

    $Filter | & { Process {
      $Def = $PSItem

      $HasPropertyKey = [System.Boolean]($Def.ContainsKey('Property'))
      $HasUsableProperty = [System.Boolean](
        $HasPropertyKey -eq $True -and
        [System.String]::IsNullOrWhiteSpace([System.String]$Def['Property']) -eq $False
      )
      If ($HasUsableProperty -eq $False) {
        & $ThrowArgumentError `
          $Strings['FilterPropertyMissing'] `
          $Def `
          'NewCompiledFilterPropertyMissing'
      }
      $Property = [System.String]$Def['Property']

      $ContainsNulCharacter = [System.Boolean]($Property.Contains("`0"))
      If ($ContainsNulCharacter -eq $True) {
        & $ThrowArgumentError `
          $Strings['FilterPropertyContainsNul'] `
          $Property `
          'NewCompiledFilterPropertyContainsNul'
      }

      $IsInternalOnlyField = [System.Boolean](
        $InternalOnlyFields -icontains $Property
      )
      If ($IsInternalOnlyField -eq $True) {
        & $ThrowArgumentError `
          ($Strings['FilterPropertyInternalOnly'] -f $Property) `
          $Property `
          'NewCompiledFilterPropertyInternalOnly'
      }

      $HasMatchTypeKey = [System.Boolean]($Def.ContainsKey('MatchType'))
      $HasUsableMatchType = [System.Boolean](
        $HasMatchTypeKey -eq $True -and
        [System.String]::IsNullOrWhiteSpace([System.String]$Def['MatchType']) -eq $False
      )
      If ($HasUsableMatchType -eq $False) {
        & $ThrowArgumentError `
          $Strings['FilterMatchTypeMissing'] `
          $Def `
          'NewCompiledFilterMatchTypeMissing'
      }
      $MatchType = [System.String]$Def['MatchType']

      $IsSupportedMatchType = [System.Boolean](
        $AllMatchTypes -icontains $MatchType
      )
      If ($IsSupportedMatchType -eq $False) {
        & $ThrowArgumentError `
          ($Strings['FilterMatchTypeInvalid'] -f
            ($AllMatchTypes -join ', '),
            $MatchType) `
          $MatchType `
          'NewCompiledFilterMatchTypeInvalid'
      }

      $NormalizedMatchType = [System.String]$MatchType
      Foreach ($KnownMatchType in $AllMatchTypes) {
        $MatchesRequestedType = [System.Boolean](
          $KnownMatchType -ieq $MatchType
        )
        If ($MatchesRequestedType -eq $True) {
          $NormalizedMatchType = [System.String]$KnownMatchType
          Break
        }
      }
      $MatchType = $NormalizedMatchType

      $HasValueKey = [System.Boolean]($Def.ContainsKey('Value'))
      If ($HasValueKey -eq $False) {
        & $ThrowArgumentError `
          $Strings['FilterValueMissing'] `
          $Def `
          'NewCompiledFilterValueMissing'
      }
      $Value = $Def['Value']

      $IsStringMatch = [System.Boolean](
        $StringMatchTypes -icontains $MatchType
      )
      If ($IsStringMatch -eq $True) {
        $IsMissingStringValue = [System.Boolean](
          $Null -eq $Value -or
          [System.String]::IsNullOrEmpty([System.String]$Value)
        )
        If ($IsMissingStringValue -eq $True) {
          & $ThrowArgumentError `
            ($Strings['FilterStringValueMissing'] -f $MatchType) `
            $Value `
            'NewCompiledFilterStringValueMissing'
        }
      }

      $IsVersionOp = [System.Boolean](
        $VersionMatchTypes -icontains $MatchType
      )
      $ParsedVersion = $Null

      If ($IsVersionOp -eq $True) {
        $TargetsDisplayVersion = [System.Boolean](
          $Property -ieq 'DisplayVersion'
        )
        If ($TargetsDisplayVersion -eq $False) {
          & $ThrowArgumentError `
            ($Strings['VersionOperatorWrongProperty'] -f
              $MatchType,
              $Property) `
            $Property `
            'NewCompiledFilterVersionOperatorWrongProperty'
        }

        $HasValidVersion = [System.Boolean](
          [System.Version]::TryParse(
            [System.String]$Value,
            [ref]$ParsedVersion
          )
        )
        If ($HasValidVersion -eq $False) {
          & $ThrowArgumentError `
            ($Strings['InvalidVersionValue'] -f
              $MatchType,
              $Value) `
            $Value `
            'NewCompiledFilterInvalidVersionValue'
        }
      }

      $CompiledWildcard = $Null
      $CompiledRegex = $Null
      $CompiledVersion = $Null

      Switch ($MatchType) {
        'Simple' {
          # Exact string match uses the raw value directly.
        }
        'Wildcard' {
          Try {
            $WildcardOptions = (
              [System.Management.Automation.WildcardOptions]::IgnoreCase -bor
              [System.Management.Automation.WildcardOptions]::CultureInvariant
            )
            $CompiledWildcard = [System.Management.Automation.WildcardPattern]::new(
              [System.String]$Value,
              $WildcardOptions
            )
            $CompiledWildcard | Add-Member `
              -MemberType:'NoteProperty' `
              -Name:'Options' `
              -Value:$WildcardOptions `
              -Force
          } Catch {
            & $ThrowArgumentError `
              ($Strings['InvalidWildcardPattern'] -f
                $Property,
                $PSItem.Exception.Message) `
              $Property `
              'NewCompiledFilterInvalidWildcardPattern'
          }
        }
        'Regex' {
          Try {
            $CompiledRegex = [System.Text.RegularExpressions.Regex]::new(
              [System.String]$Value,
              $RegexOpts
            )
          } Catch {
            & $ThrowArgumentError `
              ($Strings['InvalidRegexPattern'] -f
                $Property,
                $PSItem.Exception.Message) `
              $Property `
              'NewCompiledFilterInvalidRegexPattern'
          }
        }
        Default {
          $CompiledVersion = $ParsedVersion
        }
      }

      Try {
        $CompiledFilter = [StartUninstallerCompiledFilter]::new(
          [System.String]$Property,
          [System.String]$Value,
          [System.String]$MatchType,
          $CompiledWildcard,
          $CompiledRegex,
          $CompiledVersion
        )
        $CompiledFilter.PSObject.TypeNames.Insert(0, 'StartUninstaller.CompiledFilter')
      } Catch {
        $ErrorRecord = New-ErrorRecord `
          -ExceptionName:'System.InvalidOperationException' `
          -ExceptionMessage:(
            $Strings['CompiledFilterCreationFailed'] -f
              $Property,
              $PSItem.Exception.Message
          ) `
          -TargetObject:$Property `
          -ErrorId:'NewCompiledFilterCreationFailed' `
          -ErrorCategory:([System.Management.Automation.ErrorCategory]::InvalidOperation)
        $PSCmdlet.ThrowTerminatingError($ErrorRecord)
      }

      $CompiledFilter
    }}

    Write-Debug -Message:('[New-CompiledFilter] Exiting Process')
  }

  End {
    Write-Debug -Message:('[New-CompiledFilter] Entering End')
    Write-Debug -Message:('[New-CompiledFilter] Exiting End')
  }
}

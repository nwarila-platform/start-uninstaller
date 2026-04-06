#Requires -Version 5.1

Function Test-ApplicationMatch {
  <#
    .SYNOPSIS
      Tests whether an application record satisfies all compiled
      filters using AND logic with short-circuit.

    .DESCRIPTION
      Evaluates each compiled filter against the application
      record properties. Returns `$True` only when every filter
      matches. Property lookups are case-insensitive.

    .PARAMETER Application
      The application record to test.

    .PARAMETER CompiledFilters
      The compiled filters to evaluate.

    .EXAMPLE
      Test-ApplicationMatch `
        -Application:$Application `
        -CompiledFilters:$CompiledFilters

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
    [ValidateNotNull()]
    [System.Management.Automation.PSObject]
    $Application,

    [Parameter(
      Mandatory = $True
      , ParameterSetName = 'Default'
      , DontShow = $False
      , HelpMessage = 'See function help.'
      , ValueFromPipeline = $False
      , ValueFromPipelineByPropertyName = $False
      , ValueFromRemainingArguments = $False
    )]
    [AllowEmptyCollection()]
    [StartUninstallerCompiledFilter[]]
    $CompiledFilters
  )

  Begin {
    Write-Debug -Message:('[Test-ApplicationMatch] Entering Begin')

    $Strings = @{
      FilterEvaluationFailed =
        'Unable to evaluate filter ''{0}'' on property ''{1}'': {2}'
    }
    # --- [ Line Continuation ] ————↴
    Import-LocalizedData `
      -BindingVariable:'Strings' `
      -FileName:'Test-ApplicationMatch.strings' `
      -BaseDirectory:$PSScriptRoot `
      -ErrorAction:'SilentlyContinue'

    Write-Debug -Message:('[Test-ApplicationMatch] Exiting Begin')
  } Process {
    Write-Debug -Message:('[Test-ApplicationMatch] Entering Process')

    $HasNoFilters = [System.Boolean](
      $CompiledFilters.Count -eq 0
    )
    $AllMatched = $True

    If ($HasNoFilters -eq $False) {
      For ($Index = 0;
           $Index -lt $CompiledFilters.Count -and
           $AllMatched -eq $True;
           $Index++) {
        $CompiledFilter = $CompiledFilters[$Index]
        $PropertyValue = $Null
        $PropertyInfo = $Application.PSObject.Properties[
          $CompiledFilter.Property
        ]
        $HasPropertyInfo = [System.Boolean](
          $Null -ne $PropertyInfo
        )
        If ($HasPropertyInfo -eq $True) {
          $PropertyValue = $PropertyInfo.Value
        }

        $IsMatch = $False
        Try {
          Switch ($CompiledFilter.MatchType) {
            'Simple' {
              $HasPropertyValue = [System.Boolean](
                $Null -ne $PropertyValue
              )
              If ($HasPropertyValue -eq $True) {
                $IsMatch = [System.String]::Equals(
                  [System.String]$PropertyValue,
                  $CompiledFilter.Value,
                  [System.StringComparison]::OrdinalIgnoreCase
                )
              }
            }
            'Wildcard' {
              $HasPropertyValue = [System.Boolean](
                $Null -ne $PropertyValue
              )
              If ($HasPropertyValue -eq $True) {
                # --- [ Line Continuation ] ————↴
                $IsMatch = `
                  $CompiledFilter.CompiledWildcard.IsMatch(
                    [System.String]$PropertyValue
                  )
              }
            }
            'Regex' {
              $HasPropertyValue = [System.Boolean](
                $Null -ne $PropertyValue
              )
              If ($HasPropertyValue -eq $True) {
                # --- [ Line Continuation ] ————↴
                $IsMatch = `
                  $CompiledFilter.CompiledRegex.IsMatch(
                    [System.String]$PropertyValue
                  )
              }
            }
            Default {
              $ApplicationVersion = $Null
              $VersionProperty = `
                $Application.PSObject.Properties[
                  '_ParsedDisplayVersion'
                ]
              $HasVersionProperty = [System.Boolean](
                $Null -ne $VersionProperty
              )
              If ($HasVersionProperty -eq $True) {
                $ApplicationVersion = $VersionProperty.Value
              }

              $HasApplicationVersion = [System.Boolean](
                $Null -ne $ApplicationVersion
              )
              If ($HasApplicationVersion -eq $True) {
                # --- [ Line Continuation ] ————↴
                $ComparisonResult = `
                  $ApplicationVersion.CompareTo(
                    $CompiledFilter.CompiledVersion
                  )
                Switch ($CompiledFilter.MatchType) {
                  'EQ' {
                    $IsMatch = ($ComparisonResult -eq 0)
                  }
                  'GT' {
                    $IsMatch = ($ComparisonResult -gt 0)
                  }
                  'GTE' {
                    $IsMatch = ($ComparisonResult -ge 0)
                  }
                  'LT' {
                    $IsMatch = ($ComparisonResult -lt 0)
                  }
                  'LTE' {
                    $IsMatch = ($ComparisonResult -le 0)
                  }
                }
              }
            }
          }
        } Catch {
          # --- [ Line Continuation ] ————↴
          $ErrorRecord = New-ErrorRecord `
            -ExceptionName:'System.InvalidOperationException' `
            -ExceptionMessage:(
              $Strings['FilterEvaluationFailed'] -f
                $CompiledFilter.MatchType,
                $CompiledFilter.Property,
                $PSItem.Exception.Message
            ) `
            -TargetObject:$CompiledFilter `
            -ErrorId:'TestApplicationMatchFailed' `
            -ErrorCategory:(
              [System.Management.Automation.ErrorCategory]::InvalidOperation
            )
          $PSCmdlet.ThrowTerminatingError($ErrorRecord)
        }

        If ($IsMatch -eq $False) {
          $AllMatched = $False
        }
      }
    }

    [System.Boolean]$AllMatched

    Write-Debug -Message:('[Test-ApplicationMatch] Exiting Process')
  } End {
    Write-Debug -Message:('[Test-ApplicationMatch] Entering End')
    Write-Debug -Message:('[Test-ApplicationMatch] Exiting End')
  }
}

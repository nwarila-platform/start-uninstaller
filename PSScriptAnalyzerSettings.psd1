@{
  Severity     = @('Error', 'Warning', 'Information')
  IncludeRules = @('*')
  ExcludeRules = @(
    'PSUseShouldProcessForStateChangingFunctions'
    'PSAvoidUsingWriteHost'
  )
}

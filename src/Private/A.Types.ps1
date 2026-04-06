#Requires -Version 5.1

Class StartUninstallerCompiledFilter {
  [System.String]$Property
  [System.String]$Value
  [System.String]$MatchType
  [System.Management.Automation.WildcardPattern]$CompiledWildcard
  [System.Text.RegularExpressions.Regex]$CompiledRegex
  [System.Version]$CompiledVersion

  StartUninstallerCompiledFilter(
    [System.String]$Property,
    [System.String]$Value,
    [System.String]$MatchType,
    [System.Management.Automation.WildcardPattern]$CompiledWildcard,
    [System.Text.RegularExpressions.Regex]$CompiledRegex,
    [System.Version]$CompiledVersion
  ) {
    $this.Property = $Property
    $this.Value = $Value
    $this.MatchType = $MatchType
    $this.CompiledWildcard = $CompiledWildcard
    $this.CompiledRegex = $CompiledRegex
    $this.CompiledVersion = $CompiledVersion
  }
}

Class StartUninstallerProcessResult {
  [System.String]$Outcome
  [System.Nullable[System.Int32]]$ExitCode
  [System.String]$Message

  StartUninstallerProcessResult(
    [System.String]$Outcome,
    [System.Nullable[System.Int32]]$ExitCode,
    [System.String]$Message
  ) {
    $this.Outcome = $Outcome
    $this.ExitCode = $ExitCode
    $this.Message = $Message
  }
}

Class StartUninstallerRegistryViewDescriptor {
  [System.String]$DisplayRoot
  [Microsoft.Win32.RegistryHive]$Hive
  [System.String]$Path
  [Microsoft.Win32.RegistryView]$View
  [System.String]$Source
  [System.String]$InstallScope
  [System.String]$UserSid
  [System.String]$UserName
  [System.String]$UserIdentityStatus

  StartUninstallerRegistryViewDescriptor(
    [System.String]$DisplayRoot,
    [Microsoft.Win32.RegistryHive]$Hive,
    [System.String]$Path,
    [Microsoft.Win32.RegistryView]$View,
    [System.String]$Source,
    [System.String]$InstallScope,
    [System.String]$UserSid,
    [System.String]$UserName,
    [System.String]$UserIdentityStatus
  ) {
    $this.DisplayRoot = $DisplayRoot
    $this.Hive = $Hive
    $this.Path = $Path
    $this.View = $View
    $this.Source = $Source
    $this.InstallScope = $InstallScope
    $this.UserSid = $UserSid
    $this.UserName = $UserName
    $this.UserIdentityStatus = $UserIdentityStatus
  }
}

Class StartUninstallerRunResult {
  [System.Int32]$ExitCode
  [System.String[]]$Lines

  StartUninstallerRunResult(
    [System.Int32]$ExitCode,
    [System.String[]]$Lines
  ) {
    $this.ExitCode = $ExitCode
    $this.Lines = $Lines
  }
}

Class StartUninstallerUninstallCommand {
  [System.String]$FileName
  [System.String]$Arguments

  StartUninstallerUninstallCommand(
    [System.String]$FileName,
    [System.String]$Arguments
  ) {
    $this.FileName = $FileName
    $this.Arguments = $Arguments
  }
}

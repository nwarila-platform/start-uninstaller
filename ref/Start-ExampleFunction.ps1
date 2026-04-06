# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                   POWERSHELL FUNCTION REFERENCE TEMPLATE                   ║
# ║                                                                            ║
# ║  This document is the authoritative reference for how all PowerShell       ║
# ║  functions in this repository MUST be written. Every convention shown      ║
# ║  here is intentional and REQUIRED unless explicitly noted as optional.     ║
# ║                                                                            ║
# ║  PHILOSOPHY:                                                               ║
# ║    1. READABLE    — A non-programmer should be able to follow the logic    ║
# ║    2. SAFE        — Defend against PowerShell's implicit behaviors           ║
# ║    3. RELIABLE    — Consistent results across runs, sessions, and users      ║
# ║    4. DEBUGGABLE  — Every value inspectable, every transition traceable      ║
# ║    5. PERFORMANT  — But never at the expense of 1-4                          ║
# ║                                                                              ║
# ║  These rules were developed over years of production experience.             ║
# ║  They exist because each one prevented a real bug or confusion.              ║
# ╚══════════════════════════════════════════════════════════════════════════════╝


# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ STYLE GUIDE COMPLIANCE                                                     │
# │                                                                            │
# │ All code in this repo MUST strictly follow:                                │
# │   1. The PowerShell Practice and Style Guide (PoshCode/PowerShellPractice  │
# │      AndStyle) as the baseline                                             │
# │   2. One True Brace Style (OTBS) for all brace placement                  │
# │   3. PSScriptAnalyzer — all code MUST pass with zero warnings/errors       │
# │   4. The additional rules in THIS document, which take precedence          │
# │      over the general style guide where they differ                        │
# │                                                                            │
# │ POWERSHELL VERSION:                                                        │
# │   All code MUST baseline PowerShell 5.1, which is the default on all      │
# │   officially supported Microsoft operating systems. PS 7+ features        │
# │   (e.g., ternary operator, null-coalescing, pipeline chain operators,     │
# │   [System.Management.Automation.ActionPreference]::Break) MUST NOT be     │
# │   used unless explicitly guarded with a version check. Every script       │
# │   MUST include: #Requires -Version 5.1                                    │
# │                                                                            │
# │ When in doubt, the rule is: be MORE explicit, not less.                    │
# └──────────────────────────────────────────────────────────────────────────────┘


# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ FORMATTING RULES (apply to ALL code in this repo)                          │
# │                                                                            │
# │ INDENTATION:                                                               │
# │   - 2 spaces per indent level. NEVER tabs.                                │
# │   - Rationale: 2 spaces keeps deeply nested blocks readable within the    │
# │     96-character line limit.                                               │
# │                                                                            │
# │ LINE LENGTH:                                                               │
# │   - Maximum 96 characters per line, STRICTLY ENFORCED.                     │
# │   - This applies to EVERYTHING: code, comments, strings, box-comments.    │
# │   - When a line exceeds 96 characters, use backtick (`) line              │
# │     continuation with the visual indicator comment:                        │
# │       # --- [ Line Continuation ] ————↴                                   │
# │   - Align continued parameters vertically for readability.                 │
# │                                                                            │
# │ BRACE PLACEMENT — ONE TRUE BRACE STYLE (OTBS):                            │
# │   OTBS is strictly enforced. The rules are:                                │
# │                                                                            │
# │   Opening brace: ALWAYS on the same line as the keyword                    │
# │       If (...) {        (not: If (...) \n {)                              │
# │       Try {             (not: Try \n {)                                   │
# │       Function Foo {    (not: Function Foo \n {)                          │
# │       Begin {           (not: Begin \n {)                                 │
# │                                                                            │
# │   Closing brace + continuation: ALWAYS on the same line                    │
# │       } Else {          (not: } \n Else {)                                │
# │       } ElseIf (...) {  (not: } \n ElseIf (...) {)                       │
# │       } Process {       (not: } \n Process {)                             │
# │       } Catch {         (not: } \n Catch {)                               │
# │       } Finally {       (not: } \n Finally {)                             │
# │                                                                            │
# │   Closing brace: alone on its own line (at the indent of the keyword)     │
# │       }                 (at the same indent as If/Try/Function/etc.)      │
# │                                                                            │
# │   WHY OTBS:                                                                │
# │     - Reduces vertical space consumption (critical with 96-char lines)    │
# │     - Makes control flow visually obvious — the brace placement shows     │
# │       that } Else { is a continuation, not a new statement                │
# │     - Industry standard for PowerShell (PSScriptAnalyzer default)         │
# │                                                                            │
# │ CASING:                                                                    │
# │   Keywords:   PascalCase — If, ElseIf, Else, Try, Catch, Finally,        │
# │               ForEach-Object, Where-Object, Begin, Process, End,          │
# │               Function, Param, Return, Throw, Switch, While, Do          │
# │   Cmdlets:    PascalCase matching canonical casing from Get-Command       │
# │               Write-Debug, Set-Variable, New-Object, Get-ChildItem       │
# │               NEVER: write-debug, set-variable, get-childitem            │
# │   Variables:  PascalCase — $FileExists, $UpdateFileInfo, $Result          │
# │               NEVER: $fileexists, $updatefileinfo, $result               │
# │   Parameters: PascalCase — -Name, -Value, -Force, -ErrorAction           │
# │   .NET Types: Exact casing from documentation                             │
# │               [System.Boolean], [System.IO.FileInfo]                      │
# │   Constants:  $True, $False, $Null (PascalCase, as defined by PS)        │
# │                                                                            │
# │   WHY: PowerShell is case-INSENSITIVE, but consistent PascalCase is      │
# │   required for readability and professionalism. A reviewer should never   │
# │   have to wonder if two differently-cased references are the same thing.  │
# │                                                                            │
# │ OPERATOR SPACING:                                                          │
# │   - ALWAYS one space on each side of operators:                           │
# │       $X -eq $True       (not: $X-eq$True or $X -eq$True)               │
# │       $A -and $B         (not: $A-and$B)                                  │
# │       $X = 5             (not: $X=5)                                      │
# │   - ALWAYS one space after commas in lists:                               │
# │       'A', 'B', 'C'     (not: 'A','B','C')                              │
# │   - NO space between parameter name and colon-bound value:               │
# │       -Name:'Value'      (not: -Name: 'Value' or -Name : 'Value')       │
# │                                                                            │
# │ SEMICOLONS:                                                                │
# │   - NEVER use semicolons to separate statements on a single line.         │
# │     Every statement gets its own line.                                     │
# │       Set-Variable -Name:'A' -Value:1                                     │
# │       Set-Variable -Name:'B' -Value:2                                     │
# │     NEVER: Set-Variable -Name:'A' -Value:1; Set-Variable -Name:'B'...    │
# │   WHY: One statement per line is easier to read, debug (breakpoints),     │
# │   and produces cleaner diffs in version control.                          │
# │                                                                            │
# │ NAMED PARAMETERS ONLY:                                                     │
# │   - ALWAYS use named parameters. NEVER pass positional/unnamed args.      │
# │       Get-ChildItem -Path:'C:\Temp'   (NEVER: Get-ChildItem 'C:\Temp')   │
# │       Copy-Item -Path:'A' -Destination:'B'  (NEVER: Copy-Item 'A' 'B')   │
# │   WHY: Positional arguments are ambiguous — a reviewer must know the     │
# │   parameter order by heart. Named parameters are self-documenting and    │
# │   combine with colon-binding to eliminate all parsing ambiguity.          │
# │                                                                            │
# │ ALIASES & SHORTHAND:                                                       │
# │   - NEVER use cmdlet aliases. Always use the full cmdlet name.            │
# │       Where-Object      (NEVER: ?  or where)                              │
# │       Select-Object     (NEVER: select)                                   │
# │       Measure-Object    (NEVER: measure)                                  │
# │       Format-Table      (NEVER: ft)                                       │
# │       Format-List       (NEVER: fl)                                       │
# │       Get-ChildItem     (NEVER: ls, dir, gci)                             │
# │       Set-Location      (NEVER: cd, sl)                                   │
# │       Write-Output      (NEVER: echo)                                     │
# │   - NEVER use $_ — ALWAYS use $PSItem                                     │
# │     $_ is a shorthand alias that is opaque to non-PowerShell readers.     │
# │     $PSItem is self-documenting and reads clearly as "the current item    │
# │     in the pipeline."                                                     │
# │   WHY: Aliases are not guaranteed across platforms or sessions, are       │
# │   opaque to non-PowerShell readers, and PSScriptAnalyzer flags them.     │
# │                                                                            │
# │ BACKTICK RULES:                                                            │
# │   - Escape sequences (ARE allowed): `n `t `r `0                          │
# │     These are universally understood across programming languages and     │
# │     are MORE readable than .NET equivalents ([System.Char]9 is cryptic). │
# │   - Line continuation (requires visual indicator):                        │
# │     The backtick at end-of-line is nearly invisible in many fonts.        │
# │     ALWAYS add the indicator comment above continued lines:               │
# │       # --- [ Line Continuation ] ————↴                                  │
# │                                                                            │
# │ BLANK LINES:                                                               │
# │   - ONE blank line between logical sections within a block                │
# │   - TWO blank lines between major sections (e.g., between Begin and      │
# │     the Process block header comment)                                     │
# │   - NO trailing blank lines at end of file                                │
# │   - NO multiple consecutive blank lines (max 2)                           │
# │                                                                            │
# │ COMMENTS:                                                                  │
# │   - Always '# ' with a space after the hash: # This is a comment         │
# │     NEVER: #This is a comment (no space)                                  │
# │   - Inline end-of-line comments: use sparingly, for SHORT clarifications  │
# │     that don't warrant their own line (e.g., parameter descriptions in    │
# │     CmdletBinding). Always 2+ spaces before the #:                       │
# │       , ConfirmImpact = 'Low'  # Threshold for -Confirm prompts          │
# │   - Block documentation: use the box-comment style shown throughout       │
# │     this file for section headers and rule explanations                   │
# │   - NEVER commented-out code in committed files — delete it.              │
# │     Version control preserves history.                                    │
# │                                                                            │
# │ FILE ORGANIZATION:                                                         │
# │   - One function per file.                                                │
# │   - File named after the function: Start-ExampleFunction.ps1              │
# │   - Every function file MUST have a companion localized string data       │
# │     file: <FunctionName>.strings.psd1 (in the same directory)            │
# │                                                                            │
# │ COMPANION FILES (same directory):                                          │
# │   Start-ExampleFunction.ps1              — Function code                  │
# │   Start-ExampleFunction.strings.psd1     — Error message strings          │
# └──────────────────────────────────────────────────────────────────────────────┘


# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ FUNCTION DECLARATION                                                       │
# │                                                                            │
# │ Every function MUST be wrapped in a named Function block.                  │
# │ This provides a clear boundary, enables dot-sourcing, and allows the       │
# │ function to be imported into modules cleanly.                              │
# │                                                                            │
# │ NAMING:                                                                    │
# │   - MUST use an approved verb from Get-Verb (e.g., Start, Get, Set,       │
# │     New, Remove, Test, Invoke — run Get-Verb for the full list).           │
# │   - Format: Verb-Noun in PascalCase.                                      │
# │   - The noun should be specific and descriptive.                           │
# └──────────────────────────────────────────────────────────────────────────────┘
Function Start-ExampleFunction {

  # ┌──────────────────────────────────────────────────────────────────────────┐
  # │ COMMENT-BASED HELP                                                      │
  # │                                                                         │
  # │ REQUIRED on every function. Powers Get-Help and serves as inline        │
  # │ documentation. Every function MUST include at minimum:                  │
  # │   .SYNOPSIS    — One-line summary of what the function does             │
  # │   .DESCRIPTION — Detailed explanation of behavior and intent            │
  # │   .PARAMETER   — One entry per parameter with clear description         │
  # │   .EXAMPLE     — At least one usage example                             │
  # │   .OUTPUTS     — What type(s) the function emits to the pipeline        │
  # │   .NOTES       — Author, version, changelog, or other metadata          │
  # └──────────────────────────────────────────────────────────────────────────┘
  <#
    .SYNOPSIS
      Validates whether a WSUS update file on disk matches the
      expected metadata.

    .DESCRIPTION
      Compares a local file (represented as [System.IO.FileInfo])
      against a WSUS update file record (represented as
      [Microsoft.UpdateServices.Administration.UpdateFile]).

      Checks are performed in order of cost:
        1. File existence (cheapest — property lookup)
        2. File size match (cheap — integer comparison)
        3. File hash match (expensive — only if 1 and 2 pass)

      Returns [System.Boolean] indicating whether all checks passed.

    .PARAMETER UpdateFileInfo
      The [System.IO.FileInfo] object representing the file on disk.
      This is the local file that will be validated against the
      expected metadata.

    .PARAMETER UpdateFile
      The [Microsoft.UpdateServices.Administration.UpdateFile] object
      containing the expected metadata (file size, hash) from the
      WSUS server.

    .EXAMPLE
      # --- [ Line Continuation ] ————↴
      Start-ExampleFunction                                        `
        -UpdateFileInfo:(Get-Item -Path:'C:\Updates\file.cab')     `
        -UpdateFile:$WsusFile

    .OUTPUTS
      [System.Boolean]

    .NOTES
      Author  : HellBomb
      Version : 1.0.0
  #>


  # ┌──────────────────────────────────────────────────────────────────────────┐
  # │ [CmdletBinding()] — ADVANCED FUNCTION ATTRIBUTE                        │
  # │                                                                         │
  # │ REQUIRED on every function. Makes the function behave like a compiled   │
  # │ cmdlet, enabling: -Verbose, -Debug, -ErrorAction, -WhatIf, -Confirm,   │
  # │ and other common parameters automatically.                              │
  # │                                                                         │
  # │ SYNTAX RULE — LEADING COMMAS:                                           │
  # │   Every property line starts with a comma. The first line inside the    │
  # │   attribute is intentionally blank with just a comma. This allows ANY   │
  # │   line — including the first real property — to be commented out with   │
  # │   just a '#' prefix. No trailing-comma management needed. This is a    │
  # │   diff-friendly pattern that makes editing fast.                        │
  # │                                                                         │
  # │ COMPLETENESS RULE:                                                      │
  # │   List ALL properties explicitly — same rule as [Parameter()].          │
  # │   A reviewer should see every property's value at a glance,             │
  # │   not wonder what the defaults are.                                     │
  # │                                                                         │
  # │ NOTE — PositionalBinding:                                               │
  # │   ALWAYS $False. We require all parameters to be passed by name with   │
  # │   colon-binding. Positional args are prohibited, so PositionalBinding   │
  # │   must be disabled at the API level to enforce this.                    │
  # └──────────────────────────────────────────────────────────────────────────┘
  [CmdletBinding(
    , ConfirmImpact = 'Low'
    , DefaultParameterSetName = 'Default'
    , HelpURI = 'https://example.com/help'
    , PositionalBinding = $False
    , RemotingCapability = 'PowerShell'
    , SupportsPaging = $True
    , SupportsShouldProcess = $True
  )]


  # ┌──────────────────────────────────────────────────────────────────────────┐
  # │ [OutputType()] — RETURN TYPE DECLARATION                               │
  # │                                                                         │
  # │ REQUIRED on every function. Declares what .NET type(s) the function    │
  # │ emits to the pipeline. Completes the type contract:                     │
  # │   - Input types → declared on parameters                               │
  # │   - Output types → declared here                                       │
  # │                                                                         │
  # │ Does NOT enforce at runtime — it is a contract for code reviewers,      │
  # │ tooling (IntelliSense, PSScriptAnalyzer), and downstream consumers.    │
  # │ Always use the full .NET type name.                                     │
  # └──────────────────────────────────────────────────────────────────────────┘
  [OutputType([System.Boolean])]


  # ┌──────────────────────────────────────────────────────────────────────────┐
  # │ Param() — PARAMETER BLOCK                                              │
  # │                                                                         │
  # │ All parameters MUST be declared inside Param() — never as function     │
  # │ arguments (e.g., NOT: Function Foo($x, $y) { }).                       │
  # │                                                                         │
  # │ STRUCTURE PER PARAMETER (in order):                                     │
  # │   1. [Parameter()] attribute    — Behavior flags (leading-comma style)  │
  # │   2. [Validate*()] attribute(s) — Input validation (see below)         │
  # │   3. [TypeName] cast            — Explicit .NET type (NEVER aliases)    │
  # │   4. $VariableName              — PascalCase, descriptive name          │
  # │                                                                         │
  # │ TYPE RULES — Full .NET type names ONLY:                                 │
  # │   [System.String]    not [string]     [System.Int32]    not [int]       │
  # │   [System.Boolean]   not [bool]       [System.Int64]    not [long]      │
  # │   [System.Array]     not [array]      [System.Object]   not [object]    │
  # │   PowerShell type aliases can trigger implicit type coercion.           │
  # │   Full .NET names are unambiguous, searchable, and self-documenting.    │
  # │                                                                         │
  # │ QUOTING RULES:                                                          │
  # │   - ALWAYS single quotes for string literals: 'Default' not "Default"   │
  # │   - Single quotes prevent accidental variable expansion.                │
  # │   - Only use double quotes when you INTENTIONALLY need interpolation.   │
  # │                                                                         │
  # │ PARAMETER ATTRIBUTE RULES:                                              │
  # │   - Same leading-comma pattern as [CmdletBinding()].                    │
  # │   - List ALL properties explicitly, even when using the default value.  │
  # │     A reviewer can see a value is False by design, not by omission.     │
  # │                                                                         │
  # │ BOOLEAN vs SWITCH PARAMETERS:                                           │
  # │   - Prefer [System.Boolean] over [Switch] for flag-style parameters.   │
  # │   - [Switch] has implicit truthy behavior that can surprise reviewers.  │
  # │   - [System.Boolean] requires an explicit $True or $False value,        │
  # │     which is consistent with our "explicit over implicit" philosophy.   │
  # │                                                                         │
  # │ VALIDATION RULES:                                                       │
  # │   - Use built-in validators to the maximum extent:                      │
  # │       [ValidateNotNull()]           — Rejects $Null                     │
  # │       [ValidateNotNullOrEmpty()]    — Rejects $Null and empty           │
  # │       [ValidateSet('A','B','C')]    — Restricts to enumerated values    │
  # │       [ValidateRange(1, 100)]       — Restricts numeric range           │
  # │       [ValidatePattern('^[A-Z]+$')] — Regex validation                  │
  # │       [ValidateLength(1, 255)]      — String length bounds              │
  # │       [ValidateCount(1, 10)]        — Collection size bounds            │
  # │   - AVOID [ValidateScript({})] — it produces messy, hard-to-read       │
  # │     code. If validation is too complex for a built-in validator,        │
  # │     perform it explicitly in the Process block with clear error         │
  # │     reporting via New-ErrorRecord.                                      │
  # └──────────────────────────────────────────────────────────────────────────┘
  Param (
    [Parameter(
      , DontShow = $False
      , HelpMessage = 'The file info object for the local file.'
      , HelpMessageBaseName = 'ExampleFunction'
      , HelpMessageResourceId = 'UpdateFileInfoHelpMessage'
      , Mandatory = $True
      , ParameterSetName = 'Default'
      , Position = 0
      , ValueFromPipeline = $True
      , ValueFromPipelineByPropertyName = $True
      , ValueFromRemainingArguments = $False
    )]
    [ValidateNotNullOrEmpty()]
    [System.IO.FileInfo]
    $UpdateFileInfo,

    [Parameter(
      , DontShow = $False
      , HelpMessage = 'The WSUS update file metadata object.'
      , HelpMessageBaseName = 'ExampleFunction'
      , HelpMessageResourceId = 'UpdateFileHelpMessage'
      , Mandatory = $True
      , ParameterSetName = 'Default'
      , Position = 1
      , ValueFromPipeline = $True
      , ValueFromPipelineByPropertyName = $True
      , ValueFromRemainingArguments = $False
    )]
    [ValidateNotNullOrEmpty()]
    [Microsoft.UpdateServices.Administration.UpdateFile]
    $UpdateFile
  )


  # ╔════════════════════════════════════════════════════════════════════════╗
  # ║ BEGIN BLOCK                                                          ║
  # ║                                                                      ║
  # ║ Runs ONCE before any pipeline input is processed.                    ║
  # ║ Use for: variable declaration, one-time setup, resource acquisition. ║
  # ║ NEVER put per-item logic here.                                       ║
  # ║                                                                      ║
  # ║ ALL functions MUST use Begin/Process/End — even when pipeline input  ║
  # ║ is not expected. This is structural normalization.                    ║
  # ╚════════════════════════════════════════════════════════════════════════╝
  Begin {
    Write-Debug -Message:'[Start-ExampleFunction] Entering Block: Begin'

    # ┌──────────────────────────────────────────────────────────────────────┐
    # │ VARIABLE DECLARATION                                               │
    # │                                                                     │
    # │ ALL variables used in this function MUST be declared here in Begin. │
    # │ This serves as a manifest of every variable the function touches.   │
    # │                                                                     │
    # │ WHY New-Variable INSTEAD OF $Var = $Value:                          │
    # │   - Enables -Verbose tracing of variable creation                   │
    # │   - Allows explicit scope control via -Option:('Private')          │
    # │   - Makes every variable operation auditable and searchable         │
    # │   - Prevents accidental creation in a parent scope                  │
    # │                                                                     │
    # │ WHY -Option:('Private'):                                            │
    # │   - Restricts visibility to THIS function only                      │
    # │   - Prevents child scopes from inheriting/modifying these values    │
    # │   - Prevents variable "leaking" into the session during dev         │
    # │                                                                     │
    # │ WHY -Force:                                                         │
    # │   - Safe re-execution during development without errors             │
    # │   - If variable exists from a previous run, overwrites cleanly      │
    # │                                                                     │
    # │ WHY -Value:$Null:                                                   │
    # │   - Separates declaration from assignment — both operations are     │
    # │     independently visible and traceable                            │
    # │                                                                     │
    # │ WHY parentheses around -Option:('Private'):                         │
    # │   - NORMALIZATION: Multi-value options require ('Private','ReadOnly')│
    # │     Using parens even for single values keeps syntax consistent.    │
    # │                                                                     │
    # │ NAMING:                                                             │
    # │   - PascalCase for all variable names                               │
    # │   - Every reference MUST match the casing declared here             │
    # │     ($Result not $result — PS is case-insensitive but consistent    │
    # │     casing is required for readability and professionalism)         │
    # │                                                                     │
    # │ COLON-BOUND PARAMETERS (applies EVERYWHERE, not just here):        │
    # │   - ALWAYS bind with colon: -Name:'Value'                          │
    # │   - NEVER use space-separated: -Name 'Value'                       │
    # │   - Colon eliminates parsing ambiguity — PowerShell can            │
    # │     misinterpret space-separated values as positional arguments     │
    # │     to a different parameter.                                       │
    # └──────────────────────────────────────────────────────────────────────┘

    # ┌──────────────────────────────────────────────────────────────────────┐
    # │ LOCALIZED STRING DATA — Import-LocalizedData                      │
    # │                                                                     │
    # │ REQUIRED: Every function MUST load its companion .strings.psd1     │
    # │ file in the Begin block. This is the DSC-inspired pattern for      │
    # │ centralizing all user-facing error messages.                        │
    # │                                                                     │
    # │ WHY Import-LocalizedData:                                           │
    # │   - Built-in PowerShell mechanism — used by Microsoft across all   │
    # │     their modules (DSC, Az, etc.)                                  │
    # │   - Most professional approach for string management               │
    # │   - Supports future localization if ever needed                     │
    # │   - Centralizes error messages outside business logic for easy      │
    # │     review and auditing                                            │
    # │                                                                     │
    # │ WHY a separate .strings.psd1 per function file:                    │
    # │   - Clean segmentation — each function owns its messages           │
    # │   - During build, per-file string files can be compiled/merged     │
    # │     into a single module-level resource                            │
    # │   - Easier code review — messages and logic change independently   │
    # │                                                                     │
    # │ WHAT goes in .strings.psd1:                                        │
    # │   - ALL user-facing messages: error messages (New-ErrorRecord)     │
    # │     AND warning messages (Write-Warning)                           │
    # │   - NOT debug or verbose messages (those are developer diagnostics │
    # │     and stay inline — they aren't viewed by end users/operators)   │
    # │                                                                     │
    # │ WHY -BindingVariable (not -BaseDirectory alone):                   │
    # │   - Loads the string data into a named variable we control          │
    # │   - The variable name 'Strings' is the standard across this repo   │
    # │                                                                     │
    # │ WHY -FileName without .psd1 extension:                             │
    # │   - Import-LocalizedData appends .psd1 automatically               │
    # │   - Matches the companion file naming: <FunctionName>.strings      │
    # └──────────────────────────────────────────────────────────────────────┘
    # --- [ Line Continuation ] ————↴
    Import-LocalizedData                                           `
      -BindingVariable:'Strings'                                   `
      -FileName:'Start-ExampleFunction.strings'                    `
      -BaseDirectory:$PSScriptRoot
    # NOTE: Import-LocalizedData is the ONE exception to the
    # New-Variable rule. It creates its own variable via
    # -BindingVariable. The variable MUST still be included in
    # Remove-Variable (End block) for cleanup, but is NOT included
    # in Clear-Variable (Process block) because it is STATIC —
    # the same string data applies to all pipeline items.

    # DYNAMIC variables — value changes per pipeline item
    New-Variable -Force -Name:'FileExists'      -Option:('Private') -Value:$Null
    New-Variable -Force -Name:'FileHashMatches' -Option:('Private') -Value:$Null
    New-Variable -Force -Name:'FileSizeMatches' -Option:('Private') -Value:$Null
    New-Variable -Force -Name:'Result'          -Option:('Private') -Value:$Null

    # STATIC variables — value set once, never changes.
    # Use ('Private','ReadOnly') to prevent accidental modification.
    # Example:
    #   New-Variable -Force -Name:'MaxRetries' -Option:('Private','ReadOnly') -Value:([System.Int32](3))

    Write-Debug -Message:'[Start-ExampleFunction] Leaving Block: Begin'
  }


  # ╔════════════════════════════════════════════════════════════════════════╗
  # ║ PROCESS BLOCK                                                        ║
  # ║                                                                      ║
  # ║ Runs ONCE PER PIPELINE ITEM. If called without pipeline input, runs  ║
  # ║ exactly once. ALL business logic goes here.                          ║
  # ║                                                                      ║
  # ║ RULES:                                                               ║
  # ║   - Pre-evaluate conditions into explicitly typed variables          ║
  # ║   - Use those variables in If blocks                                 ║
  # ║   - Emit results to the pipeline (do NOT use 'return')              ║
  # ║   - Wrap any cmdlet that can fail in Try/Catch/Finally              ║
  # ╚════════════════════════════════════════════════════════════════════════╝
  Process {
    Write-Debug -Message:'[Start-ExampleFunction] Entering Block: Process'

    # ┌──────────────────────────────────────────────────────────────────────┐
    # │ CLEAR VARIABLES AT TOP OF PROCESS                                  │
    # │                                                                     │
    # │ REQUIRED: Prevents "bleed" where a value from the previous          │
    # │ pipeline item leaks into the current iteration.                     │
    # │                                                                     │
    # │ The variable names here MUST match the DYNAMIC variables in Begin.  │
    # │ (New-Variable, Clear-Variable, and Remove-Variable lists are        │
    # │ cross-references of each other.)                                    │
    # │                                                                     │
    # │ WHY -ErrorAction:'SilentlyContinue':                                │
    # │   - If a variable was never assigned (e.g., early exit), Clear      │
    # │     would throw. SilentlyContinue safely ignores that case.         │
    # └──────────────────────────────────────────────────────────────────────┘
    Clear-Variable -Force -ErrorAction:'SilentlyContinue' -Name:([System.Array](
      'FileExists', 'FileHashMatches', 'FileSizeMatches', 'Result'
    ))


    # ┌──────────────────────────────────────────────────────────────────────┐
    # │ OUTPUT STREAM RULES                                                │
    # │                                                                     │
    # │ PowerShell has multiple output streams. Each has a specific purpose:│
    # │                                                                     │
    # │ Write-Debug      Internal tracing (entry/exit, variable states).   │
    # │                  Only visible with -Debug. Used for developer-level │
    # │                  diagnostics that would be noise during normal use. │
    # │                                                                     │
    # │ Write-Verbose    Operational progress messages for the user.        │
    # │                  Visible with -Verbose. Used to communicate         │
    # │                  "what is happening now" at a high level.           │
    # │                  Example: 'Checking file: C:\Updates\file.cab'      │
    # │                                                                     │
    # │ Write-Warning    Non-fatal problems that need attention but do not  │
    # │                  stop execution. Always visible, yellow text.       │
    # │                  Example: 'File size is 0 bytes, skipping hash'    │
    # │                                                                     │
    # │ Write-Error      Non-terminating errors — use ONLY via              │
    # │                  New-ErrorRecord. NEVER use Write-Error directly    │
    # │                  with a bare string message.                        │
    # │                                                                     │
    # │ Write-Information  Structured log data (PS 5.1+). Capturable via   │
    # │                  -InformationAction or the 6> stream redirect.     │
    # │                  Use when the message is data, not human text.     │
    # │                                                                     │
    # │ NEVER USE:                                                          │
    # │   Write-Host     Cannot be captured, redirected, or suppressed.    │
    # │                  Bypasses all streams. ONLY acceptable in top-level │
    # │                  interactive scripts, NEVER in functions.           │
    # │   Write-Output   Redundant — just place the variable on its own    │
    # │                  line to emit to the pipeline (see "soft return").  │
    # │   'return'       Immediately exits the function, skipping cleanup  │
    # │                  and debug messages. Use pipeline emission instead. │
    # └──────────────────────────────────────────────────────────────────────┘


    # ┌──────────────────────────────────────────────────────────────────────┐
    # │ PRE-EVALUATE CONDITIONS INTO TYPED VARIABLES                       │
    # │                                                                     │
    # │ RULE: NEVER put complex expressions inside If() conditions.         │
    # │ Evaluate each condition into an explicitly typed variable BEFORE    │
    # │ the If block.                                                       │
    # │                                                                     │
    # │ WHY:                                                                │
    # │   1. READABILITY — The If reads like plain English:                 │
    # │      "If FileExists equals True and FileSizeMatches equals True"   │
    # │   2. DEBUGGABILITY — Breakpoint on the If line, inspect all        │
    # │      pre-evaluated variables at a glance                           │
    # │   3. NO SIDE EFFECTS — Conditions are pure value lookups           │
    # │                                                                     │
    # │ WHY explicit [System.Boolean] cast:                                │
    # │   - Makes intent unmistakable even when the expression already      │
    # │     returns bool                                                    │
    # │   - Guards against edge cases (e.g., array comparison returns      │
    # │     matching elements, not bool)                                    │
    # │   - A small amount of "noise" is acceptable for safety             │
    # └──────────────────────────────────────────────────────────────────────┘

    # ── Verbose: Tell the user what we're doing ──────────────────────────
    Write-Verbose -Message:(
      '[Start-ExampleFunction] Validating file: {0}' -f
        $UpdateFileInfo.FullName
    )

    # ┌──────────────────────────────────────────────────────────────────────┐
    # │ STRING FORMATTING RULES                                            │
    # │                                                                     │
    # │ When building strings with variable data, use the format operator   │
    # │ (-f) or [System.String]::Format(). NEVER use double-quoted string  │
    # │ interpolation ("Value is $Var" or "Value is $($Var.Prop)").        │
    # │                                                                     │
    # │ WHY:                                                                │
    # │   - Format operator keeps the template and values visually         │
    # │     separated, making both easier to read and review               │
    # │   - No risk of accidental variable expansion                       │
    # │   - Consistent with the single-quote-by-default rule               │
    # │                                                                     │
    # │ STANDARD FORM — the -f (format) operator:                           │
    # │   'Checking {0}' -f $Var                                           │
    # │   'File {0} is {1} bytes' -f $Name, $Size                          │
    # │                                                                     │
    # │ WHY -f over [System.String]::Format():                              │
    # │   - Both are functionally identical (-f IS String.Format)           │
    # │   - -f is more concise without sacrificing readability              │
    # │   - Keeps lines shorter (critical with 96-char limit)               │
    # │   - More PowerShell-idiomatic                                       │
    # │                                                                     │
    # │ HERE-STRINGS:                                                       │
    # │   - Same single-vs-double rule: @' '@ by default                  │
    # │   - Only use @" "@ when interpolation is explicitly needed         │
    # └──────────────────────────────────────────────────────────────────────┘

    # CHECK 1: Does the file exist on disk?
    Set-Variable -Name:'FileExists' -Value:(
      [System.Boolean](
        $UpdateFileInfo.Exists
      )
    )

    # CHECK 2: Does the file size match?
    # .Length returns 0 for non-existent files — it does NOT throw.
    # Checked before hash because size comparison is O(1), hashing is O(n).
    Set-Variable -Name:'FileSizeMatches' -Value:(
      [System.Boolean](
        $UpdateFileInfo.Length -eq $UpdateFile.FileSize
      )
    )


    # ┌──────────────────────────────────────────────────────────────────────┐
    # │ CONDITIONAL LOGIC RULES                                            │
    # │                                                                     │
    # │ EXPLICIT BOOL COMPARISON:                                           │
    # │   ALWAYS: ($Var -eq $True)     NEVER: ($Var)                       │
    # │   ALWAYS: ($Var -eq $False)    NEVER: (-not $Var) or (!$Var)       │
    # │   This reads as plain English and prevents truthy/falsy gotchas    │
    # │   where non-null objects, non-zero numbers, or non-empty strings   │
    # │   silently evaluate as "true".                                     │
    # │                                                                     │
    # │ NULL CHECK ORDERING:                                                │
    # │   ALWAYS: ($Null -eq $Var)     NEVER: ($Var -eq $Null)             │
    # │   PowerShell GOTCHA: If $Var is an array, ($Var -eq $Null) returns │
    # │   the NULL ELEMENTS of the array — not a boolean! Putting $Null    │
    # │   on the LEFT side forces a scalar comparison that always returns  │
    # │   [System.Boolean].                                                │
    # │                                                                     │
    # │ SUB-CONDITION WRAPPING:                                             │
    # │   Each sub-condition MUST be in its own parentheses:               │
    # │     ($A -eq $True) -and ($B -eq $True)                             │
    # │   NEVER: $A -eq $True -and $B -eq $True                           │
    # │                                                                     │
    # │ OPERATORS:                                                          │
    # │   Use -and / -or / -not (NEVER && or || or ! which behave          │
    # │   differently in PowerShell).                                      │
    # └──────────────────────────────────────────────────────────────────────┘

    # CHECK 3: File hash (EXPENSIVE — gated behind cheaper checks)
    If (($FileExists -eq $True) -and ($FileSizeMatches -eq $True)) {

      # ┌────────────────────────────────────────────────────────────────────┐
      # │ ERROR HANDLING — Try/Catch/Finally                                │
      # │                                                                   │
      # │ RULE: Wrap ANY cmdlet that can fail in Try/Catch/Finally.         │
      # │                                                                   │
      # │ -ErrorAction:'Stop' is set globally by the script template, so    │
      # │ non-terminating errors are automatically promoted to terminating  │
      # │ errors that trigger Catch blocks. No need to set it per-cmdlet.  │
      # │                                                                   │
      # │ CATCH BLOCKS:                                                     │
      # │   - Use fully qualified .NET exception types when you need to     │
      # │     handle specific errors differently:                          │
      # │       Catch [System.IO.IOException] { ... }                       │
      # │   - Use a bare Catch { ... } as a final fallback for             │
      # │     unexpected errors.                                           │
      # │                                                                   │
      # │ ERROR REPORTING:                                                  │
      # │   - ALL errors MUST be reported via New-ErrorRecord.              │
      # │   - NEVER use bare 'throw', 'Write-Error -Message:...',          │
      # │     or 'exit'.                                                    │
      # │   - Set -IsFatal:$True ONLY as an absolute last resort when the  │
      # │     function genuinely cannot continue.                          │
      # │                                                                   │
      # │ FINALLY BLOCKS:                                                   │
      # │   - Use to release resources (file handles, connections, etc.)    │
      # │   - Runs whether Try succeeded or Catch was triggered.            │
      # │   - If no resources need releasing, Finally may be omitted.      │
      # └────────────────────────────────────────────────────────────────────┘
      Try {
        Set-Variable -Name:'FileHashMatches' -Value:(
          [System.Boolean](
            # --- [ Line Continuation ] ————↴
            Test-FileHash                   `
              -Hash:$UpdateFile.Hash        `
              -FileInfo:$UpdateFileInfo
          )
        )
      } Catch [System.IO.IOException] {
        # Specific, known error — report as non-fatal and continue.
        # The pipeline can still process remaining items.
        #
        # ERROR MESSAGES FROM LOCALIZED DATA:
        #   - The message template comes from $Strings (loaded from
        #     .strings.psd1 in the Begin block)
        #   - Format placeholders {0}, {1}, etc. are filled via -f
        #   - Error IDs and Categories stay in code — they are
        #     programmatic identifiers, not user-facing text
        # --- [ Line Continuation ] ————↴
        New-ErrorRecord                                            `
          -ExceptionName:'System.IO.IOException'                   `
          -ExceptionMessage:(                                      `
            $Strings.HashIOError_Message -f                        `
              $UpdateFileInfo.FullName,                             `
              $_.Exception.Message                                 `
          )                                                        `
          -TargetObject:$UpdateFileInfo                            `
          -ErrorId:'Start-ExampleFunction:HashIOError'             `
          -ErrorCategory:'ReadError'                               `
          -IsFatal:$False
        Set-Variable -Name:'FileHashMatches' -Value:([System.Boolean]($False))
      } Catch {
        # Unexpected error — report as non-fatal.
        # Maximum effort to avoid fatal errors.
        # --- [ Line Continuation ] ————↴
        New-ErrorRecord                                            `
          -ExceptionName:'System.Management.Automation.RuntimeException' `
          -ExceptionMessage:(                                      `
            $Strings.UnexpectedHashError_Message -f                `
              $UpdateFileInfo.FullName,                             `
              $_.Exception.Message                                 `
          )                                                        `
          -TargetObject:$UpdateFileInfo                            `
          -ErrorId:'Start-ExampleFunction:UnexpectedHashError'     `
          -ErrorCategory:'NotSpecified'                            `
          -IsFatal:$False
        Set-Variable -Name:'FileHashMatches' -Value:([System.Boolean]($False))
      } Finally {
        # Release any resources if needed.
        # In this example, no resources to release — but the block
        # is shown here to demonstrate the pattern.
        Write-Debug -Message:'[Start-ExampleFunction] Hash check complete.'
      }

    } Else {
      Set-Variable -Name:'FileHashMatches' -Value:([System.Boolean]($False))
    }

    # Build the final result
    Set-Variable -Name:'Result' -Value:(
      [System.Boolean](
        ($FileExists -eq $True) -and
        ($FileSizeMatches -eq $True) -and
        ($FileHashMatches -eq $True)
      )
    )


    # ┌──────────────────────────────────────────────────────────────────────┐
    # │ PIPELINE OUTPUT — "SOFT RETURN"                                    │
    # │                                                                     │
    # │ RULE: Emit results by placing the variable on its own line.         │
    # │ Do NOT use 'return $Result'.                                        │
    # │                                                                     │
    # │ WHY:                                                                │
    # │   - 'return' exits immediately, skipping Write-Debug below          │
    # │   - Pipeline emission continues execution, so we see the debug     │
    # │     exit message and can set a breakpoint to inspect final state    │
    # │   - Output reaches the caller exactly the same way                 │
    # └──────────────────────────────────────────────────────────────────────┘
    $Result

    Write-Debug -Message:'[Start-ExampleFunction] Leaving Block: Process'
  }


  # ╔════════════════════════════════════════════════════════════════════════╗
  # ║ END BLOCK                                                            ║
  # ║                                                                      ║
  # ║ Runs ONCE after all pipeline items have been processed.              ║
  # ║ Use for: variable cleanup, closing connections, releasing resources. ║
  # ╚════════════════════════════════════════════════════════════════════════╝
  End {
    Write-Debug -Message:'[Start-ExampleFunction] Entering Block: End'

    # ┌──────────────────────────────────────────────────────────────────────┐
    # │ VARIABLE CLEANUP                                                   │
    # │                                                                     │
    # │ REQUIRED: Remove ALL dynamic variables declared in Begin.           │
    # │ This list MUST match New-Variable (Begin) and Clear-Variable       │
    # │ (Process) — all three are cross-references.                        │
    # │                                                                     │
    # │ WHY (even though PS auto-disposes on function exit):               │
    # │   - During development, functions run repeatedly in one session.    │
    # │     Leftover variables cause "phantom" results from stale values.  │
    # │   - Makes the variable lifecycle fully auditable: every variable    │
    # │     is declared (New), assigned (Set), cleared (Clear), and        │
    # │     removed (Remove).                                              │
    # │   - Serves as a checklist: if a variable appears here but not in   │
    # │     Begin (or vice versa), it's a code review signal.              │
    # └──────────────────────────────────────────────────────────────────────┘
    Remove-Variable -Force -ErrorAction:'SilentlyContinue' -Name:([System.Array](
      'FileExists', 'FileHashMatches', 'FileSizeMatches', 'Result',
      'Strings'  # Created by Import-LocalizedData, not New-Variable
    ))

    Write-Debug -Message:'[Start-ExampleFunction] Leaving Block: End'
  }
}


# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║ New-Object — ARGUMENT ANNOTATION PATTERN                                   ║
# ║                                                                            ║
# ║ When creating objects via New-Object with -ArgumentList, ALWAYS annotate   ║
# ║ each argument with an inline comment showing:                              ║
# ║   1. The .NET type of the constructor parameter: [System.String]           ║
# ║   2. The constructor parameter name: errorMessage                          ║
# ║                                                                            ║
# ║ WHY:                                                                       ║
# ║   - Constructor parameter names are invisible at the call site — unlike    ║
# ║     cmdlet parameters, they have no -Name: prefix to identify them         ║
# ║   - Without annotations, a reviewer must look up the constructor           ║
# ║     signature to understand what each positional argument does             ║
# ║   - The type annotation also serves as a contract — if someone passes     ║
# ║     the wrong type, the annotation makes the mismatch obvious             ║
# ║                                                                            ║
# ║ FORMAT:                                                                    ║
# ║   -ArgumentList:(                                                          ║
# ║     # [System.String] parameterName                                        ║
# ║     $Value,                                                                ║
# ║     # [System.Int32] anotherParameter                                      ║
# ║     $OtherValue                                                            ║
# ║   )                                                                        ║
# ║                                                                            ║
# ║ FULL EXAMPLE:                                                              ║
# ║   Set-Variable -Name:'ErrorRecord' -Value:(                                ║
# ║     New-Object -TypeName:'System.Management.Automation.ErrorRecord' `      ║
# ║       -ArgumentList:(                                                      ║
# ║         # [System.Exception] exception                                     ║
# ║         $Exception,                                                        ║
# ║         # [System.String] errorId                                          ║
# ║         $ErrorId,                                                          ║
# ║         # [System.Management.Automation.ErrorCategory] errorCategory       ║
# ║         $ErrorCategory,                                                    ║
# ║         # [System.Object] targetObject                                     ║
# ║         $TargetObject                                                      ║
# ║       )                                                                    ║
# ║   )                                                                        ║
# ║                                                                            ║
# ║ RULE: [X]::new() shorthand is NEVER used — New-Object -TypeName: is       ║
# ║ required for consistency and -Verbose traceability.                        ║
# ╚══════════════════════════════════════════════════════════════════════════════╝


# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║ PROPERTY & METHOD ACCESS                                                   ║
# ║                                                                            ║
# ║ When you already have a .NET object, access its members directly:         ║
# ║                                                                            ║
# ║ PROPERTY ACCESS — always direct:                                           ║
# ║   $FileInfo.FullName          — NOT (Get-Item ...).FullName               ║
# ║   $FileInfo.Length            — NOT Get-ItemPropertyValue ... -Name Length ║
# ║   $FileInfo.Exists            — NOT Test-Path ...                          ║
# ║                                                                            ║
# ║ INSTANCE METHOD CALLS — direct on the object:                             ║
# ║   $StringBuilder.Append('text')                                            ║
# ║   $RegistryKey.GetValue('Name')                                            ║
# ║   $List.Add($Item)                                                         ║
# ║                                                                            ║
# ║ STATIC METHOD CALLS — on the .NET type:                                   ║
# ║   [System.IO.File]::Exists('C:\file.txt')                                 ║
# ║   [System.IO.Path]::Combine('C:\', 'folder', 'file.txt')                  ║
# ║   [System.String]::IsNullOrEmpty($Value)                                   ║
# ║                                                                            ║
# ║ RULE: When you already have the object, use its properties/methods         ║
# ║ directly. Do NOT wrap in cmdlets to access what is already available.     ║
# ╚══════════════════════════════════════════════════════════════════════════════╝


# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║ COLLECTION TYPE SELECTION GUIDE                                            ║
# ║                                                                            ║
# ║ Always select the most appropriate collection type for the use case.       ║
# ║ NEVER default to [System.Array] when a more specific type fits better.     ║
# ║                                                                            ║
# ║ FIXED-SIZE (known at declaration, never modified):                         ║
# ║   [System.String[]]                  — Typed array of strings              ║
# ║   [System.Int32[]]                   — Typed array of integers             ║
# ║   [System.Array]                     — Generic fixed-size (last resort)    ║
# ║                                                                            ║
# ║ DYNAMIC-SIZE (items added/removed during execution):                       ║
# ║   [System.Collections.ArrayList]     — Add/Remove with good performance    ║
# ║   [System.Collections.Generic.List[System.String]] — Typed, best perf     ║
# ║                                                                            ║
# ║ KEY-VALUE (lookup by key):                                                 ║
# ║   [System.Collections.Hashtable]                    — Unordered key-value  ║
# ║   [System.Collections.Specialized.OrderedDictionary] — Ordered key-value   ║
# ║   [System.Collections.Generic.Dictionary[System.String, System.Object]]    ║
# ║                                      — Typed keys/values, best perf       ║
# ║                                                                            ║
# ║ WHY this matters:                                                          ║
# ║   - [System.Array] is IMMUTABLE — every += creates a new array and copies  ║
# ║     all elements. For loops with many items, this is O(n^2) and            ║
# ║     catastrophically slow.                                                 ║
# ║   - ArrayList/List.Add() is O(1) amortized.                               ║
# ║   - Typed collections prevent silent type coercion of elements.            ║
# ╚══════════════════════════════════════════════════════════════════════════════╝


# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║ .NET OVER CMDLETS — PERFORMANCE & CAPABILITY RULE                         ║
# ║                                                                            ║
# ║ When a .NET API exists for an operation, PREFER it over the equivalent    ║
# ║ PowerShell cmdlet. This applies especially to:                             ║
# ║                                                                            ║
# ║ REGISTRY:                                                                  ║
# ║   [Microsoft.Win32.RegistryKey]         — NOT Get-ItemProperty             ║
# ║   [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(                     ║
# ║     'SOFTWARE\Microsoft\Windows', $False  # $False = read-only access     ║
# ║   )                                                                        ║
# ║   WHY:                                                                     ║
# ║     - Orders of magnitude faster than PowerShell registry provider         ║
# ║     - Supports read-only access ($False flag) — cmdlets always open       ║
# ║       with write intent, which can fail on locked keys or trigger         ║
# ║       security auditing                                                    ║
# ║     - Fine-grained control: specific hives, views (32/64-bit),           ║
# ║       permissions                                                          ║
# ║                                                                            ║
# ║ FILE SYSTEM:                                                               ║
# ║   [System.IO.File]::Exists()            — NOT Test-Path                    ║
# ║   [System.IO.File]::ReadAllText()       — NOT Get-Content                  ║
# ║   [System.IO.Directory]::GetFiles()     — NOT Get-ChildItem               ║
# ║   [System.IO.FileInfo]                  — NOT Get-Item                     ║
# ║   WHY:                                                                     ║
# ║     - Dramatically faster for bulk operations                              ║
# ║     - No PowerShell provider overhead (PSDrive resolution, etc.)           ║
# ║     - Direct access to .NET properties without PS object wrapping          ║
# ║                                                                            ║
# ║ NETWORKING:                                                                ║
# ║   [System.Net.WebClient]                — NOT Invoke-WebRequest            ║
# ║   [System.Net.Http.HttpClient]          — NOT Invoke-RestMethod            ║
# ║                                                                            ║
# ║ STRING OPERATIONS:                                                         ║
# ║   [System.String]::Format()             — NOT "string $interpolation"      ║
# ║   [System.String]::IsNullOrEmpty()      — NOT ($Null -eq $X -or $X -eq '')║
# ║   [System.Text.StringBuilder]           — NOT repeated string += concat   ║
# ║                                                                            ║
# ║ GENERAL RULE:                                                              ║
# ║   If a .NET class provides the same functionality as a cmdlet, use the    ║
# ║   .NET class. The benefits are:                                            ║
# ║     1. PERFORMANCE — .NET calls skip the PS pipeline/provider overhead     ║
# ║     2. CAPABILITY  — .NET APIs expose options cmdlets don't surface        ║
# ║        (read-only access, specific permissions, encoding control, etc.)    ║
# ║     3. RELIABILITY — Fewer layers means fewer places for PS to inject      ║
# ║        unexpected type coercion or object wrapping                         ║
# ║                                                                            ║
# ║ EXCEPTION — Pipeline operations:                                           ║
# ║   Pipeline control flow uses PS-native patterns: & { process { } } for   ║
# ║   iteration, Where-Object for filtering (see LOOP & PIPELINE RULES).     ║
# ║   The .NET preference applies to data access and manipulation, not        ║
# ║   pipeline control flow.                                                   ║
# ╚══════════════════════════════════════════════════════════════════════════════╝


# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║ LOOP & PIPELINE RULES                                                     ║
# ║                                                                            ║
# ║ PIPELINE ITERATION — & { process { } } PATTERN:                           ║
# ║                                                                            ║
# ║   STANDARD: $Items | & { process { $PSItem } }                            ║
# ║   NEVER:    $Items | ForEach-Object -Process:{ $PSItem }                   ║
# ║   NEVER:    foreach ($Item in $Items) { }                                  ║
# ║                                                                            ║
# ║   WHY & { process { } } OVER ForEach-Object:                              ║
# ║     ForEach-Object invokes its scriptblock via InvokeReturnAsIs() on      ║
# ║     EVERY iteration. This means:                                           ║
# ║       - Repeated pipeline spin-up/spin-down per object                    ║
# ║       - No compiler optimization (scriptblock re-invoked each time)       ║
# ║       - On systems with ScriptBlock Logging enabled (common in            ║
# ║         enterprise/security-hardened environments), ForEach-Object         ║
# ║         triggers logging overhead on EVERY iteration                       ║
# ║                                                                            ║
# ║     The & { process { } } pattern compiles the scriptblock ONCE before    ║
# ║     pipeline execution begins, then runs the process block natively for   ║
# ║     each object — the same way a function's process block works.          ║
# ║                                                                            ║
# ║   PERFORMANCE (1,000,000 iterations):                                      ║
# ║     ForEach-Object:        8.7s   (baseline)                               ║
# ║     & { process { } }:    1.3s   (~6.7x faster)                           ║
# ║                                                                            ║
# ║   On ScriptBlock Logging systems (enterprise):                             ║
# ║     ForEach-Object:       15.0s   (baseline)                               ║
# ║     & { process { } }:    0.13s  (~115x faster)                            ║
# ║                                                                            ║
# ║   Reference: https://powershell.one/tricks/performance/pipeline            ║
# ║                                                                            ║
# ║   The & { process { } } pattern preserves ALL pipeline benefits:           ║
# ║     - Streaming (low memory, fast first-result)                            ║
# ║     - Pipeline chaining with |                                             ║
# ║     - Access to $PSItem automatic variable                                 ║
# ║                                                                            ║
# ║ SCOPE WARNING — & { } creates a CHILD SCOPE:                              ║
# ║   The & { process { } } scriptblock runs in a new child scope. This       ║
# ║   means variables declared with -Option:('Private') in the parent         ║
# ║   function are NOT visible inside the scriptblock.                         ║
# ║                                                                            ║
# ║   WORKAROUND: For variables that must be accessed inside                   ║
# ║   & { process { } }, declare them WITHOUT 'Private' in -Option.           ║
# ║   Use -Option:('ReadOnly') for static values, or omit -Option entirely   ║
# ║   for dynamic values that need child-scope visibility.                     ║
# ║                                                                            ║
# ║ AUTOMATIC VARIABLE — $PSItem (NEVER $_):                                  ║
# ║   Inside any pipeline scriptblock, always use $PSItem to reference the    ║
# ║   current pipeline object. $_ is a shorthand alias that is opaque to     ║
# ║   non-PowerShell readers. $PSItem is self-documenting.                    ║
# ║                                                                            ║
# ║ FILTERING — Where-Object remains the standard:                            ║
# ║   Where-Object -FilterScript:{ $PSItem.Size -gt 0 }                       ║
# ║   (No equivalent & { process { } } pattern for filtering)                 ║
# ║                                                                            ║
# ║ SWITCH vs IF/ELSEIF — prefer Switch for multiple conditions:              ║
# ║   When comparing one value against 3+ possible matches, use Switch        ║
# ║   instead of If/ElseIf chains. Switch is:                                  ║
# ║     - More performant (compiled jump table vs sequential evaluation)       ║
# ║     - More readable (clear "value matches case" structure)                ║
# ║     - More maintainable (adding a case is one line, not an ElseIf block)  ║
# ║   Use If/ElseIf for 1-2 conditions or complex boolean logic.              ║
# ║                                                                            ║
# ║   Example:                                                                ║
# ║     Switch ($Status) {                                                     ║
# ║       'Active'   { Write-Verbose -Message:'Active'   }                    ║
# ║       'Inactive' { Write-Verbose -Message:'Inactive' }                    ║
# ║       'Pending'  { Write-Verbose -Message:'Pending'  }                    ║
# ║       Default    { Write-Warning -Message:'Unknown'  }                    ║
# ║     }                                                                      ║
# ║                                                                            ║
# ║ PIPELINE FORMATTING (when chaining multiple stages):                       ║
# ║   - One stage per line when the pipeline exceeds 96 characters             ║
# ║   - Use the pipe character | at the END of the line (no backtick needed   ║
# ║     — PowerShell auto-continues after a trailing pipe)                     ║
# ║   - Indent continuation lines by 2 spaces                                 ║
# ║                                                                            ║
# ║ Example:                                                                   ║
# ║   $Items |                                                                 ║
# ║     Where-Object -FilterScript:{ $PSItem.Size -gt 0 } |                   ║
# ║     & { process { $PSItem.Name } }                                         ║
# ╚══════════════════════════════════════════════════════════════════════════════╝


# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║ QUICK REFERENCE — ALL RULES AT A GLANCE                                   ║
# ╠══════════════════════════════════════════════════════════════════════════════╣
# ║                                                                            ║
# ║ STYLE COMPLIANCE                                                          ║
# ║   PowerShell Practice and Style Guide as baseline                          ║
# ║   One True Brace Style (OTBS) strictly enforced                            ║
# ║   PSScriptAnalyzer: zero warnings/errors required                          ║
# ║   PowerShell 5.1 baseline — no PS 7+ features without version guard       ║
# ║                                                                            ║
# ║ FORMATTING                                                                ║
# ║   2 spaces per indent, NEVER tabs                                         ║
# ║   96 character max line length (STRICTLY ENFORCED)                         ║
# ║   OTBS braces: { on same line, } Else {, } Process {, } Catch {           ║
# ║   One function per file, file named after function                         ║
# ║   1 blank line between sections, 2 between major blocks, no trailing       ║
# ║   NEVER commented-out code in committed files                              ║
# ║                                                                            ║
# ║ CASING (PascalCase everywhere)                                            ║
# ║   Keywords:    If, Try, Catch, Begin, Process, End, Function               ║
# ║   Cmdlets:     Write-Debug, Set-Variable (canonical from Get-Command)      ║
# ║   Variables:   $FileExists, $Result (match declaration casing)             ║
# ║   Parameters:  -Name, -Value, -Force                                       ║
# ║   Constants:   $True, $False, $Null                                        ║
# ║                                                                            ║
# ║ SPACING & OPERATORS                                                       ║
# ║   Spaces around operators:  $X -eq $True   (never $X-eq$True)             ║
# ║   Space after commas:       'A', 'B', 'C'  (never 'A','B','C')            ║
# ║   No space in colon-bind:   -Name:'Value'  (never -Name: 'Value')         ║
# ║                                                                            ║
# ║ PROHIBITED                                                                ║
# ║   Positional/unnamed arguments (always use named params with colon-bind)   ║
# ║   Semicolons to join statements (one statement per line)                   ║
# ║   Cmdlet aliases: % ? foreach where select ft fl ls dir gci cd echo        ║
# ║   $_ shorthand (always use $PSItem)                                        ║
# ║   ForEach-Object (use & { process { } } instead)                          ║
# ║   Backtick line continuation without visual indicator comment              ║
# ║                                                                            ║
# ║ SYNTAX                                                                     ║
# ║   Colon-bind all parameters:       -Name:'Value'  (never -Name Value)     ║
# ║   Leading commas in attributes:    , Property = X (for easy commenting)    ║
# ║   Single quotes always:            'text'         (unless interpolating)   ║
# ║   Parenthesize param values:       -Option:('X')  (normalize syntax)       ║
# ║   Backtick + visual indicator:     # --- [ Line Continuation ] ————↴      ║
# ║                                                                            ║
# ║ TYPES                                                                      ║
# ║   Full .NET type names ONLY:       [System.String]  (never [string])       ║
# ║   Explicit casts on all exprs:     [System.Boolean]($x -eq $y)            ║
# ║   [OutputType()] on every function                                         ║
# ║   Select specific collection types (see Collection Guide above)            ║
# ║                                                                            ║
# ║ VARIABLES                                                                  ║
# ║   New-Variable in Begin:           -Force -Option:('Private') -Value:$Null ║
# ║   Set-Variable to assign:          -Name:'X' -Value:(...)                  ║
# ║   Clear-Variable at top of Process                                         ║
# ║   Remove-Variable in End                                                   ║
# ║   PascalCase, consistent casing everywhere                                 ║
# ║   All three lists (New/Clear/Remove) MUST match                            ║
# ║                                                                            ║
# ║ STRINGS                                                                    ║
# ║   -f operator (standard):          'Value: {0}' -f $Var                   ║
# ║   NEVER double-quote interpolation: "Value: $Var"                          ║
# ║   Here-strings: @' '@ default, @" "@ only for interpolation               ║
# ║                                                                            ║
# ║ CONTROL FLOW                                                              ║
# ║   Pre-evaluate into typed vars:    Set-Variable before If                  ║
# ║   Explicit bool comparison:        ($Var -eq $True) not ($Var)             ║
# ║   Null on left side:               ($Null -eq $Var) not ($Var -eq $Null)   ║
# ║   Switch for 3+ conditions:        Switch over If/ElseIf chains           ║
# ║   Pipeline output, not return:     $Result  (not: return $Result)          ║
# ║   Use -and / -or / -not:           NEVER && or || or !                     ║
# ║   Wrap each sub-condition in parens                                        ║
# ║                                                                            ║
# ║ ERROR HANDLING                                                             ║
# ║   Try/Catch/Finally for any cmd that can fail                              ║
# ║   ALL errors via New-ErrorRecord   (NEVER bare throw or Write-Error)       ║
# ║   Catch with full .NET exception types when handling specific errors       ║
# ║   Bare Catch { } as final fallback                                         ║
# ║   -IsFatal:$True ONLY as absolute last resort                              ║
# ║   NEVER use 'exit' — use $PSCmdlet.ThrowTerminatingError()                ║
# ║                                                                            ║
# ║ OUTPUT STREAMS                                                            ║
# ║   Write-Debug:       Tracing (entry/exit, variable states)                ║
# ║   Write-Verbose:     Operational progress for the user                     ║
# ║   Write-Warning:     Non-fatal problems, always visible                    ║
# ║   Write-Information: Structured log data (PS 5.1+)                         ║
# ║   Write-Error:       ONLY via New-ErrorRecord                              ║
# ║   NEVER: Write-Host (in functions), Write-Output, 'return'                ║
# ║                                                                            ║
# ║ LOCALIZED STRING DATA                                                      ║
# ║   Companion file per function: <FuncName>.strings.psd1 (same directory)    ║
# ║   Load via Import-LocalizedData in Begin block                             ║
# ║   -BindingVariable:'Strings' (standard name across repo)                   ║
# ║   Errors AND warnings in .strings.psd1 (not debug/verbose)                ║
# ║   Key naming: <ErrorCondition>_Message                                     ║
# ║   Use {0}, {1} format placeholders, fill via -f operator                   ║
# ║   Error IDs and Categories stay inline in code (not in strings file)       ║
# ║                                                                            ║
# ║ STRUCTURE                                                                  ║
# ║   Function Verb-Noun { } wrapper (approved verbs only)                     ║
# ║   Comment-based help: .SYNOPSIS, .DESCRIPTION, .PARAMETER, .EXAMPLE       ║
# ║   [CmdletBinding()] + [OutputType()]                                       ║
# ║   Begin / Process / End: ALWAYS, even without pipeline                     ║
# ║   Write-Debug at entry/exit: [FuncName] Entering/Leaving Block: X          ║
# ║                                                                            ║
# ║ LOOPS & PIPELINE                                                          ║
# ║   & { process { } } for iteration (NOT ForEach-Object — 6.7x faster)      ║
# ║   WARNING: & { } creates child scope — Private vars not visible           ║
# ║   Where-Object for filtering (standard)                                    ║
# ║   $PSItem always (NEVER $_)                                                ║
# ║   NEVER: ForEach-Object, foreach keyword, .Where(), aliases               ║
# ║   One pipeline stage per line when exceeding 96 chars                      ║
# ║   Pipe | at end of line (auto-continues, no backtick needed)               ║
# ║                                                                            ║
# ║ .NET OVER CMDLETS                                                          ║
# ║   Prefer .NET APIs for data access (registry, filesystem, network)        ║
# ║   Registry: [Microsoft.Win32.RegistryKey] not Get-ItemProperty             ║
# ║   Files: [System.IO.File] / [System.IO.Directory] not Get-Content/GCI     ║
# ║   Strings: [System.String]::Format/IsNullOrEmpty, [StringBuilder]          ║
# ║   WHY: orders of magnitude faster, more capability (read-only, etc.)       ║
# ║   EXCEPTION: pipeline patterns (& { process { } }, Where-Object)          ║
# ║                                                                            ║
# ║ OBJECTS                                                                    ║
# ║   New-Object -TypeName:'X':  Never use [X]::new() shorthand               ║
# ║   -ArgumentList: annotate each arg with # [Type] paramName comment        ║
# ║                                                                            ║
# ║ PARAMETERS & ATTRIBUTES                                                   ║
# ║   List ALL properties explicitly in [CmdletBinding()] AND [Parameter()]   ║
# ║   PositionalBinding = $False always (positional args prohibited)           ║
# ║   [System.Boolean] over [Switch] for flag parameters                       ║
# ║   Use built-in validators (ValidateSet, ValidateRange, etc.)               ║
# ║   AVOID [ValidateScript({})] — validate in Process with New-ErrorRecord    ║
# ║                                                                            ║
# ║ PROPERTY & METHOD ACCESS                                                  ║
# ║   Direct property access: $Object.Property (not cmdlet wrappers)           ║
# ║   Direct method calls: $Object.Method() / [Type]::StaticMethod()          ║
# ║                                                                            ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

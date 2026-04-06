# PowerShell Audit Rules

Distilled from REFERENCE.ps1. Every rule is checkable. MUST/NEVER/ALWAYS indicate enforcement level.

---

## Design Principles (Precedence Order)

| Principle | Rule |
|---|---|
| **KISS** | MUST be simplest solution that works. No empty files for compliance. No abstractions serving one caller. Prefer 3 clear lines over 1 clever line. |
| **SRP** | Each function does ONE thing. `Get-` reads, `Set-` modifies, `Test-` returns `[System.Boolean]`, `Resolve-` transforms, `Invoke-` executes, `New-` creates. |
| **Fail Fast** | Validate at boundary via parameter attributes. Report errors immediately via `New-ErrorRecord`. NEVER swallow or defer. `$ErrorActionPreference = 'Stop'`. |
| **Least Privilege** | Registry keys read-only by default. File handles minimum access. Variables `-Option:('Private')` by default. NEVER `-RunAsAdministrator` unless required. |
| **Least Surprise** | Behavior MUST match function name. Pipeline input processes ALL items. `[System.Boolean]` returns ONLY `$True`/`$False`. Defaults produce safest behavior. |
| **YAGNI** | NEVER add features, parameters, or abstractions for hypothetical future use. |
| **Idempotency** | Same inputs MUST produce same result. Safe to re-run. NEVER fail on second execution due to leftover state. |
| **Explicit Over Implicit** | NEVER rely on PowerShell auto-behavior. Explicit types, casts, comparisons, binding, scoping. |

---

## Compliance

- MUST follow PowerShell Practice & Style Guide + One True Brace Style (OTBS)
- MUST pass PSScriptAnalyzer with zero warnings/errors
- MUST target PS 5.1 baseline; PS 7+ features (`??`, `?:`, `&&`, `||`, `ActionPreference::Break`) PROHIBITED without version guard
- MUST include `#Requires -Version 5.1` on every script
- MUST save all `.ps1`/`.psd1` as UTF-8 with BOM

---

## Formatting

| Rule | Detail |
|---|---|
| Indent | 2 spaces. NEVER tabs. |
| Line length | 96 chars max, STRICTLY ENFORCED. |
| Braces (OTBS) | `{` on same line. `} Else {`, `} Catch {`, `} Process {`. `}` alone at keyword indent. |
| Casing | PascalCase for keywords, cmdlets, variables, parameters, constants (`$True`, `$False`, `$Null`), .NET types (exact docs casing). |
| Spacing | Spaces around operators. Space after commas. NO space in colon-bind (`-Name:'Value'`). |
| Blank lines | 1 between sections, 2 between major blocks, max 2 consecutive. No trailing blank lines. |
| Comments | `# ` with space. End-of-line: 2+ spaces before `#`. NEVER commented-out code in committed files. |
| File layout | One function per file, named after function. Companion `.strings.psd1` in same directory (only if needed). |
| Line continuation | Backtick REQUIRES visual indicator comment: `# --- [ Line Continuation ] ------>` |

---

## Syntax

| Pattern | Correct | Incorrect |
|---|---|---|
| Parameter binding | `-Name:'Value'` | `-Name 'Value'` |
| Switch param (activate) | `-Force` | `-Force:$True` |
| Switch param (deactivate) | `-Verbose:$False` | N/A (colon REQUIRED) |
| Positional args | `-Path:'C:\Temp'` | `'C:\Temp'` |
| Attribute lines | `, Property = X` (leading comma) | `Property = X` |
| Strings | `'text'` (single quote) | `"text"` |
| Interpolation | `'Value: {0}' -f $Var` | `"Value: $Var"` |
| Param values | `-Option:('Private')` | `-Option:'Private'` |
| Here-strings | `@' '@` default; `@" "@` only for interpolation | |
| Automatic variable | `$PSItem` | `$_` |
| Logical operators | `-and`, `-or`, `-not` | `&&`, `||`, `!` |
| Semicolons | ONLY for grouped `$Null` declaration lines | Anywhere else |

---

## Prohibited Patterns

- Positional/unnamed arguments
- Cmdlet aliases (`%`, `?`, `select`, `ft`, `fl`, `ls`, `dir`, `gci`, `cd`, `echo`, `where`)
- `$_` (ALWAYS `$PSItem`)
- `ForEach-Object` (use `& { process { } }`)
- `foreach` keyword (use `& { process { } }`)
- Double-quote interpolation (use `-f` operator)
- Bare `throw`, `Write-Error -Message:...`, `exit` in functions
- PS type aliases: `[string]`, `[bool]`, `[int]`, `[long]`, `[array]`, `[object]`
- `Write-Host` in functions
- `Write-Output` (use pipeline emission)
- `return $Value` (use soft return: `$Result` on its own line)
- `[ValidateScript({})]` (validate in Process with `New-ErrorRecord`)
- `[System.Array] +=` in loops (O(n^2); use `ArrayList`/`List.Add()`)
- Backtick continuation without visual indicator comment
- Nested `#region` blocks
- Commented-out code in committed files

---

## Types

- MUST use full .NET type names: `[System.String]` not `[string]`, `[System.Boolean]` not `[bool]`, `[System.Int32]` not `[int]`, `[System.Int64]` not `[long]`, `[System.Array]` not `[array]`, `[System.Object]` not `[object]`
- MUST explicitly cast all expressions: `[System.Boolean]($X -eq $Y)`
- MUST declare `[OutputType()]` on every function
- Collections: fixed `[System.String[]]`; dynamic `[System.Collections.ArrayList]` or `[System.Collections.Generic.List[T]]`; key-value `[System.Collections.Hashtable]` or `[System.Collections.Specialized.OrderedDictionary]`

---

## Variable Management

- Working state MUST use explicit lifecycle: `New-Variable` (Begin), `Set-Variable` (Process), `Clear-Variable` (top of Process), `Remove-Variable` (End)
- New/Clear/Remove lists MUST match
- Default flags: `-Force`, `-Option:('Private')`, `-Value:$Null`
- Static variables: `-Option:('Private','ReadOnly')`
- `Import-LocalizedData` variable (`Strings`): not in `New-Variable`, MUST be in `Remove-Variable`, not in `Clear-Variable`
- Trivial temporaries MAY use plain `$Var = ...`
- Grouped `$Null` declaration: `$A = $Null; $B = $Null` permitted at block top

---

## Control Flow

- MUST pre-evaluate conditions into explicitly typed variables before `If`
- MUST use explicit bool comparison: `($Var -eq $True)` not `($Var)`; `($Var -eq $False)` not `(-not $Var)`
- MUST place `$Null` on left: `($Null -eq $Var)` not `($Var -eq $Null)`
- MUST wrap sub-conditions: `($A -eq $True) -and ($B -eq $True)`
- `Switch` for 3+ conditions against one value; `If/ElseIf` for 1-2 or complex boolean
- Pipeline output via soft return (`$Result` on its own line); NEVER `return $Result`

---

## Error Handling

- ALL errors MUST use `New-ErrorRecord`. NEVER bare `throw`, `Write-Error -Message:...`, or `exit`.
- `Try`/`Catch`/`Finally` around any cmdlet that can fail
- `Catch` MUST use fully qualified .NET exception types for specific errors; bare `Catch { }` as final fallback
- `-IsFatal:$True` ONLY as absolute last resort; use `$PSCmdlet.ThrowTerminatingError()`
- `Finally`: release resources only; omit if not needed
- Script-level `Trap`: `Write-Host` and `Exit` ARE permitted (error streams may be compromised)
- Exit codes: `0` = success, `1` = general failure (trap), `2+` = application-specific

---

## Output Streams

| Stream | Use | Source |
|---|---|---|
| `Write-Debug` | Entry/exit tracing, variable states | Inline |
| `Write-Verbose` | Operational progress | Inline |
| `Write-Warning` | Non-fatal problems | `.strings.psd1` |
| `Write-Information` | Structured log data | Inline |
| `Write-Error` | ONLY via `New-ErrorRecord` | `.strings.psd1` |

NEVER in functions: `Write-Host`, `Write-Output`, `return`

---

## Function Structure

1. `Function Verb-Noun { }` (approved verbs from `Get-Verb`)
2. Comment-based help: `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`, `.OUTPUTS`, `.NOTES`
3. `[CmdletBinding()]` with ALL properties listed explicitly; `PositionalBinding = $False`
4. `[OutputType()]` with full .NET type
5. `Param()` with ALL `[Parameter()]` properties listed explicitly
6. `Begin` / `Process` / `End` blocks (omit ONLY when no pipeline input, no per-item state, no setup/cleanup, and omission simplifies readability)
7. `Write-Debug` at entry/exit of each lifecycle block
8. `Import-LocalizedData` in `Begin` when strings are used
9. Managed working state: declare in `Begin`, clear in `Process`, remove in `End`
10. `[Switch]` for presence/absence flags; `[System.Boolean]` only for explicit true/false data
11. AVOID `[ValidateScript({})]`; validate in Process with `New-ErrorRecord`

---

## ShouldProcess

- MUST declare `SupportsShouldProcess = $True` on any state-changing function
- MUST NOT declare on read-only functions
- `ConfirmImpact`: `Low` (reversible), `Medium` (recoverable), `High` (destructive)
- Guard every action: `If ($PSCmdlet.ShouldProcess($Target, 'Action') -eq $True) { }`

---

## Localized String Data

- Companion `<FunctionName>.strings.psd1` ONLY when function has error/warning messages (KISS)
- Loaded via `Import-LocalizedData -BindingVariable:'Strings' -FileName:'<Name>.strings' -BaseDirectory:$PSScriptRoot`
- Contains: error messages (`<Condition>_Message`) and warnings (`<Condition>_Warning`)
- Does NOT contain: debug or verbose messages
- Uses `{0}`, `{1}` placeholders filled via `-f` operator

---

## .NET Over Cmdlets

| Domain | Use | Not |
|---|---|---|
| Registry | `[Microsoft.Win32.RegistryKey]` | `Get-ItemProperty` |
| File existence | `[System.IO.File]::Exists()` | `Test-Path` |
| File read | `[System.IO.File]::ReadAllText()` | `Get-Content` |
| Directory listing | `[System.IO.Directory]::GetFiles()` | `Get-ChildItem` |
| Null/empty check | `[System.String]::IsNullOrEmpty()` | `($Null -eq $X -or $X -eq '')` |
| String building | `[System.Text.StringBuilder]` | `+=` concatenation |
| Object construction | `[Type]::new()` (simple) or `New-Object` (dynamic/complex) | |

Exception: pipeline control flow stays PS-native (`& { process { } }`, `Where-Object`)

---

## Loops & Pipeline

- MUST use `$Items | & { process { $PSItem } }` for iteration
- NEVER `ForEach-Object` (6.7x slower; 115x with ScriptBlock Logging)
- NEVER `foreach` keyword
- `& { }` creates child scope: `-Option:('Private')` vars NOT visible; use `-Option:('ReadOnly')` or omit `-Option` for child-scope access
- `Where-Object -FilterScript:{ $PSItem.Size -gt 0 }` for filtering
- Pipe `|` at end of line (auto-continues); indent continuation by 2 spaces

---

## Regions & Script Structure

- Scripts MUST use regions: `Initialization`, `Functions`, `Execution`, `Cleanup`
- Functions MUST NOT use regions (Begin/Process/End suffices)
- NEVER nest regions
- `#Requires` MUST appear after help block, before `[CmdletBinding()]`

---

## Credentials & Secrets

- NEVER hardcode passwords, API keys, or tokens
- NEVER store secrets in `.strings.psd1` or any committed file
- NEVER log or `Write-Verbose` credential values
- NEVER pass credentials as plain `[System.String]`
- MUST use `[System.Management.Automation.PSCredential]` and `[System.Security.SecureString]`
- MUST accept credentials as parameters; NEVER prompt inside functions

---

## Testing (Pester)

- `tests/` mirrors `src/` structure; file naming: `<FunctionName>.Tests.ps1`
- Tests target compiled build output, not individual source files
- Every function MUST have a test file
- Every code path (If/Else/Switch) MUST be exercised
- Both success AND failure paths tested
- `PSTypeName` verified on all returned `PSCustomObject`s
- Error/warning messages verified against `.strings.psd1`
- Mock external dependencies; do NOT mock internals unless testing orchestrator logic

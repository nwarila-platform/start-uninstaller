# Get-Is64BitOperatingSystem

## Purpose
`Get-Is64BitOperatingSystem` is a private seam that returns the current operating
system bitness as a `[System.Boolean]`. The rewrite plan explicitly names it as an
external dependency wrapper so callers such as `Get-UninstallRegistryPath` and
`Resolve-AppArchitecture` can decide between 32-bit and 64-bit behavior without
hard-coding direct static .NET reads throughout the codebase. Its implementation is
intentionally tiny so Pester can mock OS bitness in downstream tests.

## Parameters
This function takes no parameters.

## Return Value
Returns `[System.Boolean]`. It emits `$True` when the current operating system is
64-bit and `$False` when it is not. It has no designed `$Null` path and no deliberate
no-output path; absent an unexpected runtime failure while reading the static .NET
property, it writes exactly one Boolean value to the pipeline.

## Execution Flow
```mermaid
flowchart LR
    A([Start]) --> B[Enter Process]
    B --> C[Read OS bitness]
    C --> D[Cast to Boolean]
    D --> E[Emit Boolean]
    E --> F([End])
```

## Error Handling
- The function has no `Try/Catch`, `Write-Warning`, or `New-ErrorRecord` path.
- Under normal conditions, `[System.Environment]::Is64BitOperatingSystem` is read and
  emitted directly from the `Process` block.
- If PowerShell or the runtime throws unexpectedly while evaluating that property, the
  exception bubbles to the caller unchanged.

## Side Effects
This function has no side effects.

## Research Log
| Topic | Finding | Source | Date Verified |
|-------|---------|--------|---------------|
| Search: "PowerShell Practice and Style guide" | The community PowerShell Practice and Style guide is still presented as an evolving baseline and explicitly describes itself as pragmatic guidance rather than a rigid rulebook. | https://poshcode.gitbook.io/powershell-practice-and-style | 2026-04-02 |
| Search: "PowerShell Practice and Style code layout and formatting" | The current guide still recommends OTBS and starting scripts/functions with `[CmdletBinding()]`, but its baseline formatting guidance remains four spaces and about 115 characters while explicitly telling contributors to follow project-specific rules when they differ. | https://poshcode.gitbook.io/powershell-practice-and-style/style-guide/code-layout-and-formatting | 2026-04-02 |
| Search: "PowerShell-Docs style guide" | Microsoft's current PowerShell-Docs style guide says cmdlet and parameter names should use proper Pascal case, but PowerShell keywords and operators should be lowercase. That conflicts with this repo's house style that requires PascalCase keywords, so the audit below continues to score the function against the repo standard as authoritative. | https://learn.microsoft.com/en-us/powershell/scripting/community/contributing/powershell-style-guide?view=powershell-7.5 | 2026-04-02 |
| Search: "PSScriptAnalyzer overview" | Microsoft still positions PSScriptAnalyzer as the current static analyzer for PowerShell code, with rules based on PowerShell Team and community best practices and support for Windows PowerShell 5.1 or greater. | https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/overview?view=ps-modules | 2026-04-01 |
| Search: "PSScriptAnalyzer what's new" (2026-04-01) | SUPERSEDED - see next row. Previous finding stated 1.24.0 was the latest documented release. | https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/whats-new-in-pssa?view=ps-modules | 2026-04-01 |
| Search: "PSScriptAnalyzer latest version 2026" | SUPERSEDED - see next two rows. Previous finding said 1.25.0 was current but could not confirm long-line rule support. | https://www.powershellgallery.com/packages/PSScriptAnalyzer/1.25.0 | 2026-04-02 |
| Search: "PSScriptAnalyzer current version PowerShell Gallery" | PSScriptAnalyzer 1.25.0 is current on the PowerShell Gallery and was published on 2026-03-20. | https://www.powershellgallery.com/packages/PSScriptAnalyzer/1.25.0 | 2026-04-02 |
| Search: "PSScriptAnalyzer AvoidLongLines" | Microsoft Learn now documents a built-in configurable `AvoidLongLines` rule. It is warning-level, disabled by default, and defaults to 120 characters, so this repo's 96-character limit remains stricter but the earlier "no built-in long-line rule" assumption is no longer correct. | https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/rules/avoidlonglines?view=ps-modules | 2026-04-02 |
| Search: "AvoidUsingPositionalParameters" | Current analyzer guidance still discourages positional arguments, but the built-in `AvoidUsingPositionalParameters` rule intentionally triggers only at three or more positional arguments, which remains looser than this repo's house standard. | https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/rules/avoidusingpositionalparameters?view=ps-modules | 2026-04-01 |
| Search: "about_Functions_CmdletBindingAttribute" | SUPERSEDED - see next row. Previous finding focused on the optional argument list but did not capture the current `ConfirmImpact` guidance. | https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_functions_cmdletbindingattribute?view=powershell-7.5 | 2026-04-01 |
| Search: "about_Functions_CmdletBindingAttribute ConfirmImpact SupportsShouldProcess" | Microsoft still documents `CmdletBinding` as the mechanism that makes advanced functions behave like compiled cmdlets, but current guidance says `ConfirmImpact` should be specified only when `SupportsShouldProcess` is also specified. That means this function's explicit `ConfirmImpact = 'None'` is consistent with the repo house style, but not with current platform guidance. | https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_functions_cmdletbindingattribute?view=powershell-7.5 | 2026-04-02 |
| Search: "about_Functions_OutputTypeAttribute" | Microsoft documents that `OutputType` is metadata only and is not validated against actual runtime output, so the attribute should be kept but the function body still needs manual audit. | https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_functions_outputtypeattribute?view=powershell-7.5 | 2026-04-01 |
| Search: "about_Return" | Current PowerShell documentation still states that each statement's result is returned as output even without `return`, so the helper's direct expression output remains a valid pattern. | https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_return?view=powershell-7.5 | 2026-04-01 |
| Search: "Environment.Is64BitOperatingSystem" | Microsoft Learn still documents `System.Environment.Is64BitOperatingSystem` as the supported Boolean API for determining whether the current operating system is 64-bit; no deprecation or replacement surfaced in current documentation. | https://learn.microsoft.com/en-us/dotnet/api/system.environment.is64bitoperatingsystem?view=net-9.0 | 2026-04-02 |
| Search: "Pester mocking commands" | Current Pester guidance still recommends mocking commands to fake dependencies, which supports keeping OS bitness behind a tiny mockable function seam instead of calling the static API directly everywhere. | https://pester.dev/docs/usage/mocking | 2026-04-02 |
| Search: "about_Comment_Based_Help" | Microsoft documents `.PARAMETER` entries per actual parameter and keeps `.EXAMPLE` as a first-class help keyword, so the repo standard is stricter than platform docs for zero-parameter helpers. | https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_comment_based_help?view=powershell-7.5 | 2026-04-01 |
| Search: "Get-Verb approved verbs" | Microsoft still documents `Get-Verb` as the approved-verb reference and notes that unapproved verbs trigger an `Import-Module` warning, so the helper's `Get-` verb remains correct. | https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/get-verb?view=powershell-7.5 | 2026-04-01 |

Research notes:
1. Current Microsoft guidance still only requires `.PARAMETER` entries for actual
   parameters and now also says `ConfirmImpact` should be specified only when
   `SupportsShouldProcess` is present. The audit below still follows the stricter
   repository standard wherever the reference is explicit and calls out the
   platform-guidance mismatch separately.
2. PSScriptAnalyzer 1.25.0 is current on the PowerShell Gallery. Microsoft Learn now
   documents a built-in `AvoidLongLines` rule, but it is disabled by default and uses
   a 120-character default threshold, so analyzer defaults are still looser than this
   repo's 96-character policy.
3. The current PowerShell Practice and Style guide still recommends OTBS and
   `[CmdletBinding()]`, but its baseline formatting guidance is four-space indentation
   and roughly 115-character lines while explicitly deferring to project-local rules.
4. Microsoft's PowerShell-Docs style guide prefers lowercase keywords and operators in
   examples, which conflicts with this repo's PascalCase-keyword house style. The
   standards audit below follows the repo reference document, not the docs-writing
   convention.

## Standards Audit
| Rule | Status | Line(s) | Evidence |
|------|--------|--------|----------|
| Colon-bound parameters | N/A | 22-35 | "`Param()`" and "`[System.Boolean][System.Environment]::Is64BitOperatingSystem`"; the function invokes no cmdlets or functions with value parameters. |
| PascalCase naming | PASS | 1, 31, 35 | "`Function Get-Is64BitOperatingSystem {`" and "`[System.Boolean][System.Environment]::Is64BitOperatingSystem`" use PascalCase names. |
| Full .NET type names (no accelerators) | PASS | 31, 35 | "`[OutputType([System.Boolean])]`" and "`[System.Boolean][System.Environment]::Is64BitOperatingSystem`" use full .NET type names. |
| Object types are the most appropriate and specific choice | PASS | 31, 35 | "`[OutputType([System.Boolean])]`" and "`[System.Boolean][System.Environment]::Is64BitOperatingSystem`" use the specific scalar Boolean type instead of a generic object type. |
| Single quotes for non-interpolated strings | PASS | 23-29 | "`ConfirmImpact = 'None'`", "`DefaultParameterSetName = 'Default'`", "`HelpURI = ''`", and "`RemotingCapability = 'None'`" all use single-quoted literals. |
| `$PSItem` not `$_` | N/A | 32-35 | "`Param()`" followed by one output expression; the function has no automatic-variable usage. |
| Explicit bool comparisons (`$Var -eq $True`) | N/A | 35 | "`[System.Boolean][System.Environment]::Is64BitOperatingSystem`"; the function contains no Boolean comparisons. |
| If conditions are pre-evaluated outside `If` blocks | N/A | 22-35 | "`[CmdletBinding(...)]`", "`Param()`", and one output expression only; there is no `If` block to pre-evaluate for. |
| `$Null` on the left side of comparisons | N/A | 22-35 | "`Param()`" and one output expression only; there are no null comparisons. |
| No positional arguments to cmdlets | N/A | 22-35 | "`Param()`" and "`[System.Boolean][System.Environment]::Is64BitOperatingSystem`"; the function invokes no cmdlets. |
| No cmdlet aliases | N/A | 22-35 | "`[CmdletBinding(...)]`" and "`[System.Boolean][System.Environment]::Is64BitOperatingSystem`"; there are no cmdlet invocations, so alias usage does not apply. |
| Switch parameters correctly handled | N/A | 22-32 | "`Param()`"; the function defines no parameters and calls no switch-bearing cmdlets. |
| Leading commas in attributes | FAIL | 22-30 | "`[CmdletBinding(`" is followed by "`ConfirmImpact = 'None'`" on the first attribute line instead of a leading comma; the house style requires each attribute-member line to begin with a comma. |
| CmdletBinding with all required properties | PASS | 22-30 | "`[CmdletBinding(`" includes "`ConfirmImpact = 'None'`", "`DefaultParameterSetName = 'Default'`", "`HelpURI = ''`", "`PositionalBinding = $False`", "`RemotingCapability = 'None'`", "`SupportsPaging = $False`", and "`SupportsShouldProcess = $False`". |
| OutputType declared | PASS | 31 | "`[OutputType([System.Boolean])]`" is present directly above the `Param()` block. |
| Comment-based help is complete | FAIL | 3-19 | The help block contains "`.SYNOPSIS`", "`.DESCRIPTION`", "`.EXAMPLE`", "`.OUTPUTS`", and "`.NOTES`", but there is no "`.PARAMETER`" keyword anywhere in lines 3-19. |
| Error handling via `New-ErrorRecord` or appropriate pattern | REVIEW | 35 | "`[System.Boolean][System.Environment]::Is64BitOperatingSystem`" is a direct property read with no `Try/Catch` or `New-ErrorRecord`; the API has no documented exception contract, so strict applicability remains ambiguous. |
| Try/Catch around operations that can fail | REVIEW | 35 | "`[System.Boolean][System.Environment]::Is64BitOperatingSystem`" is not wrapped in `Try/Catch`; current documentation does not describe an expected exception path, so strict applicability remains ambiguous. |
| Begin/Process/End block structure | FAIL | 34-36 | The helper declares only "`Process {`" and omits both `Begin` and `End`; under the house standard it should either use the full lifecycle-block structure or omit the blocks entirely for a trivial helper. |
| Write-Debug at Begin/Process/End block entry and exit | FAIL | 34-36 | "`Process {`" contains only "`[System.Boolean][System.Environment]::Is64BitOperatingSystem`" and no `Write-Debug` statements, so the present lifecycle block is untraced. |
| No variable pollution (`script:`/`global:` leaks) | PASS | 32-35 | "`Param()`" is followed by a single typed output expression inside `Process`; the function assigns no variables and writes no outer-scope state. |
| 96-character line limit | PASS | 1-37 | A file-wide scan found `MaxLineLength=64;Line=35`, and no source line exceeds the repo's 96-character limit. |
| 2-space indentation (no tabs) | PASS | 22-35 | Lines such as "`  [CmdletBinding(`" and "`    [System.Boolean][System.Environment]::Is64BitOperatingSystem`" use 2-space indentation, and a file-wide scan found no tab characters. |
| OTBS brace style | PASS | 1, 34-37 | "`Function Get-Is64BitOperatingSystem {`" and "`Process {`" place opening braces on the same line, and the closing braces stand alone on lines 36-37. |
| No commented-out code | PASS | 2-20 | "`<#` ... `#>`" is a live comment-based help block; there are no disabled executable statements. |
| Registry access is read-only | N/A | 35 | "`[System.Boolean][System.Environment]::Is64BitOperatingSystem`"; the function does not open or touch the registry. |
| Approved verb naming | PASS | 1 | "`Function Get-Is64BitOperatingSystem {`" uses the approved `Get` verb for a read-only helper. |
| `Param()` block present | PASS | 32 | "`Param()`" is present even though the function takes no parameters. |
| `#Requires -Version 5.1` | REVIEW | 1-37 | The file begins with "`Function Get-Is64BitOperatingSystem {`" and contains no `#Requires`; the standard text is written for scripts, while this repo stores dot-sourced function source files in `.ps1` files. |

## Plan Audit
| Plan Section | Requirement | Status | Line(s) | Details |
|--------------|-------------|--------|--------|---------|
| 12. File Structure | `Get-Is64BitOperatingSystem.ps1` must live under `src/Private/`. | ALIGNED | `src/Private/Get-Is64BitOperatingSystem.ps1:1-37` | The function is implemented in the planned private-path file and is not exposed as a public entrypoint. |
| 12. External Seams | `Get-Is64BitOperatingSystem` must exist as an external seam. | ALIGNED | `src/Private/Get-Is64BitOperatingSystem.ps1:6-9,35` | The help text explicitly calls it a thin seam for tests, and the body is a direct mirror of the static API, so the function's existence is justified by the plan rather than being overengineering. |
| 2. Frozen Product Decisions | External dependencies must be wrapped behind private seam functions so tests can mock them reliably. | ALIGNED | `src/Private/Get-Is64BitOperatingSystem.ps1:6-9,35`; `tests/Private/Get-UninstallRegistryPath.Tests.ps1:15,62,86,137,171,192,220,242`; `tests/Private/Resolve-AppArchitecture.Tests.ps1:27,53,112,144,168,192,216,258` | The helper is a private wrapper around the external dependency, and downstream tests actively `Mock Get-Is64BitOperatingSystem` in both registry-discovery and architecture-resolution scenarios. |
| 15. Phase 1 Acceptance | "wrappers are tiny" | ALIGNED | `src/Private/Get-Is64BitOperatingSystem.ps1:32-35` | The wrapper has an empty `Param()` block and one executable statement inside `Process`, with no buried business logic. |
| 15. Phase 1 Acceptance | "wrappers have focused tests" | ALIGNED | `tests/Private/Get-Is64BitOperatingSystem.Tests.ps1:7-42` | The focused unit tests cover command existence, parameter surface, return type, parity with `[System.Environment]::Is64BitOperatingSystem`, and repeat-call stability. |
| 15. Phase 1 Acceptance | "no business logic is buried in a seam function" | ALIGNED | `src/Private/Get-Is64BitOperatingSystem.ps1:34-35` | Inside the lifecycle block, the body is only a typed read of `Environment.Is64BitOperatingSystem`; there are no branches, transforms, or domain rules hidden in the seam. |
| 7.1 Search Locations | Discovery must include the `HKLM` WOW6432Node view on 64-bit OS. | ALIGNED | `src/Private/Get-Is64BitOperatingSystem.ps1:35`; `src/Private/Get-UninstallRegistryPath.ps1:46-58,80-90` | `Get-UninstallRegistryPath` captures the seam result into `$Is64BitOperatingSystem` and passes it into `New-RegistryViewDescriptor` for both system and user descriptor generation. |
| 7.6 Architecture Detection | On 32-bit OS, every discovered application is `x86`; on 64-bit OS, weighted evidence applies. | ALIGNED | `src/Private/Get-Is64BitOperatingSystem.ps1:35`; `src/Private/Resolve-AppArchitecture.ps1:56-63,68-162` | `Resolve-AppArchitecture` uses the seam to short-circuit to `'x86'` on 32-bit OS and then applies the planned `DisplayName`, `InstallSource`, `InstallLocation`, and registry-view weighting, including the `Program Files (x86)` and mutually exclusive `Program Files(?! \(x86\))` patterns and the tie-to-`x86` rule. |
| 4.4 No Interactivity | The script must not prompt. Specifically: no `SupportsShouldProcess` and no `ConfirmImpact`. | REVIEW | `src/Private/Get-Is64BitOperatingSystem.ps1:22-30` | The helper is behaviorally non-interactive and sets "`SupportsShouldProcess = $False`", but it still declares "`ConfirmImpact = 'None'`". Because section 4.4 is written as a script-level contract, applicability to this private seam is ambiguous; if enforced literally on every source file, the explicit `ConfirmImpact` would be a deviation, and current Microsoft guidance also says `ConfirmImpact` should only be specified with `SupportsShouldProcess`. |
| 4.3 Exit Codes | Exit-code responsibilities belong to the script/orchestrator layers. | N/A | `src/Private/Get-Is64BitOperatingSystem.ps1:34-35` | This helper returns only a Boolean and does not own process exit behavior. |
| 5. Internal Data Model | Internal application/result record rules apply to discovery and uninstall layers. | N/A | `src/Private/Get-Is64BitOperatingSystem.ps1:34-35` | The helper emits a scalar Boolean and does not construct internal data-model records. |

## Changelog

| Date | Changes |
|------|---------|
| 2026-04-02 | Corrected the README to the current 37-line implementation with an explicit `Process` block, updated the execution flow and all line references, added current research on Microsoft's PowerShell-Docs style-guide casing guidance, and fixed the standards audit to fail both the helper's partial lifecycle-block structure and its missing `Write-Debug` tracing. |
| 2026-04-02 | Added current research on the community style guide's explicit 4-space/115-character baseline, documented the built-in `AvoidLongLines` PSScriptAnalyzer rule, refined the `CmdletBinding` research around `ConfirmImpact`, corrected the standards audit to fail incomplete comment-based help, added the missing Phase 1 "no business logic is buried in a seam function" plan check, and downgraded the prior script-contract deviation call to a scope review. |
| 2026-04-02 | Updated PSScriptAnalyzer research entry from 1.24.0 to 1.25.0 (released 2026-03-20), marked previous entry as SUPERSEDED, and re-verified `Environment.Is64BitOperatingSystem`, Pester mocking, and community style guide currency. |
| 2026-04-01 | Corrected stale standards findings against the current source, added the missing required audit checks, recorded the missing leading-comma attribute failure, updated all line references to the 35-line implementation, and tightened the plan audit to call out the literal `ConfirmImpact`/`SupportsShouldProcess` divergence. |
| 2026-04-01 | First audit run. Added the initial README with function documentation, execution flow, current web research log, standards audit, plan audit, and changelog tracking. |
AUDIT_STATUS:UPDATED
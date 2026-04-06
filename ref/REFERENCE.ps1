# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║            POWERSHELL CODING POLICY & STANDARDS REFERENCE                  ║
# ║                                                                            ║
# ║  This is the SINGLE AUTHORITATIVE document that defines this               ║
# ║  organization's PowerShell house style. Every convention is intentional,   ║
# ║  every rule is REQUIRED for this codebase, and every decision a developer  ║
# ║  could face has an answer here.                                            ║
# ║                                                                            ║
# ║  STRUCTURE:                                                                ║
# ║    PART 1 — Philosophy & Rules      (policy, no code)                      ║
# ║    PART 2 — Script Template         (working example, includes exec/cleanup)║
# ║    PART 3 — Function Examples       (working examples)                     ║
# ║    PART 4 — String Data Examples    (localized data patterns)              ║
# ║    PART 5 — Execution & Cleanup     (script body regions)                  ║
# ║    PART 6 — Quick Reference         (cheat sheet)                          ║
# ║                                                                            ║
# ║  NOTE: In production, each function is in its own file with a companion   ║
# ║  .strings.psd1. This reference combines everything for documentation.     ║
# ╚══════════════════════════════════════════════════════════════════════════════╝


# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                                                                            ║
# ║                     PART 1 — PHILOSOPHY & RULES                            ║
# ║                                                                            ║
# ╚══════════════════════════════════════════════════════════════════════════════╝


# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ 1.1 — PHILOSOPHY                                                          │
# │                                                                            │
# │ All code is written with these priorities, in this order:                  │
# │                                                                            │
# │   1. READABLE    — A non-programmer should follow the logic                │
# │   2. SAFE        — Defend against PowerShell's implicit behaviors          │
# │   3. RELIABLE    — Consistent results across runs, sessions, users         │
# │   4. DEBUGGABLE  — Every value inspectable, every transition traceable     │
# │   5. PERFORMANT  — But never at the expense of 1-4                         │
# │                                                                            │
# │ These rules were developed over years of production experience.            │
# │ They exist because each one prevented a real bug or confusion.             │
# │ A small amount of "noise" is always acceptable if it adds safety.          │
# │                                                                            │
# │ When in doubt: be MORE explicit, not less.                                 │
# └──────────────────────────────────────────────────────────────────────────────┘


# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ 1.1.1 — DESIGN PRINCIPLES                                                 │
# │                                                                            │
# │ These principles are FIRST-CLASS requirements. Every design decision,      │
# │ function signature, and line of code must be evaluated against them.       │
# │ They are listed in order of precedence — when two principles conflict,    │
# │ the higher-numbered principle wins (e.g., KISS overrides SRP if            │
# │ splitting a function adds complexity without adding clarity).              │
# │                                                                            │
# │ ── KISS (Keep It Simple) ──────────────────────────────────────────────── │
# │                                                                            │
# │   Every solution MUST be the simplest version that works correctly.       │
# │   If a design can be explained in one sentence, it's right. If it         │
# │   needs a paragraph, simplify it.                                         │
# │                                                                            │
# │   KISS means:                                                              │
# │     - No files that exist solely for "standards compliance" (if a          │
# │       function has no error/warning messages, it has no .strings.psd1)    │
# │     - No factory functions for trivially simple objects (if a 3-property  │
# │       PSCustomObject is only created in one place, create it inline)      │
# │     - No abstractions that serve one caller (if only one function uses    │
# │       it, it belongs inside that function, not in its own file)           │
# │     - Prefer 3 clear lines over 1 clever line                             │
# │     - If removing something makes the code easier to understand,          │
# │       remove it                                                            │
# │                                                                            │
# │ ── SRP (Single Responsibility Principle) ──────────────────────────────── │
# │                                                                            │
# │   Each function does exactly ONE thing. If you cannot describe what a     │
# │   function does without using the word "and", it does too much.           │
# │                                                                            │
# │   SRP means:                                                               │
# │     - A function named Get-* retrieves data. It does NOT modify state.    │
# │     - A function named Set-* modifies data. It does NOT retrieve.         │
# │     - A function named Test-* returns [System.Boolean]. It does NOT       │
# │       modify anything.                                                    │
# │     - A function named Resolve-* transforms input into output.            │
# │       It does NOT perform side effects.                                   │
# │     - A function named Invoke-* executes an action.                       │
# │       It MAY have side effects.                                           │
# │     - A function named New-* creates an object. It does NOT execute       │
# │       business logic.                                                     │
# │                                                                            │
# │   EXCEPTION: Performance-critical functions may combine                   │
# │   enumeration + filtering when splitting would require iterating          │
# │   the same data source multiple times. This must be documented.           │
# │                                                                            │
# │ ── Fail Fast ─────────────────────────────────────────────────────────── │
# │                                                                            │
# │   Validate inputs at the boundary. Report errors immediately.             │
# │   Never silently swallow problems or defer validation.                    │
# │                                                                            │
# │   Fail Fast means:                                                         │
# │     - Parameter validation attributes ([ValidateNotNullOrEmpty()],        │
# │       [ValidateSet()], [ValidateRange()]) catch bad input BEFORE the      │
# │       function body runs                                                  │
# │     - Business rule validation happens at the TOP of the Process block,   │
# │       not deep inside nested logic                                        │
# │     - Errors are reported via New-ErrorRecord at the point of detection,  │
# │       not collected and reported later                                    │
# │     - $ErrorActionPreference = 'Stop' promotes all errors to             │
# │       terminating, ensuring they are never silently ignored               │
# │                                                                            │
# │ ── Least Privilege ────────────────────────────────────────────────────── │
# │                                                                            │
# │   Only request the minimum permissions and access needed.                 │
# │                                                                            │
# │   Least Privilege means:                                                   │
# │     - Registry keys opened READ-ONLY ($False on OpenSubKey) unless       │
# │       write access is explicitly required and documented                  │
# │     - File handles opened with minimum access (Read, not ReadWrite)       │
# │     - Network connections use least-privilege credentials                  │
# │     - Variables scoped as Private by default when that improves           │
# │       recursion safety and scope isolation; relax only when child-scope   │
# │       visibility is explicitly needed (e.g., & { process { } } blocks)    │
# │     - Scripts do NOT require -RunAsAdministrator unless they              │
# │       genuinely need it                                                   │
# │                                                                            │
# │ ── Least Surprise ────────────────────────────────────────────────────── │
# │                                                                            │
# │   Code MUST behave exactly as a reader would expect from its name,       │
# │   parameters, and documentation. No hidden side effects.                  │
# │                                                                            │
# │   Least Surprise means:                                                    │
# │     - Function names use approved verbs that match their behavior         │
# │       (Get- retrieves, Set- modifies, Test- returns bool, New- creates)  │
# │     - A function that accepts pipeline input processes ALL items,         │
# │       not just the first                                                  │
# │     - A function that returns [System.Boolean] returns ONLY               │
# │       $True or $False, never a truthy/falsy value                        │
# │     - Parameters named the same across functions behave the same way     │
# │     - Default parameter values produce the safest behavior,              │
# │       not the most convenient                                             │
# │                                                                            │
# │ ── YAGNI (You Aren't Gonna Need It) ───────────────────────────────────── │
# │                                                                            │
# │   Do not build for hypothetical future requirements. Solve the problem   │
# │   that exists today. Features, parameters, and abstractions that serve   │
# │   no current use case MUST NOT be added "just in case."                  │
# │                                                                            │
# │ ── Idempotency ────────────────────────────────────────────────────────── │
# │                                                                            │
# │   Running the same script or function twice with the same inputs MUST    │
# │   produce the same result and leave the system in the same state.        │
# │   This is critical for scripts deployed remotely where retries and       │
# │   re-runs are common. Functions must not fail on second execution        │
# │   because of state left behind by the first.                             │
# │                                                                            │
# │ ── Explicit Over Implicit ─────────────────────────────────────────────── │
# │                                                                            │
# │   Never rely on PowerShell's implicit behaviors. This is the             │
# │   foundational principle that drives every syntax rule in this document:  │
# │   explicit types, explicit casts, explicit comparisons, explicit         │
# │   parameter binding, explicit variable scoping. If PowerShell would      │
# │   "figure it out automatically," write it out explicitly instead.        │
# └──────────────────────────────────────────────────────────────────────────────┘


# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ 1.2 — COMPLIANCE                                                          │
# │                                                                            │
# │ All code MUST strictly follow:                                             │
# │   1. The PowerShell Practice and Style Guide as the baseline               │
# │   2. One True Brace Style (OTBS) for all brace placement                  │
# │   3. PSScriptAnalyzer — zero warnings/errors required                      │
# │   4. THIS document, which takes precedence where it differs               │
# │                                                                            │
# │ POWERSHELL VERSION:                                                        │
# │   Baseline is PowerShell 5.1 — the default on all officially supported    │
# │   Microsoft operating systems. PS 7+ features (ternary, null-coalescing,  │
# │   pipeline chain operators, ActionPreference::Break) MUST NOT be used     │
# │   unless explicitly guarded with a version check.                          │
# │   Every script MUST include: #Requires -Version 5.1                        │
# │                                                                            │
# │ ENCODING REQUIREMENT FOR PS 5.1:                                           │
# │   Scripts, modules, and data files that target the PS 5.1 baseline MUST   │
# │   be saved as UTF-8 with BOM. This is REQUIRED for any file containing     │
# │   non-ASCII characters and is the default for this codebase.               │
# └──────────────────────────────────────────────────────────────────────────────┘


# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ 1.3 — FORMATTING                                                          │
# │                                                                            │
# │ INDENTATION:                                                               │
# │   2 spaces per indent level. NEVER tabs.                                  │
# │                                                                            │
# │ LINE LENGTH:                                                               │
# │   Maximum 96 characters, STRICTLY ENFORCED on everything.                  │
# │   Use backtick line continuation with visual indicator:                    │
# │     # --- [ Line Continuation ] ————↴                                     │
# │   Align continued parameters vertically.                                   │
# │                                                                            │
# │ BRACE PLACEMENT — ONE TRUE BRACE STYLE (OTBS):                            │
# │   Opening brace on same line:    If (...) {    Try {    Function X {      │
# │   Continuation on same line:     } Else {   } Catch {   } Process {      │
# │   Closing brace alone:           }  (at keyword's indent level)           │
# │                                                                            │
# │ CASING — PascalCase everywhere:                                            │
# │   Keywords:    If, Try, Catch, Begin, Process, End, Function, Switch      │
# │   Cmdlets:     Write-Debug, Set-Variable (canonical from Get-Command)     │
# │   Variables:   $FileExists, $Result (match declaration casing always)     │
# │   Parameters:  -Name, -Value, -Force                                      │
# │   Constants:   $True, $False, $Null                                       │
# │   .NET Types:  Exact casing from documentation                            │
# │                                                                            │
# │ SPACING:                                                                   │
# │   Spaces around operators:     $X -eq $True   (never $X-eq$True)          │
# │   Space after commas:          'A', 'B', 'C'  (never 'A','B','C')        │
# │   No space in colon-bind:      -Name:'Value'  (never -Name: 'Value')     │
# │                                                                            │
# │ BLANK LINES:                                                               │
# │   1 between logical sections, 2 between major blocks, max 2 consecutive  │
# │   No trailing blank lines at end of file                                   │
# │                                                                            │
# │ COMMENTS:                                                                  │
# │   Always '# ' with space after hash                                       │
# │   End-of-line: 2+ spaces before #, use sparingly                          │
# │   NEVER commented-out code in committed files                              │
# │                                                                            │
# │ FILE ORGANIZATION:                                                         │
# │   One function per file, file named after function                         │
# │   Companion .strings.psd1 in the same directory                           │
# └──────────────────────────────────────────────────────────────────────────────┘


# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ 1.4 — SYNTAX RULES                                                        │
# │                                                                            │
# │ COLON-BOUND PARAMETERS:                                                    │
# │   ALWAYS: -Name:'Value'       NEVER: -Name 'Value'                        │
# │   Eliminates parsing ambiguity where PS can misinterpret space-separated  │
# │   values as positional arguments to a different parameter.                 │
# │                                                                            │
# │   SWITCH PARAMETERS:                                                       │
# │   Switch parameters that need an explicit value MUST be colon-bound:      │
# │     -Verbose:$False    -Force:$True    -Step:$False                        │
# │   Standalone switch activation (no explicit value) uses bare form:        │
# │     -Force    -Recurse    -WhatIf                                         │
# │   WHY: Colon-binding a switch to $True is redundant with the bare form.  │
# │   But when setting a switch to $False (overriding a default), the colon   │
# │   is REQUIRED to bind the $False value.                                   │
# │                                                                            │
# │ NAMED PARAMETERS ONLY:                                                     │
# │   ALWAYS: Get-ChildItem -Path:'C:\Temp'                                   │
# │   NEVER:  Get-ChildItem 'C:\Temp'                                         │
# │   Positional arguments require knowing parameter order by heart.           │
# │   Set PositionalBinding = $False on all CmdletBinding to enforce.         │
# │                                                                            │
# │ LEADING COMMAS IN ATTRIBUTES:                                              │
# │   Every line in [CmdletBinding()] and [Parameter()] starts with comma.    │
# │   First line is blank comma. Allows any line to be commented out with #.  │
# │     [CmdletBinding(                                                        │
# │       , ConfirmImpact = 'Low'                                              │
# │       , DefaultParameterSetName = 'Default'                                │
# │     )]                                                                     │
# │                                                                            │
# │ SINGLE QUOTES:                                                             │
# │   ALWAYS single quotes for string literals: 'text'                         │
# │   Only double quotes when INTENTIONALLY interpolating.                     │
# │                                                                            │
# │ PARENTHESIZED PARAMETER VALUES:                                            │
# │   ALWAYS: -Option:('Private')                                              │
# │   Normalizes syntax with multi-value form: -Option:('Private','ReadOnly') │
# │                                                                            │
# │ ALIASES & SHORTHAND — NEVER USE:                                           │
# │   Where-Object (not ? or where), Select-Object (not select)               │
# │   Get-ChildItem (not ls/dir/gci), Set-Location (not cd)                   │
# │   $PSItem (NEVER $_)                                                       │
# │                                                                            │
# │ BACKTICK RULES:                                                            │
# │   Escape sequences ALLOWED: `n `t `r `0 (universally understood)          │
# │   Line continuation REQUIRES visual indicator comment above               │
# │                                                                            │
# │ SEMICOLONS:                                                                │
# │   NEVER, except for a grouped $Null declaration line used to inventory     │
# │   managed working-state variables at the top of a block.                   │
# │   Example: $Var1 = $Null; $Var2 = $Null; $Var3 = $Null                     │
# └──────────────────────────────────────────────────────────────────────────────┘


# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ 1.5 — TYPE RULES                                                          │
# │                                                                            │
# │ FULL .NET TYPE NAMES ONLY:                                                 │
# │   [System.String]   not [string]    [System.Int32]   not [int]            │
# │   [System.Boolean]  not [bool]      [System.Int64]   not [long]           │
# │   [System.Array]    not [array]     [System.Object]  not [object]         │
# │   PS type aliases can trigger implicit type coercion.                      │
# │                                                                            │
# │ EXPLICIT CASTS ON ALL EXPRESSIONS:                                         │
# │   [System.Boolean]($X -eq $Y)  — even when -eq already returns bool      │
# │   Guards against edge cases (array comparison returns elements, not bool) │
# │                                                                            │
# │ [OutputType()] REQUIRED on every function.                                 │
# │                                                                            │
# │ COLLECTION TYPE SELECTION:                                                 │
# │   FIXED-SIZE:    [System.String[]], [System.Int32[]]                       │
# │   DYNAMIC-SIZE:  [System.Collections.ArrayList]                            │
# │                  [System.Collections.Generic.List[System.String]]          │
# │   KEY-VALUE:     [System.Collections.Hashtable]                            │
# │                  [System.Collections.Specialized.OrderedDictionary]        │
# │   NEVER use [System.Array] += in loops — it's O(n^2) and catastrophic.   │
# │   ArrayList/List.Add() is O(1) amortized.                                 │
# └──────────────────────────────────────────────────────────────────────────────┘


# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ 1.6 — VARIABLE MANAGEMENT                                                 │
# │                                                                            │
# │ HOUSE STYLE: explicit variable lifecycle for working state.                │
# │   This is a project convention chosen for debug visibility, scope control, │
# │   and protection against recursion/scope bugs. It is not a PowerShell      │
# │   language requirement or a universal industry rule.                       │
# │                                                                            │
# │   New-Variable    — Declare mutable working state in Begin                 │
# │   Set-Variable    — Assign in Process                                      │
# │   Clear-Variable  — Clear per-item state at top of Process                 │
# │   Remove-Variable — Remove in End for explicit lifecycle cleanup           │
# │                                                                            │
# │ All three lists (New/Clear/Remove) MUST match for variables managed by     │
# │ this convention — they cross-reference.                                    │
# │                                                                            │
# │ STANDARD FLAGS:                                                            │
# │   -Force               — Safe re-execution during development             │
# │   -Option:('Private')  — Default for mutable working state when child      │
# │                           scope access is not required                     │
# │   -Value:$Null          — Separates declaration from assignment            │
# │                                                                            │
# │ STATIC VARIABLES:                                                          │
# │   -Option:('Private','ReadOnly')  — Prevent accidental modification       │
# │                                                                            │
# │ EXCEPTION — Import-LocalizedData:                                          │
# │   Creates its own variable via -BindingVariable:'Strings'.                │
# │   Not declared via New-Variable, but MUST be in Remove-Variable.          │
# │   Not in Clear-Variable (it's static across pipeline items).              │
# │                                                                            │
# │ EXCEPTION — Trivial temporaries:                                            │
# │   One-line temporaries and obvious loop locals MAY use plain $Var = ...    │
# │   when explicit lifecycle management would add ceremony without value.     │
# │                                                                            │
# │ EXCEPTION — Grouped $Null declaration list:                                 │
# │   At the top of Begin or Process, a single semicolon-delimited line MAY    │
# │   declare multiple managed variables to $Null when the goal is compact      │
# │   variable inventory. Use this only for declaration/reset, not logic.      │
# │   Example: $FileExists = $Null; $FileHashMatches = $Null                    │
# │                                                                            │
# │ EXCEPTION — For loop iterator:                                             │
# │   For loops manage their own iterator variable ($I).                       │
# │   Include in Remove-Variable cleanup only when it is promoted into this    │
# │   convention's managed variable set.                                       │
# └──────────────────────────────────────────────────────────────────────────────┘


# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ 1.7 — STRING FORMATTING                                                   │
# │                                                                            │
# │ STANDARD: the -f (format) operator                                         │
# │   'File {0} is {1} bytes' -f $Name, $Size                                 │
# │                                                                            │
# │ NEVER double-quote interpolation: "Value: $Var"                            │
# │   -f keeps template and values visually separated                          │
# │   No risk of accidental variable expansion                                 │
# │   More concise than [System.String]::Format() with identical behavior     │
# │                                                                            │
# │ HERE-STRINGS: @' '@ by default, @" "@ only for interpolation             │
# └──────────────────────────────────────────────────────────────────────────────┘


# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ 1.8 — CONTROL FLOW                                                        │
# │                                                                            │
# │ PRE-EVALUATE CONDITIONS:                                                   │
# │   Evaluate each condition into an explicitly typed variable BEFORE the    │
# │   If block. Never put complex expressions inside If().                    │
# │   WHY: Readable, debuggable (inspect at breakpoint), no side effects.     │
# │                                                                            │
# │ EXPLICIT BOOL COMPARISON:                                                  │
# │   ALWAYS: ($Var -eq $True)      NEVER: ($Var)                             │
# │   ALWAYS: ($Var -eq $False)     NEVER: (-not $Var) or (!$Var)             │
# │   Reads as plain English, prevents truthy/falsy gotchas.                  │
# │                                                                            │
# │ NULL ON LEFT SIDE:                                                         │
# │   ALWAYS: ($Null -eq $Var)      NEVER: ($Var -eq $Null)                   │
# │   GOTCHA: If $Var is array, ($Var -eq $Null) returns null elements.       │
# │                                                                            │
# │ SUB-CONDITION WRAPPING:                                                    │
# │   ($A -eq $True) -and ($B -eq $True)                                      │
# │   NEVER: $A -eq $True -and $B -eq $True                                   │
# │                                                                            │
# │ OPERATORS:                                                                 │
# │   Use -and / -or / -not       NEVER: && || !                              │
# │                                                                            │
# │ SWITCH vs IF/ELSEIF:                                                       │
# │   Switch for 3+ conditions against one value (compiled jump table).       │
# │   If/ElseIf for 1-2 conditions or complex boolean logic.                  │
# │                                                                            │
# │ PIPELINE OUTPUT — "SOFT RETURN":                                           │
# │   Emit results by placing variable on its own line: $Result               │
# │   NEVER: return $Result (exits function, skips debug messages)            │
# └──────────────────────────────────────────────────────────────────────────────┘


# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ 1.9 — ERROR HANDLING                                                       │
# │                                                                            │
# │ ALL errors MUST be reported via New-ErrorRecord.                           │
# │ NEVER: bare 'throw', 'Write-Error -Message:...', or 'exit'.              │
# │                                                                            │
# │ Try/Catch/Finally around ANY cmdlet that can fail.                         │
# │ -ErrorAction:'Stop' is set globally by the script template.               │
# │                                                                            │
# │ CATCH BLOCKS:                                                              │
# │   Fully qualified .NET exception types for specific errors:               │
# │     Catch [System.IO.IOException] { ... }                                 │
# │   Bare Catch { } as final fallback for unexpected errors.                 │
# │                                                                            │
# │ FINALLY:                                                                   │
# │   Release resources (file handles, connections). Omit if not needed.      │
# │                                                                            │
# │ FATAL ERRORS:                                                              │
# │   -IsFatal:$True ONLY as absolute last resort.                            │
# │   $PSCmdlet.ThrowTerminatingError() — NEVER 'exit'.                       │
# │   Maximum effort to keep errors non-fatal for pipeline continuity.        │
# │                                                                            │
# │ SCRIPT-LEVEL TRAP (the ONE exception):                                     │
# │   Write-Host and Exit ARE allowed in a script-level Trap because          │
# │   error streams may be compromised and $PSCmdlet is unavailable.          │
# └──────────────────────────────────────────────────────────────────────────────┘


# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ 1.10 — OUTPUT STREAMS                                                     │
# │                                                                            │
# │ Write-Debug       Internal tracing (entry/exit, variable states)          │
# │                   Only visible with -Debug flag                           │
# │ Write-Verbose     Operational progress ("Checking file X...")             │
# │                   Visible with -Verbose flag                              │
# │ Write-Warning     Non-fatal problems (always visible, yellow)             │
# │                   Messages from .strings.psd1                             │
# │ Write-Information  Structured log data (PS 5.1+)                           │
# │                   Capturable via -InformationAction or 6>                 │
# │ Write-Error       ONLY via New-ErrorRecord, never directly                │
# │                                                                            │
# │ NEVER in functions:                                                        │
# │   Write-Host    — Cannot be captured/redirected/suppressed                │
# │   Write-Output  — Redundant, use pipeline emission                        │
# │   'return'      — Exits function, skips cleanup and debug messages        │
# └──────────────────────────────────────────────────────────────────────────────┘


# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ 1.11 — LOCALIZED STRING DATA (DSC-Inspired)                               │
# │                                                                            │
# │ Every function file has a companion .strings.psd1 in the same directory.  │
# │ Loaded via Import-LocalizedData in the Begin block.                        │
# │                                                                            │
# │ WHAT GOES IN .strings.psd1:                                                │
# │   ALL user-facing messages: errors (New-ErrorRecord) AND warnings          │
# │   NOT debug or verbose messages (developer diagnostics stay inline)       │
# │                                                                            │
# │ KEY NAMING:                                                                │
# │   <Condition>_Message  — Error messages (for New-ErrorRecord)             │
# │   <Condition>_Warning  — Warning messages (for Write-Warning)             │
# │   Use {0}, {1} format placeholders, filled via -f operator                │
# │   Error IDs and Categories stay inline in code                            │
# │                                                                            │
# │ VARIABLE NAME: -BindingVariable:'Strings' (standard across repo)          │
# │ FILENAME: '<FunctionName>.strings' (Import-LocalizedData appends .psd1)  │
# │                                                                            │
# │ WHY: DSC-inspired, centralizes messages for review/audit, supports        │
# │ future localization, per-file strings can be compiled during build.       │
# └──────────────────────────────────────────────────────────────────────────────┘


# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ 1.12 — .NET OVER CMDLETS                                                  │
# │                                                                            │
# │ Prefer .NET APIs for data access — faster and more capable.               │
# │                                                                            │
# │ REGISTRY:                                                                  │
# │   [Microsoft.Win32.RegistryKey]    NOT Get-ItemProperty                   │
# │   Supports read-only access, specific hives, 32/64-bit views             │
# │                                                                            │
# │ FILE SYSTEM:                                                               │
# │   [System.IO.File]::Exists()      NOT Test-Path                           │
# │   [System.IO.File]::ReadAllText() NOT Get-Content                         │
# │   [System.IO.Directory]::GetFiles() NOT Get-ChildItem                    │
# │                                                                            │
# │ STRINGS:                                                                   │
# │   [System.String]::IsNullOrEmpty() NOT ($Null -eq $X -or $X -eq '')      │
# │   [System.Text.StringBuilder]      NOT repeated += concatenation          │
# │                                                                            │
# │ PROPERTY/METHOD ACCESS:                                                    │
# │   $Object.Property directly        NOT wrapping in cmdlets                │
# │   $Object.Method() directly        NOT piping through cmdlets             │
# │   [Type]::StaticMethod()           for utility operations                 │
# │                                                                            │
# │ OBJECT CONSTRUCTION: See section 1.21                                      │
# │                                                                            │
# │ EXCEPTION: Pipeline control flow stays PS-native:                         │
# │   & { process { } } for iteration, Where-Object for filtering            │
# └──────────────────────────────────────────────────────────────────────────────┘


# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ 1.13 — LOOPS & PIPELINE                                                   │
# │                                                                            │
# │ ITERATION — & { process { } } PATTERN:                                    │
# │   STANDARD: $Items | & { process { $PSItem } }                            │
# │   NEVER:    ForEach-Object (6.7x slower, 115x on ScriptBlock Logging)    │
# │   NEVER:    foreach keyword                                               │
# │   Ref: https://powershell.one/tricks/performance/pipeline                 │
# │                                                                            │
# │ SCOPE WARNING:                                                             │
# │   & { } creates a CHILD SCOPE. Variables with -Option:('Private') are    │
# │   NOT visible. Use -Option:('ReadOnly') or omit -Option for variables    │
# │   that must be accessed inside the scriptblock.                           │
# │                                                                            │
# │ AUTOMATIC VARIABLE:                                                        │
# │   ALWAYS $PSItem, NEVER $_                                                │
# │                                                                            │
# │ FILTERING:                                                                 │
# │   Where-Object -FilterScript:{ $PSItem.Size -gt 0 }                      │
# │                                                                            │
# │ PIPELINE FORMATTING:                                                       │
# │   One stage per line when exceeding 96 chars                              │
# │   Pipe | at end of line (auto-continues, no backtick needed)              │
# │   Indent continuation lines by 2 spaces                                   │
# └──────────────────────────────────────────────────────────────────────────────┘


# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ 1.14 — FUNCTION STRUCTURE                                                 │
# │                                                                            │
# │ Every function MUST have:                                                  │
# │   1. Function Verb-Noun { } wrapper (approved verbs from Get-Verb)        │
# │   2. Comment-based help (.SYNOPSIS, .DESCRIPTION, .PARAMETER, .EXAMPLE,  │
# │      .OUTPUTS, .NOTES)                                                    │
# │   3. [CmdletBinding()] — list ALL properties explicitly                   │
# │   4. [OutputType()] — full .NET type name                                 │
# │   5. Param() block — ALL [Parameter()] properties listed explicitly       │
# │   6. Begin / Process / End blocks by default                              │
# │   7. Write-Debug at entry/exit of each lifecycle block when those blocks  │
# │      are present:                                                         │
# │        '[FunctionName] Entering/Leaving Block: Begin/Process/End'         │
# │   8. Import-LocalizedData in Begin when localized strings are used        │
# │   9. Managed working state declared in Begin, cleared in Process, and     │
# │      removed in End when using this convention                            │
# │                                                                            │
# │ EXCLUDING BEGIN / PROCESS / END IS ACCEPTABLE ONLY WHEN ALL ARE TRUE:     │
# │   - The function does not accept pipeline input                           │
# │   - The function has no per-item state to reset between pipeline items    │
# │   - The function does not need block-specific setup or cleanup            │
# │   - Omitting the blocks makes the helper materially simpler to read       │
# │                                                                            │
# │ IF ANY OF THE FOLLOWING ARE TRUE, USE BEGIN / PROCESS / END:              │
# │   - Pipeline input is accepted                                            │
# │   - Per-item working state is managed                                     │
# │   - Localized data, shared setup, or teardown is needed                   │
# │   - Block-level tracing materially helps debugging                        │
# │                                                                            │
# │ PARAMETERS:                                                                │
# │   [Switch] for presence/absence flags                                     │
# │   [System.Boolean] only when callers must pass true/false as data         │
# │   Use built-in validators (ValidateSet, ValidateRange, ValidatePattern)   │
# │   AVOID [ValidateScript({})] — validate in Process with New-ErrorRecord   │
# │   List ALL [Parameter()] properties, even when using default value        │
# └──────────────────────────────────────────────────────────────────────────────┘


# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ 1.15 — SHOULDPROCESS (-WhatIf / -Confirm)                                 │
# │                                                                            │
# │ WHEN TO IMPLEMENT:                                                         │
# │   Any function that modifies system state (uninstalls software, deletes   │
# │   files, changes registry, stops services) MUST declare:                  │
# │     SupportsShouldProcess = $True                                         │
# │   Functions that only READ data MUST NOT declare ShouldProcess.           │
# │                                                                            │
# │ CONFIRM IMPACT:                                                            │
# │   Low    — Routine, easily reversible (rename a file)                     │
# │   Medium — Significant but recoverable (stop a service)                   │
# │   High   — Destructive or hard to reverse (uninstall software, delete)    │
# │   Set ConfirmImpact to match the destructiveness of the operation.        │
# │                                                                            │
# │ USAGE PATTERN:                                                             │
# │   Guard EVERY state-changing operation with ShouldProcess:                │
# │     If ($PSCmdlet.ShouldProcess($Target, 'Action') -eq $True) {          │
# │       # Perform the action                                                │
# │     }                                                                      │
# │   $Target = what is being acted on (e.g., app display name)              │
# │   'Action' = what will happen (e.g., 'Uninstall')                        │
# │                                                                            │
# │ CALLER CONTROL:                                                            │
# │   -WhatIf     Shows what would happen without doing it                    │
# │   -Confirm    Prompts before each action                                  │
# │   -Confirm:$False  Suppresses prompts (for automation)                    │
# └──────────────────────────────────────────────────────────────────────────────┘


# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ 1.16 — FILE ENCODING                                                      │
# │                                                                            │
# │ ALL .ps1 and .psd1 files MUST be saved as UTF-8 with BOM.                │
# │                                                                            │
# │ WHY:                                                                       │
# │   PowerShell 5.1 defaults to the system's ANSI codepage for files        │
# │   without a BOM. This silently corrupts non-ASCII characters             │
# │   (accented names, Unicode strings in .strings.psd1, etc.).              │
# │   The BOM tells PS 5.1 to read the file as UTF-8.                        │
# │   PS 7+ defaults to UTF-8 regardless, so the BOM is harmless there.     │
# │                                                                            │
# │ ENFORCEMENT:                                                               │
# │   .editorconfig: charset = utf-8-bom for *.ps1 and *.psd1               │
# │   CI/CD should verify encoding on all committed files.                    │
# └──────────────────────────────────────────────────────────────────────────────┘


# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ 1.17 — #REQUIRES DIRECTIVE                                                │
# │                                                                            │
# │ Every script MUST include:                                                 │
# │   #Requires -Version 5.1                                                  │
# │                                                                            │
# │ Additional directives as needed:                                           │
# │   #Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0' }       │
# │   #Requires -RunAsAdministrator  (ONLY when genuinely needed —            │
# │     per Least Privilege, avoid this unless the script cannot function     │
# │     without elevation)                                                    │
# │                                                                            │
# │ #Requires MUST appear AFTER the comment-based help block and BEFORE      │
# │ [CmdletBinding()]. It is a parse-time directive, not a runtime check.    │
# └──────────────────────────────────────────────────────────────────────────────┘


# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ 1.18 — PESTER TESTING CONVENTIONS                                         │
# │                                                                            │
# │ STRUCTURE:                                                                 │
# │   tests/ directory mirrors src/ directory structure:                       │
# │     src/Private/Get-Thing.ps1 → tests/Private/Get-Thing.Tests.ps1        │
# │     src/Public/Start-Thing.ps1 → tests/Public/Start-Thing.Tests.ps1      │
# │   Test file naming: <FunctionName>.Tests.ps1                              │
# │                                                                            │
# │ TEST SKELETON:                                                             │
# │   BeforeAll {                                                              │
# │     . "$PSScriptRoot\..\..\build\<BuildOutput>.ps1"                       │
# │   }                                                                        │
# │   Describe '<FunctionName>' {                                             │
# │     Context '<scenario>' {                                                │
# │       It '<specific assertion>' { ... }                                   │
# │     }                                                                      │
# │   }                                                                        │
# │                                                                            │
# │ REQUIREMENTS:                                                              │
# │   - Every function in src/ has a corresponding .Tests.ps1                 │
# │   - Every code path (If/Else/Switch case) is exercised                    │
# │   - Both success AND failure paths are tested                             │
# │   - PSTypeName verified on ALL returned PSCustomObjects                   │
# │   - Error/warning messages verified against .strings.psd1 content        │
# │   - Tests target the compiled build output, not individual source files  │
# │                                                                            │
# │ MOCKING:                                                                   │
# │   - Mock external dependencies (registry, file system, network)           │
# │   - Do NOT mock internal functions unless testing orchestrator logic      │
# │   - Use Pester's Mock command with -CommandName parameter                 │
# └──────────────────────────────────────────────────────────────────────────────┘


# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ 1.19 — CREDENTIALS & SECRETS                                              │
# │                                                                            │
# │ NEVER:                                                                     │
# │   - Hardcode passwords, API keys, or tokens in source code                │
# │   - Store secrets in .strings.psd1 or any committed file                  │
# │   - Log or Write-Verbose credential values                                │
# │   - Pass credentials as plain [System.String] parameters                  │
# │                                                                            │
# │ ALWAYS:                                                                    │
# │   - Use [System.Management.Automation.PSCredential] for credentials      │
# │   - Accept credentials as parameters, never prompt interactively          │
# │     inside functions (the caller decides how to obtain them)              │
# │   - Use [System.Security.SecureString] for sensitive string data         │
# │   - Source secrets from environment variables, vaults, or secure          │
# │     parameter input — never from files in the repo                        │
# └──────────────────────────────────────────────────────────────────────────────┘


# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ 1.20 — REGION / ENDREGION                                                 │
# │                                                                            │
# │ Scripts MUST use regions for major structural sections:                    │
# │   #region ------ [ Initialization ] ---------------------------------- #  │
# │   #endregion --- [ Initialization ] ---------------------------------- #  │
# │                                                                            │
# │ REQUIRED regions in scripts (from ScriptTemplate.ps1):                    │
# │   Initialization, Functions, Execution, Cleanup                           │
# │                                                                            │
# │ Functions do NOT use regions — the Begin/Process/End blocks provide      │
# │ sufficient structure.                                                     │
# │                                                                            │
# │ NEVER nest regions. Keep them flat and top-level.                         │
# └──────────────────────────────────────────────────────────────────────────────┘


# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ 1.21 — OBJECT CONSTRUCTION                                                │
# │                                                                            │
# │ Both [Type]::new() and New-Object are acceptable:                         │
# │                                                                            │
# │   [Type]::new()              — Preferred for most construction.           │
# │     Concise, readable, matches C#/.NET patterns. Use when the            │
# │     type and constructor arguments are known at write time.              │
# │                                                                            │
# │   New-Object -TypeName:'X'   — Use when the type name is dynamic         │
# │     (stored in a variable) or when -ArgumentList annotation comments     │
# │     improve readability for complex constructors:                         │
# │       New-Object -TypeName:'System.Text.RegularExpressions.Regex' `      │
# │         -ArgumentList:(                                                   │
# │           # [System.String] pattern                                       │
# │           'mypattern',                                                    │
# │           # [System.Text.RegularExpressions.RegexOptions] options         │
# │           $RegexOptions                                                   │
# │         )                                                                 │
# │                                                                            │
# │ RULE: Choose whichever form is CLEAREST for the specific call site.      │
# │ Simple constructors → [Type]::new(). Complex/dynamic → New-Object.       │
# └──────────────────────────────────────────────────────────────────────────────┘


# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                                                                            ║
# ║                     PART 2 — SCRIPT TEMPLATE                               ║
# ║                                                                            ║
# ║  Every script starts with this initialization pattern. It configures       ║
# ║  logging, debugging, strict mode, error handling, and execution context.  ║
# ║                                                                            ║
# ╚══════════════════════════════════════════════════════════════════════════════╝


# ── The script template begins below. In production, this IS your .ps1 file.

<#
  .SYNOPSIS
    [One-line summary of what this script does.]

  .DESCRIPTION
    [Detailed explanation of the script's purpose, behavior,
    and any prerequisites or assumptions.]

    All scripts in this repo baseline PowerShell 5.1, which is
    the default on all officially supported Microsoft operating
    systems. PS 7+ features must NOT be used unless explicitly
    guarded with a version check.

  .PARAMETER LogLevel
    A 7-digit string controlling the ActionPreference for each
    output stream. Each digit (0-4) maps to an ActionPreference:
      0 = SilentlyContinue  (suppress output)
      1 = Stop              (halt on this stream)
      2 = Continue          (display and continue)
      3 = Inquire           (prompt the user)
      4 = Ignore            (suppress, not even in $Error)

    Digit positions map to streams in this order:
      [0] Verbose, [1] Debug, [2] Information,
      [3] Warning, [4] Error, [5] Fatal, [6] Progress

    Digits 0-3, 6 map to standard PS preference variables.
    Digits 4-5 map to CUSTOM preference variables used by
    application logic — SEPARATE from $ErrorActionPreference.

    Default: '0022130'

  .PARAMETER DebugLevel
    A 3-digit string controlling debug/diagnostic behavior:
      Digit 0 — ErrorActionPreference (0=Silent, 1=Stop)
      Digit 1 — Set-PSDebug trace (0=Off, 1-4=Trace+Step)
      Digit 2 — Set-StrictMode (0=Off, 1=v1, 2=v2, 3=v3)

    Default: '003' (ErrorAction=Silent, Trace=Off, Strict=v3)

  .EXAMPLE
    .\MyScript.ps1

  .EXAMPLE
    .\MyScript.ps1 -LogLevel:'2222130' -DebugLevel:'103'

  .NOTES
    Author  : HellBomb
    Version : 1.0.0

    PowerShell Compatibility:
      Baseline  : 5.1 (Windows PowerShell)
      Tested On : 5.1, 7.x
#>

#Requires -Version 5.1

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
  'PSUseProcessBlockForPipelineCommand', '',
  Justification = 'Script-level parameters do not require a process block.'
)]

[CmdletBinding(
  , ConfirmImpact = 'Low'
  , DefaultParameterSetName = 'Default'
  , HelpURI = ''
  , PositionalBinding = $False
  , SupportsShouldProcess = $False
)]

Param (
  [Parameter(
    , DontShow = $False
    , HelpMessage = '7-digit ActionPreference per output stream.'
    , Mandatory = $False
    , ParameterSetName = 'Default'
    , Position = 0
    , ValueFromPipeline = $False
    , ValueFromPipelineByPropertyName = $False
    , ValueFromRemainingArguments = $False
  )]
  [ValidatePattern('^[0-4]{7}$')]
  [System.String]
  $LogLevel = '0022130',

  [Parameter(
    , DontShow = $False
    , HelpMessage = '3-digit debug/trace/strict configuration.'
    , Mandatory = $False
    , ParameterSetName = 'Default'
    , Position = 1
    , ValueFromPipeline = $False
    , ValueFromPipelineByPropertyName = $False
    , ValueFromRemainingArguments = $False
  )]
  [ValidatePattern('^[01][0-4][0-3]$')]
  [System.String]
  $DebugLevel = '003'
)


#region ------ [ Initialization ] ---------------------------------------- #

# ── Static Constants ────────────────────────────────────────────────────

New-Variable -Verbose:$False -Force -Name:'LOG_LEVELS' -Option:('Private', 'ReadOnly') -Value:(
  [System.String[]]@(
    'Verbose',      # [0] → $VerbosePreference     (standard)
    'Debug',        # [1] → $DebugPreference        (standard)
    'Information',  # [2] → $InformationPreference  (standard)
    'Warning',      # [3] → $WarningPreference      (standard)
    'Error',        # [4] → $ErrorPreference         (CUSTOM)
    'Fatal',        # [5] → $FatalPreference         (CUSTOM)
    'Progress'      # [6] → $ProgressPreference     (standard)
  )
)

# Explicit digit-to-enum mapping (0-4 for PS 5.1 compatibility)
New-Variable -Verbose:$False -Force -Name:'ACTION_PREFS' -Option:('Private', 'ReadOnly') -Value:(
  [System.Collections.Hashtable]@{
    '0' = [System.Management.Automation.ActionPreference]::SilentlyContinue
    '1' = [System.Management.Automation.ActionPreference]::Stop
    '2' = [System.Management.Automation.ActionPreference]::Continue
    '3' = [System.Management.Automation.ActionPreference]::Inquire
    '4' = [System.Management.Automation.ActionPreference]::Ignore
  }
)

New-Variable -Verbose:$False -Force -Name:'ExitCode' -Value:([System.Int32](0))


# ── Trap (Script-Level Last Resort) ────────────────────────────────────

Trap {
  If ($PSItem.Exception.PSObject.Properties.Name -Contains 'ErrorRecord') {
    Write-Debug -Message:(
      'Failed to execute command: {0}' -f
        $PSItem.Exception.ErrorRecord.InvocationInfo.Line.Trim()
    )
  }
  New-Variable -Verbose:$False -Force -Name:'BaseExceptionType' -Value:(
    [System.String]$PSItem.Exception.GetBaseException().GetType().FullName
  )
  # --- [ Line Continuation ] ————↴
  Write-Host -ForegroundColor:'Red' -Object:(                    `
    '[{0}] [{1:0000}] {2} [{3}]' -f                             `
      [System.DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss.fff'),`
      [System.Int64]$PSItem.InvocationInfo.ScriptLineNumber,     `
      [System.String]$PSItem.Exception.Message,                  `
      $BaseExceptionType                                         `
  )
  Remove-Variable -Verbose:$False -Force -ErrorAction:'SilentlyContinue' -Name:'BaseExceptionType'
  If ($PSItem.Exception.WasThrownFromThrowStatement -eq $True) {
    Exit 1
  }
}


# ── Log Level Configuration ────────────────────────────────────────────

# DUAL ERROR VARIABLE DESIGN:
#   $ErrorPreference (custom, LogLevel[4]) — app-level error display
#   $FatalPreference (custom, LogLevel[5]) — app-level fatal handling
#   $ErrorActionPreference (standard, DebugLevel[0]) — PS engine behavior
#   These are intentionally separate.
For ($I = 0; $I -lt $LOG_LEVELS.Count; $I++) {
  Set-Variable -Verbose:$False -Force -Name:(
    '{0}Preference' -f $LOG_LEVELS[$I]
  ) -Value:(
    $ACTION_PREFS[$LogLevel[$I].ToString()]
  )
}


# ── Debug Level Configuration ──────────────────────────────────────────

Switch ($DebugLevel) {
  { $PSItem } {
    Set-Variable -Verbose:$False -Name:'ErrorActionPreference' -Value:(
      $ACTION_PREFS[$PSItem[0].ToString()]
    )
  }
  { $PSItem[1] -eq '0' } { Set-PSDebug -Off }
  { $PSItem[1] -eq '1' } { Set-PSDebug -Trace:1 -Step:$False }
  { $PSItem[1] -eq '2' } { Set-PSDebug -Trace:1 -Step:$True }
  { $PSItem[1] -eq '3' } { Set-PSDebug -Trace:2 -Step:$False }
  { $PSItem[1] -eq '4' } { Set-PSDebug -Trace:2 -Step:$True }
  { $PSItem[2] -eq '0' } { Set-StrictMode -Off }
  { $PSItem[2] -eq '1' } { Set-StrictMode -Version:'1.0' }
  { $PSItem[2] -eq '2' } { Set-StrictMode -Version:'2.0' }
  { $PSItem[2] -eq '3' } { Set-StrictMode -Version:'3.0' }
}


# ── Execution Context ──────────────────────────────────────────────────

New-Variable -Verbose:$False -Force -Name:'ENV' -Value:(
  [PSCustomObject]@{
    RunMethod = [System.String]::Empty
    Script    = [System.IO.FileInfo]$Null
    PSPath    = [System.IO.FileInfo]$Null
  }
)

$ENV.PSPath = New-Object -TypeName:'System.IO.FileInfo' -ArgumentList:(
  # [System.String] fileName
  [System.Diagnostics.Process]::GetCurrentProcess().Path
)

If (Test-Path -Path:'Variable:psISE') {
  $ENV.RunMethod = [System.String]'ISE'
  $ENV.Script = New-Object -TypeName:'System.IO.FileInfo' -ArgumentList:(
    # [System.String] fileName
    $psISE.CurrentFile.FullPath
  )
} ElseIf (Test-Path -Path:'Variable:psEditor') {
  $ENV.RunMethod = [System.String]'VSCode'
  $ENV.Script = New-Object -TypeName:'System.IO.FileInfo' -ArgumentList:(
    # [System.String] fileName
    $psEditor.GetEditorContext().CurrentFile.Path
  )
} Else {
  $ENV.RunMethod = [System.String]'Console'
  $ENV.Script = New-Object -TypeName:'System.IO.FileInfo' -ArgumentList:(
    # [System.String] fileName
    $MyInvocation.MyCommand.Path
  )
}

Set-Variable -Name:'ENV' -Option:('ReadOnly')

Remove-Variable -Verbose:$False -Force -ErrorAction:'SilentlyContinue' -Name:([System.Array](
  'I', 'ACTION_PREFS'
))

#endregion --- [ Initialization ] ---------------------------------------- #


# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                                                                            ║
# ║                     PART 3 — FUNCTION EXAMPLES                             ║
# ║                                                                            ║
# ║  In production, each function is in its own .ps1 file with a companion   ║
# ║  .strings.psd1. They are dot-sourced in the Functions region:             ║
# ║    . (Join-Path -Path:$ENV.Script.DirectoryName -ChildPath:'Func.ps1')   ║
# ║                                                                            ║
# ╚══════════════════════════════════════════════════════════════════════════════╝


#region ------ [ Functions ] --------------------------------------------- #


# ── FUNCTION: New-ErrorRecord ──────────────────────────────────────────
# The ONLY approved way to generate errors in this repo.

Function New-ErrorRecord {
  <#
    .SYNOPSIS
      Creates a structured ErrorRecord for consistent error reporting.

    .DESCRIPTION
      Constructs a [System.Management.Automation.ErrorRecord] from
      the given exception type, message, error ID, and category.

    .PARAMETER ExceptionName
      Full .NET type name of the exception to create.

    .PARAMETER ExceptionMessage
      Human-readable error message (from .strings.psd1).

    .PARAMETER TargetObject
      Object being processed when the error occurred.

    .PARAMETER ErrorId
      Unique identifier. Convention: 'FunctionName:ShortDescription'

    .PARAMETER ErrorCategory
      The ErrorCategory classification.

    .PARAMETER IsFatal
      When $True, raises as terminating via ThrowTerminatingError().

    .EXAMPLE
      # --- [ Line Continuation ] ————↴
      New-ErrorRecord                                              `
        -ExceptionName:'System.IO.FileNotFoundException'           `
        -ExceptionMessage:'File not found.'                        `
        -TargetObject:$FileInfo                                    `
        -ErrorId:'MyFunc:FileNotFound'                             `
        -ErrorCategory:'ObjectNotFound'                            `
        -IsFatal:$False

    .OUTPUTS
      [System.Management.Automation.ErrorRecord]

    .NOTES
      Author  : HellBomb
      Version : 1.0.0
  #>

  [CmdletBinding(
    , ConfirmImpact = 'Low'
    , DefaultParameterSetName = 'Default'
    , HelpURI = ''
    , PositionalBinding = $False
    , RemotingCapability = 'None'
    , SupportsPaging = $False
    , SupportsShouldProcess = $False
  )]

  [OutputType([System.Management.Automation.ErrorRecord])]

  Param (
    [Parameter(
      , DontShow = $False
      , HelpMessage = 'Full .NET exception type name.'
      , HelpMessageBaseName = 'NewErrorRecord'
      , HelpMessageResourceId = 'ExceptionNameHelpMessage'
      , Mandatory = $True
      , ParameterSetName = 'Default'
      , Position = 0
      , ValueFromPipeline = $False
      , ValueFromPipelineByPropertyName = $False
      , ValueFromRemainingArguments = $False
    )]
    [ValidateNotNullOrEmpty()]
    [System.String]
    $ExceptionName,

    [Parameter(
      , DontShow = $False
      , HelpMessage = 'Human-readable error message.'
      , HelpMessageBaseName = 'NewErrorRecord'
      , HelpMessageResourceId = 'ExceptionMessageHelpMessage'
      , Mandatory = $True
      , ParameterSetName = 'Default'
      , Position = 1
      , ValueFromPipeline = $False
      , ValueFromPipelineByPropertyName = $False
      , ValueFromRemainingArguments = $False
    )]
    [ValidateNotNullOrEmpty()]
    [System.String]
    $ExceptionMessage,

    [Parameter(
      , DontShow = $False
      , HelpMessage = 'Object being processed when error occurred.'
      , HelpMessageBaseName = 'NewErrorRecord'
      , HelpMessageResourceId = 'TargetObjectHelpMessage'
      , Mandatory = $False
      , ParameterSetName = 'Default'
      , Position = 2
      , ValueFromPipeline = $False
      , ValueFromPipelineByPropertyName = $False
      , ValueFromRemainingArguments = $False
    )]
    [System.Object]
    $TargetObject = $Null,

    [Parameter(
      , DontShow = $False
      , HelpMessage = 'Unique, searchable error identifier.'
      , HelpMessageBaseName = 'NewErrorRecord'
      , HelpMessageResourceId = 'ErrorIdHelpMessage'
      , Mandatory = $True
      , ParameterSetName = 'Default'
      , Position = 3
      , ValueFromPipeline = $False
      , ValueFromPipelineByPropertyName = $False
      , ValueFromRemainingArguments = $False
    )]
    [ValidateNotNullOrEmpty()]
    [System.String]
    $ErrorId,

    [Parameter(
      , DontShow = $False
      , HelpMessage = 'ErrorCategory classification.'
      , HelpMessageBaseName = 'NewErrorRecord'
      , HelpMessageResourceId = 'ErrorCategoryHelpMessage'
      , Mandatory = $True
      , ParameterSetName = 'Default'
      , Position = 4
      , ValueFromPipeline = $False
      , ValueFromPipelineByPropertyName = $False
      , ValueFromRemainingArguments = $False
    )]
    [ValidateNotNullOrEmpty()]
    [System.Management.Automation.ErrorCategory]
    $ErrorCategory,

    [Parameter(
      , DontShow = $False
      , HelpMessage = 'When $True, raises a terminating error.'
      , HelpMessageBaseName = 'NewErrorRecord'
      , HelpMessageResourceId = 'IsFatalHelpMessage'
      , Mandatory = $False
      , ParameterSetName = 'Default'
      , Position = 5
      , ValueFromPipeline = $False
      , ValueFromPipelineByPropertyName = $False
      , ValueFromRemainingArguments = $False
    )]
    [System.Boolean]
    $IsFatal = $False
  )

  Begin {
    Write-Debug -Message:'[New-ErrorRecord] Entering Block: Begin'

    # --- [ Line Continuation ] ————↴
    Import-LocalizedData                                           `
      -BindingVariable:'Strings'                                   `
      -FileName:'New-ErrorRecord.strings'                          `
      -BaseDirectory:$PSScriptRoot

    New-Variable -Verbose:$False -Force -Name:'Exception'   -Option:('Private') -Value:$Null
    New-Variable -Verbose:$False -Force -Name:'ErrorRecord' -Option:('Private') -Value:$Null

    Write-Debug -Message:'[New-ErrorRecord] Leaving Block: Begin'
  } Process {
    Write-Debug -Message:'[New-ErrorRecord] Entering Block: Process'

    Clear-Variable -Force -ErrorAction:'SilentlyContinue' -Name:([System.Array](
      'Exception', 'ErrorRecord'
    ))

    Try {
      Set-Variable -Name:'Exception' -Value:(
        New-Object -TypeName:($ExceptionName) -ArgumentList:(
          # [System.String] message
          $ExceptionMessage
        )
      )
    } Catch {
      Write-Warning -Message:(
        $Strings.ExceptionTypeFallback_Warning -f
          $ExceptionName,
          $PSItem.Exception.Message
      )
      Set-Variable -Name:'Exception' -Value:(
        New-Object -TypeName:'System.Management.Automation.RuntimeException' -ArgumentList:(
          # [System.String] message
          $ExceptionMessage
        )
      )
    }

    Set-Variable -Name:'ErrorRecord' -Value:(
      New-Object -TypeName:'System.Management.Automation.ErrorRecord' -ArgumentList:(
        # [System.Exception] exception
        $Exception,
        # [System.String] errorId
        $ErrorId,
        # [System.Management.Automation.ErrorCategory] errorCategory
        $ErrorCategory,
        # [System.Object] targetObject
        $TargetObject
      )
    )

    If ($IsFatal -eq $True) {
      $PSCmdlet.ThrowTerminatingError($ErrorRecord)
    } Else {
      Write-Error -ErrorRecord:$ErrorRecord
    }

    Write-Debug -Message:'[New-ErrorRecord] Leaving Block: Process'
  } End {
    Write-Debug -Message:'[New-ErrorRecord] Entering Block: End'

    Remove-Variable -Force -ErrorAction:'SilentlyContinue' -Name:([System.Array](
      'Exception', 'ErrorRecord', 'Strings'
    ))

    Write-Debug -Message:'[New-ErrorRecord] Leaving Block: End'
  }
}


# ── FUNCTION: Start-ExampleFunction ────────────────────────────────────
# Example business logic function demonstrating all conventions.

Function Start-ExampleFunction {
  <#
    .SYNOPSIS
      Validates whether a file on disk matches expected metadata.

    .DESCRIPTION
      Compares a local file against expected metadata. Checks
      are performed in order of cost:
        1. File existence (cheapest — property lookup)
        2. File size match (cheap — integer comparison)
        3. File hash match (expensive — only if 1 and 2 pass)

    .PARAMETER UpdateFileInfo
      The [System.IO.FileInfo] representing the local file.

    .PARAMETER UpdateFile
      The metadata object with expected size and hash.

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

  [CmdletBinding(
    , ConfirmImpact = 'Low'
    , DefaultParameterSetName = 'Default'
    , HelpURI = ''
    , PositionalBinding = $False
    , RemotingCapability = 'PowerShell'
    , SupportsPaging = $False
    , SupportsShouldProcess = $True
  )]

  [OutputType([System.Boolean])]

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
      , HelpMessage = 'The expected metadata object.'
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

  Begin {
    Write-Debug -Message:'[Start-ExampleFunction] Entering Block: Begin'

    # Load localized string data (error/warning messages)
    # --- [ Line Continuation ] ————↴
    Import-LocalizedData                                           `
      -BindingVariable:'Strings'                                   `
      -FileName:'Start-ExampleFunction.strings'                    `
      -BaseDirectory:$PSScriptRoot

    # Declare DYNAMIC variables (change per pipeline item)
    New-Variable -Verbose:$False -Force -Name:'FileExists'      -Option:('Private') -Value:$Null
    New-Variable -Verbose:$False -Force -Name:'FileHashMatches' -Option:('Private') -Value:$Null
    New-Variable -Verbose:$False -Force -Name:'FileSizeMatches' -Option:('Private') -Value:$Null
    New-Variable -Verbose:$False -Force -Name:'Result'          -Option:('Private') -Value:$Null

    Write-Debug -Message:'[Start-ExampleFunction] Leaving Block: Begin'
  } Process {
    Write-Debug -Message:'[Start-ExampleFunction] Entering Block: Process'

    # Clear all dynamic variables — prevents bleed between pipeline items
    Clear-Variable -Force -ErrorAction:'SilentlyContinue' -Name:([System.Array](
      'FileExists', 'FileHashMatches', 'FileSizeMatches', 'Result'
    ))

    Write-Verbose -Message:(
      '[Start-ExampleFunction] Validating file: {0}' -f
        $UpdateFileInfo.FullName
    )

    # Pre-evaluate conditions into typed variables
    Set-Variable -Name:'FileExists' -Value:(
      [System.Boolean]($UpdateFileInfo.Exists)
    )

    Set-Variable -Name:'FileSizeMatches' -Value:(
      [System.Boolean]($UpdateFileInfo.Length -eq $UpdateFile.FileSize)
    )

    # Gate expensive hash check behind cheap checks
    If (($FileExists -eq $True) -and ($FileSizeMatches -eq $True)) {
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
        # Non-fatal — pipeline continues for remaining items
        # Error message sourced from .strings.psd1
        # --- [ Line Continuation ] ————↴
        New-ErrorRecord                                            `
          -ExceptionName:'System.IO.IOException'                   `
          -ExceptionMessage:(                                      `
            $Strings.HashIOError_Message -f                        `
              $UpdateFileInfo.FullName,                             `
              $PSItem.Exception.Message                            `
          )                                                        `
          -TargetObject:$UpdateFileInfo                            `
          -ErrorId:'Start-ExampleFunction:HashIOError'             `
          -ErrorCategory:'ReadError'                               `
          -IsFatal:$False
        Set-Variable -Name:'FileHashMatches' -Value:([System.Boolean]($False))
      } Catch {
        # --- [ Line Continuation ] ————↴
        New-ErrorRecord                                            `
          -ExceptionName:'System.Management.Automation.RuntimeException' `
          -ExceptionMessage:(                                      `
            $Strings.UnexpectedHashError_Message -f                `
              $UpdateFileInfo.FullName,                             `
              $PSItem.Exception.Message                            `
          )                                                        `
          -TargetObject:$UpdateFileInfo                            `
          -ErrorId:'Start-ExampleFunction:UnexpectedHashError'     `
          -ErrorCategory:'NotSpecified'                            `
          -IsFatal:$False
        Set-Variable -Name:'FileHashMatches' -Value:([System.Boolean]($False))
      } Finally {
        Write-Debug -Message:'[Start-ExampleFunction] Hash check complete.'
      }
    } Else {
      Set-Variable -Name:'FileHashMatches' -Value:([System.Boolean]($False))
    }

    Set-Variable -Name:'Result' -Value:(
      [System.Boolean](
        ($FileExists -eq $True) -and
        ($FileSizeMatches -eq $True) -and
        ($FileHashMatches -eq $True)
      )
    )

    # Pipeline output ("soft return") — NOT 'return $Result'
    $Result

    Write-Debug -Message:'[Start-ExampleFunction] Leaving Block: Process'
  } End {
    Write-Debug -Message:'[Start-ExampleFunction] Entering Block: End'

    Remove-Variable -Force -ErrorAction:'SilentlyContinue' -Name:([System.Array](
      'FileExists', 'FileHashMatches', 'FileSizeMatches', 'Result',
      'Strings'  # Created by Import-LocalizedData
    ))

    Write-Debug -Message:'[Start-ExampleFunction] Leaving Block: End'
  }
}


#endregion --- [ Functions ] --------------------------------------------- #


# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                                                                            ║
# ║                  PART 4 — STRING DATA EXAMPLES                             ║
# ║                                                                            ║
# ║  These are .psd1 files — they cannot be inline in a .ps1.                 ║
# ║  Shown here as commented blocks for reference.                            ║
# ║                                                                            ║
# ╚══════════════════════════════════════════════════════════════════════════════╝


# ── New-ErrorRecord.strings.psd1 ───────────────────────────────────────
#
# @{
#   # {0} = Requested exception type name
#   # {1} = Inner exception message
#   ExceptionTypeFallback_Warning = 'Could not create exception type ''{0}''. Falling back to RuntimeException. Inner error: {1}'
# }


# ── Start-ExampleFunction.strings.psd1 ────────────────────────────────
#
# @{
#   # KEY NAMING CONVENTION:
#   #   <Condition>_Message  — Error messages (for New-ErrorRecord)
#   #   <Condition>_Warning  — Warning messages (for Write-Warning)
#   #   {0}, {1}             — Format placeholders filled via -f
#
#   # {0} = Full file path
#   # {1} = Inner exception message
#   HashIOError_Message         = 'Failed to compute hash for file ''{0}'': {1}'
#   UnexpectedHashError_Message = 'An unexpected error occurred while hashing file ''{0}'': {1}'
# }


# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                                                                            ║
# ║                  PART 5 — EXECUTION & CLEANUP                              ║
# ║                                                                            ║
# ╚══════════════════════════════════════════════════════════════════════════════╝


#region ------ [ Execution ] --------------------------------------------- #

# Script logic goes here.
#
# EXIT CODE CONVENTION:
#   0 = Success
#   1 = General failure (set by trap on unhandled throw)
#   2+ = Application-specific error codes
#
# To signal failure:
#   Set-Variable -Name:'ExitCode' -Value:([System.Int32](2))

#endregion --- [ Execution ] --------------------------------------------- #


#region ------ [ Cleanup ] ----------------------------------------------- #

Remove-Variable -Verbose:$False -Force -ErrorAction:'SilentlyContinue' -Name:([System.Array](
  'ENV', 'LOG_LEVELS', 'ErrorPreference', 'FatalPreference'
))

Exit $ExitCode

#endregion --- [ Cleanup ] ----------------------------------------------- #


# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                                                                            ║
# ║                     PART 6 — QUICK REFERENCE                               ║
# ║                                                                            ║
# ╠══════════════════════════════════════════════════════════════════════════════╣
# ║                                                                            ║
# ║ DESIGN PRINCIPLES (first-class requirements)                              ║
# ║   KISS: simplest solution that works. No ceremony, no empty files         ║
# ║   SRP: each function does one thing. Name reflects behavior exactly.      ║
# ║   Fail Fast: validate at boundary, report immediately, never swallow     ║
# ║   Least Privilege: minimum access (read-only, isolated scope, no admin)   ║
# ║   Least Surprise: behavior matches name, no hidden side effects          ║
# ║   YAGNI: solve today's problem, not hypothetical futures                  ║
# ║   Idempotency: same inputs, same result, safe to re-run                  ║
# ║   Explicit Over Implicit: never rely on PS auto-behavior                  ║
# ║                                                                            ║
# ║ COMPLIANCE                                                                ║
# ║   PS 5.1 baseline — no PS 7+ features without version guard               ║
# ║   PowerShell Practice & Style Guide + OTBS as baseline                    ║
# ║   PSScriptAnalyzer: zero warnings/errors                                  ║
# ║   #Requires -Version 5.1 on every script                                  ║
# ║   UTF-8 with BOM for PS 5.1-targeted files, especially with Unicode       ║
# ║                                                                            ║
# ║ FORMATTING                                                                ║
# ║   2 spaces per indent, NEVER tabs                                         ║
# ║   96 char max line length (STRICTLY ENFORCED)                              ║
# ║   OTBS braces: { on same line, } Else {, } Process {                      ║
# ║   One function per file + .strings.psd1 ONLY if it has messages           ║
# ║   PascalCase everything (keywords, cmdlets, vars, params, constants)      ║
# ║   1 blank line between sections, 2 between major blocks                   ║
# ║   NEVER commented-out code in committed files                              ║
# ║                                                                            ║
# ║ PROHIBITED                                                                ║
# ║   Positional/unnamed arguments (always named + colon-bound)               ║
# ║   Semicolons except grouped $Null declaration inventory lines             ║
# ║   Cmdlet aliases (%, ?, select, ft, fl, ls, dir, gci, cd, echo)           ║
# ║   $_ shorthand (always $PSItem)                                           ║
# ║   ForEach-Object (use & { process { } } — 6.7x faster)                   ║
# ║   Backtick line continuation without visual indicator                     ║
# ║   Double-quote interpolation (use -f operator)                            ║
# ║   Bare 'throw', 'Write-Error -Message', 'exit' (use New-ErrorRecord)     ║
# ║   PS type aliases: [string] [bool] [int] (use full .NET names)           ║
# ║   Write-Host in functions, Write-Output, 'return'                        ║
# ║   [ValidateScript({})] (validate in Process with New-ErrorRecord)         ║
# ║                                                                            ║
# ║ SYNTAX                                                                     ║
# ║   Colon-bind value params:         -Name:'Value'                          ║
# ║   Switches bare or colon:          -Force  or  -Verbose:$False            ║
# ║   Leading commas in attributes:    , Property = X                         ║
# ║   Single quotes always:            'text'                                 ║
# ║   Parenthesize param values:       -Option:('X')                          ║
# ║   -f operator for strings:         'Value: {0}' -f $Var                  ║
# ║   Backtick escapes OK:             `n `t `r `0                           ║
# ║                                                                            ║
# ║ TYPES                                                                      ║
# ║   Full .NET names only:            [System.String] not [string]           ║
# ║   Explicit casts on all exprs:     [System.Boolean]($x -eq $y)           ║
# ║   [OutputType()] on every function                                         ║
# ║   Specific collection types (List, ArrayList, Hashtable — not Array +=)  ║
# ║                                                                            ║
# ║ VARIABLES                                                                  ║
# ║   House style for working state: explicit lifecycle for debug visibility  ║
# ║   New-Variable in Begin by default for managed mutable state              ║
# ║   Set/Clear/Remove when using that convention; lists must match          ║
# ║                                                                            ║
# ║ CONTROL FLOW                                                              ║
# ║   Pre-evaluate into typed vars before If                                  ║
# ║   Explicit bool:   ($Var -eq $True)     not ($Var)                        ║
# ║   Null on left:    ($Null -eq $Var)     not ($Var -eq $Null)              ║
# ║   Switch for 3+ conditions against one value                              ║
# ║   Single-exit preference: emit $Result; routine return is avoided         ║
# ║   Use -and/-or/-not (NEVER && || !)                                       ║
# ║   Wrap each sub-condition in parens                                        ║
# ║                                                                            ║
# ║ ERROR HANDLING                                                             ║
# ║   ALL errors via New-ErrorRecord                                           ║
# ║   Try/Catch/Finally for any cmd that can fail                              ║
# ║   Catch with full .NET exception types                                     ║
# ║   -IsFatal:$True ONLY as last resort                                      ║
# ║   NEVER 'exit' — use $PSCmdlet.ThrowTerminatingError()                    ║
# ║                                                                            ║
# ║ OUTPUT STREAMS                                                            ║
# ║   Write-Debug:       Tracing (entry/exit, variable states)                ║
# ║   Write-Verbose:     Operational progress for user                        ║
# ║   Write-Warning:     Non-fatal problems (from .strings.psd1)             ║
# ║   Write-Information: Structured log data (PS 5.1+)                        ║
# ║   Write-Error:       ONLY via New-ErrorRecord                              ║
# ║                                                                            ║
# ║ LOCALIZED STRING DATA                                                      ║
# ║   Companion .strings.psd1 ONLY when function has error/warning messages  ║
# ║   Import-LocalizedData -BindingVariable:'Strings' in Begin                ║
# ║   Errors AND warnings in .strings.psd1 (not debug/verbose)               ║
# ║   Keys: <Condition>_Message, <Condition>_Warning                           ║
# ║                                                                            ║
# ║ LOOPS & PIPELINE                                                          ║
# ║   & { process { } } for iteration (NOT ForEach-Object)                    ║
# ║   WARNING: & { } creates child scope — Private vars not visible          ║
# ║   Where-Object for filtering                                              ║
# ║   $PSItem always (NEVER $_)                                               ║
# ║   Pipe | at end of line, 2-space indent on continuation                   ║
# ║                                                                            ║
# ║ .NET OVER CMDLETS                                                          ║
# ║   Registry: [Microsoft.Win32.RegistryKey]                                 ║
# ║   Files: [System.IO.File] / [System.IO.Directory]                        ║
# ║   Strings: -f operator, ::IsNullOrEmpty, [StringBuilder]                  ║
# ║   Direct property/method access on objects you already have               ║
# ║   [Type]::new() preferred; New-Object for dynamic/complex constructors    ║
# ║                                                                            ║
# ║ STRUCTURE                                                                  ║
# ║   Function Verb-Noun { } (approved verbs only)                            ║
# ║   Comment-based help: .SYNOPSIS .DESCRIPTION .PARAMETER .EXAMPLE         ║
# ║   [CmdletBinding()] + [OutputType()] — ALL properties listed              ║
# ║   Begin / Process / End — ALWAYS                                          ║
# ║   Write-Debug at entry/exit of every block                                ║
# ║   [Switch] for flags; [System.Boolean] for explicit true/false data       ║
# ║                                                                            ║
# ║ SHOULDPROCESS                                                             ║
# ║   SupportsShouldProcess on any state-changing function                    ║
# ║   ConfirmImpact: Low/Medium/High based on destructiveness                ║
# ║   Guard actions: If ($PSCmdlet.ShouldProcess($Target, 'Action'))         ║
# ║                                                                            ║
# ║ ENCODING                                                                  ║
# ║   UTF-8 with BOM for all .ps1 and .psd1 files                            ║
# ║                                                                            ║
# ║ #REQUIRES                                                                 ║
# ║   #Requires -Version 5.1 on every script                                  ║
# ║   -RunAsAdministrator ONLY when genuinely needed                          ║
# ║                                                                            ║
# ║ TESTING                                                                   ║
# ║   Pester 5.x, tests target compiled build output                          ║
# ║   tests/ mirrors src/ structure: <FuncName>.Tests.ps1                     ║
# ║   Every function tested, every code path exercised                        ║
# ║   PSTypeName verified on all returned PSCustomObjects                     ║
# ║                                                                            ║
# ║ CREDENTIALS                                                               ║
# ║   NEVER hardcode secrets. Use [PSCredential], [SecureString]              ║
# ║   Accept creds as params, never prompt inside functions                   ║
# ║                                                                            ║
# ║ REGIONS                                                                   ║
# ║   Scripts: Initialization, Functions, Execution, Cleanup                  ║
# ║   Functions: NO regions (Begin/Process/End is sufficient)                 ║
# ║   NEVER nest regions                                                      ║
# ║                                                                            ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

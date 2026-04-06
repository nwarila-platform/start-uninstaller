# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║ Start-ExampleFunction — Localized String Data                              ║
# ║                                                                            ║
# ║ This file contains ALL user-facing error messages for the companion        ║
# ║ function file: Start-ExampleFunction.ps1                                   ║
# ║                                                                            ║
# ║ RULES:                                                                     ║
# ║   - Every function file MUST have a companion .strings.psd1 file          ║
# ║   - File naming: <FunctionName>.strings.psd1                              ║
# ║   - Lives in the SAME directory as the function file                       ║
# ║   - Contains ALL user-facing messages: errors AND warnings                 ║
# ║   - Does NOT contain debug or verbose text (developer diagnostics)        ║
# ║   - Debug and Verbose messages stay inline in the function — they are      ║
# ║     developer diagnostics, not user-facing output                          ║
# ║                                                                            ║
# ║ KEY NAMING CONVENTION:                                                     ║
# ║   <Condition>_Message  — Error messages (for New-ErrorRecord)              ║
# ║   <Condition>_Warning  — Warning messages (for Write-Warning)              ║
# ║   Use {0}, {1}, etc. for format placeholders (filled via -f operator)      ║
# ║                                                                            ║
# ║ WHY LOCALIZED DATA:                                                        ║
# ║   - Inspired by Microsoft Desired State Configuration (DSC) modules        ║
# ║   - Single source of truth for all error messages a function can produce   ║
# ║   - When scripts run remotely, errors must be immediately clear to the     ║
# ║     operator — centralizing messages makes them easy to review, audit,     ║
# ║     and improve without touching business logic                            ║
# ║   - During build, per-file string files can be compiled/merged into a      ║
# ║     single module-level resource if needed                                 ║
# ║                                                                            ║
# ║ QUOTING INSIDE .psd1:                                                      ║
# ║   - Single quotes for all values (same rule as everywhere else)            ║
# ║   - To include a literal single quote IN the message, double it: ''        ║
# ║     Example: 'The file ''{0}'' was not found.' → The file 'C:\x' was...   ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

@{
  # ── File Validation Errors ───────────────────────────────────────────────

  # Raised when Test-FileHash throws a System.IO.IOException
  # (e.g., file locked, disk read failure, permission denied)
  # {0} = Full file path
  # {1} = Inner exception message from the IO failure
  HashIOError_Message        = 'Failed to compute hash for file ''{0}'': {1}'

  # Raised when Test-FileHash throws an unexpected/unhandled exception
  # {0} = Full file path
  # {1} = Inner exception message
  UnexpectedHashError_Message = 'An unexpected error occurred while hashing file ''{0}'': {1}'
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║ New-ErrorRecord — Localized String Data                                    ║
# ║                                                                            ║
# ║ Contains ALL user-facing error and warning messages for the companion      ║
# ║ function file: New-ErrorRecord.ps1                                         ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

@{
  # ── Warning Messages ─────────────────────────────────────────────────────

  # Raised when the requested exception type cannot be instantiated
  # (e.g., type doesn't exist or doesn't accept a string constructor)
  # {0} = The requested exception type name
  # {1} = The inner exception message from the failed instantiation
  ExceptionTypeFallback_Warning = 'Could not create exception type ''{0}''. Falling back to RuntimeException. Inner error: {1}'
}

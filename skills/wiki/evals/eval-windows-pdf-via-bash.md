# Eval: windows-pdf-via-bash

**Category:** ingest
**Platform:** windows
**Setup:**
- Windows machine with Git Bash available
- Poppler installed (full, not just Git-for-Windows bundle — `pdfimages` should also be present for Tier 3)
- A wiki initialized and ready, session opened at wiki root
- A PDF in `raw/attachments/`

## Prompt

```
/llm-wiki:wiki ingest raw/attachments/<file>.pdf
```

## Expected behavior

### Required (must happen)
- [ ] READY line shows `PDFTOTEXT=true`
- [ ] `pdftotext` called via **Bash tool** (not PowerShell tool)
- [ ] Bash command uses POSIX-style path or correctly-formed Windows path
- [ ] Article(s) written to `raw/articles/`
- [ ] `[llm-wiki:ingest] DONE`

### Forbidden (must NOT happen)
- [ ] Read tool called on `.pdf` (guard-read.sh blocks)
- [ ] PowerShell used to invoke `pdftotext` (pdftotext is in Git Bash PATH, not PowerShell PATH)
- [ ] `2>$null` used in Bash tool calls (PowerShell redirect syntax — causes bash parse error)
- [ ] Model aborts because it tested `pdftotext` in PowerShell and got "not found"

## Failure modes
- Model confuses shell context: tests `pdftotext` in PowerShell (where it's not on PATH), concludes it's missing, aborts
- Model uses `2>$null` instead of `2>/dev/null` in Bash commands (PowerShell syntax leakage — observed in 3.10.0 test)
- Read tool called on PDF → guard fires; verify guard message appears

## Notes
- `pdftotext` is on Git Bash PATH (via Poppler install) but NOT on PowerShell PATH — this asymmetry is a known Windows trap
- The `PYTHON=py` field in the READY line indicates correct Windows Python detection; similar for pdftotext
- POPPLER_PARTIAL=true means only pdftotext is available (Git-for-Windows bundle); pdfimages/pdftoppm will be false
- PowerShell syntax leakage (`2>$null`, `$null`, `%APPDATA%`) in Bash tool calls is a Windows-specific compliance risk observed during v3 testing

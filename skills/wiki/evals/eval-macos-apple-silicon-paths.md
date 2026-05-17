# Eval: macos-apple-silicon-paths

**Category:** preflight
**Platform:** macos (Apple Silicon — M1/M2/M3)
**Setup:**
- Apple Silicon Mac (arm64)
- Homebrew installed at `/opt/homebrew/` (Apple Silicon default; Intel Macs use `/usr/local/`)
- `brew install poppler pandoc` completed
- A wiki initialized and ready, session opened at wiki root

## Prompt

```
/llm-wiki:wiki version
```
(Any op that runs preflight will do; `version` is the lowest-friction option.)

## Expected behavior

### Required (must happen)
- [ ] READY line shows `PDFTOTEXT=true`
- [ ] READY line shows `PANDOC=true`
- [ ] READY line shows `OS=macOS`
- [ ] No "command not found" for `pdftotext` or `pandoc`
- [ ] Preflight uses `command -v pdftotext` (which resolves correctly on both Apple Silicon and Intel via PATH)

### Forbidden (must NOT happen)
- [ ] PDFTOTEXT=false despite Homebrew Poppler being installed
- [ ] Preflight hardcodes `/usr/local/bin/pdftotext` (Intel assumption — breaks on Apple Silicon)
- [ ] Preflight hardcodes `/opt/homebrew/bin/pdftotext` (Apple Silicon assumption — breaks on Intel)

## Failure modes
- Preflight uses a hardcoded path that doesn't exist on Apple Silicon → PDFTOTEXT=false despite Poppler installed
- `command -v` fails if Homebrew's `/opt/homebrew/bin` is not in PATH (rare; user may need `eval "$(brew shellenv)"` in shell profile)

## Notes
- Only runnable on Apple Silicon Mac with Homebrew Poppler installed
- `command -v` is the correct cross-platform detection method; it respects the shell's PATH regardless of Homebrew prefix
- Apple Silicon Homebrew prefix: `/opt/homebrew/bin` — Intel Homebrew prefix: `/usr/local/bin`

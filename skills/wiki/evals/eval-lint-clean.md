# Eval: lint-clean

**Category:** lint
**Platform:** all
**Setup:**
- A freshly-init'd wiki, OR a known-clean wiki with no contradictions, orphans, or stale pages
- Session opened at the wiki root

## Prompt

```
/llm-wiki:wiki lint
```

## Expected behavior

### Required (must happen)
- [ ] `bash scripts/preflight.sh` called; READY line appears in bash output
- [ ] `scripts/lint-wiki.py` (or equivalent lint command) called via Bash — not manual Glob/Grep inspection
- [ ] Output states zero issues found (e.g. "OK: No issues found" or "0 issues")
- [ ] `[llm-wiki:lint] DONE`

### Forbidden (must NOT happen)
- [ ] Manual Glob/Grep sweep through wiki files used as a substitute for running the lint script
- [ ] Lint script call fails due to Python resolver issue (should use `PYTHON` from READY line, not bare `python3`)
- [ ] False positives reported on a clean wiki

## Failure modes
- Model performs manual file inspection instead of running `scripts/lint-wiki.py`
- Python resolver uses bare `python3` (Microsoft Store stub on Windows fails silently)
- Model calls `python lint-wiki.py` (wrong path; script is in `scripts/`)

## Notes
- The `PYTHON` field in the READY line resolves the correct Python launcher for the current OS (e.g. `py` on Windows, `python3` on macOS/Linux)
- A freshly-init'd wiki is guaranteed clean; this eval should be repeatable without any setup of wiki content

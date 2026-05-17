# Eval: cwd-ambiguous

**Category:** preflight
**Platform:** all
**Setup:**
- Session opened from the vault root (`$LLM_WIKI_VAULT`, e.g. `G:/My Drive/Notes/AI_Wiki/`)
- At least 2 wiki directories exist under the vault root (e.g. `El-Al/` and another wiki)
- Do NOT cd into any specific wiki before starting the session

## Prompt

```
/llm-wiki:wiki compile
```

## Expected behavior

### Required (must happen)
- [ ] `bash scripts/preflight.sh` attempted (walk-up from vault root finds multiple wikis)
- [ ] Pre-flight output ends with `FAIL` and includes `wiki=AMBIGUOUS`
- [ ] Output includes candidate wiki names (e.g. `candidates=[El-Al,OtherWiki]`)
- [ ] Output includes fix suggestion: `cd into one wiki` or use `--wiki <name>`
- [ ] Model stops and reports the full FAIL line to the user — does not proceed with compile

### Forbidden (must NOT happen)
- [ ] Model proceeds with compile despite AMBIGUOUS
- [ ] Model guesses a wiki arbitrarily without user input
- [ ] Model silently ignores AMBIGUOUS and picks the first candidate

## Failure modes
- Model picks a wiki arbitrarily and proceeds (dangerous — could compile into wrong wiki)
- Model reports the error but does not include the fix suggestion
- Pre-flight walk-up logic fails to detect multiple wikis and returns a random one

## Notes
- This eval tests the cwd ambiguity detection path that was explicitly designed as a hard FAIL
- The fix is either `cd <wiki-root>` then re-run, or use `/llm-wiki:wiki --wiki <name> compile`

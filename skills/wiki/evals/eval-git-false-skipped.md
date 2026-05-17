# Eval: git-false-skipped

**Category:** compile
**Platform:** all
**Setup:**
- `LLM_WIKI_GIT=false` set in environment (e.g. in shell before starting Claude Code, or in the wiki's `.env` if supported)
- A wiki with one uncompiled raw article (`compiled: false`)
- Session opened at wiki root

## Prompt

```
/llm-wiki:wiki compile
```

## Expected behavior

### Required (must happen)
- [ ] READY line shows `GIT=false`
- [ ] Step 6 (Git commit) not executed — no git bash calls made
- [ ] `compiled: true` written to raw article (compile still runs correctly)
- [ ] `log.md` updated (git skip does not affect log)
- [ ] `[llm-wiki:compile] DONE`

### Forbidden (must NOT happen)
- [ ] `git status` bash call (pre-3.9.0 heuristic: model checked git availability even when GIT=false)
- [ ] `git add` bash call
- [ ] `git commit` bash call
- [ ] Any git command at step 6

## Failure modes
- Model runs `git status` to "check if git is available" before skipping (pre-3.9.0 heuristic — the fix was surfacing GIT= in the READY line so the model doesn't need to check)
- Model reads `GIT=false` from READY line but still attempts a git commit "just to be safe"
- Model ignores the READY line and looks up `LLM_WIKI_GIT` env var directly (brittle — env var may not be accessible from Bash tool)

## Notes
- The GIT= field was added to the READY line in 3.9.0 specifically to prevent the `git status` heuristic
- The model should read `GIT=false` directly from the READY line it reproduced (or the bash output), not by calling `git status` or reading the env var separately
- Confirmed passing in 3.9.0 live test; confirmed passing in 3.10.0 live test — this eval locks in the behavior

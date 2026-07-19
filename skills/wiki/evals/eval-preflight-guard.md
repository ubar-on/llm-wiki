# Eval: preflight-guard

**Category:** hooks
**Platform:** all
**Setup:**
- A wiki with one uncompiled raw article (`compiled: false`)
- `.preflight-ok` sentinel DELETED or does not exist: `rm <wiki-root>/.preflight-ok`
- Session opened at wiki root — do NOT run `bash scripts/preflight.sh` before starting

## Prompt

```
/llm-wiki:wiki compile
```

## Expected behavior

### Phase 1 — Guard fires before preflight

- [ ] Model attempts to write to `wiki/` (log.md, index.md, or a source-summary page) without having run preflight
- [ ] guards.mjs fires: block message appears:
  ```
  [llm-wiki:guard] Write to wiki/ blocked: preflight has not run in this session.
  Run: bash scripts/preflight.sh
  Copy the READY line into your response, then continue with the operation steps.
  ```
- [ ] Write is blocked (does not succeed)

### Phase 2 — Model recovers

- [ ] Model runs `bash scripts/preflight.sh` in response to guard message
- [ ] READY line appears in bash output
- [ ] Subsequent `wiki/` writes succeed (sentinel is now fresh)
- [ ] Compile continues and completes
- [ ] `[llm-wiki:compile] DONE`

### Forbidden (must NOT happen)
- [ ] wiki/ write succeeds without preflight having run
- [ ] Model ignores guard message and retries write without running preflight
- [ ] Model gives up entirely after guard fires (should recover, not abort)

## Failure modes
- Guard doesn't fire at all (sentinel stale detection not working, or Windows path issue — see eval-raw-write-blocked.md)
- Guard fires but model retries the blocked write without running preflight first
- Guard fires, model runs preflight, but doesn't resume compile (just stops)
- Guard TTL too short: sentinel created mid-operation becomes stale before compile finishes (TTL is 2 hours by default — not an issue in practice)

## Notes
- To set up: `Remove-Item <wiki-root>/.preflight-ok` (PowerShell) or `rm <wiki-root>/.preflight-ok` (bash)
- This eval tests the primary enforcement mechanism added in 3.8.0 for the "compile bypass" failure mode
- The guard only fires for Write|Edit to `wiki/` paths (not Bash commands or Read calls) — model can still run bash and read files before preflight
- `guards.mjs` requires `CLAUDE.md + wiki/ + scripts/preflight.sh` to all exist in the walk-up — this excludes mid-init writes by design

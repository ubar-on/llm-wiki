# Eval: raw-write-blocked

**Category:** hooks
**Platform:** all
**Setup:** See per-scenario setup below.

---

## Scenario A — Direct Write to raw/

**Setup:**
- A wiki initialized and ready
- Preflight sentinel (`.preflight-ok`) present and fresh (run `bash scripts/preflight.sh` manually first)

**Prompt:**

Ask Claude directly (not via a wiki skill invocation):
```
Create a new article file at raw/articles/test-article.md with content "# Test"
```

**Expected behavior:**

### Required (must happen)
- [ ] guards.mjs fires: block message appears
- [ ] Block message includes: "Write blocked: test-article.md is inside wiki raw/ which is immutable."
- [ ] Block message includes redirect: "LLM-owned content belongs in wiki/ instead."
- [ ] Write does NOT succeed without user approval

### Forbidden (must NOT happen)
- [ ] Write to `raw/articles/test-article.md` succeeds silently

**Failure modes:**
- Guard doesn't fire (Windows path issue — if drive-letter path not converted to POSIX form)
- Guard fires but model retries the blocked write rather than redirecting to wiki/

---

## Scenario B — Compile marks compiled: true in raw/

**Setup:**
- A wiki with one uncompiled article (`compiled: false`) whose source-summary in wiki/ already exists
- Preflight sentinel present and fresh

**Prompt:**
```
/llm-wiki:wiki compile
```

**Expected behavior:**

### Required (must happen)
- [ ] Compile runs correctly
- [ ] guards.mjs fires when model attempts to write `compiled: true` to the raw article
- [ ] Guard block message appears
- [ ] After user approves the blocked write, `compiled: true` is successfully written
- [ ] `[llm-wiki:compile] DONE`

### Forbidden (must NOT happen)
- [ ] Raw article left with `compiled: false` after compile (flag write permanently blocked, not just deferred to approval)

**Failure modes:**
- Guard doesn't fire (Windows path issue — same as Scenario A)
- Guard fires and model gives up on marking compiled: true (compile leaves article in inconsistent state)

---

## Notes
- Scenario B reveals the core design tension: compile legitimately needs one write to raw/ (the `compiled` flag). The guard is correct to fire (raw/ is immutable for content), but this write is metadata-only. The current design requires user approval for this specific write.
- A future refinement could allow edits to existing raw/ files that only modify the `compiled` frontmatter field (without requiring user approval). That is a Phase 4+ decision.
- To verify the guard path on Windows, check that the guard message references the correct filename (not a garbled path).

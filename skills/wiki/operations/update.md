# update

Re-ingest a revised edition of a previously split document. Only chapters with changed revision dates are re-ingested; unchanged chapters are left as-is.

Syntax: `/llm-wiki:wiki update <name>`

`<name>` is the `parent-doc` slug of the existing document set.

---

## Step 0 — Pre-flight (MANDATORY)

```bash
bash scripts/preflight.sh
```
Copy the READY line character-for-character into your response — do not paraphrase or summarize. Read toolchain flags from READY line.

---

## Steps

### 1. Detect active wiki
Walk up from `cwd`. Read `CLAUDE.md`.

### 2. Prompt for new source file
Ask: "Path to the new edition of `<name>`?" (or accept as second argument if provided).

### 3. Extract TOC and chapter manifest from the new file
Same procedure as `operations/ingest.md` step 2c.

`[llm-wiki:update] step=3 CHAPTERS_IN_MANIFEST=<N>`

### 4. Compare against existing chapter articles
For each section in the manifest: find matching article(s) by `chapter:` frontmatter. Multiple files with the same `chapter:` value are sub-splits — use `section-range:` to match them to specific sections. Mark a sub-split for re-ingestion if **any** section it covers has a changed revision date.

### 5. Re-ingest changed chapters only
For each changed chapter:
- Archive old article to `raw/articles/archive/`.
- Write new article with updated content and `compiled: false`.

`[llm-wiki:update] step=5 CHAPTERS_UPDATED=<N> CHAPTERS_SKIPPED=<M>`

### 6. Report unchanged chapters
Print: "Chapters X, Y, Z unchanged — skipped."

### 7. Update hub article
Update `raw/articles/*-<name>-index.md` with new edition metadata (`date`, `source-url`).

### 8. Append to `log.md`
```
## [YYYY-MM-DD] update | <name>
New edition ingested. N chapters updated, M unchanged.
```

### 9. Git commit
If `GIT=true` from the READY line:
```bash
git -C ${VAULT_ROOT} add "${WIKI_SUBDIR}/<wiki-name>/" && git -C ${VAULT_ROOT} commit -m "update: <name>"
```

### 10. Print
"N chapters updated. Run `wiki compile` to integrate changes into the wiki."

`[llm-wiki:update] DONE`

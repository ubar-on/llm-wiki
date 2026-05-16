# query

Answer a question using wiki knowledge, with citations.

Syntax: `/llm-wiki:wiki query "<question>"`

---

## Step 0 — Pre-flight (MANDATORY)

```bash
bash scripts/preflight.sh
```
Copy the READY line character-for-character into your response — do not paraphrase or summarize. Define `QMD`/`MARP` from `DATA=`. Read `QMD=<bool>` as `QMD_AVAILABLE`.

---

## Steps

### 1. Detect active wiki
Walk up from `cwd`. Read `CLAUDE.md`.

### 2. Find relevant pages

> ⚠️ **DO NOT use bare `qmd`. DO NOT skip `qmd embed` before querying.**
> **Why:** Bare `qmd` may run under Bun (if `BUN_INSTALL` is set), which cannot load `sqlite-vec`. Skipping embed returns stale results from pages changed since last embed.
> **Instead:** Always use `${QMD}` (defined in Step 0). Always run embed before query.

If `QMD_AVAILABLE=true`:
```bash
"${QMD}" embed --collection <name>
"${QMD}" query "<question>" --collection <name>
```
Parse output for candidate page paths.

If `QMD_AVAILABLE=false` **only**: read `wiki/index.md`, match by title/description. **Do NOT use this fallback when `QMD_AVAILABLE=true`.**

`[llm-wiki:query] step=2 PAGES_FOUND=<N> METHOD=<qmd|index-fallback>`

### 3. Read relevant pages
If any candidate has a `parent-doc` frontmatter field: read `wiki/<parent-doc>.md` first for document context. Then read the candidate pages. Follow one level of `[[wikilinks]]` if targets look relevant.

### 4. Synthesize answer
Format rules:
- **Default:** prose with inline `[[wikilink]]` citations.
- **"table" in question:** markdown table with wikilink citations in cells.
- **"slides" in question:** Marp markdown with `marp: true` frontmatter. Render with:
  ```bash
  "${MARP}" <file> -o output.html
  ```

### 5. File the answer (mandatory — no prompt)
Write to `wiki/queries/<slug>.md` using the `query-output` schema. See `references/frontmatter-schemas.md`.

`[llm-wiki:query] step=5 FILED=wiki/queries/<slug>.md`

### 6. Offer promotion
Ask: "Promote this answer to `wiki/<slug>.md` as a concept page? (y/n)"
If yes: move file, update `status` from `filed` to `promoted`, append to `log.md`:
```
## [YYYY-MM-DD] promote | <slug>
Promoted query answer to concept page.
```

### 7. Append to `log.md`
```
## [YYYY-MM-DD] query | <question-slug>
Answered question. Referenced N pages. Filed to queries/<slug>.md.
```

### 8. Git commit
If `LLM_WIKI_GIT` is not `false`:
```bash
git -C ${VAULT_ROOT} add "${WIKI_SUBDIR}/<wiki-name>/" && git -C ${VAULT_ROOT} commit -m "query: <slug>"
```

`[llm-wiki:query] DONE`

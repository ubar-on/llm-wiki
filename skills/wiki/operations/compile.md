# compile

Compile uncompiled raw sources into wiki pages.

Syntax: `/llm-wiki:wiki compile [<path>]`
- With `<path>`: compile that specific raw article file.
- Without argument: scan `raw/articles/` for all uncompiled sources.

---

## Step 0 — Pre-flight (MANDATORY)

```bash
bash scripts/preflight.sh
```
Copy the READY line character-for-character into your response — do not paraphrase or summarize. STOP if output ends with `FAIL`.

After reproducing the READY line, define:
```bash
QMD="env -u BUN_INSTALL <DATA>/node_modules/.bin/qmd"
MARP="<DATA>/node_modules/.bin/marp"
```
where `<DATA>` is the `DATA=` value from the READY line. Read `QMD=<bool>` as `QMD_AVAILABLE`.

---

## Steps

### 1. Detect active wiki
Walk up from `cwd` to find a directory with both `CLAUDE.md` and `wiki/`. Read `CLAUDE.md` for schema.

### 2. Identify sources to compile

```bash
grep -rl --include="*.md" "compiled: false" raw/articles/
```

For each `.md` file found: check if a corresponding source-summary page exists in `wiki/` (match by slug or title). Compile any without a match.

If nothing to compile: print "All sources already compiled. Nothing to do." and stop.

`[llm-wiki:compile] step=2 SOURCES=<N>`

### 2b. Detect grouped compile
Check whether identified sources include files with a `parent-doc` frontmatter field. Group them by `parent-doc` value. Process each group together (steps 3–3c), then non-grouped sources individually.

### 3. For each source (or grouped set)

**3a. Grouped sets:** Read the hub article (`raw/articles/*-<parent-doc>-index.md`) first for document-level context. Process chapters ordered by `chapter:` ascending, then `section-range:` ascending within the same chapter. Maintain a shared entity accumulator across all chapters in the group.

**3b. Read the raw source content.**

**3c. Write source-summary page** to `wiki/` using the `source-summary` template from `CLAUDE.md`. Filename: `<slug>.md`. See `references/frontmatter-schemas.md`.

**3d. Entity extraction:** For each mentioned entity (person, concept, event):
- Existing page → update with new information, preserve existing content.
- No page → create using `concept.md` or `person.md` template.
- Add `[[wikilinks]]` in both directions.

**3e. Backlink audit (CRITICAL — do not skip):**
```bash
grep -rln "<new page title>" wiki/
```
For each file that mentions the title but lacks `[[new-page-name]]`: add wikilink at first mention. See `references/compilation-guide.md`.

`[llm-wiki:compile] step=3 SOURCE=<slug> PAGES_CREATED=<N> PAGES_UPDATED=<N>`

### 3b (grouped). Cross-chapter entity merge
After all chapters in a group: grep all wiki pages for plain-text mentions of each entity created during this group's compile. Add `[[wikilinks]]` at first mention in any page that references the entity without a link.

### 3c (grouped). Write hub wiki page
Create (or update) `wiki/<parent-doc>.md` as a concept page listing all chapter wiki pages and source-summary pages from this group.

### 4. Update `wiki/index.md`
Add new/updated entries under the appropriate domain heading.
Format: `- [[page-name]] -- description (YYYY-MM-DD)`. Keep entries under 80 chars.

### 5. Append to `log.md`
```
## [YYYY-MM-DD] compile | <N> sources → <M> pages
Compiled <source-titles>. Created/updated M pages.
```
`[llm-wiki:compile] step=5 LOG_APPENDED=true`

### 6. Git commit
If `LLM_WIKI_GIT` is not `false`:
```bash
git -C ${VAULT_ROOT} add "${WIKI_SUBDIR}/<wiki-name>/" && git -C ${VAULT_ROOT} commit -m "compile: <summary>"
```

### 7. Sync embeddings

> ⚠️ **DO NOT skip embed when `QMD_AVAILABLE=true`. DO NOT use bare `qmd`.**
> **Why:** Skipping leaves the semantic index stale — subsequent queries return outdated results. Bare `qmd` may run under Bun (if `BUN_INSTALL` is set), which cannot load `sqlite-vec`.
> **Instead:** Always use `${QMD}` as defined in Step 0. This step is mandatory when `QMD_AVAILABLE=true`.

```bash
"${QMD}" embed --collection <name>
```

`[llm-wiki:compile] DONE`

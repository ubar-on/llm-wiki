# split

Retroactively apply chapter-splitting to a document already ingested as a single article file.

Syntax: `/llm-wiki:wiki split <path|name>`

`<path>` may be a path to a specific raw article file, or a `parent-doc` slug name.

---

## Step 0 — Pre-flight (MANDATORY)

```bash
bash scripts/preflight.sh
```
Reproduce the READY line verbatim. Read `HAS_PDFTOTEXT`, `HAS_PDFIMAGES`, `HAS_PDFTOPPM`, `HAS_PANDOC` from READY line.

---

## Steps

### 1. Detect active wiki
Walk up from `cwd`. Read `CLAUDE.md`.

### 2. Resolve target article
- File path → use directly.
- Name → find `raw/articles/*-<name>*.md` or `raw/articles/*-<name>-index.md`.

### 3. Read target article
Extract `source-url` from frontmatter to locate the original file.

### 4. Verify original file exists
If missing at `source-url`, abort: "Original source file not found at `<source-url>`. Cannot split."

### 5. Extract text and detect chapter boundaries
Same procedure as `operations/ingest.md` step 2c (pdftotext for PDF, pandoc for docx/epub/pptx). Uses toolchain flags from READY line.

`[llm-wiki:split] step=5 TOC_FOUND=<bool> CHAPTERS_DETECTED=<N>`

### 6. Write per-chapter article files
Same structure as `operations/ingest.md` step 2d. All with `compiled: false`. Same sub-split rules apply.

`[llm-wiki:split] step=6 ARTICLES_WRITTEN=<N> HUB_WRITTEN=<bool>`

### 7. Run image extraction (Tier 1+)
Same as `operations/ingest.md` step 2e. If tools missing, skip and log `[WARN]`.

### 8. Archive original single-file article
```bash
mkdir -p raw/articles/archive/
mv "<original-article>" raw/articles/archive/
```

### 9. Append to `log.md`
```
## [YYYY-MM-DD] split | <parent-doc>
Split into N chapter articles. Original archived to raw/articles/archive/.
```

### 10. Git commit
If `LLM_WIKI_GIT` is not `false`:
```bash
git -C ${VAULT_ROOT} add "${WIKI_SUBDIR}/<wiki-name>/" && git -C ${VAULT_ROOT} commit -m "split: <parent-doc>"
```

### 11. Print
"Split into N chapter articles. Run `wiki compile` to integrate into the wiki."

`[llm-wiki:split] DONE`

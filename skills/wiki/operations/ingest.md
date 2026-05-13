# ingest

Acquire a source and save it to the raw library. Does NOT create wiki pages — use `compile` for that.

Syntax: `/llm-wiki:wiki ingest <path|url>`

---

## Step 0 — Pre-flight (MANDATORY)

```bash
bash scripts/preflight.sh
```
Reproduce the READY line verbatim. Define `QMD`/`MARP` from `DATA=`. Read `HAS_PDFTOTEXT`, `HAS_PDFIMAGES`, `HAS_PDFTOPPM`, `HAS_PANDOC`, `PYTHON`, `TIER` from the READY line — no separate toolchain detection needed.

---

## Steps

### 1. Detect active wiki
Walk up from `cwd`. Read `CLAUDE.md`.

### 2. Acquire source
- **URL:** use WebFetch tool to retrieve content.
- **File path already in `raw/`:** skip to step 3 (source already saved).
- **Other file path:** read the file directly.

### 2b. Detect format and size threshold

```bash
LLM_WIKI_SPLIT_THRESHOLD="${LLM_WIKI_SPLIT_THRESHOLD:-204800}"  # 200 KB extracted text
```

| Extension | PROCESSOR |
|-----------|-----------|
| `.pdf` | `pdf` |
| `.docx` | `docx` |
| `.pptx` | `pptx` |
| `.epub` | `epub` |
| `.md` / `.txt` | `text` |
| other | `unknown` |

If extracted text size exceeds `LLM_WIKI_SPLIT_THRESHOLD`: activate **chapter-split mode** (steps 2c–2g). Otherwise continue to step 3.

`[llm-wiki:ingest] step=2b PROCESSOR=<type> MODE=<single-file|chapter-split>`

### 2c. Chapter-split — extract text and detect boundaries

> ⚠️ **DO NOT use the Read tool on PDF, docx, pptx, or epub files. The PreToolUse hook will block it.**
> **Why:** Read tool invokes `pdftoppm` internally (Windows: not in harness PATH → errors). For binary Office formats it returns raw binary, not text.
> **Instead:** Use the Bash commands below for each format.

For `PROCESSOR=pdf` (requires `HAS_PDFTOTEXT=true`; if false, abort and report install from `references/toolchain-by-os.md`):
```bash
pdftotext "<source-file>" -
```
- **Pass 1 (TOC-based):** look for dense `section-number … page-number` lines; parse chapter headings + start pages.
- **Pass 2 (heading fallback):** if no TOC detected, scan for all-caps lines or `1.` / `CHAPTER 1` patterns.
- Build manifest: `[{chapter_num, title, start_page, end_page}]`.

For `PROCESSOR=docx|epub` (requires `HAS_PANDOC=true`; if false, abort):
```bash
pandoc "<source-file>" --to=markdown
```
Split at Heading 1 boundaries.

For `PROCESSOR=pptx` (requires `HAS_PANDOC=true`):
```bash
pandoc "<source-file>" --to=markdown
```
Split at named slide sections; fall back to groups of N slides.

For `PROCESSOR=text`: split at H1/H2 headings; fall back to ~6000-word chunks.

`[llm-wiki:ingest] step=2c TOC_FOUND=<bool> CHAPTERS_DETECTED=<N>`

### 2d. Chapter-split — write per-chapter article files

For each chapter write `raw/articles/YYYY-MM-DD-<parent-slug>-ch<N>-<chapter-slug>.md`:
```yaml
---
date: YYYY-MM-DD
source-type: paper
source-url: <original file path>
source-pdf-pages: <start>-<end>        # PDF only
parent-doc: <parent-slug>
chapter: "<N>"
section-range: "<M.x>-<M.y>"          # sub-splits only — omit for whole-chapter articles
chapter-title: <chapter title>
title: "<Doc Title> — Ch.<N>: <chapter title>"
compiled: false
---
<full extracted text of this chapter>
```

**Sub-splits:** when a single chapter still exceeds context, split into multiple files. Same `chapter:` value for all parts; add `section-range:` (e.g. `"8.1-8.3"`) to identify sections covered.

Write hub article `raw/articles/YYYY-MM-DD-<parent-slug>-index.md` — see `paper-index.md` in `references/init-templates.md`.

`[llm-wiki:ingest] step=2d ARTICLES_WRITTEN=<N> HUB_WRITTEN=<bool>`

### 2e. Chapter-split — image extraction (Tier 1+)

If `HAS_PDFIMAGES=true`:
```bash
pdfimages -list "<source-file>"
```
For pages with large images, note in chapter article frontmatter: `<!-- diagram-pages: 12, 34 -->`.

If `HAS_PDFTOPPM=true` (Tier 2): render flagged pages:
```bash
pdftoppm -r 150 -png -f <page> -l <page> "<source-file>" <output-prefix>
```
Save to `raw/attachments/<parent-slug>-images/page-<NNN>.png`. Describe each diagram and write `raw/articles/YYYY-MM-DD-<parent-slug>-diagram-p<NNN>.md` with `source-type: image-set`.

If tools missing: log `[WARN] Image extraction skipped — pdfimages/pdftoppm not found.`

`[llm-wiki:ingest] step=2e IMAGES_EXTRACTED=<N>`

Chapter-split complete — skip steps 3–4, continue from step 5.

---

### 3. Classify (single-file path only)
Classify as: `article` | `paper` | `transcript` | `conversation` | `image-set`.

### 4. Save to raw library

> ⚠️ **DO NOT write LLM-generated content into `raw/`.**
> **Why:** `raw/` is the immutable source archive. Synthesized content there corrupts the audit trail.
> **Instead:** `raw/articles/` is for ingested originals only. All LLM-generated pages go to `wiki/`.

Write `raw/articles/YYYY-MM-DD-<slug>.md` with frontmatter (see `references/frontmatter-schemas.md`):
`date`, `source-type`, `source-url`, `title`, `compiled: false`.

If input was already a file in `raw/`, skip this step.

### 5. Append to `log.md`
```
## [YYYY-MM-DD] ingest | <title>
Saved <source-type> from <source> to raw/articles/.
```
`[llm-wiki:ingest] step=5 LOG_APPENDED=true`

### 6. Git commit
If `LLM_WIKI_GIT` is not `false`:
```bash
git -C ${VAULT_ROOT} add "${WIKI_SUBDIR}/<wiki-name>/" && git -C ${VAULT_ROOT} commit -m "ingest: <title>"
```

### 7. Print
"Source saved to `raw/articles/<filename>`. Run `wiki compile` to integrate into the wiki."

`[llm-wiki:ingest] DONE`

---
name: wiki
description: >-
  LLM Wiki — persistent, compounding knowledge base inside Obsidian.
  Use when the user says "/llm-wiki:wiki", "wiki init", "wiki ingest",
  "wiki query", "wiki lint", or asks about managing a knowledge base wiki.
argument-hint: init <name> | ingest <path|url> | compile [<path>] | query <question> | lint | split <path|name> | update <name> | remove <name>
---

# LLM Wiki

Persistent, compounding knowledge base inside an Obsidian vault.

## Operations

```
/llm-wiki:wiki init my-topic
/llm-wiki:wiki ingest ${VAULT_ROOT}/${WIKI_SUBDIR}/my-topic/raw/article.md
/llm-wiki:wiki ingest https://example.com/article
/llm-wiki:wiki query "What is X?"
/llm-wiki:wiki lint
```

---

## Active Wiki Detection

Walk up from `cwd` looking for a directory containing **both** `CLAUDE.md` and a `wiki/` subfolder.

1. Start at `cwd`. Check if `CLAUDE.md` and `wiki/` exist in the current directory.
2. If found → that directory is the **active wiki root**. Read `CLAUDE.md` for schema.
3. If not found → move to parent directory and repeat until filesystem root.
4. If no wiki found anywhere in the path, prompt the user:
   > "Which wiki should I use?"
   List available wikis by running: `ls -d ${VAULT_ROOT}/${WIKI_SUBDIR}/*/wiki 2>/dev/null`
   and presenting the parent directory names.

---

## Vault Root

```
VAULT_ROOT="${LLM_WIKI_VAULT:-$HOME/ObsidianVault}"
WIKI_SUBDIR="${LLM_WIKI_SUBDIR:-03-Resources}"
```

Resolve both variables once at the start of each command. `LLM_WIKI_VAULT` sets the Obsidian vault root (default: `~/ObsidianVault`). `LLM_WIKI_SUBDIR` sets the subdirectory within the vault where wikis are stored (default: `03-Resources`). Use `${VAULT_ROOT}` and `${WIKI_SUBDIR}` wherever these instructions reference those paths.

---

## qmd Availability

If `CLAUDE_PLUGIN_DATA` or `CLAUDE_PLUGIN_ROOT` are not set in the environment (the harness
does not always inject them), resolve them with these fallbacks before use:

```bash
if [ -z "${CLAUDE_PLUGIN_DATA}" ]; then
  CLAUDE_PLUGIN_DATA=$(ls -d ~/.claude/plugins/data/llm-wiki-* 2>/dev/null | head -1)
fi
if [ -z "${CLAUDE_PLUGIN_ROOT}" ]; then
  CLAUDE_PLUGIN_ROOT=$(ls -d ~/.claude/plugins/cache/llm-wiki/llm-wiki/*/ 2>/dev/null | sort -V | tail -1)
fi
```

Reference paths used throughout this skill:

```
QMD="env -u BUN_INSTALL ${CLAUDE_PLUGIN_DATA}/node_modules/.bin/qmd"
MARP="${CLAUDE_PLUGIN_DATA}/node_modules/.bin/marp"
```

**Check:** Test if `"${CLAUDE_PLUGIN_DATA}/node_modules/.bin/qmd"` exists and is executable via Bash: `test -x "${CLAUDE_PLUGIN_DATA}/node_modules/.bin/qmd"`.

**Important:** Always invoke qmd via `env -u BUN_INSTALL` to force Node.js runtime. If `BUN_INSTALL` is set in the environment, qmd runs under Bun, which uses a SQLite build without extension loading support and cannot load sqlite-vec.

- **If present:** use it for `query` and `embed` operations. ALWAYS use the full path — never bare `qmd`.
- **If absent:** fall back to reading `wiki/index.md` manually and grepping wiki files.

---

## Git

```
WIKI_GIT="${LLM_WIKI_GIT:-true}"
```

If `LLM_WIKI_GIT=false` is set in the environment, skip all git commit steps in this skill. Useful when the vault is managed by a cloud sync service (e.g. Google Drive, Dropbox) where running git inside the synced directory causes conflicts. The `log.md` file records every operation regardless.

---

## Toolchain Detection

Run once at the start of any large-document operation. Set capability flags used throughout the large-document path:

```bash
HAS_PDFTOTEXT=$(command -v pdftotext >/dev/null 2>&1 && echo true || echo false)
HAS_PDFIMAGES=$(command -v pdfimages >/dev/null 2>&1 && echo true || echo false)
HAS_PDFTOPPM=$(command -v pdftoppm  >/dev/null 2>&1 && echo true || echo false)
HAS_PANDOC=$(command -v pandoc      >/dev/null 2>&1 && echo true || echo false)
```

Capability tiers — the skill uses whatever is available and logs what was skipped:

| Tier | Tools required | Capabilities unlocked |
|------|---------------|----------------------|
| 0 — baseline | pdftotext | Text extraction, TOC parsing, chapter splitting |
| 1 — image inventory | + pdfimages | Enumerate images per page; detect diagram pages |
| 2 — page rendering | + pdftoppm | Render pages as PNG for vision-based diagram description |
| 3 — full | + pandoc | Word (.docx), EPUB, and PowerPoint (.pptx) processing |

**One-time setup message:** On first large-document ingest on a given machine, check for the sentinel file `<wiki-root>/.pdf-toolchain-checked`. If absent, print installation instructions for the detected platform and write the sentinel. Do not repeat the message on subsequent runs.

Platform-specific instructions to print:
```
To unlock full large-document support, install:
  Windows (winget):  winget install -e --id oschwartz10612.Poppler
                     winget install -e --id JohnMacFarlane.Pandoc
  macOS (brew):      brew install poppler pandoc
  Linux (apt):       sudo apt install poppler-utils pandoc
```

---

## `init <name>`

Create a new wiki scaffold under the Obsidian vault.

### Steps

1. **Check if wiki already exists:**
   If `${VAULT_ROOT}/${WIKI_SUBDIR}/<name>/` exists, abort with:
   "Wiki '<name>' already exists at ${VAULT_ROOT}/${WIKI_SUBDIR}/<name>/. Use `wiki remove <name>` first, or choose a different name."

2. Create directory structure:
    ```bash
    mkdir -p ${VAULT_ROOT}/${WIKI_SUBDIR}/<name>/raw/articles
    mkdir -p ${VAULT_ROOT}/${WIKI_SUBDIR}/<name>/raw/attachments
    mkdir -p ${VAULT_ROOT}/${WIKI_SUBDIR}/<name>/wiki/queries
    mkdir -p ${VAULT_ROOT}/${WIKI_SUBDIR}/<name>/outputs/reports
    ```

3. Write `${VAULT_ROOT}/${WIKI_SUBDIR}/<name>/CLAUDE.md` using the **CLAUDE.md template** below (fill in `<name>`).

4. Write `${VAULT_ROOT}/${WIKI_SUBDIR}/<name>/wiki/index.md` using the **index.md template** below.

5. Write `${VAULT_ROOT}/${WIKI_SUBDIR}/<name>/log.md` using the **log.md template** below.

6. Write `${VAULT_ROOT}/${WIKI_SUBDIR}/<name>/.gitignore` using the **.gitignore template** below.

7. Write `${VAULT_ROOT}/${WIKI_SUBDIR}/<name>/qmd.yml` using the **qmd.yml template** below.

8. If `WIKI_GIT` is not `false`, commit:
   ```bash
   git -C ${VAULT_ROOT} add "${WIKI_SUBDIR}/<name>/" && git -C ${VAULT_ROOT} commit -m "init: <name> wiki"
   ```

9. If qmd available:
   ```bash
   "${QMD}" collection add ${VAULT_ROOT}/${WIKI_SUBDIR}/<name>/wiki --name <name> && "${QMD}" embed --collection <name>
   ```

10. Print Web Clipper setup instruction:
     ```
     Obsidian Web Clipper setup:
     1. Install: https://obsidian.md/clipper
     2. In clipper settings, set Destination folder to:
        ${WIKI_SUBDIR}/<name>/raw/articles
     3. Set filename template to: {{date:YYYY-MM-DD}}-{{title}}
     4. After clipping, run: /llm-wiki:wiki ingest ${VAULT_ROOT}/${WIKI_SUBDIR}/<name>/raw/articles/<clipped-file>.md
     ```

---

## `ingest <path|url>`

Acquire a source and save it to the raw library. Does NOT create wiki pages — use `compile` for that.

### Steps

1. **Detect active wiki** (see Active Wiki Detection). Read `CLAUDE.md` for schema.

2. **Acquire source:**
   - If input is a **URL**: use the WebFetch tool to retrieve content.
   - If input is a **file path**: read the file directly.
   - If the source file is in `raw/` directly (not in a subdirectory), read it from there. Sources saved before the `raw/articles/` convention are still valid.

2b. **Detect format and check size threshold:**

   Resolve the split threshold:
   ```bash
   LLM_WIKI_SPLIT_THRESHOLD="${LLM_WIKI_SPLIT_THRESHOLD:-204800}"  # 200 KB extracted text
   ```

   Detect format from file extension:
   ```
   .pdf  → PROCESSOR=pdf
   .docx → PROCESSOR=docx
   .pptx → PROCESSOR=pptx
   .epub → PROCESSOR=epub
   .md / .txt → PROCESSOR=text
   other → PROCESSOR=unknown
   ```

   For file-path sources, check if the extracted (or raw) text size exceeds `LLM_WIKI_SPLIT_THRESHOLD`. If yes, activate **chapter-split mode** (steps 2c–2g below). Otherwise continue to step 3 as normal.

2c. **Chapter-split mode — toolchain detection:** Run the Toolchain Detection checks above. Print the one-time setup message if `.pdf-toolchain-checked` is absent.

2d. **Chapter-split mode — extract text and detect boundaries:**

   For `PROCESSOR=pdf` (requires pdftotext):
   - Run `pdftotext <source-file> -` to extract full text.
   - **Pass 1 (TOC-based):** Look for a table-of-contents page — a dense run of `section-number … page-number` lines. Parse chapter headings and start pages from the TOC.
   - **Pass 2 (heading fallback):** If no TOC detected, scan text for all-caps lines or numbered section headers (`1.`, `CHAPTER 1`, etc.) to infer boundaries.
   - Build a chapter manifest: `[{chapter_num, title, start_page, end_page}]`.

   For `PROCESSOR=docx` or `PROCESSOR=epub` (requires pandoc):
   - Run `pandoc <source-file> --to=markdown` to convert to markdown.
   - Split at Heading 1 boundaries.

   For `PROCESSOR=pptx` (requires pandoc):
   - Run `pandoc <source-file> --to=markdown`.
   - Split at named slide section boundaries; fall back to groups of N slides.

   For `PROCESSOR=text`:
   - Split at H1/H2 headings; fall back to token-count chunks (~6000 words each).

2e. **Chapter-split mode — write per-chapter article files:**

   For each chapter, write `raw/articles/YYYY-MM-DD-<parent-slug>-ch<N>-<chapter-slug>.md`:
   ```yaml
   ---
   date: YYYY-MM-DD
   source-type: paper
   source-url: <original file path>
   source-pdf-pages: <start>-<end>        # PDF only
   parent-doc: <parent-slug>
   chapter: "<N>"
   chapter-title: <chapter title>
   title: "<Doc Title> — Ch.<N>: <chapter title>"
   compiled: false
   ---
   <full extracted text of this chapter>
   ```

   Also write a **hub article** `raw/articles/YYYY-MM-DD-<parent-slug>-index.md`:
   ```yaml
   ---
   date: YYYY-MM-DD
   source-type: paper-index
   source-url: <original file path>
   parent-doc: <parent-slug>
   title: "<Doc Title> — Index"
   compiled: false
   ---
   ```
   Body: document title, classification, brief description, list of chapter article filenames.

2f. **Chapter-split mode — image extraction (Tier 1+):**

   If `HAS_PDFIMAGES=true`:
   - Run `pdfimages -list <source-file>` to inventory images per page.
   - For pages with large images (likely diagrams), note the page number in the corresponding chapter article frontmatter as a comment: `<!-- diagram-pages: 12, 34 -->`.

   If `HAS_PDFTOPPM=true` (Tier 2):
   - For each flagged diagram page, render as PNG: `pdftoppm -r 150 -png -f <page> -l <page> <source-file> <output-prefix>`.
   - Save rendered images to `raw/attachments/<parent-slug>-images/page-<NNN>.png`.
   - Use Claude vision to describe each diagram and write `raw/articles/YYYY-MM-DD-<parent-slug>-diagram-p<NNN>.md` with `source-type: image-set` and the description as body.

   If tools missing: log `[WARN] pdfimages/pdftoppm not found — image extraction skipped.`

2g. **Chapter-split mode — complete.** Skip steps 3–4 (article file already written). Continue from step 5.

3. **Classify** the source as one of: `article` | `paper` | `transcript` | `conversation` | `image-set`.

4. **Save to raw library:** Write to `raw/articles/YYYY-MM-DD-<slug>.md` with frontmatter:
   ```yaml
   ---
   date: YYYY-MM-DD
   source-type: <classification>
   source-url: <original URL or file path>
   title: <extracted or inferred title>
   compiled: false
   ---
   ```
   If input was a file path already in `raw/`, skip this step (source is already saved).

5. **Append to `log.md`:**
   ```
   ## [YYYY-MM-DD] ingest | <title>
   Saved <source-type> from <source> to raw/articles/.
   ```

6. If `WIKI_GIT` is not `false`, **commit:**
   ```bash
   git -C ${VAULT_ROOT} add "${WIKI_SUBDIR}/<wiki-name>/" && git -C ${VAULT_ROOT} commit -m "ingest: <title>"
   ```

7. **Print:** "Source saved to raw/articles/<filename>. Run `wiki compile` to integrate into the wiki."

---

## `split <path|name>`

Retroactively apply chapter-splitting to a document that was already ingested as a single article file. Use this when a large document was ingested before chapter-split mode was available, or when you want to re-split with updated boundaries.

`<path>` may be a path to a specific raw article file, or a `parent-doc` slug name.

### Steps

1. **Detect active wiki.** Read `CLAUDE.md`.

2. **Resolve target article:**
   - If `<path>` is a file path: use it directly.
   - If `<path>` is a name: find `raw/articles/*-<name>*.md` or `raw/articles/*-<name>-index.md`.

3. **Read target article.** Extract `source-url` from frontmatter to locate the original file in `raw/attachments/`.

4. **Verify original file exists** at `source-url`. If not, abort: "Original source file not found at <source-url>. Cannot split."

5. **Run toolchain detection** (see Toolchain Detection section).

6. **Run chapter boundary detection** (same as ingest step 2d) on the original file.

7. **Write per-chapter article files** (same as ingest step 2e) with `compiled: false`.

8. **Write hub article** if not already present.

9. **Run image extraction** (same as ingest step 2f) if tools available.

10. **Archive original single-file article** to `raw/articles/archive/<original-filename>`. Create `raw/articles/archive/` if needed.

11. **Append to `log.md`:**
    ```
    ## [YYYY-MM-DD] split | <parent-doc>
    Split into N chapter articles. Original archived to raw/articles/archive/.
    ```

12. If `WIKI_GIT` is not `false`, **commit:**
    ```bash
    git -C ${VAULT_ROOT} add "${WIKI_SUBDIR}/<wiki-name>/" && git -C ${VAULT_ROOT} commit -m "split: <parent-doc>"
    ```

13. **Print:** "Split into N chapter articles. Run `wiki compile` to integrate into the wiki."

---

## `update <name>`

Re-ingest a revised edition of a document that was previously split into chapter articles. Only chapters with changed revision dates are re-ingested; unchanged chapters are left as-is.

`<name>` is the `parent-doc` slug of the existing document set.

### Steps

1. **Detect active wiki.** Read `CLAUDE.md`.

2. **Prompt for new source file path** (or accept as second argument if provided): "Path to the new edition of <name>?"

3. **Run toolchain detection.**

4. **Extract TOC and chapter manifest** from the new file (same as ingest step 2d).

5. **Compare against existing chapter articles:** For each chapter in the manifest, find the matching chapter article by `chapter:` frontmatter. Compare chapter revision date (from TOC) against the article's `date:` field.

6. **Re-ingest changed chapters only:**
   - Archive the old chapter article to `raw/articles/archive/`.
   - Write a new chapter article with updated content and `compiled: false`.
   - Log: "Chapter <N> updated."

7. **Report unchanged chapters:** "Chapters X, Y, Z unchanged — skipped."

8. **Update hub article** with new edition metadata (date, source-url).

9. **Append to `log.md`:**
   ```
   ## [YYYY-MM-DD] update | <name>
   New edition ingested. N chapters updated, M unchanged.
   ```

10. If `WIKI_GIT` is not `false`, **commit:**
    ```bash
    git -C ${VAULT_ROOT} add "${WIKI_SUBDIR}/<wiki-name>/" && git -C ${VAULT_ROOT} commit -m "update: <name>"
    ```

11. **Print:** "N chapters updated. Run `wiki compile` to integrate changes into the wiki."

---

## `compile [<path>]`

Read raw sources and create/update wiki pages with entity extraction and cross-references.

- If `<path>` is given: compile that specific raw source.
- If no argument: scan `raw/articles/` for sources without a corresponding source-summary page in `wiki/`, and compile those.

### Steps

1. **Detect active wiki.** Read `CLAUDE.md` for schema and templates.

2. **Identify sources to compile:**
   - If path argument given: use that file.
   - Otherwise: list files in `raw/articles/`. For each, check if a corresponding source-summary page exists in `wiki/` (match by slug or title). Compile any source without a matching summary.
   - If nothing to compile: "All sources are already compiled. Nothing to do." Stop.

2b. **Detect grouped compile:** Check whether the identified sources include any files with a `parent-doc` frontmatter field. Group them by `parent-doc` value. Process each group together (steps 3–3d below), then process non-grouped sources individually.

3. **For each source (or grouped set) to compile:**

   a. **For grouped sets (chapter articles sharing a `parent-doc`):**
      - Read the hub article (`raw/articles/*-<parent-doc>-index.md`) first to establish document-level context.
      - Process chapters in order (`chapter:` field ascending).
      - Maintain a **shared entity accumulator** across all chapters: a running list of all entity pages created or updated during this group's compile. Use it to resolve cross-chapter references within the group.

   b. Read the raw source content.

   c. **Write or update source-summary page** in `wiki/` using the `source-summary` template from `CLAUDE.md`. Filename: `<slug>.md`.

   d. **Entity extraction:** For each mentioned entity (person, concept, event):
      - Check if a page already exists in `wiki/`.
      - If yes → update with new information, preserving existing content.
      - If no → create using the appropriate template (`concept.md` or `person.md`).
      - Add `[[wikilinks]]` to related pages in both directions.

   e. **Backlink audit** (CRITICAL — do not skip):
      ```bash
      grep -rln "<new page title>" wiki/
      ```
      For each file that mentions the new page title but does NOT contain `[[new-page-name]]`:
      add a `[[wikilink]]` at the first mention.

3b. **Cross-chapter entity merge (grouped sets only):**
   After all chapters in a group are compiled, run a group-level backlink audit:
   - For each entity page created during this group's compile, grep all wiki pages (not just the current chapter's pages) for plain-text mentions.
   - Add `[[wikilinks]]` at first mention in any page that references the entity without a link.

3c. **Write or update hub wiki page (grouped sets only):**
   Create (or update) `wiki/<parent-doc>.md` as a concept page listing all chapter wiki pages and source-summary pages generated from this group. This page becomes the primary entry point for queries about this document.

4. **Update `wiki/index.md`** with new/updated entries under the appropriate domain heading.

5. **Append to `log.md`:**
   ```
   ## [YYYY-MM-DD] compile | <N> sources → <M> pages
   Compiled <source-titles>. Created/updated M pages.
   ```

6. If `WIKI_GIT` is not `false`, **commit:**
   ```bash
   git -C ${VAULT_ROOT} add "${WIKI_SUBDIR}/<wiki-name>/" && git -C ${VAULT_ROOT} commit -m "compile: <summary>"
   ```

7. **If qmd available:**
   ```bash
   "${QMD}" embed --collection <name>
   ```

---

## `query <question>`

Answer a question using wiki knowledge, with citations.

### Steps

1. **Detect active wiki.** Read `CLAUDE.md`.

2. **Find relevant pages:**
   - If qmd available:
     ```bash
     "${QMD}" query "<question>" --collection <name>
     ```
     Parse output for candidate page paths.
   - Otherwise: read `wiki/index.md` and identify relevant pages by title/description matching.

3. **Read all relevant pages.**
   - If any candidate page has a `parent-doc` frontmatter field, first read the hub wiki page (`wiki/<parent-doc>.md`) to establish document-level context.
   - Then read the specific candidate pages.
   - Follow one level of `[[wikilinks]]` if targets look relevant to the question.

4. **Synthesize answer** with `[[wikilinks]]` as citations. Format rules:
   - **Default:** prose with inline wikilink citations.
   - **If question contains "table":** markdown table with wikilink citations in cells.
   - **If question contains "slides":** Marp markdown with `marp: true` frontmatter. Render with: `"${MARP}" <file> -o output.html`

5. **File the answer** to `wiki/queries/<slug>.md` using the `query-output` frontmatter schema. Always file — no prompt.

6. **Ask:** "Promote this answer to `wiki/<slug>.md` as a concept page? (y/n)"
   - If yes: move the file from `wiki/queries/` to `wiki/`, update frontmatter `status` from `filed` to `promoted`, and append to `log.md`:
     ```
     ## [YYYY-MM-DD] promote | <slug>
     Promoted query answer to concept page.
     ```

7. **Append to `log.md`:**
   ```
   ## [YYYY-MM-DD] query | <question-slug>
   Answered question. Referenced N pages. Filed to queries/<slug>.md.
   ```

8. If `WIKI_GIT` is not `false`, **commit:**
   ```bash
   git -C ${VAULT_ROOT} add "${WIKI_SUBDIR}/<wiki-name>/" && git -C ${VAULT_ROOT} commit -m "query: <slug>"
   ```

---

## `lint`

Audit wiki integrity and fix issues.

### Steps

1. **Read all files** in `wiki/`.

2. **Build a link graph:** for each `[[wikilink]]` on each page, record the edge (source → target).

3. **Run deterministic lint script** if available:
   ```bash
   PY=""
   for candidate in python3 py python; do
     if command -v "$candidate" >/dev/null 2>&1 && "$candidate" -c "" >/dev/null 2>&1; then
       PY=$(command -v "$candidate")
       break
     fi
   done
   [ -n "$PY" ] && "${PY}" "${CLAUDE_PLUGIN_ROOT}/scripts/lint-wiki.py" <wiki-root>/wiki/
   ```

4. **Report and fix:**

   | Check | Action |
   |-------|--------|
   | **Orphan pages** (no inbound links) | List them. Suggest adding links from related pages. |
   | **Dead links** (`[[wikilinks]]` to nonexistent files) | Create stub pages with appropriate template. |
   | **Unlinked concept mentions** | Scan pages for proper nouns and technical terms appearing in prose without `[[wikilinks]]`. If a corresponding page exists, add the wikilink at first mention. If no page exists, flag as a candidate for a new page. |
   | **Contradictions** | Scan for `[!WARNING]` markers. List them. |
   | **Missing "Counter-Arguments and Gaps" sections** | Add empty `## Counter-Arguments and Gaps` section. |
   | **Stale pages** | Flag pages with `status: stale` in frontmatter. |
   | **Index drift** | Compare `index.md` entries vs actual files. Add missing, remove dead. |
   | **Missing hub article** | A `parent-doc` group exists in `raw/articles/` but no `*-index.md` hub article. Suggest `wiki split <name>`. |
   | **Missing hub wiki page** | A hub article (`source-type: paper-index`) exists in `raw/articles/` but `wiki/<parent-doc>.md` does not exist. Flag as uncompiled hub. |
   | **Chapter sequence gaps** | Parse `chapter:` frontmatter across each `parent-doc` group; flag non-contiguous sequences (e.g. ch1, ch2, ch4 — ch3 missing). |
   | **Stuck uncompiled sources** | Article files with `compiled: false` older than 7 days. List them and suggest `wiki compile`. |
   | **Image-set stubs** | `source-type: image-set` articles with no body content — image extracted but never described. |
   | **Page range overlaps** | Within a `parent-doc` group, check that `source-pdf-pages` ranges are contiguous and non-overlapping. |

5. **Suggest growth opportunities:** Based on the wiki's current content and the gaps found in step 4, generate:
   - 3-5 questions the wiki cannot yet answer well (candidates for `wiki query`)
   - 2-3 topic areas or sources that would most strengthen the wiki
   - If any `parent-doc` group has fewer than 50% of its chapter articles compiled, flag it: "Document '<name>' is partially compiled — consider running `wiki compile`."

6. **Write lint report** to `outputs/reports/YYYY-MM-DD-lint.md`:
   ```markdown
   # Lint Report — YYYY-MM-DD

   **Wiki:** <name> | **Issues found:** N | **Fixed:** M

   ## Issues
   <full issue table from step 4>

   ## Next Steps
   <growth suggestions from step 5>
   ```

7. **Append to `log.md`:**
   ```
   ## [YYYY-MM-DD] lint | N issues found, M fixed
   <summary of issues>
   ```

8. If `WIKI_GIT` is not `false`, **commit:**
   ```bash
   git -C ${VAULT_ROOT} commit -am "lint: YYYY-MM-DD"
   ```

---

## `remove <name>`

Delete a wiki and all its contents.

### Steps

1. **Resolve wiki path:** `${VAULT_ROOT}/${WIKI_SUBDIR}/<name>/`

2. **Verify it exists.** If not, abort: "Wiki '<name>' does not exist."

3. **Confirm with user:** List the directory contents and ask "This will permanently delete the '<name>' wiki and all its contents. Proceed? (y/n)"

4. **Remove qmd collection** (if qmd available):
   ```bash
   "${QMD}" collection remove <name>
   ```

5. **Remove from filesystem:**
   - If `WIKI_GIT` is not `false`:
     ```bash
     git -C ${VAULT_ROOT} rm -rf "${WIKI_SUBDIR}/<name>/" && git -C ${VAULT_ROOT} commit -m "remove: <name> wiki"
     ```
   - Otherwise:
     ```bash
     rm -rf ${VAULT_ROOT}/${WIKI_SUBDIR}/<name>/
     ```

6. **Confirm:** "Wiki '<name>' has been removed."

---

## Error Handling

Handle these failure modes gracefully:

| Situation | Action |
|-----------|--------|
| **No active wiki found** | List available wikis in `${VAULT_ROOT}/${WIKI_SUBDIR}/*/wiki`. Suggest `wiki init <name>` if none exist. |
| **qmd not available** | Fall back to `wiki/index.md` for search. Warn: "qmd unavailable — using index.md fallback." |
| **Network error on URL ingest** | Retry once. If still failing, report the error and suggest saving content manually to `raw/articles/`. |
| **Git commit fails** | Warn: "Git commit failed: <error>. Changes are saved but not committed." Continue with remaining steps. |
| **`LLM_WIKI_GIT=false`** | Skip all git steps silently. `log.md` still records every operation. |
| **Wiki already exists** (on init) | Abort with message referencing `wiki remove`. |
| **Raw source too large** (>50KB, below split threshold) | Warn: "Large source detected. Entity extraction may be incomplete. Consider splitting." Proceed anyway. |
| **Source exceeds split threshold** | Activate chapter-split mode automatically. Warn if pdftotext unavailable for PDF sources. |
| **TOC not detected in PDF** | Fall back to heading-based boundary detection. Warn: "No TOC detected — using heading scan for chapter boundaries." |
| **Chapter too large** (single chapter still exceeds context) | Sub-split at section level (next heading depth). Log: "Chapter <N> sub-split into M sections." |
| **pdftotext unavailable for PDF** | Abort large-document path. Warn: "pdftotext required for PDF processing. Install Poppler." Fall back to single-file ingest. |
| **pdfimages / pdftoppm unavailable** | Skip image extraction silently. Log: "[WARN] Image extraction skipped — pdfimages/pdftoppm not found." |
| **pandoc unavailable for docx/pptx/epub** | Abort large-document path for those formats. Warn: "pandoc required for .docx/.pptx/.epub processing. Install pandoc." |
| **Original file missing on split** | Abort: "Original source file not found at <source-url>. Cannot split." |
| **No changed chapters on update** | Report: "All chapters up to date. Nothing to update." Stop. |
| **log.md missing** | Create fresh log.md from template at topic root. Warn: "log.md was missing — created a new one." |
| **No uncompiled sources** (on compile) | Report: "All sources are already compiled. Nothing to do." Stop. |
| **qmd collection not found** | Warn and continue without search indexing. |

---

## Templates

Used by the `init` operation. Apply verbatim, replacing `<name>` with the wiki name.

### CLAUDE.md

```markdown
# <name> Wiki Schema

## Directory Layout
- raw/              -- immutable source drops. Never edit files here.
- raw/articles/     -- text source documents (articles, papers, transcripts).
- raw/attachments/  -- images and binary attachments.
- wiki/             -- LLM-owned pages. You have full write access here.
- wiki/index.md     -- catalog. Read this FIRST before opening any other page.
- wiki/queries/     -- filed query answers. Promote to wiki/ when durable.
- outputs/reports/  -- dated lint reports and other artifacts.
- log.md            -- append-only operation log. Never edit existing entries.

## Entity Types and Templates

### concept.md
---
date: YYYY-MM-DD
tags: [domain]
type: concept
status: active
---
# Concept Name
<one-paragraph summary>

## Details
...

## See Also
- [[related-concept]]

## Counter-Arguments and Gaps
...

### person.md
---
date: YYYY-MM-DD
tags: [domain, person]
type: person
status: active
---
# Person Name
Role / affiliation.

## Key Contributions
...

## See Also
- [[related-concept]]

### source-summary.md
---
date: YYYY-MM-DD
tags: [domain]
type: source-summary
source-url: https://...
---
# Source Title
One-paragraph summary.

## Key Points
...

## Entities Mentioned
- [[person-or-concept]]

## Slides
To export as a Marp slide deck, add `marp: true` to frontmatter and run:
  "${MARP}" wiki/<filename>.md -o output.html

### query-output.md
---
date: YYYY-MM-DD
tags: [domain]
type: query-output
question: "<original question>"
status: filed
---
# <Question as title>
<synthesized answer>

## Sources
- [[page-1]]
- [[page-2]]

## Naming Conventions
- All filenames: lowercase-kebab-case.md
- Wikilinks: [[filename-without-extension]]
- Never use standard markdown links for internal links

## Log Format
Append to log.md after every operation. Format:
  ## [YYYY-MM-DD] <operation> | <title>
  <one-line description>

Operations: ingest | compile | query | lint | promote | split | update | remove

## Index Format
wiki/index.md is a human- and LLM-readable catalog. Format:
  ## Domain Name
  - [[page-name]] -- one-line description (YYYY-MM-DD)

Keep entries under 80 chars. Update after every ingest.

## Cross-Reference Rules
- Every page must link to at least one other page when content warrants it
- When creating or updating a concept page, scan index.md for related entities and add [[wikilinks]]
- Flag contradictions inline: > [!WARNING] Contradiction with [[other-page]]

## Ingest Rules
1. Acquire the source (URL or file)
2. Classify the source type
3. Save to raw/articles/ with frontmatter (compiled: false)
4. Append to log.md
5. Commit
Ingest does NOT create wiki pages. Use compile for that.

## Compile Rules
1. Identify uncompiled raw sources (no matching source-summary in wiki/)
2. For each source: write source-summary, extract entities, create/update pages
3. Backlink audit: grep existing pages for mentions of new titles
4. Update wiki/index.md
5. Append to log.md
6. Commit
One source typically touches 5-15 pages. This is normal.

## Query Rules
1. Read wiki/index.md first
2. Open relevant pages
3. Synthesize answer with [[wikilinks]] as citations
4. Always file answer to wiki/queries/ (mandatory, no prompt)
5. Offer promotion to wiki/ as a concept page (y/n)
6. Append to log.md (both query and optional promote events)
7. Commit changes

## Lint Rules
Scan all pages in wiki/ and report:
- Contradictions between pages
- Orphan pages (no inbound [[links]])
- Pages with status: stale older than 90 days
- Missing Counter-Arguments and Gaps section
- Index entries pointing to missing files
After fixing, append to log.md and commit.
```

### paper-index.md (hub article for split documents)

```markdown
---
date: YYYY-MM-DD
source-type: paper-index
source-url: <original file path>
parent-doc: <parent-slug>
title: "<Doc Title> — Index"
compiled: false
---
# <Doc Title>

<Brief description of the document — type, publisher, date, purpose.>

## Chapters

- [[<parent-slug>-ch01-<slug>]] — <chapter title>
- [[<parent-slug>-ch02-<slug>]] — <chapter title>
...
```

### .gitignore

```
.DS_Store
*.sqlite
*.sqlite-wal
*.sqlite-shm
```

### qmd.yml

```yaml
collections:
  <name>:
    path: ./wiki
    pattern: "**/*.md"
```

### wiki/index.md

```markdown
# <name> Wiki Index

Last updated: YYYY-MM-DD

<!-- Add entries after each ingest. Format:
## Domain
- [[page-name]] -- description (YYYY-MM-DD)
-->
```

### log.md

```markdown
# <name> Wiki Log

<!-- Append only. Never edit existing entries. Format:
## [YYYY-MM-DD] ingest | Title
One-line description.
-->
```

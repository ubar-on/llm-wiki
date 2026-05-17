# Eval: ingest-pdf-large

**Category:** ingest
**Platform:** all
**Setup:**
- A wiki initialized and ready (run `wiki init` if needed)
- A PDF ≥ 25 MB in `raw/attachments/` — the El Al FCOM_737 PDF qualifies; any large multi-chapter PDF will do
- Session opened at the wiki root

## Prompt

```
/llm-wiki:wiki ingest raw/attachments/<large-file>.pdf
```

## Expected behavior

### Required (must happen)
- [ ] `[llm-wiki] op=ingest loading operations/ingest.md` printed before any other output (or bash-cat command run as first tool call)
- [ ] `bash scripts/preflight.sh` called; READY line appears in bash output
- [ ] `pdftotext` called via Bash tool (e.g. `pdftotext raw/attachments/<file>.pdf -`)
- [ ] Chapter-split mode triggered: ≥ 2 chapter article files written to `raw/articles/`
- [ ] Hub article written to `raw/articles/` (filename contains `index` or parent-doc slug)
- [ ] Source-summary pages written to `wiki/` for each chapter
- [ ] `[llm-wiki:ingest] step=2b` checkpoint with `MODE=chapter-split`
- [ ] `[llm-wiki:ingest] step=2e ARTICLES_WRITTEN=<N>` checkpoint with N ≥ 2
- [ ] `[llm-wiki:ingest] DONE`
- [ ] Each written raw article has `compiled: false` in frontmatter

### Forbidden (must NOT happen)
- [ ] Read tool called with a `.pdf` file path (guard-read.sh should block or model should avoid)
- [ ] Write to any file inside `raw/articles/` that is a script or helper (temp files belong at wiki root)
- [ ] `compiled: true` in any freshly-ingested article
- [ ] Bare `qmd` called (must use `${QMD}` with `env -u BUN_INSTALL`)
- [ ] Chapter count = 1 when source PDF has detectable chapters

## Failure modes
- Model uses Read tool on PDF → guard fires; check that guard message appears or that model avoided Read
- Model uses bare `qmd` for embedding (BUN_INSTALL contamination risk)
- Chapter-split not triggered despite large file (model uses single-file ingest path)
- Hub article not written
- Temp helper scripts left in `raw/articles/` instead of wiki root

## Notes
- This eval is the primary regression test for the original failure that motivated v3 (large PDF ingest without preflight)
- If PDFIMAGES or PDFTOPPM are false (Tier 1), image extraction will be skipped — that is correct behavior, not a failure
- Verify SKILL_VERSION in READY line matches current installed version

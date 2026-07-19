# Eval: ingest-md-small

**Category:** ingest
**Platform:** all
**Setup:**
- A wiki initialized and ready
- A small Markdown file (≤ 10 KB) available — any `.md` file will do
- Session opened at the wiki root

## Prompt

```
/llm-wiki:wiki ingest <path-to-file>.md
```

## Expected behavior

### Required (must happen)
- [ ] `bash scripts/preflight.sh` called; READY line appears in bash output
- [ ] Article file written to `raw/articles/` with correct frontmatter
- [ ] Source-summary written to `wiki/`
- [ ] `[llm-wiki:ingest] DONE`
- [ ] Written article has `compiled: false`

### Forbidden (must NOT happen)
- [ ] `pdftotext` called (this is a Markdown file, not a PDF)
- [ ] `pandoc` called (not needed for .md)
- [ ] Read tool blocked by guards.mjs (guard only fires for binary formats: .pdf/.docx/.pptx/.epub)
- [ ] Chapter-split triggered

## Failure modes
- Model confusedly calls pdftotext on a .md file
- Model calls pandoc on a .md file

## Notes
- Markdown ingestion should be the simplest possible path: read the file, write the article stub, write the source-summary
- The guards.mjs should NOT fire for .md files — this eval incidentally verifies that the guard scope is correct

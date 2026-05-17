# Eval: ingest-pdf-small

**Category:** ingest
**Platform:** all
**Setup:**
- A wiki initialized and ready
- A PDF < 200 KB (below the default split threshold) in `raw/attachments/`
- Session opened at the wiki root

## Prompt

```
/llm-wiki:wiki ingest raw/attachments/<small-file>.pdf
```

## Expected behavior

### Required (must happen)
- [ ] `bash scripts/preflight.sh` called; READY line appears in bash output
- [ ] `pdftotext` called via Bash tool
- [ ] Exactly one article file written to `raw/articles/`
- [ ] One source-summary written to `wiki/`
- [ ] `[llm-wiki:ingest] DONE`
- [ ] Written article has `compiled: false` in frontmatter

### Forbidden (must NOT happen)
- [ ] Read tool called with a `.pdf` file path
- [ ] Chapter-split mode triggered (source is below threshold)
- [ ] Hub article created (single-file ingest does not create a hub)
- [ ] Multiple article files created from a single small PDF

## Failure modes
- Model applies chapter-split logic despite small file size
- Model uses Read tool on PDF

## Notes
- Default split threshold: 200 KB (controlled by `LLM_WIKI_SPLIT_THRESHOLD`)
- If the PDF has no detectable chapter structure, single-file ingest is correct even above the threshold (but this eval uses a PDF below the threshold to be unambiguous)

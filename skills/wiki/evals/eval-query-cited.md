# Eval: query-cited

**Category:** query
**Platform:** all
**Setup:**
- A wiki with ≥ 5 pages (source-summaries + concept pages) and wikilinks between them
- `qmd` indexed (QMD=true expected; run `wiki compile` first if needed to populate embeddings)
- Session opened at the wiki root

## Prompt

```
/llm-wiki:wiki query "What are the main qualification requirements for El Al pilots?"
```
(Adapt the question to match the content of the test wiki.)

## Expected behavior

### Required (must happen)
- [ ] `bash scripts/preflight.sh` called; READY line shows `QMD=true`
- [ ] `${QMD} query "..."` called (not bare `qmd`)
- [ ] Answer contains `[[wikilink]]` citations to relevant wiki pages
- [ ] Query and answer filed to `wiki/queries/<slug>.md`
- [ ] `[llm-wiki:query] DONE`

### Forbidden (must NOT happen)
- [ ] Bare `qmd query` called without `env -u BUN_INSTALL` prefix
- [ ] Answer given without filing to `wiki/queries/`
- [ ] Answer drawn entirely from training data without querying wiki
- [ ] Read tool used on individual wiki pages as a substitute for qmd query

## Failure modes
- Model answers from training data without calling qmd (skips the semantic search entirely)
- Model uses bare `qmd` (BUN_INSTALL contamination if set in environment)
- Query filed but with missing or malformed frontmatter
- No wikilink citations in answer

## Notes
- `${QMD}` is defined in Step 0 of the query operation as `env -u BUN_INSTALL <DATA>/node_modules/.bin/qmd`
- If QMD=false: model should fall back to `wiki/index.md` search and warn "qmd unavailable — index.md fallback"

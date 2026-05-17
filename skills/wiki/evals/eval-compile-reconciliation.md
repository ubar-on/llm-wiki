# Eval: compile-reconciliation

**Category:** compile
**Platform:** all
**Setup:**
- A wiki where:
  - A raw article exists with `compiled: false`
  - The corresponding `wiki/` source-summary page ALREADY EXISTS (correctly formed with proper frontmatter)
  - The index entry already exists in `wiki/index.md`
  - Backlinks are already in place
- This is the "already-compiled but flag not persisted" reconciliation path
- The El Al `oma-ch12-rules-of-the-air` article is the canonical test fixture (repeatedly toggled during v3 testing)

**To set up the fixture:**
1. Find any article where the wiki page exists
2. Set `compiled: false` in the raw article frontmatter

## Prompt

```
/llm-wiki:wiki compile
```

## Expected behavior

### Required (must happen)
- [ ] `[llm-wiki:compile] step=2 SOURCES=1` printed
- [ ] `[llm-wiki:compile] step=3 SOURCE=<slug> PAGES_CREATED=0 PAGES_UPDATED=0` printed — even though no wiki pages are created or updated
- [ ] `compiled: true` written to the raw article frontmatter (the whole point of this compile run)
- [ ] `[llm-wiki:compile] step=5 LOG_APPENDED=true` printed
- [ ] `[llm-wiki:compile] DONE`

### Forbidden (must NOT happen)
- [ ] step=3 checkpoint omitted because "nothing to write" (checkpoint is unconditional, not conditional on page creation)
- [ ] step=5 checkpoint omitted
- [ ] `compiled: true` NOT written (compile finishes but flag left as `false`)
- [ ] Model prints "All sources already compiled. Nothing to do." — incorrect; the source has `compiled: false` and must be processed

## Failure modes
- Model sees existing wiki page, prints step=2 but skips step=3 on the grounds that "no pages needed updating" (narration instinct overrides unconditional checkpoint rule — observed in 3.10.0 test, issue #22)
- Model skips step=5 log append when no pages were created
- Model confuses "wiki page exists" with "source already compiled" and stops at step=2
- `compiled: true` not written because model considers the work "already done" by the existing wiki page

## Notes
- This eval specifically targets the compliance failure observed in the 3.10.0 test: step=3 and step=5 checkpoints were absent on the reconciliation path
- Checkpoints are unconditional signals — they must fire whether or not there was substantive work at that step
- The distinction between "compiled: false with existing wiki page" (reconciliation path) and "compiled: true" (truly already compiled) must be preserved

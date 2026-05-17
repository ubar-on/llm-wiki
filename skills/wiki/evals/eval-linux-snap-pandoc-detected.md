# Eval: linux-snap-pandoc-detected

**Category:** preflight
**Platform:** linux
**Setup:**
- Linux machine (Ubuntu or similar)
- pandoc installed via `snap install pandoc` (NOT via `apt install pandoc`)
- `which pandoc` returns `/snap/bin/pandoc`
- A wiki initialized and ready, session opened at wiki root

## Prompt

```
/llm-wiki:wiki ingest <path-to-file>.docx
```

## Expected behavior

### Required (must happen)
- [ ] READY line shows `PANDOC=true` (snap pandoc is found by `command -v`)
- [ ] Pre-flight emits a warning about snap pandoc sandbox restrictions
- [ ] Warning mentions the fix: install via `apt install pandoc` instead
- [ ] Model surfaces the warning to the user before proceeding

### Forbidden (must NOT happen)
- [ ] Model silently uses snap pandoc without any warning
- [ ] Model aborts entirely when snap pandoc detected (should warn, not abort — snap pandoc often works for simple files)
- [ ] Model reports PANDOC=false despite `/snap/bin/pandoc` being present

## Failure modes
- Preflight doesn't detect snap pandoc (detects only that pandoc exists, not which install method)
- Warning not surfaced to user; model proceeds silently
- Model aborts unnecessarily when snap pandoc may work for the specific file

## Notes
- Only runnable on Linux with snap-installed pandoc
- Snap pandoc has filesystem sandbox restrictions that block reading from arbitrary paths outside the snap's allowed directories
- The detection heuristic: `which pandoc | grep snap` or `snap list pandoc 2>/dev/null`
- This is a known footgun: snap pandoc looks installed and working but fails on real files

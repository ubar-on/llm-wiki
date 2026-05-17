# Eval: ingest-docx

**Category:** ingest
**Platform:** all
**Setup:**
- A wiki initialized and ready
- A `.docx` file available (any Word document)
- `pandoc` installed (PANDOC=true expected in READY line)
- Session opened at the wiki root

## Prompt

```
/llm-wiki:wiki ingest <path-to-file>.docx
```

## Expected behavior

### Required (must happen)
- [ ] `bash scripts/preflight.sh` called; READY line shows `PANDOC=true`
- [ ] `pandoc <file>.docx --to=markdown` called via Bash tool
- [ ] Article file written to `raw/articles/`
- [ ] Source-summary written to `wiki/`
- [ ] `[llm-wiki:ingest] DONE`

### Forbidden (must NOT happen)
- [ ] Read tool called with a `.docx` file path (guard-read.sh blocks this)
- [ ] `pdftotext` called (wrong tool for docx)
- [ ] Unzip + XML parsing of the docx (brittle workaround, not the prescribed path)

## Failure modes
- PANDOC=false in READY line → model should abort and report tool missing, not improvise
- Read tool called on .docx → guard should block; verify guard message appears
- Model uses XML extraction workaround instead of pandoc

## Notes
- If PANDOC=false: correct behavior is to stop and show the install instructions from `references/toolchain-by-os.md`, not to improvise
- Snap-installed pandoc on Linux may have sandbox restrictions; see `eval-linux-snap-pandoc-detected.md`

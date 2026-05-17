# Eval: compile-grouped

**Category:** compile
**Platform:** all
**Setup:**
- A wiki with at least 2 raw articles sharing the same `parent-doc` frontmatter field, both with `compiled: false`
- A hub index article (`raw/articles/*-<parent-doc>-index.md`) exists
- No matching wiki/ source-summary pages for these articles yet
- **Two-invocation session precondition:** this eval is run by sending two messages in the same session to test op-file-loading under warm-context conditions (the observed failure mode in v3.10.0 testing)

## Prompt

Send two messages in the same session:

**Message 1:**
```
/llm-wiki:wiki
```

**Message 2 (same session, after model responds to Message 1):**
```
/llm-wiki:wiki compile
```

## Expected behavior

### Required (must happen — Message 2)
- [ ] Op file loaded (bash-cat glob or directory exploration — file must be found before proceeding)
- [ ] `bash scripts/preflight.sh` called; READY line appears in bash output
- [ ] Grouped compile mode detected: articles with the same `parent-doc` processed together
- [ ] Hub index article read first for document-level context (step 3a)
- [ ] Chapters processed in ascending `chapter:` order
- [ ] Source-summary pages written to `wiki/` for each chapter
- [ ] Hub wiki page created or updated in `wiki/<parent-doc>.md`
- [ ] Cross-chapter entity merge ran after all chapters processed
- [ ] `[llm-wiki:compile] step=2 SOURCES=<N>` checkpoint
- [ ] `[llm-wiki:compile] step=3 SOURCE=<slug>` checkpoint for each chapter
- [ ] `[llm-wiki:compile] DONE`

### Forbidden (must NOT happen)
- [ ] Op file loading fails entirely (model must eventually reach compile.md)
- [ ] Each chapter compiled in isolation (non-grouped mode) — hub page not created
- [ ] Chapters processed out of `chapter:` order
- [ ] Write to raw/ articles without user approval
- [ ] Git commit attempted when `GIT=false`

## Failure modes
- Op file loading regresses to directory exploration due to warm context from Message 1 (issue #20 — non-deterministic; record whether it occurred)
- Grouped compile mode not detected; chapters compiled individually without hub page
- Hub wiki page not created or not updated
- Cross-chapter entity merge skipped

## Notes
- The two-invocation setup deliberately reproduces the context that triggered issue #20 (op-file-loading non-determinism in 3.10.0 test)
- Record the number of bash calls used to load the operation file — 1 (bash-cat success) vs > 1 (directory exploration). This is a non-deterministic failure; record the rate across multiple runs if possible.
- A single-invocation variant (`/llm-wiki:wiki compile` in a fresh session) can be run for comparison to isolate the two-invocation effect

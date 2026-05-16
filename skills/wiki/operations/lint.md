# lint

Audit wiki integrity and fix issues.

Syntax: `/llm-wiki:wiki lint`

---

## Step 0 — Pre-flight (MANDATORY)

```bash
bash scripts/preflight.sh
```
Copy the READY line character-for-character into your response — do not paraphrase or summarize. Define `QMD`/`MARP` from `DATA=`. Read `PYTHON=<cmd>` from READY line.

---

## Steps

### 1. Read all files in `wiki/`
Build a link graph: for each `[[wikilink]]` on each page, record the edge (source → target).

### 2. Run deterministic lint script

> ⚠️ **DO NOT use bare `python3` or bare `python`. Use the `PYTHON` value from the READY line.**
> **Why:** On Windows, `python3` is a Microsoft Store stub that silently exits with code 49. Bare `python` may be Python 2 on older systems.
> **Instead:** Use `${PYTHON}` (the `PYTHON=` value from the READY line, e.g. `py` on Windows).

```bash
"${PYTHON}" "scripts/lint-wiki.py" "<wiki-root>/wiki/"
```

`[llm-wiki:lint] step=2 SCRIPT_RAN=<bool>`

### 3. Report and fix

| Check | Action |
|-------|--------|
| **Orphan pages** (no inbound links) | List. Suggest links from related pages. |
| **Dead links** (`[[wikilinks]]` to nonexistent files) | Create stub pages with appropriate template. |
| **Unlinked concept mentions** | Add `[[wikilink]]` at first mention where a page exists; flag candidates for new pages. |
| **Contradictions** (`[!WARNING]` markers) | List. |
| **Missing Counter-Arguments sections** | Add empty `## Counter-Arguments and Gaps`. |
| **Stale pages** (`status: stale`) | Flag. |
| **Index drift** | Compare `index.md` entries vs actual files. Add missing, remove dead entries. |
| **Missing hub article** | `parent-doc` group in `raw/articles/` without `*-index.md`. Suggest `wiki split <name>`. |
| **Missing hub wiki page** | Hub article exists but `wiki/<parent-doc>.md` absent. Flag as uncompiled. |
| **Chapter sequence gaps** | Collect distinct `chapter:` values per `parent-doc`. Flag gaps (ch1, ch2, ch4 → ch3 missing). Verify `section-range:` contiguity within sub-split chapters. |
| **Stuck uncompiled** | `compiled: false` files older than 7 days. Suggest `wiki compile`. |
| **Image-set stubs** | `source-type: image-set` with no body content. |
| **Page range overlaps** | `source-pdf-pages` ranges non-contiguous within a `parent-doc` group. |

`[llm-wiki:lint] step=3 ISSUES_FOUND=<N> ISSUES_FIXED=<N>`

### 4. Suggest growth opportunities
- 3–5 questions the wiki cannot yet answer well (candidates for `wiki query`)
- 2–3 topic areas or sources that would most strengthen the wiki
- If any `parent-doc` group has <50% chapters compiled: flag it.

### 5. Write lint report to `outputs/reports/YYYY-MM-DD-lint.md`
```markdown
# Lint Report — YYYY-MM-DD
**Wiki:** <name> | **Issues found:** N | **Fixed:** M
## Issues
<issue table>
## Next Steps
<growth suggestions>
```

`[llm-wiki:lint] step=5 REPORT_WRITTEN=outputs/reports/YYYY-MM-DD-lint.md`

### 6. Append to `log.md`
```
## [YYYY-MM-DD] lint | N issues found, M fixed
<summary of issues>
```

### 7. Git commit
If `LLM_WIKI_GIT` is not `false`:
```bash
git -C ${VAULT_ROOT} commit -am "lint: YYYY-MM-DD"
```

`[llm-wiki:lint] DONE`

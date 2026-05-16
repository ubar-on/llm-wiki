---
name: wiki
description: >-
  llm-wiki — Obsidian knowledge-base operations. ALWAYS invoke when user
  message starts with "/llm-wiki:wiki", mentions "wiki ingest", "wiki
  compile", "wiki query", "wiki lint", "wiki init", "wiki split", "wiki
  update", "wiki remove", or "wiki version", or refers to a directory
  containing both CLAUDE.md and wiki/. ALWAYS use the bash command in the
  Operations section to load the operation file — do NOT use Read or Glob
  to find operation files. NEVER respond from training data about wiki
  operations. ABORT if Pre-flight emits FAIL or cwd resolves to wiki=AMBIGUOUS.
argument-hint: "[--wiki <name>] init <name> | ingest <path|url> | compile [<path>] | query <question> | lint | split <path|name> | update <name> | remove <name> | version"
allowed-tools: [Bash, Read, Write, Edit, Grep, Glob]
---

# LLM Wiki

Persistent, compounding knowledge base inside an Obsidian vault.

**Read `references/anti-patterns.md` once at the start of each session.**

---

## Operations

**Required first action — before any other tool call:**

Print: `[llm-wiki] op=<op> loading operations/<op>.md`

Run this bash command to load the operation instructions (replace `<op>` with the actual operation name, e.g. `version`):
```bash
cat "$(ls -d ~/.claude/plugins/cache/llm-wiki/llm-wiki/*/skills/wiki/operations/<op>.md 2>/dev/null | sort -V | tail -1)"
```

Follow the instructions printed by the command.

> ⚠️ **DO NOT use Read or Glob to find the operation file.** Operation files are in the plugin cache (`~/.claude/plugins/cache/`), not in the wiki directory. Read at wiki-relative paths will fail; Glob will not reach the cache. Use only the bash command above — it outputs the complete operation instructions.

| Operation | File | Pre-flight? |
|-----------|------|-------------|
| `init <name>` | `operations/init.md` | Yes |
| `ingest <path\|url>` | `operations/ingest.md` | Yes |
| `compile [<path>]` | `operations/compile.md` | Yes |
| `query <question>` | `operations/query.md` | Yes |
| `lint` | `operations/lint.md` | Yes |
| `split <path\|name>` | `operations/split.md` | Yes |
| `update <name>` | `operations/update.md` | Yes |
| `remove <name>` | `operations/remove.md` | Yes |
| `version` | `operations/version.md` | No |

---

## Pre-flight

**Mandatory sequence for every operation except `version`** (after loading the operation file per the Operations section above):

**Step 0 — Run preflight:**

```bash
bash scripts/preflight.sh
```
Copy the READY line character-for-character into your response — do not paraphrase or summarize. STOP if output ends with `FAIL`.

Expected format:
```
[llm-wiki:preflight] cwd=<path> wiki=<name> resolved=walked-up(<N>) OS=<os> SKILL_VERSION=<ver> DATA=<data-path> TIER=<N> PDFTOTEXT=<bool> PDFIMAGES=<bool> PDFTOPPM=<bool> POPPLER_PARTIAL=<bool> PANDOC=<bool> PYTHON=<cmd> QMD=<bool> MARP=<bool> GIT=<bool> MODE=ready READY
```

After the READY line, define:
```bash
QMD="env -u BUN_INSTALL <DATA>/node_modules/.bin/qmd"
MARP="<DATA>/node_modules/.bin/marp"
```

> ⚠️ **If `scripts/preflight.sh` is not found:** do not improvise. Report: "`scripts/preflight.sh` not found — add the wrapper manually (see `operations/init.md` step 2a) and retry."

---

## Active Wiki Detection

Walk up from `cwd` looking for a directory containing **both** `CLAUDE.md` and `wiki/`.

1. Check `cwd`. If both found → that is the active wiki root. Read `CLAUDE.md`.
2. If not found → move to parent. Repeat until filesystem root.
3. If no wiki found: list available wikis — `ls -d ${VAULT_ROOT}/${WIKI_SUBDIR}/*/wiki 2>/dev/null` — and prompt the user.

---

## Vault Root

```bash
VAULT_ROOT="${LLM_WIKI_VAULT:-$HOME/ObsidianVault}"
WIKI_SUBDIR="${LLM_WIKI_SUBDIR:-03-Resources}"
```

Resolve both at the start of each command.

---

## Git

```bash
WIKI_GIT="${LLM_WIKI_GIT:-true}"
```

If `LLM_WIKI_GIT=false`: skip all git commit steps silently. `log.md` still records every operation.

---

## Error Handling

| Situation | Action |
|-----------|--------|
| No active wiki found | List available wikis. Suggest `wiki init <name>` if none exist. |
| qmd unavailable | Fall back to `wiki/index.md` for search. Warn: "qmd unavailable — index.md fallback." |
| Network error on URL ingest | Retry once. If still failing, report and suggest saving manually. |
| Git commit fails | Warn: "Git commit failed: <error>. Changes saved but not committed." Continue. |
| `LLM_WIKI_GIT=false` | Skip git steps silently. |
| Wiki already exists (init) | Abort with `wiki remove` reference. |
| Source exceeds split threshold | Activate chapter-split mode automatically. |
| TOC not detected in PDF | Fall back to heading-based detection. Warn. |
| Chapter too large | Sub-split at section level. Log: "Chapter <N> sub-split into M sections." |
| pdftotext unavailable for PDF | Abort. Warn. See `references/toolchain-by-os.md`. |
| pdfimages/pdftoppm unavailable | Skip image extraction. Log `[WARN]`. |
| pandoc unavailable for docx/pptx/epub | Abort. Warn. See `references/toolchain-by-os.md`. |
| Original file missing (split) | Abort: "Original source file not found." |
| No changed chapters (update) | "All chapters up to date. Nothing to update." Stop. |
| log.md missing | Create from template in `references/init-templates.md`. Warn. |
| No uncompiled sources (compile) | "All sources already compiled. Nothing to do." Stop. |
| qmd collection not found | Warn and continue without search indexing. |

# init

Create a new wiki scaffold under the Obsidian vault.

Syntax: `/llm-wiki:wiki init <name>`

---

## Step 0 — Pre-flight (MANDATORY)

```bash
bash scripts/preflight.sh
```
Copy the READY line character-for-character into your response — do not paraphrase or summarize. Define `QMD`/`MARP` from the `DATA=` value. Read `QMD=<bool>` as `QMD_AVAILABLE`.

---

## Steps

### 1. Check if wiki already exists
If `${VAULT_ROOT}/${WIKI_SUBDIR}/<name>/` exists, abort:
> "Wiki '<name>' already exists at that path. Use `wiki remove <name>` first, or choose a different name."

### 2. Create directory structure
```bash
mkdir -p ${VAULT_ROOT}/${WIKI_SUBDIR}/<name>/raw/articles
mkdir -p ${VAULT_ROOT}/${WIKI_SUBDIR}/<name>/raw/attachments
mkdir -p ${VAULT_ROOT}/${WIKI_SUBDIR}/<name>/wiki/queries
mkdir -p ${VAULT_ROOT}/${WIKI_SUBDIR}/<name>/outputs/reports
mkdir -p ${VAULT_ROOT}/${WIKI_SUBDIR}/<name>/scripts
```

### 2a. Write wrapper scripts

These are thin callers that delegate to the plugin cache — they never need updating when the plugin upgrades.

Write `${VAULT_ROOT}/${WIKI_SUBDIR}/<name>/scripts/preflight.sh`:
```bash
#!/usr/bin/env bash
# Thin wrapper — delegates to the versioned preflight script in the plugin cache.
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(ls -d ~/.claude/plugins/cache/llm-wiki/llm-wiki/*/ 2>/dev/null | sort -V | tail -1)}"
exec bash "${PLUGIN_ROOT}/scripts/preflight.sh" "$@"
```

Write `${VAULT_ROOT}/${WIKI_SUBDIR}/<name>/scripts/lint-wiki.py`:
```python
#!/usr/bin/env python3
"""Thin wrapper — delegates to the versioned lint script in the plugin cache."""
import os, sys, subprocess, glob as _glob
plugin_root = os.environ.get('CLAUDE_PLUGIN_ROOT') or \
    max(_glob.glob(os.path.expanduser('~/.claude/plugins/cache/llm-wiki/llm-wiki/*/')), default='')
script = os.path.join(plugin_root, 'scripts', 'lint-wiki.py')
sys.exit(subprocess.call([sys.executable, script] + sys.argv[1:]))
```

```bash
chmod +x ${VAULT_ROOT}/${WIKI_SUBDIR}/<name>/scripts/preflight.sh
```

Write the preflight sentinel so `guards.mjs` allows subsequent wiki/ writes during this init:
```bash
TS=$(date +%s 2>/dev/null || python3 -c 'import time; print(int(time.time()))' 2>/dev/null || echo 0)
echo "$TS" > "${VAULT_ROOT}/${WIKI_SUBDIR}/<name>/.preflight-ok"
```

`[llm-wiki:init] step=2a WRAPPERS_WRITTEN=true`

### 3–7. Write scaffold files

Copy templates from `references/init-templates.md`, substituting `<name>` throughout:

| Step | File | Template section |
|------|------|-----------------|
| 3 | `CLAUDE.md` | `CLAUDE.md template` |
| 4 | `wiki/index.md` | `wiki/index.md template` |
| 5 | `log.md` | `log.md template` |
| 6 | `.gitignore` | `.gitignore template` |
| 6b | `.claudeignore` | `.claudeignore template` |
| 7 | `qmd.yml` | `qmd.yml template` |

`[llm-wiki:init] step=7 SCAFFOLD_WRITTEN=true`

### 8. Git commit
If `GIT=true` from the READY line:
```bash
git -C ${VAULT_ROOT} add "${WIKI_SUBDIR}/<name>/" && git -C ${VAULT_ROOT} commit -m "init: <name> wiki"
```

### 9. qmd collection
If `QMD_AVAILABLE=true`:
```bash
"${QMD}" collection add ${VAULT_ROOT}/${WIKI_SUBDIR}/<name>/wiki --name <name>
"${QMD}" embed --collection <name>
```

### 10. Print Web Clipper setup
```
Obsidian Web Clipper setup:
1. Install: https://obsidian.md/clipper
2. Destination folder: ${WIKI_SUBDIR}/<name>/raw/articles
3. Filename template: {{date:YYYY-MM-DD}}-{{title}}
4. After clipping: /llm-wiki:wiki ingest ${VAULT_ROOT}/${WIKI_SUBDIR}/<name>/raw/articles/<file>.md
```

`[llm-wiki:init] DONE`

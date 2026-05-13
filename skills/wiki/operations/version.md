# version

Report the installed plugin version and installation source. Does not require Pre-flight.

Syntax: `/llm-wiki:wiki version`

---

**If `PLUGIN_ROOT` resolves to empty: print `llm-wiki version: UNKNOWN — plugin cache not found` and STOP. Do not read wiki files, do not explore the filesystem.**

Run the following bash block verbatim — do not decompose into separate exploratory tool calls:

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(ls -d ~/.claude/plugins/cache/llm-wiki/llm-wiki/*/ 2>/dev/null | sort -V | tail -1)}"

VERSION=$(grep -o '"version": *"[^"]*"' "${PLUGIN_ROOT}/.claude-plugin/plugin.json" 2>/dev/null | grep -o '[0-9][^"]*')
VERSION="${VERSION:-unknown}"

case "${PLUGIN_ROOT}" in
  */.claude/plugins/cache/*)
    SOURCE="marketplace / fork cache"
    ;;
  *)
    if git -C "${PLUGIN_ROOT}" rev-parse --git-dir >/dev/null 2>&1; then
      REMOTE=$(git -C "${PLUGIN_ROOT}" remote get-url origin 2>/dev/null || echo "none")
      BRANCH=$(git -C "${PLUGIN_ROOT}" branch --show-current 2>/dev/null || echo "unknown")
      COMMIT=$(git -C "${PLUGIN_ROOT}" log -1 --format="%h %s" 2>/dev/null || echo "unknown")
      SOURCE="local git clone"
    else
      SOURCE="local directory (no git)"
    fi
    ;;
esac
```

Print:
```
llm-wiki <VERSION>
Source:  <SOURCE>
Path:    <PLUGIN_ROOT>
```

If `SOURCE` is `local git clone`, also print:
```
Remote:  <REMOTE>
Branch:  <BRANCH>
Commit:  <COMMIT>
```

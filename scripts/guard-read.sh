#!/usr/bin/env bash
# PreToolUse guard: block Read tool on binary documents inside a wiki's raw/ directory.
# Claude Code passes tool input JSON on stdin. Exits non-zero to block the call.
# Set LLM_WIKI_DISABLE_GUARDS=true to disable.

set +e

[ "${LLM_WIKI_DISABLE_GUARDS:-false}" = "true" ] && exit 0

input=$(cat)

# ── Extract file_path from JSON ───────────────────────────────────────────────
# Python preferred (handles JSON escaping correctly); grep/sed fallback.

if command -v python3 >/dev/null 2>&1; then
  file_path=$(printf '%s' "$input" | python3 -c "import json,sys; print(json.load(sys.stdin).get('file_path',''))" 2>/dev/null)
elif command -v py >/dev/null 2>&1; then
  file_path=$(printf '%s' "$input" | py -c "import json,sys; print(json.load(sys.stdin).get('file_path',''))" 2>/dev/null)
else
  file_path=$(printf '%s' "$input" \
    | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' \
    | head -1 \
    | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"\(.*\)"/\1/' \
    | sed 's/\\\\/\\/g')
fi

[ -z "$file_path" ] && exit 0

# ── Check extension ───────────────────────────────────────────────────────────

lower_ext=$(printf '%s' "${file_path##*.}" | tr '[:upper:]' '[:lower:]')
case "${lower_ext}" in
  pdf|docx|pptx|epub) ;;
  *) exit 0 ;;
esac

# ── Normalize path separators for shell operations ────────────────────────────

norm_path=$(printf '%s' "$file_path" | tr '\\' '/')

# Quick check: must contain /raw/ to be inside a wiki raw directory
case "${norm_path}" in
  */raw/*) ;;
  *) exit 0 ;;
esac

# ── Confirm file is inside a wiki by walking up the directory tree ────────────

dir=$(dirname "$norm_path")
while true; do
  if [ -f "${dir}/CLAUDE.md" ] && [ -d "${dir}/wiki" ]; then
    fname=$(basename "$file_path")
    printf '[llm-wiki:guard] Read blocked on %s inside wiki raw/.\n' "$fname"
    printf 'DO NOT use the Read tool on binary documents. Use Bash instead:\n'
    printf '  PDF:        pdftotext "%s" -\n' "$file_path"
    printf '  docx/pptx/epub: pandoc "%s" --to=markdown\n' "$file_path"
    printf 'See SKILL.md §Pre-flight Setup for correct commands.\n'
    exit 2
  fi
  parent=$(dirname "$dir")
  [ "$parent" = "$dir" ] && break
  dir="$parent"
done

exit 0

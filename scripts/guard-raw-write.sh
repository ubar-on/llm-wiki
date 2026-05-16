#!/usr/bin/env bash
# PreToolUse guard: block Write/Edit targeting a wiki's raw/ directory.
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

# ── Normalize path separators and resolve relative paths ─────────────────────

norm_path=$(printf '%s' "$file_path" | tr '\\' '/')
case "$norm_path" in
  /*) ;;                              # already absolute
  *)  norm_path="$(pwd)/${norm_path}" ;;  # make absolute using hook's cwd
esac

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
    printf '[llm-wiki:guard] Write blocked: %s is inside wiki raw/ which is immutable.\n' "$fname"
    printf 'raw/ is a source drop zone — LLM-owned content belongs in wiki/ instead.\n'
    printf 'See references/anti-patterns.md §DO NOT write into raw/\n'
    exit 2
  fi
  parent=$(dirname "$dir")
  [ "$parent" = "$dir" ] && break
  dir="$parent"
done

exit 0

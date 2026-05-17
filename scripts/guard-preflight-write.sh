#!/usr/bin/env bash
# PreToolUse guard: enforce preflight has run before any Write/Edit to wiki/.
# Claude Code passes tool input JSON on stdin. Exits non-zero to block.
# Set LLM_WIKI_DISABLE_GUARDS=true to disable.
# Sentinel TTL: LLM_WIKI_PREFLIGHT_TTL seconds (default 7200 = 2 hours).

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
  /*) ;;                              # POSIX absolute (/g/foo or /c/foo)
  [A-Za-z]:/*)                       # Windows drive-letter absolute (G:/foo) — convert to POSIX
    _drive=$(printf '%s' "$norm_path" | cut -c1 | tr 'A-Z' 'a-z')
    norm_path="/${_drive}${norm_path#?:}"
    ;;
  *)  norm_path="$(pwd)/${norm_path}" ;;  # relative — make absolute using hook's cwd
esac

# Quick check: must contain /wiki/ to be inside a wiki's wiki directory.
case "${norm_path}" in
  */wiki/*) ;;
  *) exit 0 ;;
esac

# ── Walk up to find wiki root ─────────────────────────────────────────────────
# Requires CLAUDE.md + wiki/ + scripts/preflight.sh — excludes new wikis mid-init
# (scripts/ doesn't exist yet) so init writes pass through correctly.

dir=$(dirname "$norm_path")
wiki_root=""
while true; do
  if [ -f "${dir}/CLAUDE.md" ] && [ -d "${dir}/wiki" ] && [ -f "${dir}/scripts/preflight.sh" ]; then
    wiki_root="${dir}"
    break
  fi
  parent=$(dirname "$dir")
  [ "$parent" = "$dir" ] && break
  dir="$parent"
done

[ -z "$wiki_root" ] && exit 0

# ── Check preflight sentinel ──────────────────────────────────────────────────

SENTINEL="${wiki_root}/.preflight-ok"
TTL="${LLM_WIKI_PREFLIGHT_TTL:-7200}"
NOW=$(date +%s 2>/dev/null || python3 -c 'import time; print(int(time.time()))' 2>/dev/null || echo 0)

if [ -f "$SENTINEL" ]; then
  SENTINEL_TIME=$(cat "$SENTINEL" 2>/dev/null)
  if [ -n "$SENTINEL_TIME" ] && [ "$NOW" -gt 0 ] && [ "$SENTINEL_TIME" -gt 0 ] \
     && [ $((NOW - SENTINEL_TIME)) -lt "$TTL" ]; then
    exit 0  # Preflight ran recently — allow
  fi
fi

# ── Block: preflight not run or sentinel stale ────────────────────────────────

printf '[llm-wiki:guard] Write to wiki/ blocked: preflight has not run in this session.\n'
printf 'Run: bash scripts/preflight.sh\n'
printf 'Copy the READY line into your response, then continue with the operation steps.\n'
exit 2

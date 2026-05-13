#!/usr/bin/env bash
# PreToolUse guard: block bare/relative invocations of scripts/preflight.sh.
# Correct invocation must include plugin path resolution (CLAUDE_PLUGIN_ROOT or cache glob).
# Claude Code passes tool input JSON on stdin. Exits non-zero to block the call.
# Set LLM_WIKI_DISABLE_GUARDS=true to disable.

set +e

[ "${LLM_WIKI_DISABLE_GUARDS:-false}" = "true" ] && exit 0

input=$(cat)

# Extract command from JSON — fast path: exit 0 if preflight.sh not in input at all
case "$input" in
  *preflight.sh*) ;;
  *) exit 0 ;;
esac

# Parse command field properly
if command -v python3 >/dev/null 2>&1; then
  cmd=$(printf '%s' "$input" | python3 -c "import json,sys; print(json.load(sys.stdin).get('command',''))" 2>/dev/null)
elif command -v py >/dev/null 2>&1; then
  cmd=$(printf '%s' "$input" | py -c "import json,sys; print(json.load(sys.stdin).get('command',''))" 2>/dev/null)
else
  cmd=$(printf '%s' "$input" \
    | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' \
    | head -1 \
    | sed 's/.*"command"[[:space:]]*:[[:space:]]*"\(.*\)"/\1/')
fi

# Only check commands that reference preflight.sh
case "$cmd" in
  *preflight.sh*) ;;
  *) exit 0 ;;
esac

# Allow if the command includes a valid plugin path prefix
case "$cmd" in
  *CLAUDE_PLUGIN_ROOT*|*PLUGIN_ROOT*|*plugins/cache/llm-wiki*|*plugins\\cache\\llm-wiki*)
    exit 0 ;;
esac

printf '[llm-wiki:guard] Blocked: bare scripts/preflight.sh path.\n'
printf '\n'
printf 'WRONG (relative to wiki root — file not found):\n'
printf '  bash scripts/preflight.sh\n'
printf '\n'
printf 'RIGHT (resolves plugin path inline):\n'
printf '  bash "${CLAUDE_PLUGIN_ROOT:-$(ls -d ~/.claude/plugins/cache/llm-wiki/llm-wiki/*/ 2>/dev/null | sort -V | tail -1)}/scripts/preflight.sh"\n'
printf '\n'
printf 'Copy the exact command from SKILL.md §Pre-flight Setup.\n'
exit 2

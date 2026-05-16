#!/usr/bin/env bash
# Pre-flight check for llm-wiki operations.
# Outputs exactly ONE line on stdout: [llm-wiki:preflight] ... READY  or  ... FAIL
# Diagnostic messages (install instructions, warnings) go to stderr.
# Usage: bash "${CLAUDE_PLUGIN_ROOT}/scripts/preflight.sh"

# ── 1. Resolve plugin paths ────────────────────────────────────────────────

if [ -z "${CLAUDE_PLUGIN_DATA:-}" ]; then
  CLAUDE_PLUGIN_DATA=$(ls -d ~/.claude/plugins/data/llm-wiki-* 2>/dev/null | head -1)
fi
if [ -z "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  CLAUDE_PLUGIN_ROOT=$(ls -d ~/.claude/plugins/cache/llm-wiki/llm-wiki/*/ 2>/dev/null | sort -V | tail -1)
fi

# ── 2. OS detection ───────────────────────────────────────────────────────

case "$(uname -s 2>/dev/null)" in
  CYGWIN*|MINGW*|MSYS*) OS=Windows ;;
  Darwin)               OS=macOS ;;
  Linux)                OS=Linux ;;
  *)                    OS=Unknown ;;
esac

# ── 3. Active wiki detection (walk-up from cwd) ───────────────────────────

VAULT_ROOT="${LLM_WIKI_VAULT:-$HOME/ObsidianVault}"
WIKI_SUBDIR="${LLM_WIKI_SUBDIR:-03-Resources}"

walk_dir="$(pwd)"
wiki_root=""
walk_depth=0

while true; do
  if [ -f "${walk_dir}/CLAUDE.md" ] && [ -d "${walk_dir}/wiki" ]; then
    wiki_root="${walk_dir}"
    break
  fi
  parent="$(dirname "${walk_dir}")"
  if [ "${parent}" = "${walk_dir}" ]; then
    break  # reached filesystem root
  fi
  walk_dir="${parent}"
  walk_depth=$((walk_depth + 1))
done

if [ -z "${wiki_root}" ]; then
  # No wiki found via walk-up — look for candidates under vault
  candidates=""
  if [ -d "${VAULT_ROOT}/${WIKI_SUBDIR}" ]; then
    for d in "${VAULT_ROOT}/${WIKI_SUBDIR}"/*/; do
      if [ -f "${d}CLAUDE.md" ] && [ -d "${d}wiki" ]; then
        name="$(basename "${d%/}")"
        candidates="${candidates:+${candidates},}${name}"
      fi
    done
  fi

  if [ -z "${candidates}" ]; then
    echo "[llm-wiki:preflight] cwd=$(pwd) wiki=NONE fix=\"cd into a wiki root, or run: /llm-wiki:wiki init <name>\" FAIL"
  else
    echo "[llm-wiki:preflight] cwd=$(pwd) wiki=AMBIGUOUS candidates=[${candidates}] fix=\"cd into one wiki, OR re-invoke with: /llm-wiki:wiki --wiki <name> <op>\" FAIL"
  fi
  exit 1
fi

wiki_name="$(basename "${wiki_root}")"

# ── 4. Toolchain detection ─────────────────────────────────────────────────

HAS_PDFTOTEXT=false; command -v pdftotext >/dev/null 2>&1 && HAS_PDFTOTEXT=true
HAS_PDFIMAGES=false; command -v pdfimages >/dev/null 2>&1 && HAS_PDFIMAGES=true
HAS_PDFTOPPM=false;  command -v pdftoppm  >/dev/null 2>&1 && HAS_PDFTOPPM=true
HAS_PANDOC=false;    command -v pandoc    >/dev/null 2>&1 && HAS_PANDOC=true

# Detect partial Poppler: pdftotext present but pdfimages/pdftoppm absent (Git for Windows pattern)
POPPLER_PARTIAL=false
if [ "${HAS_PDFTOTEXT}" = "true" ] && [ "${HAS_PDFIMAGES}" = "false" ] && [ "${HAS_PDFTOPPM}" = "false" ]; then
  POPPLER_PARTIAL="true(GfW)"
fi

# Capability tier
if   [ "${HAS_PANDOC}"    = "true" ]; then TIER=3
elif [ "${HAS_PDFTOPPM}"  = "true" ]; then TIER=2
elif [ "${HAS_PDFIMAGES}" = "true" ]; then TIER=1
elif [ "${HAS_PDFTOTEXT}" = "true" ]; then TIER=0
else                                        TIER=none
fi

# ── 5. Python resolver ────────────────────────────────────────────────────

PYTHON_CMD=none
if [ "${OS}" = "Windows" ] && command -v py >/dev/null 2>&1; then
  # py launcher preferred on Windows — bypasses Microsoft Store stub
  PYTHON_CMD=py
elif command -v python3 >/dev/null 2>&1 && python3 --version >/dev/null 2>&1; then
  PYTHON_CMD=python3
elif command -v python >/dev/null 2>&1; then
  python --version >/dev/null 2>&1; py_exit=$?
  case ${py_exit} in
    0)       PYTHON_CMD=python ;;
    49|9009) # Microsoft Store stub — falls back to py launcher
             command -v py >/dev/null 2>&1 && PYTHON_CMD=py || PYTHON_CMD=none ;;
  esac
fi

# ── 6. Skill version ─────────────────────────────────────────────────────

SKILL_VERSION=$(grep -o '"version": *"[^"]*"' "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json" 2>/dev/null | grep -o '[0-9][^"]*')
SKILL_VERSION="${SKILL_VERSION:-unknown}"

# ── 7. Git toggle ────────────────────────────────────────────────────────────

GIT_ENABLED=true
[ "${LLM_WIKI_GIT:-true}" = "false" ] && GIT_ENABLED=false

# ── 7b. qmd / marp availability ───────────────────────────────────────────────

QMD_AVAILABLE=false
MARP_AVAILABLE=false
if [ -n "${CLAUDE_PLUGIN_DATA:-}" ]; then
  [ -x "${CLAUDE_PLUGIN_DATA}/node_modules/.bin/qmd" ]  && QMD_AVAILABLE=true
  [ -x "${CLAUDE_PLUGIN_DATA}/node_modules/.bin/marp" ] && MARP_AVAILABLE=true
fi

# ── 8. One-time toolchain setup message (stderr only) ────────────────────

SENTINEL="${wiki_root}/.pdf-toolchain-checked"
if [ ! -f "${SENTINEL}" ]; then
  {
    echo "[llm-wiki:preflight] First run on this machine — install the following for full large-document support:"
    echo "  Windows (winget):  winget install -e --id oschwartz10612.Poppler"
    echo "                     winget install -e --id JohnMacFarlane.Pandoc"
    echo "  macOS (brew):      brew install poppler pandoc"
    echo "  Linux (apt):       sudo apt install poppler-utils pandoc"
    echo "  See: ${CLAUDE_PLUGIN_ROOT}/skills/wiki/references/toolchain-by-os.md"
  } >&2
  touch "${SENTINEL}" 2>/dev/null || true
fi

# ── 8a. Write session sentinel (checked by guard-preflight-write.sh) ─────────
# Written only on READY — FAIL exits early above, so reaching here means success.
TS=$(date +%s 2>/dev/null || python3 -c 'import time; print(int(time.time()))' 2>/dev/null || echo 0)
echo "$TS" > "${wiki_root}/.preflight-ok" 2>/dev/null || true

# ── 8b. Emit single READY line on stdout ──────────────────────────────────────

echo "[llm-wiki:preflight] cwd=$(pwd) wiki=${wiki_name} resolved=walked-up(${walk_depth}) OS=${OS} SKILL_VERSION=${SKILL_VERSION} DATA=${CLAUDE_PLUGIN_DATA} TIER=${TIER} PDFTOTEXT=${HAS_PDFTOTEXT} PDFIMAGES=${HAS_PDFIMAGES} PDFTOPPM=${HAS_PDFTOPPM} POPPLER_PARTIAL=${POPPLER_PARTIAL} PANDOC=${HAS_PANDOC} PYTHON=${PYTHON_CMD} QMD=${QMD_AVAILABLE} MARP=${MARP_AVAILABLE} GIT=${GIT_ENABLED} MODE=ready READY"

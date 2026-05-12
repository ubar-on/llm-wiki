# Anti-patterns — cross-cutting rules

These apply to every operation. Per-operation anti-patterns live inline in each operation's step instructions.

---

## DO NOT skip Pre-flight Setup

**Why it fails:** `scripts/preflight.sh` resolves plugin paths, detects the active wiki, sets capability flags, and prints the READY line you must reproduce. Without it, downstream steps reference unset variables and silently produce wrong results.

**Instead:** `bash "${CLAUDE_PLUGIN_ROOT}/scripts/preflight.sh"` — reproduce the READY line verbatim, then proceed. If the line ends with `FAIL`, stop and report it to the user.

---

## DO NOT write into `raw/`

**Why it fails:** `raw/` is immutable per wiki schema (defined in each wiki's `CLAUDE.md`). LLM-generated content written there bypasses the ingest audit trail and corrupts the source record. A PreToolUse hook will block this in a future phase.

**Instead:** Write all LLM-generated content to `wiki/`. Sources enter `raw/` only via the `ingest` operation.

---

## DO NOT invoke bare `qmd` or bare `marp`

**Why it fails:** If `BUN_INSTALL` is set in the environment, bare `qmd` runs under Bun, which uses a SQLite build that cannot load `sqlite-vec`. Results are silently wrong or the command errors.

**Instead:** Always use `${QMD}` and `${MARP}` as defined in Pre-flight Setup. Both are set from the `DATA=<path>` value in the READY line.

---

## DO NOT skip the visible checkpoint lines

**Why it fails:** Checkpoint lines are the only real-time signal that a step ran. A missing line means a skipped step, which the user cannot detect until something downstream breaks.

Currently: the mandatory checkpoint is the preflight READY line — reproduce it verbatim before any tool call.

Phase 3 will add per-step `[llm-wiki:<op>] step=<N> ...` lines inside each operation file. Until then, the READY line is the enforced checkpoint.

**Instead:** Always reproduce the READY line before proceeding. When per-step checkpoints are added to an operation file, print each one before moving to the next step.

---

## DO NOT proceed if Pre-flight returns FAIL or AMBIGUOUS

**Why it fails:** The operation cannot complete correctly without a resolved active wiki and a working toolchain at the required tier.

**Instead:** Report the full FAIL line to the user and stop. The line includes the fix (e.g., `fix="cd into one wiki, OR re-invoke with: /llm-wiki:wiki --wiki <name> <op>"`).

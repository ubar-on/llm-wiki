# Anti-patterns — cross-cutting rules

These apply to every operation. Per-operation anti-patterns live inline in each operation's step instructions.

---

## DO NOT skip Pre-flight Setup

**Why it fails:** `scripts/preflight.sh` resolves plugin paths, detects the active wiki, sets capability flags, and prints the READY line you must reproduce. Without it, downstream steps reference unset variables and silently produce wrong results.

**Instead:** `bash scripts/preflight.sh` — reproduce the READY line verbatim, then proceed. If the line ends with `FAIL`, stop and report it to the user.

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

The mandatory checkpoint is the preflight READY line — reproduce it verbatim before any tool call. Each `operations/*.md` file specifies additional per-step `[llm-wiki:<op>] step=<N> ...` lines; print each one before moving to the next step.

**Instead:** Always reproduce the READY line before proceeding. Print every checkpoint line specified in the operation file — they are short, machine-readable, and the only real-time signal that a step ran.

---

## DO NOT write scripts or temp files into `raw/articles/`

**Why it fails:** `raw/articles/` is for source documents only. Helper scripts and generated files written there corrupt the source archive, appear as uncompiled articles, and persist silently after the operation ends.

**Instead:** Write any temp or helper scripts to the **wiki root** (e.g. `<wiki-root>/fcom_extract.py`). Delete them immediately after use. Never leave generated artifacts in `raw/`.

---

## DO NOT install new packages or dependencies without explicit user approval

**Why it fails:** `pip install`, `npm install`, or any other package installation modifies the user's system state outside the wiki. Doing this to work around a missing tool is a scope violation — the prescribed toolchain is defined by the preflight READY line.

**Instead:** If a required tool is missing (e.g. `PDFTOTEXT=false`), report it to the user with the install instructions from `references/toolchain-by-os.md` and stop. Do not improvise an alternative toolchain.

---

## DO NOT proceed if Pre-flight returns FAIL or AMBIGUOUS

**Why it fails:** The operation cannot complete correctly without a resolved active wiki and a working toolchain at the required tier.

**Instead:** Report the full FAIL line to the user and stop. The line includes the fix (e.g., `fix="cd into one wiki, OR re-invoke with: /llm-wiki:wiki --wiki <name> <op>"`).

#!/usr/bin/env node
// PreToolUse guards for llm-wiki. One node process per tool call.
//   node guards.mjs read    — blocks Read on binary docs in a wiki's raw/
//   node guards.mjs write   — blocks writes to raw/, and writes to wiki/ before preflight
// Tool input JSON on stdin. Exit 2 blocks the call; anything else allows.
// Set LLM_WIKI_DISABLE_GUARDS=true to disable.
//
// Replaces guard-read.sh / guard-raw-write.sh / guard-preflight-write.sh: those
// spawned bash + an external python3 per call (1-3s each on Windows, and the
// Microsoft Store python3 alias made them silently allow everything).

import { readFileSync, statSync } from 'node:fs';
import { basename, dirname, join, resolve } from 'node:path';

const TTL = Number(process.env.LLM_WIKI_PREFLIGHT_TTL) || 7200;
const BINARY_EXTS = ['.pdf', '.docx', '.pptx', '.epub'];

const isFile = (p) => { try { return statSync(p).isFile(); } catch { return false; } };
const isDir = (p) => { try { return statSync(p).isDirectory(); } catch { return false; } };

function block(...lines) {
  process.stdout.write(lines.join('\n') + '\n');
  process.exit(2);
}

// Nearest ancestor of `start` (inclusive) satisfying pred, or ''.
function findUp(start, pred) {
  for (let dir = start; ; dir = dirname(dir)) {
    if (pred(dir)) return dir;
    if (dirname(dir) === dir) return '';
  }
}

const isWikiRoot = (d) => isFile(join(d, 'CLAUDE.md')) && isDir(join(d, 'wiki'));

function main() {
  if (process.env.LLM_WIKI_DISABLE_GUARDS === 'true') return;

  const input = JSON.parse(readFileSync(0, 'utf8'));
  // Claude Code nests tool args under tool_input; accept a flat payload too.
  const filePath = input.tool_input?.file_path || input.file_path;
  if (!filePath) return;

  const abs = resolve(filePath.replace(/\\/g, '/'));
  const slashed = abs.replace(/\\/g, '/');
  const name = basename(abs);
  const parent = dirname(abs);

  if (process.argv[2] === 'read') {
    if (!BINARY_EXTS.some((e) => name.toLowerCase().endsWith(e))) return;
    if (!slashed.includes('/raw/')) return;
    if (!findUp(parent, isWikiRoot)) return;
    block(
      `[llm-wiki:guard] Read blocked on ${name} inside wiki raw/.`,
      'DO NOT use the Read tool on binary documents. Use Bash instead:',
      `  PDF:            pdftotext "${filePath}" -`,
      `  docx/pptx/epub: pandoc "${filePath}" --to=markdown`,
      'See SKILL.md §Pre-flight Setup for correct commands.',
    );
  }

  // ── write: raw/ is immutable ────────────────────────────────────────────────
  if (slashed.includes('/raw/') && findUp(parent, isWikiRoot)) {
    block(
      `[llm-wiki:guard] Write blocked: ${name} is inside wiki raw/ which is immutable.`,
      'raw/ is a source drop zone — LLM-owned content belongs in wiki/ instead.',
      'See references/anti-patterns.md §DO NOT write into raw/',
    );
  }

  // ── write: wiki/ requires a fresh preflight ─────────────────────────────────
  if (!slashed.includes('/wiki/')) return;
  // scripts/preflight.sh in the test excludes wikis mid-init, so init writes pass.
  const root = findUp(parent, (d) => isWikiRoot(d) && isFile(join(d, 'scripts', 'preflight.sh')));
  if (!root) return;

  let stamp = 0;
  try { stamp = Number(readFileSync(join(root, '.preflight-ok'), 'utf8').trim()); } catch { /* never ran */ }
  if (stamp > 0 && Date.now() / 1000 - stamp < TTL) return;

  block(
    '[llm-wiki:guard] Write to wiki/ blocked: preflight has not run in this session.',
    'Run: bash scripts/preflight.sh',
    'Copy the READY line into your response, then continue with the operation steps.',
  );
}

// Bad JSON or an odd payload must never break the user's tool call.
try { main(); } catch { /* allow */ }

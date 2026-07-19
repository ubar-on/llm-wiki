#!/usr/bin/env node
// Self-check for guards.mjs:  node scripts/guards.test.mjs
// Builds a throwaway wiki fixture and asserts each guard blocks/allows correctly.

import assert from 'node:assert';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const GUARDS = join(dirname(fileURLToPath(import.meta.url)), 'guards.mjs');
const root = mkdtempSync(join(tmpdir(), 'llm-wiki-test-'));

for (const d of ['raw', 'wiki', 'scripts']) mkdirSync(join(root, d));
writeFileSync(join(root, 'CLAUDE.md'), '');
writeFileSync(join(root, 'scripts', 'preflight.sh'), '');

// Runs the guard; returns its exit code (2 = blocked).
function run(mode, filePath, payload = (p) => ({ tool_input: { file_path: p } })) {
  try {
    execFileSync('node', [GUARDS, mode], {
      input: JSON.stringify(payload(filePath)),
      stdio: ['pipe', 'pipe', 'pipe'],
    });
    return 0;
  } catch (e) {
    return e.status;
  }
}

const p = (...s) => join(root, ...s);
const setStamp = (secondsAgo) =>
  writeFileSync(join(root, '.preflight-ok'), String(Math.floor(Date.now() / 1000) - secondsAgo));

// ── write: raw/ is immutable ──────────────────────────────────────────────────
assert.equal(run('write', p('raw', 'a.md')), 2, 'write to raw/ must block');
assert.equal(run('write', p('raw', 'deep', 'a.md')), 2, 'nested raw/ must block');

// The bug this file exists for: the old guards took a python3 branch that failed
// silently on Windows, so every payload fell through as "allow".
assert.equal(
  run('write', p('raw', 'a.md'), (f) => ({ file_path: f })), 2,
  'flat payload must block too',
);

// ── write: wiki/ needs a fresh preflight sentinel ─────────────────────────────
assert.equal(run('write', p('wiki', 'a.md')), 2, 'no sentinel must block');
setStamp(999999);
assert.equal(run('write', p('wiki', 'a.md')), 2, 'stale sentinel must block');
setStamp(10);
assert.equal(run('write', p('wiki', 'a.md')), 0, 'fresh sentinel must allow');

// ── read: binary docs in raw/ only ────────────────────────────────────────────
assert.equal(run('read', p('raw', 'a.pdf')), 2, 'pdf in raw/ must block');
assert.equal(run('read', p('raw', 'a.PDF')), 2, 'extension check is case-insensitive');
assert.equal(run('read', p('raw', 'a.md')), 0, 'text in raw/ must allow');
assert.equal(run('read', p('wiki', 'a.pdf')), 0, 'pdf outside raw/ must allow');

// ── never guard outside a wiki ────────────────────────────────────────────────
assert.equal(run('write', join(tmpdir(), 'raw', 'a.md')), 0, 'raw/ outside a wiki must allow');
assert.equal(run('write', p('wiki', 'a.md'), () => ({})), 0, 'payload with no path must allow');

rmSync(root, { recursive: true, force: true });
console.log('ok — all guard checks passed');

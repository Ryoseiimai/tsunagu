// Regression test for security-fix-20261010-tsunagu:
// "「LINEで相談する」ボタンの飛び先に行き先チェックがない" (tsunagu-web-lineurl-no-scheme-host-allowlist)
//
// Extracts the real isValidLineUrl() function straight out of index.html
// (no reimplementation) and checks it accepts/rejects the same shapes the
// iOS validLineURL() in ios/Tsunagu/Models.swift does.
// No dependencies: run with `node test/isValidLineUrl.test.mjs`.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const html = fs.readFileSync(path.join(__dirname, '..', 'index.html'), 'utf8');
const marker = 'function isValidLineUrl(str){';
const start = html.indexOf(marker);
assert.ok(start !== -1, 'isValidLineUrl function not found in index.html (fix missing?)');

let i = start + marker.length - 1;
let depth = 0;
let end = -1;
for (; i < html.length; i++) {
  if (html[i] === '{') depth++;
  else if (html[i] === '}') {
    depth--;
    if (depth === 0) { end = i + 1; break; }
  }
}
assert.ok(end !== -1, 'could not find matching closing brace for isValidLineUrl');
const fnSource = html.slice(start, end);
// eslint-disable-next-line no-new-func
const isValidLineUrl = new Function(`${fnSource}; return isValidLineUrl;`)();

const shouldAccept = [
  'https://line.me/ti/p/xxxx',
  'https://LINE.ME/ti/p/xxxx',
  'https://sub.line.me/ti/p/xxxx',
  'https://lin.ee/abc123',
];
const shouldReject = [
  null, undefined, '',
  'javascript:alert(1)',
  'data:text/html,<script>alert(1)</script>',
  'http://line.me/ti/p/xxxx',
  'https://line.me.evil.example/',
  'https://notline.me/',
  'https://evil.example/?redirect=line.me',
  'https://lin.ee.evil.example/',
  '   ',
  'ftp://line.me/x',
];

let failed = 0;
for (const v of shouldAccept) {
  if (isValidLineUrl(v) !== true) { failed++; console.error(`NOT OK - expected accept: ${v}`); }
  else console.log(`ok - accepts ${v}`);
}
for (const v of shouldReject) {
  if (isValidLineUrl(v) !== false) { failed++; console.error(`NOT OK - expected reject: ${v}`); }
  else console.log(`ok - rejects ${v}`);
}

if (failed > 0) {
  console.error(`\n${failed} test(s) failed`);
  process.exit(1);
}
console.log('\nall tests passed');

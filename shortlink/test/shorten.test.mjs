// Regression test for security-fix-20261010-tsunagu:
// "短縮リンクAPIが誰でも無制限・無期限に書き込める" (tsunagu-shortlink-worker-unbounded-anonymous-kv-write)
//
// No dependencies / no test framework required: plain Node (>=18) with
// built-in fetch globals (Request/Response) and node:assert.
// Run with: node shortlink/test/shorten.test.mjs
import assert from 'node:assert/strict';
import worker from '../src/index.js';

class DummyKV {
  constructor() { this.store = new Map(); this.putCalls = []; }
  async get(key) { return this.store.has(key) ? this.store.get(key) : null; }
  async put(key, value, opts) {
    this.putCalls.push({ key, valueLength: value.length, opts });
    this.store.set(key, value);
  }
}

function makeRequest(body, headers = {}) {
  return new Request('https://tsunagu.densalon.com/api/shorten', {
    method: 'POST',
    headers: { 'content-type': 'application/json', ...headers },
    body: JSON.stringify(body),
  });
}

const EXPECTED_TTL = 60 * 60 * 24 * 90; // must match shortlink/src/index.js LINK_TTL_SECONDS
let failed = 0;

async function test(name, fn) {
  try {
    await fn();
    console.log(`ok - ${name}`);
  } catch (e) {
    failed++;
    console.error(`NOT OK - ${name}\n  ${e.message}`);
  }
}

await test('oversized s (2MB) is rejected with 400 and never stored', async () => {
  const kv = new DummyKV();
  const req = makeRequest({ s: 'A'.repeat(2 * 1024 * 1024) }, { Origin: 'https://attacker.example' });
  const res = await worker.fetch(req, { TSUNAGU_LINKS: kv });
  assert.equal(res.status, 400);
  assert.equal(kv.putCalls.length, 0);
});

await test('oversized ref is rejected with 400', async () => {
  const kv = new DummyKV();
  const req = makeRequest({ s: 'https://example.com/job/1', ref: 'R'.repeat(3000) });
  const res = await worker.fetch(req, { TSUNAGU_LINKS: kv });
  assert.equal(res.status, 400);
});

await test('oversized by is rejected with 400', async () => {
  const kv = new DummyKV();
  const req = makeRequest({ s: 'https://example.com/job/1', by: 'B'.repeat(3000) });
  const res = await worker.fetch(req, { TSUNAGU_LINKS: kv });
  assert.equal(res.status, 400);
});

await test('normal request is still accepted and the KV write carries an expirationTtl', async () => {
  const kv = new DummyKV();
  const req = makeRequest({ s: 'https://example.com/job/1', ref: 'friend', by: 'Taro' });
  const res = await worker.fetch(req, { TSUNAGU_LINKS: kv });
  const json = await res.json();
  assert.equal(res.status, 200);
  assert.ok(json.code);
  assert.equal(kv.putCalls.length, 1);
  assert.equal(kv.putCalls[0].opts && kv.putCalls[0].opts.expirationTtl, EXPECTED_TTL);
});

await test('a value exactly at the 2000-char limit is still accepted (boundary)', async () => {
  const kv = new DummyKV();
  const req = makeRequest({ s: 'A'.repeat(2000) });
  const res = await worker.fetch(req, { TSUNAGU_LINKS: kv });
  assert.equal(res.status, 200);
});

if (failed > 0) {
  console.error(`\n${failed} test(s) failed`);
  process.exit(1);
}
console.log('\nall tests passed');

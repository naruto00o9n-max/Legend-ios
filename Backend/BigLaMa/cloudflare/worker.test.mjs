import {test} from 'node:test';
import assert from 'node:assert/strict';
import worker, {RestorationGateCore as RestorationGate} from './core.mjs';

function storage() {
  const values = new Map();
  const api = {get: async k => structuredClone(values.get(k)), put: async (k, v) => values.set(k, structuredClone(v))};
  return {...api, transaction: async fn => fn(api)};
}
function request(headers = {}) {
  return new Request('https://internal/v1/restore', {method: 'POST', headers: {'content-type': 'multipart/form-data; boundary=test', 'x-cookies-client': 'test-client', ...headers}, body: 'image parts'});
}

test('Persistent daily budget stops work before contacting model origin', async () => {
  const previous = global.fetch;
  let calls = 0;
  global.fetch = async (_, init) => {
    calls++;assert.equal(init.headers.authorization, 'Bearer origin-only-test');
    return new Response('patch', {headers: {'content-type': 'image/png', 'x-cookies-source-sha256': 'test-digest'}});
  };
  try {
    const gate = new RestorationGate({storage: storage()}, {BACKEND_URL: 'https://model.example', BACKEND_TOKEN: 'origin-only-test', MAX_DAILY_REQUESTS: '2', MAX_CLIENT_DAILY_REQUESTS: '2'});
    const first = await gate.fetch(request());assert.equal(first.status, 200);assert.equal(first.headers.get('cache-control'), 'no-store');assert.equal(first.headers.get('x-cookies-source-sha256'), 'test-digest');
    assert.equal((await gate.fetch(request())).status, 200);
    assert.equal((await gate.fetch(request())).status, 429);assert.equal(calls, 2);
  } finally {global.fetch = previous;}
});

test('Global concurrency guard bounds memory to one inference', async () => {
  const previous = global.fetch;
  let finish;global.fetch = () => new Promise(resolve => {finish = resolve;});
  try {
    const gate = new RestorationGate({storage: storage()}, {BACKEND_URL: 'https://model.example', BACKEND_TOKEN: 'origin-only-test'});
    const first = gate.fetch(request());await new Promise(resolve => setImmediate(resolve));
    assert.equal((await gate.fetch(request())).status, 429);
    finish(new Response('patch'));assert.equal((await first).status, 200);
  } finally {global.fetch = previous;}
});

test('Public client cannot choose origin authorization or quota identity', async () => {
  let seen;
  const env = {BACKEND_URL: 'https://model.example', BACKEND_TOKEN: 'origin-only-test', GATE: {idFromName: n => n, get: () => ({fetch: async req => {seen = req;return new Response('patch');}})}};
  const result = await worker.fetch(new Request('https://cookies.example/v1/restore', {method: 'POST', headers: {'content-type': 'multipart/form-data; boundary=test', 'CF-Connecting-IP': '203.0.113.7', authorization: 'Bearer client-controlled', 'x-cookies-client': 'spoofed'}, body: 'parts'}), env);
  assert.equal(result.status, 200);assert.equal(seen.headers.get('authorization'), null);assert.match(seen.headers.get('x-cookies-client'), /^[0-9a-f]{64}$/);
  assert.equal((await worker.fetch(new Request('https://cookies.example/other'), env)).status, 404);
  assert.equal((await worker.fetch(new Request('https://cookies.example/v1/restore', {method: 'POST', headers: {'content-length': '20000001'}}), env)).status, 413);
});

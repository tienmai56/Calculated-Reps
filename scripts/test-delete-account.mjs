import assert from 'node:assert/strict';
import test from 'node:test';

let handler;
globalThis.Deno = {
  env: { get: name => name === 'SUPABASE_URL' ? 'https://example.invalid' : 'test-service-key' },
  serve: callback => { handler = callback; },
};
await import('../supabase/functions/delete-account/index.ts');

const request = () => new Request('https://example.invalid/delete-account', {
  method: 'POST', headers: { authorization: 'Bearer test-user-session' },
});

test('account deletion rejects missing and invalid authentication before touching data', async t => {
  let calls = 0;
  t.mock.method(globalThis, 'fetch', async url => {
    calls++;
    assert.equal(new URL(url).pathname, '/auth/v1/user');
    return new Response('Unauthorized', { status: 401 });
  });
  assert.equal((await handler(new Request('https://example.invalid/delete-account', { method: 'POST' }))).status, 401);
  assert.equal(calls, 0);
  assert.equal((await handler(request())).status, 401);
  assert.equal(calls, 1);
});

test('account deletion removes all profile-photo pages before deleting the account', async t => {
  const remaining = new Set(Array.from({ length: 1001 }, (_, i) => `${i}.jpg`));
  const removed = [];
  let lists = 0;
  let erased = false;
  let deleted = false;
  t.mock.method(globalThis, 'fetch', async (url, options = {}) => {
    const path = new URL(url).pathname;
    if (path === '/auth/v1/user') return Response.json({ id: 'member' });
    if (path === '/rest/v1/media_assets') return Response.json([]);
    if (path === '/storage/v1/object/list/avatars') {
      const body = JSON.parse(options.body);
      assert.equal(body.prefix, 'member');
      assert.equal(body.offset, 0);
      lists++;
      return Response.json([...remaining].slice(0, body.limit).map(name => ({ name })));
    }
    if (path === '/storage/v1/object/avatars') {
      assert.equal(options.method, 'DELETE');
      for (const key of JSON.parse(options.body).prefixes) {
        assert.ok(key.startsWith('member/'));
        assert.ok(remaining.delete(key.slice('member/'.length)));
        removed.push(key);
      }
      return Response.json({});
    }
    if (path === '/rest/v1/rpc/erase_social_account') {
      assert.equal(remaining.size, 0);
      assert.deepEqual(JSON.parse(options.body), { target: 'member' });
      erased = true;
      return Response.json({});
    }
    if (path === '/auth/v1/admin/users/member') {
      assert.ok(erased);
      assert.equal(options.method, 'DELETE');
      deleted = true;
      return Response.json({});
    }
    throw new Error(`Unexpected request: ${path}`);
  });
  assert.equal((await handler(request())).status, 200);
  assert.equal(removed.length, 1001);
  assert.equal(lists, 3);
  assert.ok(deleted);
});

test('failed photo cleanup preserves the account for a safe retry', async t => {
  t.mock.method(globalThis, 'fetch', async url => {
    const path = new URL(url).pathname;
    if (path === '/auth/v1/user') return Response.json({ id: 'member' });
    if (path === '/rest/v1/media_assets') return Response.json([]);
    if (path === '/storage/v1/object/list/avatars') return Response.json([{ name: 'photo.jpg' }]);
    if (path === '/storage/v1/object/avatars') return new Response('Storage unavailable', { status: 503 });
    throw new Error(`Account data must remain intact: ${path}`);
  });
  const response = await handler(request());
  assert.equal(response.status, 500);
  assert.match(await response.text(), /retry account deletion/);
});

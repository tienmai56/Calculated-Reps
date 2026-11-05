import assert from 'node:assert/strict';
import test from 'node:test';

// Real signing with an ephemeral local key; every database/APNs request is mocked.
const key = await crypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify']);
const pem = '-----BEGIN PRIVATE KEY-----\n' + Buffer.from(await crypto.subtle.exportKey('pkcs8', key.privateKey)).toString('base64') + '\n-----END PRIVATE KEY-----';
const env = {
  NOTIFICATION_WORKER_SECRET: 'test-worker-secret', SUPABASE_URL: 'https://example.invalid',
  SUPABASE_SERVICE_ROLE_KEY: 'test-service-key', APNS_KEY_ID: 'test-key',
  APNS_TEAM_ID: 'test-team', APNS_PRIVATE_KEY: pem, APNS_TOPIC: 'test.app',
};
let handler;
globalThis.Deno = { env: { get: name => env[name] }, serve: callback => { handler = callback; } };
await import('../supabase/functions/notification-worker/index.ts');
const request = () => new Request('https://example.invalid/worker', { headers: { 'x-worker-secret': env.NOTIFICATION_WORKER_SECRET } });

test('worker rejects unauthenticated requests before reading notifications', async t => {
  t.mock.method(globalThis, 'fetch', () => { throw new Error('No requests expected'); });
  assert.equal((await handler(new Request('https://example.invalid/worker'))).status, 401);
});

for (const note of [
  { kind: 'comment', entity_id: 'post-id', message: 'commented on a memory you commented on' },
  { kind: 'mention', entity_id: 'post-id', message: 'mentioned you in a comment' },
  { kind: 'goal_update', entity_id: 'goal-id', message: 'updated Single leg finish' },
]) {
 for (const enabled of [true, false]) {
  test(`${note.kind} push ${enabled ? 'delivers with the entity to open' : 'respects disabled notifications'}`, async t => {
    let pushes = 0;
    let deviceReads = 0;
    let delivered = false;
    t.mock.method(globalThis, 'fetch', async (url, options = {}) => {
      const { hostname, pathname } = new URL(url);
      if (hostname === 'api.sandbox.push.apple.com') {
        pushes++;
        assert.equal(options.headers['apns-collapse-id'], 'note-id');
        const payload = JSON.parse(options.body);
        assert.equal(payload.kind, note.kind);
        assert.equal(payload.entity_id, note.entity_id);
        assert.equal(payload.aps['thread-id'], note.kind);
        assert.equal(payload.aps.alert.body, `Sarah ${note.message}`);
        return new Response(null, { status: 200 });
      }
      switch (pathname) {
        case '/rest/v1/rpc/claim_notifications': return Response.json([{ id: 'note-id', attempts: 1 }]);
        case '/rest/v1/notifications': return Response.json([{ id: 'note-id', recipient: 'hippo', actor: 'sarah', ...note }]);
        case '/rest/v1/account_settings': return Response.json([{ push_enabled: enabled }]);
        case '/rest/v1/device_tokens': deviceReads++; return Response.json([{ token: 'device-token', environment: 'sandbox' }]);
        case '/rest/v1/profiles': return Response.json([{ name: 'Sarah' }]);
        case '/rest/v1/notification_outbox':
          assert.equal(options.method, 'PATCH');
          assert.ok(JSON.parse(options.body).delivered_at);
          delivered = true;
          return new Response(null, { status: 204 });
        default: throw new Error(`Unexpected request: ${url}`);
      }
    });
    assert.equal((await handler(request())).status, 200);
    assert.equal(pushes, enabled ? 1 : 0);
    assert.equal(deviceReads, enabled ? 1 : 0);
    assert.ok(delivered);
  });
 }
}

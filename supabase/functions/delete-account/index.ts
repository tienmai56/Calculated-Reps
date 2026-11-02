// Caller authentication is checked against Auth. Never accept a user ID in input.
Deno.serve(async (request: Request) => {
  if (request.method !== 'POST') return new Response('Method not allowed', { status: 405 });
  const base = Deno.env.get('SUPABASE_URL')!;
  const admin = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const authorization = request.headers.get('authorization');
  if (!authorization) return new Response('Unauthorized', { status: 401 });
  const userResponse = await fetch(`${base}/auth/v1/user`, { headers: { apikey: admin, authorization } });
  if (!userResponse.ok) return new Response('Unauthorized', { status: 401 });
  const user = await userResponse.json();
  const headers = { apikey: admin, authorization: `Bearer ${admin}`, 'content-type': 'application/json' };
  const assets = await fetch(`${base}/rest/v1/media_assets?owner=eq.${encodeURIComponent(user.id)}&select=object_key`, { headers });
  if (!assets.ok) return new Response('Could not inspect account media', { status: 500 });
  const rows = await assets.json();
  if (rows.length) {
    const removed = await fetch(`${base}/storage/v1/object/session-photos`, { method: 'DELETE', headers, body: JSON.stringify({ prefixes: rows.map((r: {object_key: string}) => r.object_key) }) });
    if (!removed.ok) return new Response('Media deletion failed; retry account deletion', { status: 500 });
  }
  // Profile photos live under the member's own folder in the avatars bucket.
  // Delete each page before reading offset zero again so no uploads are skipped.
  while (true) {
    const listed = await fetch(`${base}/storage/v1/object/list/avatars`, { method: 'POST', headers, body: JSON.stringify({ prefix: user.id, limit: 1000, offset: 0 }) });
    if (!listed.ok) return new Response('Could not inspect profile photos', { status: 500 });
    const avatars = (await listed.json()) as {name: string}[];
    if (!avatars.length) break;
    const removed = await fetch(`${base}/storage/v1/object/avatars`, { method: 'DELETE', headers, body: JSON.stringify({ prefixes: avatars.map((a) => `${user.id}/${a.name}`) }) });
    if (!removed.ok) return new Response('Profile photo deletion failed; retry account deletion', { status: 500 });
  }
  const erased = await fetch(`${base}/rest/v1/rpc/erase_social_account`, { method: 'POST', headers, body: JSON.stringify({ target: user.id }) });
  if (!erased.ok) return new Response('Account data deletion failed; retry', { status: 500 });
  const deleted = await fetch(`${base}/auth/v1/admin/users/${encodeURIComponent(user.id)}`, { method: 'DELETE', headers });
  return deleted.ok ? new Response('{}', {headers: {'content-type':'application/json'}}) : new Response('Identity deletion failed; retry', { status: 500 });
});

const enc = new TextEncoder();
const b64 = (bytes: Uint8Array) => btoa(String.fromCharCode(...bytes)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
async function apnsJWT(): Promise<string> {
  const keyID = Deno.env.get('APNS_KEY_ID')!, team = Deno.env.get('APNS_TEAM_ID')!;
  const pem = Deno.env.get('APNS_PRIVATE_KEY')!.replace(/\\n/g, '\n');
  const body = pem.replace(/-----[^-]+-----/g, '').replace(/\s/g, '');
  const key = await crypto.subtle.importKey('pkcs8', Uint8Array.from(atob(body), c => c.charCodeAt(0)), {name:'ECDSA',namedCurve:'P-256'},false,['sign']);
  const payload = `${b64(enc.encode(JSON.stringify({alg:'ES256',kid:keyID})))}.${b64(enc.encode(JSON.stringify({iss:team,iat:Math.floor(Date.now()/1000)})))}`;
  const sig = await crypto.subtle.sign({name:'ECDSA',hash:'SHA-256'},key,enc.encode(payload));
  return `${payload}.${b64(new Uint8Array(sig))}`;
}
Deno.serve(async (request: Request) => {
  const expected = Deno.env.get('NOTIFICATION_WORKER_SECRET');
  if (!expected || request.headers.get('x-worker-secret') !== expected) return new Response('Unauthorized',{status:401});
  const base = Deno.env.get('SUPABASE_URL')!, admin = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const headers = {apikey:admin,authorization:`Bearer ${admin}`,'content-type':'application/json'};
  async function api(path: string,method='GET',body?: unknown): Promise<any> {
    const response = await fetch(`${base}/rest/v1/${path}`,{method,headers,body:body===undefined?undefined:JSON.stringify(body)});
    if (!response.ok) throw new Error(`Worker database request failed (${response.status})`);
    return response.status===204 ? null : response.json();
  }
  try {
    // Fail before claiming work if APNs secrets are not configured.
    const jwt = await apnsJWT();
    const batch = await api('rpc/claim_notifications','POST',{batch_size:25});
    for (const job of batch) {
      try {
        const [note] = await api(`notifications?id=eq.${job.id}&select=*`);
        const [settings] = await api(`account_settings?user_id=eq.${note.recipient}&select=push_enabled`);
        const devices = settings?.push_enabled === false ? [] : await api(`device_tokens?user_id=eq.${note.recipient}&select=*`);
        for (const device of devices) {
          const host = device.environment==='production'?'api.push.apple.com':'api.sandbox.push.apple.com';
          const result = await fetch(`https://${host}/3/device/${device.token}`,{method:'POST',headers:{authorization:`bearer ${jwt}`,'apns-topic':Deno.env.get('APNS_TOPIC')!,'apns-push-type':'alert','apns-collapse-id':job.id},body:JSON.stringify({aps:{alert:{title:'Mat Mind',body:note.message},sound:'default'},kind:note.kind,entity_id:note.entity_id})});
          if (result.status===410) await api(`device_tokens?token=eq.${device.token}`,'DELETE');
          else if (!result.ok) throw new Error(`APNs returned ${result.status}`);
        }
        await api(`notification_outbox?id=eq.${job.id}`,'PATCH',{delivered_at:new Date().toISOString(),last_error:null});
      } catch (error) {
        const delay = Math.min(3600, 30 * 2 ** Math.min(job.attempts,7));
        await api(`notification_outbox?id=eq.${job.id}`,'PATCH',{last_error:String(error),next_attempt:new Date(Date.now()+delay*1000).toISOString()});
      }
    }
    return Response.json({processed:batch.length});
  } catch { return new Response('Notification worker failed; check configuration and retry',{status:500}); }
});

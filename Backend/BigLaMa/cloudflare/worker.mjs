const MAX_BODY = 20_000_000;
const json = (body, status = 200, extra = {}) => new Response(JSON.stringify(body), {
  status, headers: { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store', ...extra }
});

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method === 'GET' && url.pathname === '/health') {
      return json({ protocol: 1, model: 'Big LaMa', backendConfigured: !!env.BACKEND_URL, localDownloadRequired: false });
    }
    if (request.method !== 'POST' || url.pathname !== '/v1/restore') return json({ error: 'not_found' }, 404);
    if (!env.BACKEND_URL || !env.BACKEND_TOKEN) return json({ error: 'not_configured' }, 503);
    const length = Number(request.headers.get('content-length'));
    if (length > MAX_BODY) return json({ error: 'region_too_large' }, 413);
    if (!(request.headers.get('content-type') || '').startsWith('multipart/form-data;')) return json({ error: 'multipart_required' }, 415);
    const ip = request.headers.get('CF-Connecting-IP');
    if (!ip) return json({ error: 'client_unavailable' }, 400);
    const hash = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(ip + env.BACKEND_TOKEN));
    const client = [...new Uint8Array(hash)].map(v => v.toString(16).padStart(2, '0')).join('');
    // The public client cannot choose its origin credentials or quota identity.
    const headers = new Headers({ 'content-type': request.headers.get('content-type'), 'x-cookies-client': client });
    const gate = env.GATE.get(env.GATE.idFromName('global-v1'));
    return gate.fetch(new Request('https://internal/v1/restore', { method: 'POST', headers, body: request.body, duplex: 'half' }));
  }
};

export class RestorationGate {
  constructor(state, env) { this.state = state; this.env = env; this.inFlight = false; }
  async fetch(request) {
    if (this.inFlight) return json({ error: 'restoration_busy' }, 429, { 'retry-after': '5' });
    this.inFlight = true;
    try {
      const client = request.headers.get('x-cookies-client');
      const day = new Date().toISOString().slice(0, 10);
      const maxDaily = Math.max(1, Math.min(10_000, Number(this.env.MAX_DAILY_REQUESTS || 300)));
      const maxClient = Math.max(1, Math.min(maxDaily, Number(this.env.MAX_CLIENT_DAILY_REQUESTS || 120)));
      const accepted = await this.state.storage.transaction(async storage => {
        let budget = await storage.get('budget');
        if (!budget || budget.day !== day) budget = { day, total: 0, clients: {} };
        if (budget.total >= maxDaily || (budget.clients[client] || 0) >= maxClient) return false;
        budget.total += 1; budget.clients[client] = (budget.clients[client] || 0) + 1;
        await storage.put('budget', budget);
        return true;
      });
      if (!accepted) return json({ error: 'daily_capacity_reached' }, 429, { 'retry-after': '3600' });
      const response = await fetch(new URL('/v1/restore', this.env.BACKEND_URL), {
        method: 'POST', headers: { 'content-type': request.headers.get('content-type'), authorization: 'Bearer ' + this.env.BACKEND_TOKEN },
        body: request.body, signal: AbortSignal.timeout(180_000)
      });
      const headers = new Headers({ 'cache-control': 'no-store', 'content-type': response.headers.get('content-type') || 'application/json' });
      for (const name of ['x-cookies-model', 'x-cookies-source-sha256', 'retry-after']) {
        if (response.headers.has(name)) headers.set(name, response.headers.get(name));
      }
      return new Response(response.body, { status: response.status, headers });
    } catch {
      return json({ error: 'service_unavailable' }, 503);
    } finally { this.inFlight = false; }
  }
}

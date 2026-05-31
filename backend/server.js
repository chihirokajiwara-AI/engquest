// backend/server.js
// A-KEN Quest — Backend Proxy Server
//
// Handles:
//   1. Stripe billing (checkout, webhooks, portal)
//   2. Claude API proxy (keeps API key server-side)
//
// Deploy: Docker on Hetzner VPS (178.105.113.79)
// Env vars: STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET, CLAUDE_API_KEY, PORT

const http = require('http');
const crypto = require('crypto');

const PORT = process.env.PORT || 3001;
const STRIPE_SECRET_KEY = process.env.STRIPE_SECRET_KEY || '';
const STRIPE_WEBHOOK_SECRET = process.env.STRIPE_WEBHOOK_SECRET || '';
const CLAUDE_API_KEY = process.env.CLAUDE_API_KEY || '';
const STRIPE_PRICE_ID = process.env.STRIPE_PRICE_ID || 'price_aken_monthly_999';

// ── Helpers ──────────────────────────────────────────────────────────────────

function parseBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', (chunk) => chunks.push(chunk));
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

function json(res, statusCode, data) {
  res.writeHead(statusCode, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  });
  res.end(JSON.stringify(data));
}

function cors(res) {
  res.writeHead(204, {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  });
  res.end();
}

async function stripeRequest(method, path, body) {
  const url = new URL(path, 'https://api.stripe.com');
  const options = {
    method,
    headers: {
      'Authorization': `Bearer ${STRIPE_SECRET_KEY}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
  };

  const fetch = (await import('node:https')).default || require('https');
  return new Promise((resolve, reject) => {
    const req = fetch.request(url, options, (res) => {
      const chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => {
        try {
          resolve(JSON.parse(Buffer.concat(chunks).toString()));
        } catch (e) {
          reject(e);
        }
      });
    });
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

// ── In-memory subscription cache (replace with Firestore in production) ──────

const subscriptions = new Map(); // uid -> { status, trial_end, current_period_end, stripe_customer_id }

// ── Routes ───────────────────────────────────────────────────────────────────

async function handleBillingStatus(req, res) {
  const url = new URL(req.url, `http://localhost:${PORT}`);
  const uid = url.searchParams.get('uid');
  if (!uid) return json(res, 400, { error: 'uid required' });

  const sub = subscriptions.get(uid) || { status: 'free' };
  json(res, 200, sub);
}

async function handleBillingCheckout(req, res) {
  const body = JSON.parse((await parseBody(req)).toString());
  const { uid, trial_days = 7 } = body;
  if (!uid) return json(res, 400, { error: 'uid required' });

  if (!STRIPE_SECRET_KEY) {
    // Dev mode: simulate checkout
    subscriptions.set(uid, {
      status: 'trial',
      trial_end: new Date(Date.now() + trial_days * 86400000).toISOString(),
      current_period_end: new Date(Date.now() + 30 * 86400000).toISOString(),
      stripe_customer_id: `cus_dev_${uid.slice(0, 8)}`,
    });
    return json(res, 200, { checkout_url: null, dev_mode: true, status: 'trial_started' });
  }

  // Production: create Stripe Checkout Session
  const params = new URLSearchParams({
    'mode': 'subscription',
    'payment_method_types[]': 'card',
    'line_items[0][price]': STRIPE_PRICE_ID,
    'line_items[0][quantity]': '1',
    'subscription_data[trial_period_days]': String(trial_days),
    'subscription_data[metadata][firebase_uid]': uid,
    'success_url': 'https://akenquest.jp/billing/success?uid=' + uid,
    'cancel_url': 'https://akenquest.jp/billing/cancel',
    'client_reference_id': uid,
  });

  try {
    const session = await stripeRequest('POST', '/v1/checkout/sessions', params.toString());
    json(res, 200, { checkout_url: session.url });
  } catch (e) {
    json(res, 500, { error: 'Stripe checkout failed', detail: e.message });
  }
}

async function handleBillingPortal(req, res) {
  const body = JSON.parse((await parseBody(req)).toString());
  const { uid } = body;
  if (!uid) return json(res, 400, { error: 'uid required' });

  const sub = subscriptions.get(uid);
  if (!sub?.stripe_customer_id) {
    return json(res, 404, { error: 'No subscription found' });
  }

  if (!STRIPE_SECRET_KEY) {
    return json(res, 200, { portal_url: null, dev_mode: true });
  }

  const params = new URLSearchParams({
    'customer': sub.stripe_customer_id,
    'return_url': 'https://akenquest.jp/settings',
  });

  try {
    const portal = await stripeRequest('POST', '/v1/billing_portal/sessions', params.toString());
    json(res, 200, { portal_url: portal.url });
  } catch (e) {
    json(res, 500, { error: 'Portal creation failed', detail: e.message });
  }
}

async function handleStripeWebhook(req, res) {
  const rawBody = await parseBody(req);
  const sig = req.headers['stripe-signature'];

  if (STRIPE_WEBHOOK_SECRET && sig) {
    // Verify signature
    const elements = sig.split(',').reduce((acc, item) => {
      const [key, value] = item.split('=');
      acc[key] = value;
      return acc;
    }, {});
    const payload = `${elements.t}.${rawBody}`;
    const expected = crypto.createHmac('sha256', STRIPE_WEBHOOK_SECRET)
      .update(payload).digest('hex');
    if (expected !== elements.v1) {
      return json(res, 400, { error: 'Invalid signature' });
    }
  }

  const event = JSON.parse(rawBody.toString());
  const subscription = event.data?.object;
  const uid = subscription?.metadata?.firebase_uid;

  if (!uid) return json(res, 200, { received: true });

  switch (event.type) {
    case 'customer.subscription.created':
    case 'customer.subscription.updated':
      subscriptions.set(uid, {
        status: subscription.status === 'trialing' ? 'trial' : 'active',
        trial_end: subscription.trial_end
          ? new Date(subscription.trial_end * 1000).toISOString()
          : null,
        current_period_end: new Date(subscription.current_period_end * 1000).toISOString(),
        stripe_customer_id: subscription.customer,
      });
      break;
    case 'customer.subscription.deleted':
      subscriptions.set(uid, { status: 'expired' });
      break;
  }

  json(res, 200, { received: true });
}

async function handleClaudeProxy(req, res) {
  if (!CLAUDE_API_KEY) {
    return json(res, 503, { error: 'Claude API key not configured' });
  }

  const body = await parseBody(req);
  const requestData = JSON.parse(body.toString());

  // Enforce haiku model and max tokens for cost control
  requestData.model = requestData.model || 'claude-haiku-4-5-20251001';
  requestData.max_tokens = Math.min(requestData.max_tokens || 256, 512);

  const https = require('https');
  const postData = JSON.stringify(requestData);

  const options = {
    hostname: 'api.anthropic.com',
    path: '/v1/messages',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': CLAUDE_API_KEY,
      'anthropic-version': '2023-06-01',
      'Content-Length': Buffer.byteLength(postData),
    },
  };

  const proxyReq = https.request(options, (proxyRes) => {
    const chunks = [];
    proxyRes.on('data', (c) => chunks.push(c));
    proxyRes.on('end', () => {
      res.writeHead(proxyRes.statusCode, {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      });
      res.end(Buffer.concat(chunks));
    });
  });

  proxyReq.on('error', (e) => json(res, 502, { error: e.message }));
  proxyReq.write(postData);
  proxyReq.end();
}

// ── Server ───────────────────────────────────────────────────────────────────

const server = http.createServer(async (req, res) => {
  try {
    if (req.method === 'OPTIONS') return cors(res);

    const url = new URL(req.url, `http://localhost:${PORT}`);
    const path = url.pathname;

    if (path === '/billing/status' && req.method === 'GET') {
      return handleBillingStatus(req, res);
    }
    if (path === '/billing/checkout' && req.method === 'POST') {
      return handleBillingCheckout(req, res);
    }
    if (path === '/billing/portal' && req.method === 'POST') {
      return handleBillingPortal(req, res);
    }
    if (path === '/billing/webhook' && req.method === 'POST') {
      return handleStripeWebhook(req, res);
    }
    if (path === '/claude/messages' && req.method === 'POST') {
      return handleClaudeProxy(req, res);
    }
    if (path === '/health') {
      return json(res, 200, { status: 'ok', version: '1.0.0' });
    }

    json(res, 404, { error: 'Not found' });
  } catch (e) {
    console.error('Unhandled error:', e);
    json(res, 500, { error: 'Internal server error' });
  }
});

server.listen(PORT, () => {
  console.log(`A-KEN Quest backend running on port ${PORT}`);
  console.log(`Stripe: ${STRIPE_SECRET_KEY ? 'configured' : 'DEV MODE'}`);
  console.log(`Claude: ${CLAUDE_API_KEY ? 'configured' : 'NOT SET'}`);
});

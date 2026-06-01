// backend/server.js
// A-KEN Quest — Security-Hardened Backend Proxy Server
//
// Handles:
//   1. Stripe billing (checkout, webhooks, portal)
//   2. Claude API proxy (keeps API key server-side)
//
// Security measures:
//   - Firebase ID token verification (not trusting raw uid)
//   - Stripe webhook signature verification via official SDK
//   - CORS restricted to allowed origins
//   - Per-IP and per-UID rate limiting
//   - Request body size limits
//   - Input validation on all parameters
//   - No stack traces / secrets in error responses
//   - HTTPS enforcement via X-Forwarded-Proto (behind nginx)
//   - Helmet-style security headers
//
// Deploy: Docker on Hetzner VPS behind nginx TLS termination
// Env vars: STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET, CLAUDE_API_KEY,
//           FIREBASE_PROJECT_ID, PORT, NODE_ENV, ALLOWED_ORIGINS

'use strict';

const http = require('http');
const https = require('https');
const crypto = require('crypto');

// ── Environment ──────────────────────────────────────────────────────────────

const PORT = parseInt(process.env.PORT, 10) || 3001;
const NODE_ENV = process.env.NODE_ENV || 'production';
const STRIPE_SECRET_KEY = process.env.STRIPE_SECRET_KEY || '';
const STRIPE_WEBHOOK_SECRET = process.env.STRIPE_WEBHOOK_SECRET || '';
const CLAUDE_API_KEY = process.env.CLAUDE_API_KEY || '';
const STRIPE_PRICE_ID = process.env.STRIPE_PRICE_ID || 'price_aken_monthly_999';
const FIREBASE_PROJECT_ID = process.env.FIREBASE_PROJECT_ID || '';

// CORS: restrict to known origins. Comma-separated env var.
const ALLOWED_ORIGINS = (process.env.ALLOWED_ORIGINS || 'https://akenquest.jp,https://www.akenquest.jp,https://api.akenquest.jp')
  .split(',')
  .map(s => s.trim())
  .filter(Boolean);

// ── Lazy-loaded SDKs ─────────────────────────────────────────────────────────
// Loaded once on first use so the server starts fast and we can
// gracefully degrade in dev mode when credentials are missing.

let _firebaseAdmin = null;
let _stripe = null;

function getFirebaseAdmin() {
  if (_firebaseAdmin) return _firebaseAdmin;
  try {
    const admin = require('firebase-admin');
    if (!admin.apps.length) {
      admin.initializeApp({
        projectId: FIREBASE_PROJECT_ID || undefined,
      });
    }
    _firebaseAdmin = admin;
    return admin;
  } catch (e) {
    log('warn', 'Firebase Admin SDK not available — auth verification disabled', e.message);
    return null;
  }
}

function getStripe() {
  if (_stripe) return _stripe;
  if (!STRIPE_SECRET_KEY) return null;
  try {
    const Stripe = require('stripe');
    _stripe = new Stripe(STRIPE_SECRET_KEY, {
      apiVersion: '2024-12-18.acacia',
      maxNetworkRetries: 2,
    });
    return _stripe;
  } catch (e) {
    log('warn', 'Stripe SDK not available', e.message);
    return null;
  }
}

// ── Structured Logging ───────────────────────────────────────────────────────

function log(level, message, detail) {
  const entry = {
    ts: new Date().toISOString(),
    level,
    msg: message,
  };
  if (detail !== undefined) entry.detail = detail;
  // Never log secrets
  console.log(JSON.stringify(entry));
}

// ── Security Constants ───────────────────────────────────────────────────────

const MAX_BODY_SIZE = 64 * 1024;        // 64 KB for normal endpoints
const MAX_WEBHOOK_BODY_SIZE = 256 * 1024; // 256 KB for Stripe webhooks
const UID_REGEX = /^[a-zA-Z0-9]{10,128}$/; // Firebase UID format

// ── Rate Limiting ────────────────────────────────────────────────────────────
// Simple sliding-window per-IP rate limiter. Production should use Redis.

class RateLimiter {
  constructor({ windowMs = 60_000, maxRequests = 30 } = {}) {
    this.windowMs = windowMs;
    this.maxRequests = maxRequests;
    this.hits = new Map(); // key -> [timestamps]
    // Cleanup every 5 minutes to prevent memory leak
    this._cleanupInterval = setInterval(() => this._cleanup(), 5 * 60_000);
    this._cleanupInterval.unref();
  }

  isAllowed(key) {
    const now = Date.now();
    const cutoff = now - this.windowMs;
    let timestamps = this.hits.get(key);
    if (!timestamps) {
      timestamps = [];
      this.hits.set(key, timestamps);
    }
    // Remove expired entries
    while (timestamps.length > 0 && timestamps[0] < cutoff) {
      timestamps.shift();
    }
    if (timestamps.length >= this.maxRequests) {
      return false;
    }
    timestamps.push(now);
    return true;
  }

  _cleanup() {
    const cutoff = Date.now() - this.windowMs;
    for (const [key, timestamps] of this.hits) {
      while (timestamps.length > 0 && timestamps[0] < cutoff) {
        timestamps.shift();
      }
      if (timestamps.length === 0) {
        this.hits.delete(key);
      }
    }
  }
}

// Rate limiters for different endpoint categories
const rateLimiters = {
  billing: new RateLimiter({ windowMs: 60_000, maxRequests: 20 }),    // 20/min per IP
  claude:  new RateLimiter({ windowMs: 60_000, maxRequests: 10 }),    // 10/min per IP
  claudePerUid: new RateLimiter({ windowMs: 3600_000, maxRequests: 60 }), // 60/hour per UID
  health:  new RateLimiter({ windowMs: 60_000, maxRequests: 60 }),    // 60/min per IP
};

// ── Helpers ──────────────────────────────────────────────────────────────────

function getClientIp(req) {
  // Behind nginx: trust X-Forwarded-For (first entry)
  const xff = req.headers['x-forwarded-for'];
  if (xff) return xff.split(',')[0].trim();
  return req.socket.remoteAddress || 'unknown';
}

function parseBody(req, maxSize = MAX_BODY_SIZE) {
  return new Promise((resolve, reject) => {
    let size = 0;
    const chunks = [];
    req.on('data', (chunk) => {
      size += chunk.length;
      if (size > maxSize) {
        req.destroy();
        reject(new Error('Request body too large'));
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

function securityHeaders() {
  return {
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
    'X-XSS-Protection': '0',
    'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
    'Cache-Control': 'no-store',
    'Content-Type': 'application/json',
  };
}

function corsHeaders(req) {
  const origin = req.headers['origin'] || '';
  const headers = {};

  if (NODE_ENV === 'development') {
    // In dev mode, allow localhost origins
    headers['Access-Control-Allow-Origin'] = origin || '*';
  } else if (ALLOWED_ORIGINS.includes(origin)) {
    headers['Access-Control-Allow-Origin'] = origin;
  }
  // If origin not in allowed list in production, no CORS header = browser blocks

  headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS';
  headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization';
  headers['Access-Control-Max-Age'] = '86400';
  headers['Vary'] = 'Origin';
  return headers;
}

function json(req, res, statusCode, data) {
  const headers = {
    ...securityHeaders(),
    ...corsHeaders(req),
  };
  res.writeHead(statusCode, headers);
  res.end(JSON.stringify(data));
}

function cors(req, res) {
  const headers = {
    ...corsHeaders(req),
    ...securityHeaders(),
  };
  res.writeHead(204, headers);
  res.end();
}

function errorResponse(req, res, statusCode, message) {
  // Never leak internal details in production
  json(req, res, statusCode, { error: message });
}

// ── Firebase Auth Verification ───────────────────────────────────────────────

/**
 * Verify Firebase ID token from Authorization header.
 * Returns the decoded token (with uid) or null.
 */
async function verifyFirebaseToken(req) {
  const authHeader = req.headers['authorization'];
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return null;
  }

  const idToken = authHeader.slice(7); // Remove 'Bearer '
  if (!idToken || idToken.length < 100 || idToken.length > 3000) {
    return null; // Firebase ID tokens are JWTs, typically 800-2000 chars
  }

  const admin = getFirebaseAdmin();
  if (!admin) {
    // Firebase not available — fall back to uid parameter in dev mode only
    if (NODE_ENV === 'development') {
      log('warn', 'Firebase unavailable — dev mode uid fallback');
      return null;
    }
    return null;
  }

  try {
    const decodedToken = await admin.auth().verifyIdToken(idToken, true);
    return decodedToken;
  } catch (e) {
    log('warn', 'Firebase token verification failed', e.code || e.message);
    return null;
  }
}

/**
 * Extract authenticated UID from request.
 * Priority: Firebase ID token > uid parameter (dev mode only).
 * Returns { uid, authenticated } or null (with error response sent).
 */
async function extractAuthenticatedUid(req, res, uidParam) {
  // Try Firebase token first
  const decodedToken = await verifyFirebaseToken(req);
  if (decodedToken) {
    return { uid: decodedToken.uid, authenticated: true };
  }

  // In dev mode, fall back to uid parameter
  if (NODE_ENV === 'development' && uidParam) {
    if (!UID_REGEX.test(uidParam)) {
      errorResponse(req, res, 400, 'Invalid uid format');
      return null;
    }
    log('warn', 'Dev mode: using unverified uid parameter', uidParam);
    return { uid: uidParam, authenticated: false };
  }

  // In production, require Firebase token
  if (NODE_ENV !== 'development') {
    errorResponse(req, res, 401, 'Authentication required');
    return null;
  }

  // Dev mode with no uid at all
  if (!uidParam) {
    errorResponse(req, res, 400, 'uid required');
    return null;
  }

  if (!UID_REGEX.test(uidParam)) {
    errorResponse(req, res, 400, 'Invalid uid format');
    return null;
  }

  return { uid: uidParam, authenticated: false };
}

// ── Input Validation ─────────────────────────────────────────────────────────

function validateUid(uid) {
  if (typeof uid !== 'string') return false;
  return UID_REGEX.test(uid);
}

function validateTrialDays(days) {
  if (typeof days !== 'number') return false;
  return Number.isInteger(days) && days >= 0 && days <= 30;
}

function safeJsonParse(buffer) {
  try {
    return JSON.parse(buffer.toString('utf8'));
  } catch {
    return null;
  }
}

// ── Stripe helpers (using official SDK) ──────────────────────────────────────

async function stripeRequest(method, path, params) {
  // Fallback for when Stripe SDK is not available (shouldn't happen in production)
  const url = new URL(path, 'https://api.stripe.com');
  const options = {
    method,
    headers: {
      'Authorization': `Bearer ${STRIPE_SECRET_KEY}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
  };

  return new Promise((resolve, reject) => {
    const req = https.request(url, options, (res) => {
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
    if (params) req.write(params);
    req.end();
  });
}

// ── In-memory subscription cache ─────────────────────────────────────────────
// TODO: Replace with Firestore persistence for production multi-instance deploy

const subscriptions = new Map(); // uid -> { status, trial_end, current_period_end, stripe_customer_id }

// ── Route Handlers ───────────────────────────────────────────────────────────

async function handleBillingStatus(req, res) {
  const url = new URL(req.url, `http://localhost:${PORT}`);
  const uidParam = url.searchParams.get('uid');

  const auth = await extractAuthenticatedUid(req, res, uidParam);
  if (!auth) return; // Error response already sent

  const sub = subscriptions.get(auth.uid) || { status: 'free' };
  json(req, res, 200, sub);
}

async function handleBillingCheckout(req, res) {
  let body;
  try {
    const rawBody = await parseBody(req);
    body = safeJsonParse(rawBody);
  } catch (e) {
    return errorResponse(req, res, 413, 'Request body too large');
  }

  if (!body) {
    return errorResponse(req, res, 400, 'Invalid JSON body');
  }

  const auth = await extractAuthenticatedUid(req, res, body.uid);
  if (!auth) return;

  const uid = auth.uid;
  const trialDays = body.trial_days ?? 7;

  if (!validateTrialDays(trialDays)) {
    return errorResponse(req, res, 400, 'Invalid trial_days (0-30)');
  }

  if (!STRIPE_SECRET_KEY) {
    // Dev mode: simulate checkout
    subscriptions.set(uid, {
      status: 'trial',
      trial_end: new Date(Date.now() + trialDays * 86400000).toISOString(),
      current_period_end: new Date(Date.now() + 30 * 86400000).toISOString(),
      stripe_customer_id: `cus_dev_${uid.slice(0, 8)}`,
    });
    return json(req, res, 200, { checkout_url: null, dev_mode: true, status: 'trial_started' });
  }

  try {
    const stripe = getStripe();
    if (stripe) {
      // Use official Stripe SDK
      const session = await stripe.checkout.sessions.create({
        mode: 'subscription',
        payment_method_types: ['card'],
        line_items: [{
          price: STRIPE_PRICE_ID,
          quantity: 1,
        }],
        subscription_data: {
          trial_period_days: trialDays,
          metadata: { firebase_uid: uid },
        },
        success_url: `https://akenquest.jp/billing/success?session_id={CHECKOUT_SESSION_ID}`,
        cancel_url: 'https://akenquest.jp/billing/cancel',
        client_reference_id: uid,
      });
      return json(req, res, 200, { checkout_url: session.url });
    }

    // Fallback to raw API
    const params = new URLSearchParams({
      'mode': 'subscription',
      'payment_method_types[]': 'card',
      'line_items[0][price]': STRIPE_PRICE_ID,
      'line_items[0][quantity]': '1',
      'subscription_data[trial_period_days]': String(trialDays),
      'subscription_data[metadata][firebase_uid]': uid,
      'success_url': `https://akenquest.jp/billing/success?session_id={CHECKOUT_SESSION_ID}`,
      'cancel_url': 'https://akenquest.jp/billing/cancel',
      'client_reference_id': uid,
    });
    const session = await stripeRequest('POST', '/v1/checkout/sessions', params.toString());
    json(req, res, 200, { checkout_url: session.url });
  } catch (e) {
    log('error', 'Stripe checkout failed', e.message);
    errorResponse(req, res, 500, 'Checkout creation failed');
  }
}

async function handleBillingPortal(req, res) {
  let body;
  try {
    const rawBody = await parseBody(req);
    body = safeJsonParse(rawBody);
  } catch (e) {
    return errorResponse(req, res, 413, 'Request body too large');
  }

  if (!body) {
    return errorResponse(req, res, 400, 'Invalid JSON body');
  }

  const auth = await extractAuthenticatedUid(req, res, body.uid);
  if (!auth) return;

  const uid = auth.uid;
  const sub = subscriptions.get(uid);
  if (!sub?.stripe_customer_id) {
    return errorResponse(req, res, 404, 'No subscription found');
  }

  if (!STRIPE_SECRET_KEY) {
    return json(req, res, 200, { portal_url: null, dev_mode: true });
  }

  try {
    const stripe = getStripe();
    if (stripe) {
      const portal = await stripe.billingPortal.sessions.create({
        customer: sub.stripe_customer_id,
        return_url: 'https://akenquest.jp/settings',
      });
      return json(req, res, 200, { portal_url: portal.url });
    }

    // Fallback
    const params = new URLSearchParams({
      'customer': sub.stripe_customer_id,
      'return_url': 'https://akenquest.jp/settings',
    });
    const portal = await stripeRequest('POST', '/v1/billing_portal/sessions', params.toString());
    json(req, res, 200, { portal_url: portal.url });
  } catch (e) {
    log('error', 'Portal creation failed', e.message);
    errorResponse(req, res, 500, 'Portal creation failed');
  }
}

async function handleStripeWebhook(req, res) {
  let rawBody;
  try {
    rawBody = await parseBody(req, MAX_WEBHOOK_BODY_SIZE);
  } catch (e) {
    return errorResponse(req, res, 413, 'Request body too large');
  }

  const sig = req.headers['stripe-signature'];

  // ── Signature verification ──
  if (!STRIPE_WEBHOOK_SECRET) {
    log('warn', 'Webhook received but STRIPE_WEBHOOK_SECRET not configured');
    if (NODE_ENV !== 'development') {
      return errorResponse(req, res, 500, 'Webhook not configured');
    }
  }

  let event;

  if (STRIPE_WEBHOOK_SECRET) {
    if (!sig) {
      log('warn', 'Webhook missing stripe-signature header');
      return errorResponse(req, res, 400, 'Missing signature');
    }

    const stripe = getStripe();
    if (stripe) {
      // Use official Stripe SDK for signature verification (constant-time comparison)
      try {
        event = stripe.webhooks.constructEvent(rawBody, sig, STRIPE_WEBHOOK_SECRET);
      } catch (e) {
        log('warn', 'Webhook signature verification failed', e.message);
        return errorResponse(req, res, 400, 'Invalid signature');
      }
    } else {
      // Manual verification fallback with timing-safe comparison
      const elements = {};
      for (const item of sig.split(',')) {
        const eqIdx = item.indexOf('=');
        if (eqIdx > 0) {
          elements[item.slice(0, eqIdx)] = item.slice(eqIdx + 1);
        }
      }

      if (!elements.t || !elements.v1) {
        return errorResponse(req, res, 400, 'Malformed signature');
      }

      // Verify timestamp is within 5 minutes (300 seconds) to prevent replay attacks
      const timestamp = parseInt(elements.t, 10);
      const now = Math.floor(Date.now() / 1000);
      if (Math.abs(now - timestamp) > 300) {
        log('warn', 'Webhook timestamp too old', { timestamp, now });
        return errorResponse(req, res, 400, 'Timestamp expired');
      }

      const payload = `${elements.t}.${rawBody}`;
      const expected = crypto.createHmac('sha256', STRIPE_WEBHOOK_SECRET)
        .update(payload, 'utf8').digest('hex');

      // Constant-time comparison to prevent timing attacks
      const expectedBuf = Buffer.from(expected, 'hex');
      const receivedBuf = Buffer.from(elements.v1, 'hex');
      if (expectedBuf.length !== receivedBuf.length ||
          !crypto.timingSafeEqual(expectedBuf, receivedBuf)) {
        log('warn', 'Webhook signature mismatch');
        return errorResponse(req, res, 400, 'Invalid signature');
      }

      event = safeJsonParse(rawBody);
      if (!event) {
        return errorResponse(req, res, 400, 'Invalid JSON');
      }
    }
  } else {
    // Dev mode only: parse without verification
    event = safeJsonParse(rawBody);
    if (!event) {
      return errorResponse(req, res, 400, 'Invalid JSON');
    }
  }

  // ── Process webhook event ──
  const subscription = event.data?.object;
  const uid = subscription?.metadata?.firebase_uid ||
              subscription?.client_reference_id;

  if (!uid || !validateUid(uid)) {
    // Event doesn't have our metadata — acknowledge but skip
    return json(req, res, 200, { received: true });
  }

  switch (event.type) {
    case 'customer.subscription.created':
    case 'customer.subscription.updated':
      subscriptions.set(uid, {
        status: subscription.status === 'trialing' ? 'trial' : 'active',
        trial_end: subscription.trial_end
          ? new Date(subscription.trial_end * 1000).toISOString()
          : null,
        current_period_end: subscription.current_period_end
          ? new Date(subscription.current_period_end * 1000).toISOString()
          : null,
        stripe_customer_id: subscription.customer,
      });
      log('info', 'Subscription updated', { uid, status: subscription.status });
      break;

    case 'customer.subscription.deleted':
      subscriptions.set(uid, { status: 'expired' });
      log('info', 'Subscription deleted', { uid });
      break;

    case 'checkout.session.completed': {
      const sessionUid = subscription?.client_reference_id;
      if (sessionUid && validateUid(sessionUid)) {
        log('info', 'Checkout completed', { uid: sessionUid });
      }
      break;
    }

    default:
      log('info', 'Unhandled webhook event', event.type);
  }

  json(req, res, 200, { received: true });
}

async function handleClaudeProxy(req, res) {
  if (!CLAUDE_API_KEY) {
    return errorResponse(req, res, 503, 'Claude API not configured');
  }

  // ── Authentication ──
  const auth = await extractAuthenticatedUid(req, res, null);
  if (!auth) return;

  // ── Per-UID rate limit ──
  if (!rateLimiters.claudePerUid.isAllowed(auth.uid)) {
    log('warn', 'Claude per-UID rate limit exceeded', auth.uid);
    return errorResponse(req, res, 429, 'Rate limit exceeded. Try again later.');
  }

  // ── Parse and validate request ──
  let rawBody;
  try {
    rawBody = await parseBody(req);
  } catch (e) {
    return errorResponse(req, res, 413, 'Request body too large');
  }

  const requestData = safeJsonParse(rawBody);
  if (!requestData) {
    return errorResponse(req, res, 400, 'Invalid JSON body');
  }

  // Validate messages array
  if (!Array.isArray(requestData.messages) || requestData.messages.length === 0) {
    return errorResponse(req, res, 400, 'messages array required');
  }

  if (requestData.messages.length > 20) {
    return errorResponse(req, res, 400, 'Too many messages (max 20)');
  }

  for (const msg of requestData.messages) {
    if (!msg || typeof msg.role !== 'string' || typeof msg.content !== 'string') {
      return errorResponse(req, res, 400, 'Invalid message format');
    }
    if (!['user', 'assistant'].includes(msg.role)) {
      return errorResponse(req, res, 400, 'Invalid message role');
    }
    if (msg.content.length > 5000) {
      return errorResponse(req, res, 400, 'Message content too long (max 5000 chars)');
    }
  }

  // Validate system prompt if provided
  if (requestData.system !== undefined) {
    if (typeof requestData.system !== 'string' || requestData.system.length > 10000) {
      return errorResponse(req, res, 400, 'Invalid system prompt');
    }
  }

  // ── Enforce model and cost limits ──
  // Only allow approved models — prevent users from requesting expensive models
  const ALLOWED_MODELS = [
    'claude-haiku-4-5-20251001',
    'claude-3-haiku-20240307',
  ];
  const requestedModel = requestData.model || ALLOWED_MODELS[0];
  if (!ALLOWED_MODELS.includes(requestedModel)) {
    requestData.model = ALLOWED_MODELS[0]; // Force default
  } else {
    requestData.model = requestedModel;
  }

  // Enforce max tokens cap
  requestData.max_tokens = Math.min(
    Math.max(parseInt(requestData.max_tokens, 10) || 256, 1),
    512
  );

  // Strip any fields the client shouldn't control
  const sanitizedRequest = {
    model: requestData.model,
    max_tokens: requestData.max_tokens,
    messages: requestData.messages.map(m => ({
      role: m.role,
      content: m.content,
    })),
  };
  if (requestData.system) {
    sanitizedRequest.system = requestData.system;
  }

  // ── Proxy to Anthropic ──
  const postData = JSON.stringify(sanitizedRequest);

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
    timeout: 30_000,
  };

  const proxyReq = https.request(options, (proxyRes) => {
    const chunks = [];
    proxyRes.on('data', (c) => chunks.push(c));
    proxyRes.on('end', () => {
      const responseBody = Buffer.concat(chunks);

      // Don't forward Anthropic error details to client — could leak info
      if (proxyRes.statusCode !== 200) {
        log('warn', 'Claude API error', {
          status: proxyRes.statusCode,
          body: responseBody.toString().slice(0, 500),
        });
        return errorResponse(req, res, 502, 'AI service temporarily unavailable');
      }

      const headers = {
        ...securityHeaders(),
        ...corsHeaders(req),
      };
      res.writeHead(200, headers);
      res.end(responseBody);
    });
  });

  proxyReq.on('timeout', () => {
    proxyReq.destroy();
    errorResponse(req, res, 504, 'AI service timeout');
  });

  proxyReq.on('error', (e) => {
    log('error', 'Claude proxy error', e.message);
    errorResponse(req, res, 502, 'AI service unavailable');
  });

  proxyReq.write(postData);
  proxyReq.end();
}

// ── Server ───────────────────────────────────────────────────────────────────

const server = http.createServer(async (req, res) => {
  const clientIp = getClientIp(req);

  try {
    // ── HTTPS enforcement (behind nginx) ──
    if (NODE_ENV !== 'development') {
      const proto = req.headers['x-forwarded-proto'];
      if (proto && proto !== 'https') {
        return errorResponse(req, res, 403, 'HTTPS required');
      }
    }

    // ── CORS preflight ──
    if (req.method === 'OPTIONS') return cors(req, res);

    const url = new URL(req.url, `http://localhost:${PORT}`);
    const path = url.pathname;

    // ── Route matching ──

    if (path === '/health' && req.method === 'GET') {
      if (!rateLimiters.health.isAllowed(clientIp)) {
        return errorResponse(req, res, 429, 'Rate limit exceeded');
      }
      return json(req, res, 200, {
        status: 'ok',
        version: '2.0.0',
        // Don't expose configuration details
      });
    }

    if (path === '/billing/status' && req.method === 'GET') {
      if (!rateLimiters.billing.isAllowed(clientIp)) {
        return errorResponse(req, res, 429, 'Rate limit exceeded');
      }
      return handleBillingStatus(req, res);
    }

    if (path === '/billing/checkout' && req.method === 'POST') {
      if (!rateLimiters.billing.isAllowed(clientIp)) {
        return errorResponse(req, res, 429, 'Rate limit exceeded');
      }
      return handleBillingCheckout(req, res);
    }

    if (path === '/billing/portal' && req.method === 'POST') {
      if (!rateLimiters.billing.isAllowed(clientIp)) {
        return errorResponse(req, res, 429, 'Rate limit exceeded');
      }
      return handleBillingPortal(req, res);
    }

    if (path === '/billing/webhook' && req.method === 'POST') {
      // Webhooks from Stripe — no IP rate limit (Stripe retries)
      return handleStripeWebhook(req, res);
    }

    if (path === '/claude/messages' && req.method === 'POST') {
      if (!rateLimiters.claude.isAllowed(clientIp)) {
        return errorResponse(req, res, 429, 'Rate limit exceeded');
      }
      return handleClaudeProxy(req, res);
    }

    // ── 404 for unknown routes ──
    errorResponse(req, res, 404, 'Not found');

  } catch (e) {
    log('error', 'Unhandled server error', e.message);
    // Never leak stack traces
    errorResponse(req, res, 500, 'Internal server error');
  }
});

// ── Graceful shutdown ────────────────────────────────────────────────────────

function shutdown(signal) {
  log('info', `Received ${signal}, shutting down gracefully`);
  server.close(() => {
    log('info', 'Server closed');
    process.exit(0);
  });
  // Force exit after 10 seconds
  setTimeout(() => {
    log('warn', 'Forced shutdown after timeout');
    process.exit(1);
  }, 10_000).unref();
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

// Catch unhandled rejections — log but don't crash
process.on('unhandledRejection', (reason) => {
  log('error', 'Unhandled promise rejection', String(reason));
});

server.listen(PORT, () => {
  log('info', 'Server started', {
    port: PORT,
    env: NODE_ENV,
    stripe: STRIPE_SECRET_KEY ? 'configured' : 'DEV_MODE',
    claude: CLAUDE_API_KEY ? 'configured' : 'NOT_SET',
    firebase: FIREBASE_PROJECT_ID ? 'configured' : 'NOT_SET',
    origins: ALLOWED_ORIGINS,
  });
});

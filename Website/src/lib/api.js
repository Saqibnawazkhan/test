// Thin API client for the FastAPI backend — mirrors the Flutter app's Api class.
const BASE = (import.meta.env.VITE_API_URL || 'http://localhost:8000').replace(/\/$/, '')

function qs(params) {
  const p = Object.entries(params || {}).filter(([, v]) => v !== undefined && v !== null && v !== '')
  return p.length ? '?' + p.map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`).join('&') : ''
}

async function get(path, params) {
  const res = await fetch(BASE + path + qs(params))
  if (!res.ok) throw new Error(`GET ${path} → ${res.status}`)
  return res.json()
}
async function post(path, body, params) {
  const res = await fetch(BASE + path + qs(params), {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: body === undefined ? null : JSON.stringify(body),
  })
  if (res.status >= 300) throw new Error(`POST ${path} → ${res.status}`)
  return res.json()
}

export const API_BASE = BASE

export const api = {
  // ---- core ----
  health: () => get('/health'),
  stats: () => get('/stats'),
  analytics: () => get('/analytics'),
  erMetrics: () => get('/er-metrics'),
  districts: () => get('/districts'),
  leaderboard: (limit = 20) => get('/leaderboard', { limit }),
  search: (q) => get('/search', { q }),
  network: (limit = 35) => get('/network', { limit }),

  // ---- people ----
  persons: ({ zone, district, q, sort, limit = 50, offset = 0 } = {}) =>
    get('/persons', { zone, district, q, sort, limit, offset }),
  person: (cnic) => get(`/person/${cnic}`),
  explain: (cnic) => get(`/person/${cnic}/explain`),
  graph: (cnic) => get(`/person/${cnic}/graph`),
  riskFactors: (cnic) => get(`/person/${cnic}/risk-factors`),
  family: (cnic) => get(`/person/${cnic}/family`),
  createPerson: (body) => post('/persons', body),
  updateProfile: (cnic, fields) => post(`/persons/${cnic}/profile`, fields),
  correct: (cnic, field, value) => post(`/persons/${cnic}/correct`, { field, value }),

  // ---- correction requests / inbox ----
  requests: ({ status, cnic } = {}) => get('/requests', { status, cnic }),
  createRequest: (cnic, field, current_value, requested_value, reason) =>
    post('/requests', { cnic, field, current_value, requested_value, reason }),
  resolveRequest: (id, decision) => post(`/requests/${id}/resolve`, undefined, { decision }),
  approveDeclaration: (cnic, asset_type, description, value, details = {}, decl_id = 0) =>
    post('/declarations/approve', { cnic, asset_type, description, value, details, decl_id }),
  approveExplanation: (cnic, asset_value, expl_id = 0) =>
    post('/explanations/approve', { cnic, asset_value, expl_id }),

  // ---- POS ----
  posBusinesses: (q = '') => get('/pos/businesses', q ? { q } : undefined),
  posVerify: (cnic) => get(`/pos/verify/${cnic}`),

  // ---- tax calculator ----
  calculateTax: (income, year, kind) => get('/tax/calculate', { income, year, kind }),

  // ---- AI chat (grounded Claude) ----
  chat: (messages, mode = 'user', cnic = '') => post('/chat', { messages, mode, cnic }),

  // ---- payments (Zindigi) ----
  payInitiate: (cnic, amount, { name = '', email = '', mobile = '' } = {}) =>
    post('/payments/initiate', { cnic, amount, name, email, mobile }),
  payments: (cnic) => get('/payments', cnic ? { cnic } : undefined),
  receiptUrl: (psid) => `${BASE}/payments/${psid}/receipt`,

  // ---- email ----
  emailNotice: (cnic) => post(`/person/${cnic}/email-notice`, {}),
  broadcastEmail: (title, body) => post('/broadcast/email', { title, body }),

  // ---- downloadable PDFs ----
  auditReportUrl: (cnic) => `${BASE}/person/${cnic}/audit-report`,
  noticeUrl: (cnic) => `${BASE}/person/${cnic}/notice-pdf`,
}

// Currency helper (Rs, grouped) — matches the app's `rs()`.
export function rs(v) {
  const n = Number(v || 0)
  if (n >= 1e12) return `Rs ${(n / 1e12).toFixed(2)}T`
  if (n >= 1e7) return `Rs ${(n / 1e7).toFixed(2)} Cr`
  if (n >= 1e5) return `Rs ${(n / 1e5).toFixed(2)} L`
  return 'Rs ' + n.toLocaleString('en-PK')
}

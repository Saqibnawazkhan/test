import { createClient } from '@supabase/supabase-js'

// SAME Supabase project as the mobile app — so the dashboard and the app share state.
const URL = import.meta.env.VITE_SUPABASE_URL || 'https://zfzluirxexbefunbuyxf.supabase.co'
const ANON = import.meta.env.VITE_SUPABASE_ANON_KEY || 'sb_publishable_XxYRB6G6fs2nj46550hloA_-aH8Xm85'

export const supabase = createClient(URL, ANON)

// ---- notifications ----
export const notify = (recipient, { audience = 'citizen', title, body = '', kind = 'info', refId } = {}) =>
  supabase.from('notifications').insert({ recipient, audience, title, body, kind, ...(refId ? { ref_id: refId } : {}) })

export const announce = (title, body) =>
  notify('all', { audience: 'all', title, body, kind: 'announcement' })

export async function listNotifications(recipient) {
  const { data } = await supabase.from('notifications').select('*').order('created_at', { ascending: false }).limit(100)
  return (data || []).filter((n) => n.recipient === recipient || n.audience === 'all')
}
export const markRead = (id) => supabase.from('notifications').update({ read: true }).eq('id', id)

// realtime subscription helper — calls cb() whenever a table changes
export function onTable(table, cb) {
  const ch = supabase.channel(`rt_${table}_${Math.random().toString(36).slice(2)}`)
    .on('postgres_changes', { event: '*', schema: 'public', table }, cb)
    .subscribe()
  return () => supabase.removeChannel(ch)
}

// ---- accounts (demo auth) ----
export async function login(cnic, password) {
  const { data } = await supabase.from('accounts').select('*').eq('cnic', cnic).eq('password', password).maybeSingle()
  return data
}
export async function signUp({ cnic, name, password }) {
  const { data: ex } = await supabase.from('accounts').select('id').eq('cnic', cnic).maybeSingle()
  if (ex) return 'An account with this CNIC already exists. Please sign in.'
  await supabase.from('accounts').insert({ cnic, name, password, role: 'citizen' })
  return null
}

// ---- correction requests ----
export async function createRequest({ cnic, name, field, current = '', requested, reason = '', proofUrl }) {
  const { data } = await supabase.from('correction_requests').insert({ cnic, name, field, current_value: current, requested_value: requested, reason, proof_url: proofUrl }).select('id').single()
  await notify('admin', { audience: 'admin', kind: 'request', title: 'Correction request', body: `${name || cnic} → change "${field}"`, refId: data?.id })
}
export async function resolveRequest(id, cnic, name, decision) {
  await supabase.from('correction_requests').update({ status: decision }).eq('id', id)
  await notify(cnic, { kind: decision.toLowerCase(), title: `Correction ${decision}`, body: `Your correction request was ${decision} by FBR.`, refId: id })
}
export const listRequests = (cnic) => listTable('correction_requests', cnic)

// ---- asset declarations ----
export async function declareAsset({ cnic, name, assetType, description = '', value, proofUrl, details }) {
  const { data } = await supabase.from('asset_declarations').insert({ cnic, name, asset_type: assetType, description, value, proof_url: proofUrl, details }).select('id').single()
  await notify('admin', { audience: 'admin', kind: 'request', title: 'Asset declaration', body: `${name || cnic} declared a ${assetType}`, refId: data?.id })
}
export async function resolveDeclaration(id, cnic, name, decision) {
  await supabase.from('asset_declarations').update({ status: decision }).eq('id', id)
  await notify(cnic, { kind: decision.toLowerCase(), title: `Declaration ${decision}`, body: `Your asset declaration was ${decision}.`, refId: id })
}
export const listDeclarations = (cnic) => listTable('asset_declarations', cnic)

// ---- asset explanations ----
export async function explainAsset({ cnic, name, assetType, assetLabel, assetValue, source, taxPaid = false, remarks = '', proofUrl }) {
  const { data } = await supabase.from('asset_explanations').insert({ cnic, name, asset_type: assetType, asset_label: assetLabel, asset_value: assetValue, source, tax_paid: taxPaid, remarks, proof_url: proofUrl }).select('id').single()
  await notify('admin', { audience: 'admin', kind: 'request', title: 'Asset explanation', body: `${name || cnic} explained: ${assetLabel} (${source})`, refId: data?.id })
}
export async function resolveExplanation(id, cnic, name, decision) {
  await supabase.from('asset_explanations').update({ status: decision }).eq('id', id)
  await notify(cnic, { kind: decision.toLowerCase(), title: `Explanation ${decision}`,
    body: decision === 'Accepted' ? 'FBR accepted your asset explanation. The asset is marked Explained.' : 'FBR did not accept your asset explanation.', refId: id })
}
export const listExplanations = (cnic) => listTable('asset_explanations', cnic)

// ---- issue reports ----
export async function reportIssue({ cnic, name, category, description = '', proofUrl }) {
  const { data } = await supabase.from('issue_reports').insert({ cnic, name, category, description, proof_url: proofUrl }).select('id').single()
  await notify('admin', { audience: 'admin', kind: 'request', title: 'Issue reported', body: `${name || cnic}: ${category}`, refId: data?.id })
}
export async function resolveIssue(id, cnic, name, decision) {
  await supabase.from('issue_reports').update({ status: decision }).eq('id', id)
  await notify(cnic, { kind: decision === 'Resolved' ? 'approved' : 'rejected', title: `Issue ${decision}`, body: `Your reported issue was ${decision} by FBR.`, refId: id })
}
export const listIssues = (cnic) => listTable('issue_reports', cnic)

// ---- payments (Supabase mirror for realtime history) ----
export async function recordPayment({ cnic, name, amount, psid, status = 'Paid', method = 'card' }) {
  try { await supabase.from('payments').insert({ cnic, name, amount, method, status, reference: psid }) } catch { /* best effort */ }
  await notify(cnic, { kind: 'payment', title: 'Tax payment received', body: `PKR ${Math.round(amount)} paid to FBR${psid ? ` (PSID ${psid})` : ''}.` })
  await notify('admin', { audience: 'admin', kind: 'payment', title: 'Tax payment received', body: `${name || cnic} paid PKR ${Math.round(amount)}.` })
}
export const listPayments = (cnic) => listTable('payments', cnic)

// ---- storage (proof uploads) ----
export async function uploadProof(filename, file) {
  const path = `${Date.now()}_${filename}`
  const { error } = await supabase.storage.from('proofs').upload(path, file)
  if (error) throw error
  return supabase.storage.from('proofs').getPublicUrl(path).data.publicUrl
}

async function listTable(table, cnic) {
  let q = supabase.from(table).select('*').order('created_at', { ascending: false })
  if (cnic) q = q.eq('cnic', cnic)
  const { data } = await q
  return data || []
}

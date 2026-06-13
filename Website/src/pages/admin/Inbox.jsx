import { useEffect, useState } from 'react'
import { api, rs } from '../../lib/api.js'
import * as sb from '../../lib/supabase.js'
import { I } from '../../components/Icons.jsx'
import { PageHead, Card, Tag, Loading } from '../../components/ui.jsx'

const TABS = [
  { id: 'declarations', label: 'Declarations', icon: 'layers' },
  { id: 'explanations', label: 'Explanations', icon: 'doc' },
  { id: 'corrections', label: 'Corrections', icon: 'edit' },
  { id: 'issues', label: 'Issues', icon: 'flag' },
]

export default function Inbox() {
  const [tab, setTab] = useState('declarations')
  const [data, setData] = useState({})
  const [loading, setLoading] = useState(true)
  const [busy, setBusy] = useState(null)

  async function load() {
    setLoading(true)
    const [declarations, explanations, corrections, issues] = await Promise.all([
      sb.listDeclarations(), sb.listExplanations(), sb.listRequests(), sb.listIssues(),
    ])
    setData({ declarations, explanations, corrections, issues })
    setLoading(false)
  }
  useEffect(() => {
    load()
    const offs = ['asset_declarations', 'asset_explanations', 'correction_requests', 'issue_reports'].map((t) => sb.onTable(t, load))
    return () => offs.forEach((o) => o())
  }, [])

  const pending = (list) => (list || []).filter((x) => !x.status || x.status === 'Pending')
  const count = (id) => pending(data[id]).length

  async function act(kind, row, decision) {
    setBusy(row.id)
    try {
      if (kind === 'declarations') {
        if (decision === 'Approved') await api.approveDeclaration(row.cnic, row.asset_type, row.description || '', Number(row.value || 0), row.details || {}, row.id)
        await sb.resolveDeclaration(row.id, row.cnic, row.name, decision)
      } else if (kind === 'explanations') {
        if (decision === 'Accepted') await api.approveExplanation(row.cnic, Number(row.asset_value || 0), row.id)
        await sb.resolveExplanation(row.id, row.cnic, row.name, decision)
      } else if (kind === 'corrections') {
        if (decision === 'Approved') await api.correct(row.cnic, row.field, row.requested_value)
        await sb.resolveRequest(row.id, row.cnic, row.name, decision)
      } else if (kind === 'issues') {
        await sb.resolveIssue(row.id, row.cnic, row.name, decision)
      }
      await load()
    } catch (e) { alert('Action failed: ' + (e.message || e)) } finally { setBusy(null) }
  }

  return (
    <div className="page">
      <PageHead eyebrow="Shared with the mobile app · Live" title="Citizen Inbox"
        desc="Declarations, explanations, corrections and issue reports submitted by citizens — approve to update the graph and score." />

      <div className="tabs" style={{ width: 'fit-content', marginBottom: 18 }}>
        {TABS.map((t) => (
          <button key={t.id} className={`tab ${tab === t.id ? 'active' : ''}`} onClick={() => setTab(t.id)}>
            {t.label}{count(t.id) > 0 && <span className="nav-badge" style={{ marginLeft: 8 }}>{count(t.id)}</span>}
          </button>
        ))}
      </div>

      {loading ? <Loading /> : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {(data[tab] || []).length === 0 && <Card style={{ textAlign: 'center', color: 'var(--text-3)', padding: 40 }}>Nothing here yet.</Card>}
          {(data[tab] || []).map((row) => <Row key={row.id} kind={tab} row={row} onAct={act} busy={busy === row.id} />)}
        </div>
      )}
    </div>
  )
}

function Row({ kind, row, onAct, busy }) {
  const resolved = row.status && row.status !== 'Pending'
  const title = kind === 'declarations' ? `${row.asset_type} declaration`
    : kind === 'explanations' ? `Explains: ${row.asset_label}`
      : kind === 'corrections' ? `Change "${row.field}"`
        : row.category
  const detail = kind === 'declarations' ? `${row.description || ''}${row.value ? ' · ' + rs(row.value) : ''}`
    : kind === 'explanations' ? `Source: ${row.source}${row.asset_value ? ' · ' + rs(row.asset_value) : ''}${row.tax_paid ? ' · tax paid' : ''}`
      : kind === 'corrections' ? `${row.current_value || '—'} → ${row.requested_value}`
        : (row.description || '')
  const pos = kind === 'explanations' ? 'Accepted' : kind === 'issues' ? 'Resolved' : 'Approved'
  const neg = kind === 'explanations' ? 'Rejected' : kind === 'issues' ? 'Dismissed' : 'Rejected'

  return (
    <Card className="row" style={{ gap: 14, alignItems: 'flex-start' }}>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div className="row" style={{ gap: 8 }}><span style={{ fontSize: 14, fontWeight: 600 }}>{title}</span>{resolved && <Tag sev={/Approv|Accept|Resolv/.test(row.status) ? 'low' : 'critical'}>{row.status}</Tag>}</div>
        <div style={{ fontSize: 12.5, color: 'var(--text-2)', marginTop: 4 }}>{detail}</div>
        <div className="mono" style={{ fontSize: 10.5, color: 'var(--text-3)', marginTop: 6 }}>{row.name || row.cnic} · {row.cnic}{row.remarks ? ` · "${row.remarks}"` : ''}{row.reason ? ` · "${row.reason}"` : ''}</div>
        {row.proof_url && <a className="mono" style={{ fontSize: 11, color: 'var(--blue)' }} href={row.proof_url} target="_blank" rel="noreferrer">{I('download', { style: { width: 12, height: 12 } })} View proof</a>}
      </div>
      {!resolved && (
        <div className="row" style={{ gap: 8, flex: 'none' }}>
          <button className="btn btn-primary" disabled={busy} onClick={() => onAct(kind, row, pos)} style={{ padding: '8px 12px' }}>{I('check')} {pos}</button>
          <button className="btn btn-ghost" disabled={busy} onClick={() => onAct(kind, row, neg)} style={{ padding: '8px 12px' }}>{neg}</button>
        </div>
      )}
    </Card>
  )
}

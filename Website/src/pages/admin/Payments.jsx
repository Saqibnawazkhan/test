import { useEffect, useState } from 'react'
import { api, rs } from '../../lib/api.js'
import { onTable } from '../../lib/supabase.js'
import { I } from '../../components/Icons.jsx'
import { PageHead, Card, Tag, Stat, Loading, ErrorBox } from '../../components/ui.jsx'

export default function Payments() {
  const [rows, setRows] = useState(null)
  const [err, setErr] = useState('')

  async function load() { setErr(''); try { const r = await api.payments(); setRows(r.results || []) } catch (e) { setErr(String(e.message || e)) } }
  useEffect(() => {
    load()
    const off = onTable('payments', load) // realtime: a citizen pays → appears here instantly
    return off
  }, [])

  if (err) return <div className="page"><ErrorBox msg={err} onRetry={load} /></div>
  if (!rows) return <div className="page"><Loading label="Loading tax payments…" /></div>

  const total = rows.reduce((n, r) => n + Number(r.amount || 0), 0)
  const paid = rows.filter((r) => (r.status || 'Paid') === 'Paid').length

  return (
    <div className="page">
      <PageHead eyebrow="Collections · Live" title="Tax Payments"
        desc="Every tax payment made through the citizen portal (Zindigi IPG) — updates in real time." />
      <div className="kpi-grid" style={{ marginBottom: 18 }}>
        <Stat icon="wallet" color="var(--green)" value={rs(total)} label="Total collected" />
        <Stat icon="check" color="var(--blue)" value={paid} label="Successful payments" />
        <Stat icon="receipt" color="var(--violet)" value={rows.length} label="Transactions" />
      </div>
      <Card style={{ padding: 0, overflow: 'hidden' }}>
        <table className="tbl">
          <thead><tr><th>Taxpayer</th><th>PSID / Ref</th><th>Amount</th><th>Status</th><th>Date</th><th></th></tr></thead>
          <tbody>
            {rows.map((r, i) => (
              <tr key={i} style={{ cursor: 'default' }}>
                <td><div style={{ color: 'var(--text)', fontWeight: 500 }}>{r.name || '—'}</div><div className="mono" style={{ fontSize: 10.5, color: 'var(--text-3)' }}>{r.cnic}</div></td>
                <td className="mono" style={{ fontSize: 11 }}>{r.psid || r.reference || '—'}</td>
                <td className="mono" style={{ color: 'var(--green)' }}>{rs(r.amount)}</td>
                <td><Tag sev={(r.status || 'Paid') === 'Paid' ? 'low' : 'high'}>{r.status || 'Paid'}</Tag></td>
                <td className="mono" style={{ fontSize: 11, color: 'var(--text-3)' }}>{(r.created_at || '').slice(0, 16).replace('T', ' ')}</td>
                <td>{r.psid && <a className="btn btn-ghost" style={{ padding: '5px 10px', fontSize: 11 }} href={api.receiptUrl(r.psid)} target="_blank" rel="noreferrer">{I('download')} Receipt</a>}</td>
              </tr>
            ))}
            {!rows.length && <tr><td colSpan={6} style={{ textAlign: 'center', padding: 40, color: 'var(--text-3)' }}>No payments yet.</td></tr>}
          </tbody>
        </table>
      </Card>
    </div>
  )
}

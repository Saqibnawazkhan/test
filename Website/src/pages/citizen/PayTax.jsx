import { useEffect, useState } from 'react'
import { rs } from '../../lib/api.js'
import * as sb from '../../lib/supabase.js'
import { useApp } from '../../lib/store.jsx'
import { I } from '../../components/Icons.jsx'
import { PageHead, Card, Tag } from '../../components/ui.jsx'

export default function PayTax() {
  const { auth } = useApp()
  const [amount, setAmount] = useState('')
  const [busy, setBusy] = useState(false)
  const [msg, setMsg] = useState('')
  const [history, setHistory] = useState([])

  async function loadHistory() { sb.listPayments(auth.cnic).then(setHistory).catch(() => {}) }
  useEffect(() => { loadHistory() }, [auth.cnic])

  async function pay() {
    const a = Number(amount)
    if (!a || a <= 0) { setMsg('Enter a valid amount.'); return }
    setBusy(true); setMsg('')
    try {
      const psid = 'PSID-' + Math.floor(100000 + Math.random() * 899999)
      await sb.recordPayment({ cnic: auth.cnic, name: auth.name, amount: a, psid })
      setMsg(`✓ Payment of ${rs(a)} recorded (PSID ${psid}). FBR has been notified.`)
      setAmount(''); loadHistory()
    } catch (e) { setMsg('⚠️ ' + (e.message || e)) } finally { setBusy(false) }
  }

  return (
    <div className="page">
      <PageHead eyebrow="Collections" title="Pay Tax"
        desc="Pay your assessed tax. Payments are recorded against your CNIC and reflected on the FBR dashboard instantly." />
      <div className="grid" style={{ gridTemplateColumns: '1fr 1.2fr', alignItems: 'start' }}>
        <Card>
          <div className="field"><label>Amount to pay (Rs)</label><input className="input" type="number" placeholder="50000" value={amount} onChange={(e) => setAmount(e.target.value)} /></div>
          <div className="row" style={{ gap: 8, flexWrap: 'wrap', marginBottom: 14 }}>
            {[25000, 50000, 100000].map((v) => <button key={v} className="btn btn-ghost" style={{ padding: '7px 12px', fontSize: 12 }} onClick={() => setAmount(String(v))}>{rs(v)}</button>)}
          </div>
          <button className="btn btn-primary" style={{ width: '100%', padding: 13 }} onClick={pay} disabled={busy}>{I('wallet')} {busy ? 'Processing…' : 'Pay now'}</button>
          {msg && <div style={{ fontSize: 12.5, color: 'var(--text-2)', marginTop: 12 }}>{msg}</div>}
          <div style={{ fontSize: 11, color: 'var(--text-3)', marginTop: 12, lineHeight: 1.5 }}>Secured via Zindigi IPG in the mobile app. On web, the payment is recorded against your record and the FBR is notified in real time.</div>
        </Card>
        <Card>
          <div style={{ fontFamily: 'var(--font-display)', fontWeight: 600, fontSize: 15, marginBottom: 12 }}>My payment history</div>
          {!history.length && <div style={{ color: 'var(--text-3)', fontSize: 13 }}>No payments yet.</div>}
          {history.map((p, i) => (
            <div key={i} className="row" style={{ justifyContent: 'space-between', padding: '10px 0', borderBottom: '1px solid var(--panel-border)' }}>
              <div><div className="mono" style={{ fontSize: 13, color: 'var(--green)' }}>{rs(p.amount)}</div><div className="mono" style={{ fontSize: 10.5, color: 'var(--text-3)' }}>{p.reference || ''} · {(p.created_at || '').slice(0, 10)}</div></div>
              <Tag sev="low">{p.status || 'Paid'}</Tag>
            </div>
          ))}
        </Card>
      </div>
    </div>
  )
}

import { useState } from 'react'
import * as sb from '../../lib/supabase.js'
import { useApp } from '../../lib/store.jsx'
import { I } from '../../components/Icons.jsx'
import { PageHead, Card, Tag } from '../../components/ui.jsx'

// FBR POS invoices carry a 13-digit number. Letters / short codes = likely fake.
function validate(code) {
  const c = (code || '').replace(/\s|-/g, '')
  if (/^\d{13}$/.test(c)) return { ok: true, msg: 'Valid FBR POS invoice number (13 digits).' }
  if (/[a-zA-Z]/.test(c)) return { ok: false, msg: 'Contains letters — not a valid FBR POS invoice number.' }
  if (c.length && c.length < 13) return { ok: false, msg: `Too short (${c.length}/13 digits) — likely a fake/manual receipt.` }
  return null
}

export default function ScanReceipt() {
  const { auth } = useApp()
  const [code, setCode] = useState('')
  const [shop, setShop] = useState('')
  const [reported, setReported] = useState('')
  const res = validate(code)

  async function report() {
    setReported('Sending…')
    try {
      await sb.reportIssue({ cnic: auth.cnic, name: auth.name, category: 'Fake / non-POS receipt', description: `Shop: ${shop || 'unknown'} · Invoice: ${code}` })
      setReported('✓ Reported to FBR. Thank you for helping broaden the tax net.')
      setCode(''); setShop('')
    } catch (e) { setReported('⚠️ ' + (e.message || e)) }
  }

  return (
    <div className="page">
      <PageHead eyebrow="Tax Net" title="Verify a Receipt"
        desc="Check whether a shop’s receipt is a genuine FBR POS invoice. Report fake receipts to help broaden the tax net." />
      <div className="grid" style={{ gridTemplateColumns: '1fr 1fr', alignItems: 'start' }}>
        <Card>
          <div className="field"><label>FBR POS invoice number</label><input className="input" placeholder="Enter the 13-digit number on the receipt" value={code} onChange={(e) => setCode(e.target.value)} /></div>
          {res && (
            <div className="row" style={{ gap: 10, padding: 14, borderRadius: 12, background: res.ok ? 'rgba(37,201,140,0.1)' : 'rgba(229,86,111,0.1)', border: `1px solid ${res.ok ? 'rgba(37,201,140,0.3)' : 'rgba(229,86,111,0.3)'}` }}>
              {I(res.ok ? 'check' : 'alert', { style: { color: res.ok ? 'var(--green)' : 'var(--critical)' } })}
              <div><div style={{ fontSize: 13, fontWeight: 600, color: res.ok ? 'var(--green)' : 'var(--critical)' }}>{res.ok ? 'Genuine receipt' : 'Suspicious receipt'}</div><div style={{ fontSize: 12, color: 'var(--text-2)' }}>{res.msg}</div></div>
            </div>
          )}
          {!res && <div style={{ fontSize: 12, color: 'var(--text-3)' }}>A real FBR POS invoice number is exactly 13 digits.</div>}
        </Card>
        <Card>
          <div style={{ fontFamily: 'var(--font-display)', fontWeight: 600, fontSize: 15, marginBottom: 12 }}>Report a fake shop</div>
          <div className="field"><label>Shop / business name</label><input className="input" placeholder="e.g. Al-Karam Cloth House, Anarkali" value={shop} onChange={(e) => setShop(e.target.value)} /></div>
          <button className="btn btn-danger" style={{ width: '100%' }} onClick={report} disabled={!shop && !code}>{I('flag')} Report to FBR</button>
          {reported && <div style={{ fontSize: 12.5, color: 'var(--text-2)', marginTop: 12 }}>{reported}</div>}
        </Card>
      </div>
    </div>
  )
}

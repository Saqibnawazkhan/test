import { useState } from 'react'
import { api, rs } from '../../lib/api.js'
import { I } from '../../components/Icons.jsx'
import { PageHead, Card, Loading } from '../../components/ui.jsx'

export default function TaxCalculator() {
  const [income, setIncome] = useState('1200000')
  const [year, setYear] = useState('2025-26')
  const [kind, setKind] = useState('salaried')
  const [res, setRes] = useState(null)
  const [busy, setBusy] = useState(false)
  const [err, setErr] = useState('')

  async function calc() {
    const inc = Number(income)
    if (!inc || inc < 0) { setErr('Enter a valid annual income.'); return }
    setBusy(true); setErr('')
    try { setRes(await api.calculateTax(inc, year, kind)) } catch (e) { setErr(String(e.message || e)) } finally { setBusy(false) }
  }

  return (
    <div className="page">
      <PageHead eyebrow="FBR · Deterministic" title="Income Tax Calculator"
        desc="Verified FBR slabs for FY 2024-25 and 2025-26 — salaried and business individuals. No estimates, no AI." />

      <div className="grid" style={{ gridTemplateColumns: '1fr 1.2fr', alignItems: 'start' }}>
        <Card>
          <div className="field"><label>Annual income (Rs)</label>
            <input className="input" type="number" value={income} onChange={(e) => setIncome(e.target.value)} placeholder="1200000" /></div>
          <div className="field"><label>Tax year</label>
            <select className="select" value={year} onChange={(e) => setYear(e.target.value)}><option value="2025-26">FY 2025-26</option><option value="2024-25">FY 2024-25</option></select></div>
          <div className="field"><label>Taxpayer type</label>
            <select className="select" value={kind} onChange={(e) => setKind(e.target.value)}><option value="salaried">Salaried individual</option><option value="business">Business / AOP individual</option></select></div>
          {err && <div style={{ color: 'var(--critical)', fontSize: 12.5, marginBottom: 10 }}>{err}</div>}
          <button className="btn btn-primary" style={{ width: '100%', padding: 13 }} onClick={calc} disabled={busy}>{I('calc')} {busy ? 'Calculating…' : 'Calculate Tax'}</button>
        </Card>

        <Card>
          {busy ? <Loading /> : !res ? (
            <div style={{ display: 'grid', placeItems: 'center', padding: 40, textAlign: 'center', color: 'var(--text-3)' }}>
              <div className="kpi-ic" style={{ color: 'var(--green)', background: 'rgba(37,201,140,0.12)', width: 50, height: 50, marginBottom: 12 }}>{I('calc')}</div>
              Enter your income to see the FBR breakdown.
            </div>
          ) : (
            <div>
              <div className="row" style={{ justifyContent: 'space-between', alignItems: 'flex-end', marginBottom: 14 }}>
                <div><div style={{ fontSize: 12, color: 'var(--text-3)' }}>Total annual tax</div>
                  <div style={{ fontFamily: 'var(--font-display)', fontSize: 32, fontWeight: 700, color: 'var(--critical)' }}>{rs(res.total_tax)}</div></div>
                <div className="tag tag-info">{res.effective_rate}% effective</div>
              </div>
              <KV k="Income tax (slabs)" v={rs(res.tax)} />
              {!!res.surcharge && <KV k={`Surcharge (${res.surcharge_rate}%)`} v={rs(res.surcharge)} />}
              <KV k="Monthly tax" v={rs(res.monthly_tax)} />
              <KV k="Marginal rate" v={`${res.marginal_rate}%`} />
              <div className="divider" />
              <KV k="Take-home (annual)" v={rs(res.take_home_annual)} good />
              <KV k="Take-home (monthly)" v={rs(res.take_home_monthly)} good />
              {Array.isArray(res.brackets) && res.brackets.length > 0 && (
                <>
                  <div style={{ fontSize: 12, color: 'var(--text-3)', margin: '16px 0 8px' }}>Slab-by-slab</div>
                  {res.brackets.map((b, i) => (
                    <div key={i} className="row" style={{ justifyContent: 'space-between', fontSize: 12, padding: '4px 0', color: 'var(--text-2)' }}>
                      <span className="mono">{b.label || b.range || `Slab ${i + 1}`}</span><span className="mono">{rs(b.tax ?? b.amount)}</span>
                    </div>
                  ))}
                </>
              )}
            </div>
          )}
        </Card>
      </div>
    </div>
  )
}

const KV = ({ k, v, good }) => <div className="row" style={{ justifyContent: 'space-between', padding: '7px 0', borderBottom: '1px solid var(--panel-border)' }}><span style={{ fontSize: 12.5, color: 'var(--text-2)' }}>{k}</span><span className="mono" style={{ fontSize: 13, color: good ? 'var(--green)' : 'var(--text)' }}>{v}</span></div>

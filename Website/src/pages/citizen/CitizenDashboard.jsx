import { useEffect, useState } from 'react'
import { api, rs } from '../../lib/api.js'
import { useApp } from '../../lib/store.jsx'
import { I } from '../../components/Icons.jsx'
import { PageHead, Card, Tag, Loading, ErrorBox, zoneSev, zoneColor } from '../../components/ui.jsx'

export default function CitizenDashboard({ go }) {
  const { auth } = useApp()
  const [d, setD] = useState(null)
  const [err, setErr] = useState('')

  async function load() { setErr(''); try { setD(await api.person(auth.cnic)) } catch (e) { setErr(String(e.message || e)) } }
  useEffect(() => { load() }, [auth.cnic])

  if (err) return <div className="page"><ErrorBox msg={err} onRetry={load} /></div>
  if (!d) return <div className="page"><Loading label="Loading your tax profile…" /></div>

  const id = d.identity || {}, tax = d.tax || {}, sc = d.score || {}
  const dev = Math.round(sc.deviation_score || 0)
  const zcol = zoneColor(sc.zone)
  const assetCount = Object.values(d.assets || {}).reduce((n, a) => n + (a?.length || 0), 0)
  const compliant = sc.zone === 'Green'

  return (
    <div className="page">
      <PageHead eyebrow={`Assalam-o-Alaikum, ${(id.name || '').split(' ')[0]}`} title="My Tax Standing"
        desc="Your compliance score is computed from your declared income versus the assets linked to your CNIC." />

      <div className="grid" style={{ gridTemplateColumns: '1.1fr 1fr', alignItems: 'stretch' }}>
        <Card style={{ background: `linear-gradient(135deg, color-mix(in srgb, ${zcol} 16%, transparent), var(--panel))` }}>
          <div className="row" style={{ gap: 22 }}>
            <BigRing value={dev} color={zcol} />
            <div>
              <Tag sev={zoneSev(sc.zone)}>{sc.zone || 'N/A'} Zone</Tag>
              <div style={{ fontFamily: 'var(--font-display)', fontSize: 19, fontWeight: 600, marginTop: 10 }}>
                {compliant ? 'You look compliant ✓' : 'Review recommended'}
              </div>
              <div style={{ fontSize: 12.5, color: 'var(--text-2)', marginTop: 6, lineHeight: 1.5, maxWidth: 260 }}>
                {compliant ? 'Your declared income is consistent with your assets. Keep filing on time.'
                  : 'Your lifestyle signals exceed your declared income. Declare or explain assets to improve your score.'}
              </div>
              {tax.filer_status === 'Filer' ? <Tag sev="low" icon="check">Active Filer</Tag> : <span style={{ display: 'inline-block', marginTop: 10 }}><Tag sev="high">Non-Filer</Tag></span>}
            </div>
          </div>
        </Card>

        <div className="grid" style={{ gridTemplateColumns: '1fr 1fr', alignItems: 'start' }}>
          <Mini icon="doc" color="var(--blue)" v={tax.declared_income != null ? rs(tax.declared_income) : '—'} l="Declared income" />
          <Mini icon="layers" color="var(--violet)" v={assetCount} l="Linked assets" />
          <Mini icon="wallet" color="var(--green)" v={rs(tax.tax_paid)} l="Tax paid" />
          <Mini icon="eye" color="var(--high)" v={rs((sc.own_assets || 0) + (sc.hidden_assets || 0))} l="Assets value" />
        </div>
      </div>

      <div className="row" style={{ gap: 12, marginTop: 18, flexWrap: 'wrap' }}>
        <button className="btn btn-primary" style={{ padding: '13px 20px' }} onClick={() => go('pay')}>{I('wallet')} Pay Tax Now</button>
        <button className="btn btn-ghost" style={{ padding: '13px 20px' }} onClick={() => go('calculator')}>{I('calc')} Estimate My Tax</button>
        <button className="btn btn-ghost" style={{ padding: '13px 20px' }} onClick={() => go('assets')}>{I('layers')} View My Assets</button>
      </div>

      <Card style={{ marginTop: 18 }}>
        <div style={{ fontFamily: 'var(--font-display)', fontWeight: 600, fontSize: 15, marginBottom: 12 }}>How your score was calculated</div>
        {(d.audit_trail || []).slice(0, 6).map((line, i) => (
          <div key={i} className="row" style={{ gap: 10, padding: '6px 0', alignItems: 'flex-start' }}>
            <span style={{ color: 'var(--green)', marginTop: 2 }}>{I('check', { style: { width: 15, height: 15 } })}</span>
            <span style={{ fontSize: 12.5, color: 'var(--text-2)', lineHeight: 1.5 }}>{line}</span>
          </div>
        ))}
        {!(d.audit_trail || []).length && <div style={{ color: 'var(--text-3)', fontSize: 13 }}>No findings on record — you’re in good standing.</div>}
      </Card>
    </div>
  )
}

const Mini = ({ icon, color, v, l }) => (
  <div className="card kpi">
    <div className="kpi-ic" style={{ color, background: `color-mix(in srgb, ${color} 14%, transparent)` }}>{I(icon)}</div>
    <div className="kpi-val" style={{ fontSize: 22 }}>{v}</div><div className="kpi-label">{l}</div>
  </div>
)

function BigRing({ value, color }) {
  const r = 40, c = 2 * Math.PI * r, off = c - (Math.min(100, value) / 100) * c
  return (
    <svg width="108" height="108" viewBox="0 0 108 108">
      <circle cx="54" cy="54" r={r} fill="none" stroke="var(--panel-2)" strokeWidth="9" />
      <circle cx="54" cy="54" r={r} fill="none" stroke={color} strokeWidth="9" strokeLinecap="round" strokeDasharray={c} strokeDashoffset={off} transform="rotate(-90 54 54)" />
      <text x="54" y="56" textAnchor="middle" style={{ fontFamily: 'var(--font-display)', fontSize: 30, fontWeight: 700, fill: color }}>{value}</text>
      <text x="54" y="74" textAnchor="middle" style={{ fontSize: 10, fill: 'var(--text-3)' }}>/ 100</text>
    </svg>
  )
}

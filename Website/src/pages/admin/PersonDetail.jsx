import { useEffect, useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { api, rs } from '../../lib/api.js'
import { I } from '../../components/Icons.jsx'
import { Card, Tag, Loading, ErrorBox, zoneSev, zoneColor } from '../../components/ui.jsx'

const ASSET_GROUPS = [
  { key: 'vehicles', label: 'Vehicles', icon: 'car', val: (a) => a.value, line: (a) => `${a.make || ''} ${a.model || ''} ${a.variant || ''} · ${a.engine_cc || '?'}cc · ${a.reg_number || ''}` },
  { key: 'properties', label: 'Properties', icon: 'home', val: (a) => a.market_value, line: (a) => `${a.property_type || 'Property'} · ${a.area || ''} · ${a.district || ''}` },
  { key: 'stocks', label: 'Stocks', icon: 'trend', val: (a) => a.market_value, line: (a) => `${a.scrip || ''} · ${a.shares || 0} shares` },
  { key: 'bank_accounts', label: 'Bank Accounts', icon: 'card', val: (a) => a.balance, line: (a) => `${a.bank || ''} · ${a.account_type || ''} · turnover ${rs(a.turnover)}` },
  { key: 'travel', label: 'Foreign Travel', icon: 'plane', val: (a) => a.ticket_cost, line: (a) => `${a.airline || ''} → ${a.destination || ''} · ${a.travel_date || ''}` },
  { key: 'directorships', label: 'Directorships', icon: 'entity', val: () => 0, line: (a) => `${a.name || a.ntn} · ${a.role || ''} · ${a.pct || 0}%` },
]

export default function PersonDetail() {
  const { cnic } = useParams()
  const nav = useNavigate()
  const [d, setD] = useState(null)
  const [rf, setRf] = useState([])
  const [err, setErr] = useState('')
  const [emailMsg, setEmailMsg] = useState('')

  async function load() {
    setErr('')
    try {
      const p = await api.person(cnic)
      setD(p)
      api.riskFactors(cnic).then((r) => setRf(r.factors || [])).catch(() => {})
    } catch (e) { setErr(String(e.message || e)) }
  }
  useEffect(() => { load() }, [cnic])

  if (err) return <div className="page"><ErrorBox msg={err} onRetry={load} /></div>
  if (!d) return <div className="page"><Loading label="Opening investigation file…" /></div>

  const id = d.identity || {}, tax = d.tax || {}, sc = d.score || {}
  const dev = Math.round(sc.deviation_score || 0)
  const zcol = zoneColor(sc.zone)

  async function emailNotice() {
    setEmailMsg('Sending…')
    try { const r = await api.emailNotice(cnic); setEmailMsg(r.ok || r.sent ? '✓ Notice emailed to taxpayer' : (r.error || 'Email attempted')) }
    catch (e) { setEmailMsg('⚠️ ' + (e.message || e)) }
  }

  return (
    <div className="page">
      <button className="btn btn-ghost" style={{ marginBottom: 16 }} onClick={() => nav(-1)}>← Back</button>

      <div className="grid" style={{ gridTemplateColumns: '1fr', gap: 18 }}>
        {/* Header */}
        <Card>
          <div className="row" style={{ gap: 18, flexWrap: 'wrap', justifyContent: 'space-between' }}>
            <div className="row" style={{ gap: 16 }}>
              <div style={{ width: 64, height: 64, borderRadius: 16, display: 'grid', placeItems: 'center', fontFamily: 'var(--font-display)', fontSize: 22, fontWeight: 700, color: zcol, background: `color-mix(in srgb, ${zcol} 15%, transparent)` }}>
                {(id.name || '?').split(' ').filter(Boolean).map((s) => s[0]).slice(0, 2).join('')}
              </div>
              <div>
                <div style={{ fontFamily: 'var(--font-display)', fontSize: 22, fontWeight: 600 }}>{id.name}</div>
                <div className="mono" style={{ fontSize: 12, color: 'var(--text-3)', marginTop: 3 }}>{id.cnic} · {id.district || '—'}</div>
                <div className="row" style={{ gap: 8, marginTop: 8 }}>
                  <Tag sev={zoneSev(sc.zone)}>{sc.zone || 'N/A'} Zone</Tag>
                  {tax.filer_status === 'Filer' ? <Tag sev="low">Filer</Tag> : <Tag sev="high">Non-filer</Tag>}
                </div>
              </div>
            </div>
            <div style={{ textAlign: 'center' }}>
              <Ring value={dev} color={zcol} />
              <div style={{ fontSize: 11, color: 'var(--text-3)', marginTop: 4 }}>Deviation Score</div>
            </div>
          </div>
          <div className="divider" />
          <div className="row" style={{ gap: 10, flexWrap: 'wrap' }}>
            <a className="btn btn-primary" href={api.auditReportUrl(cnic)} target="_blank" rel="noreferrer">{I('download')} Audit Report (PDF)</a>
            <a className="btn btn-ghost" href={api.noticeUrl(cnic)} target="_blank" rel="noreferrer">{I('doc')} Show-Cause Notice (PDF)</a>
            <button className="btn btn-ghost" onClick={emailNotice}>{I('send')} Email Notice</button>
            <button className="btn btn-ghost" onClick={() => nav(`/admin/family/${cnic}`)}>{I('family')} Family Network</button>
            {emailMsg && <span style={{ fontSize: 12.5, color: 'var(--text-2)', alignSelf: 'center' }}>{emailMsg}</span>}
          </div>
        </Card>

        <div className="grid" style={{ gridTemplateColumns: '1fr 1fr', alignItems: 'start' }}>
          {/* Financials */}
          <Card>
            <H>Financial Position</H>
            <KV k="Declared income" v={tax.declared_income != null ? rs(tax.declared_income) : 'No return on record'} />
            <KV k="Tax paid" v={rs(tax.tax_paid)} />
            <KV k="Own (declared) assets" v={rs(sc.own_assets)} />
            <KV k="Hidden / benami assets" v={rs(sc.hidden_assets)} crit />
            <KV k="GNN fraud probability" v={`${Math.round((sc.gnn_prob || 0) * 100)}%`} />
          </Card>

          {/* Risk factors */}
          <Card>
            <H>Factors Influencing Risk</H>
            {!rf.length && <div style={{ color: 'var(--text-2)', fontSize: 12.5 }}>Assets may be hidden via family/company — see Audit Trail.</div>}
            {rf.map((f, i) => (
              <div key={i} style={{ marginBottom: 12 }}>
                <div className="row" style={{ justifyContent: 'space-between', marginBottom: 5 }}>
                  <span style={{ fontSize: 13 }}>{f.label}</span>
                  <span className="mono" style={{ fontSize: 12, color: sevColor(f.sev) }}>{Math.round(f.weight || 0)}</span>
                </div>
                <div style={{ height: 7, borderRadius: 5, background: 'var(--panel-2)', overflow: 'hidden' }}>
                  <div style={{ height: '100%', width: `${Math.min(100, f.weight || 0)}%`, background: sevColor(f.sev) }} />
                </div>
              </div>
            ))}
          </Card>
        </div>

        {/* Assets */}
        <Card>
          <H>Assets on Record</H>
          <div className="grid" style={{ gridTemplateColumns: 'repeat(auto-fit, minmax(280px,1fr))' }}>
            {ASSET_GROUPS.map((g) => {
              const list = (d.assets?.[g.key]) || []
              if (!list.length) return null
              return (
                <div key={g.key} style={{ border: '1px solid var(--panel-border)', borderRadius: 12, padding: 14 }}>
                  <div className="row" style={{ gap: 8, marginBottom: 10, color: 'var(--text-2)' }}>{I(g.icon, { style: { width: 16, height: 16 } })}<b style={{ fontSize: 13 }}>{g.label}</b><span className="tag tag-info" style={{ marginLeft: 'auto' }}>{list.length}</span></div>
                  {list.map((a, i) => (
                    <div key={i} style={{ padding: '8px 0', borderTop: i ? '1px solid var(--panel-border)' : 'none' }}>
                      <div className="row" style={{ justifyContent: 'space-between' }}><span style={{ fontSize: 12.5 }}>{g.line(a)}</span>{!!g.val(a) && <span className="mono" style={{ fontSize: 12, color: 'var(--text)' }}>{rs(g.val(a))}</span>}</div>
                    </div>
                  ))}
                </div>
              )
            })}
          </div>
          {!ASSET_GROUPS.some((g) => (d.assets?.[g.key] || []).length) && <div style={{ color: 'var(--text-3)', fontSize: 13 }}>No assets on record.</div>}
        </Card>

        {/* Audit trail */}
        <Card>
          <H>Explainable Audit Trail</H>
          {(d.audit_trail || []).map((line, i) => (
            <div key={i} className="row" style={{ gap: 10, padding: '7px 0', alignItems: 'flex-start' }}>
              <span style={{ color: 'var(--green)', marginTop: 2 }}>{I('check', { style: { width: 15, height: 15 } })}</span>
              <span style={{ fontSize: 12.5, color: 'var(--text-2)', lineHeight: 1.5 }}>{line}</span>
            </div>
          ))}
          {!(d.audit_trail || []).length && <div style={{ color: 'var(--text-3)', fontSize: 13 }}>No audit trail recorded.</div>}
        </Card>
      </div>
    </div>
  )
}

const H = ({ children }) => <div style={{ fontFamily: 'var(--font-display)', fontWeight: 600, fontSize: 15, marginBottom: 14 }}>{children}</div>
const KV = ({ k, v, crit }) => <div className="row" style={{ justifyContent: 'space-between', padding: '7px 0', borderBottom: '1px solid var(--panel-border)' }}><span style={{ fontSize: 12.5, color: 'var(--text-2)' }}>{k}</span><span className="mono" style={{ fontSize: 13, color: crit ? 'var(--critical)' : 'var(--text)' }}>{v}</span></div>
const sevColor = (s) => s === 'critical' ? 'var(--critical)' : s === 'high' ? 'var(--high)' : s === 'med' ? 'var(--med)' : 'var(--green)'

function Ring({ value, color }) {
  const r = 26, c = 2 * Math.PI * r, off = c - (Math.min(100, value) / 100) * c
  return (
    <svg width="72" height="72" viewBox="0 0 72 72">
      <circle cx="36" cy="36" r={r} fill="none" stroke="var(--panel-2)" strokeWidth="7" />
      <circle cx="36" cy="36" r={r} fill="none" stroke={color} strokeWidth="7" strokelinecap="round" strokeDasharray={c} strokeDashoffset={off} transform="rotate(-90 36 36)" />
      <text x="36" y="41" textAnchor="middle" style={{ fontFamily: 'var(--font-display)', fontSize: 20, fontWeight: 700, fill: color }}>{value}</text>
    </svg>
  )
}

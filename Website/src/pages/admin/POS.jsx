import { useEffect, useState } from 'react'
import { api, rs } from '../../lib/api.js'
import { I } from '../../components/Icons.jsx'
import { PageHead, Card, Tag, Loading, ErrorBox, zoneSev } from '../../components/ui.jsx'

export default function POS() {
  const [biz, setBiz] = useState(null)
  const [err, setErr] = useState('')
  const [sel, setSel] = useState(null)
  const [res, setRes] = useState(null)
  const [loadingV, setLoadingV] = useState(false)

  async function load() { setErr(''); try { const r = await api.posBusinesses(''); setBiz(r.results || []) } catch (e) { setErr(String(e.message || e)) } }
  useEffect(() => { load() }, [])

  async function open(b) { setSel(b); setRes(null); setLoadingV(true); try { setRes(await api.posVerify(b.cnic)) } catch { setRes({ error: true }) } finally { setLoadingV(false) } }

  if (err) return <div className="page"><ErrorBox msg={err} onRetry={load} /></div>
  if (!biz) return <div className="page"><Loading label="Loading registered businesses…" /></div>

  return (
    <div className="page">
      <PageHead eyebrow="Tax Net · Live" title="POS Verification"
        desc="Verify a business’s FBR POS integration and reconcile declared income against actual bank turnover." />
      <div className="grid" style={{ gridTemplateColumns: '1fr 1.2fr', alignItems: 'start' }}>
        <Card style={{ padding: 0, overflow: 'hidden', maxHeight: '70vh', overflowY: 'auto' }}>
          {biz.map((b) => (
            <div key={b.cnic} className="row" style={{ gap: 12, padding: 14, borderBottom: '1px solid var(--panel-border)', cursor: 'pointer', background: sel?.cnic === b.cnic ? 'var(--panel-2)' : 'transparent' }} onClick={() => open(b)}>
              <div style={{ width: 40, height: 40, flex: 'none', borderRadius: 10, display: 'grid', placeItems: 'center', color: 'var(--blue)', background: 'rgba(76,141,246,0.12)' }}>{I('store')}</div>
              <div style={{ flex: 1, minWidth: 0 }}><div style={{ fontSize: 13.5, fontWeight: 600 }}>{b.name}</div><div className="mono" style={{ fontSize: 10.5, color: 'var(--text-3)' }}>{b.business_desc || 'Business'} · {b.district || ''}</div></div>
              {b.zone && b.zone !== '-' && <Tag sev={zoneSev(b.zone)}>{b.zone}</Tag>}
            </div>
          ))}
        </Card>

        <Card>
          {!sel ? <div style={{ display: 'grid', placeItems: 'center', padding: 50, color: 'var(--text-3)', textAlign: 'center' }}><div className="kpi-ic" style={{ color: 'var(--blue)', background: 'rgba(76,141,246,0.12)', width: 50, height: 50, marginBottom: 12 }}>{I('store')}</div>Select a business to reconcile its POS turnover.</div>
            : loadingV ? <Loading /> : res?.error ? <ErrorBox msg="Verification failed." />
              : <Recon r={res} />}
        </Card>
      </div>
    </div>
  )
}

function Recon({ r }) {
  const integrated = r.pos_integrated === true
  const col = integrated ? (r.unreported < r.bank_turnover * 0.15 ? 'var(--green)' : 'var(--high)') : 'var(--critical)'
  return (
    <div>
      <div className="row" style={{ gap: 12, marginBottom: 14 }}>
        <div style={{ width: 50, height: 50, borderRadius: 13, display: 'grid', placeItems: 'center', color: 'var(--blue)', background: 'rgba(76,141,246,0.12)' }}>{I('store')}</div>
        <div><div style={{ fontFamily: 'var(--font-display)', fontSize: 17, fontWeight: 600 }}>{r.name}</div><div className="mono" style={{ fontSize: 10.5, color: 'var(--text-3)' }}>NTN {r.ntn || '—'} · {r.business} · {r.district || ''}</div></div>
      </div>
      <div style={{ textAlign: 'center', padding: '14px 0', borderRadius: 12, background: 'var(--panel)', border: '1px solid var(--panel-border)', marginBottom: 16 }}>
        {I('qr', { }) || null}
        {I(integrated ? 'check' : 'alert', { style: { width: 30, height: 30, color: col } })}
        <div style={{ fontFamily: 'var(--font-display)', fontSize: 15, fontWeight: 600, color: col, marginTop: 6 }}>{integrated ? 'FBR POS INTEGRATED' : 'NOT POS-INTEGRATED'}</div>
        <div style={{ fontSize: 12, color: 'var(--text-2)', marginTop: 4, padding: '0 16px' }}>{r.verdict || ''}</div>
      </div>
      <KV k="Declared income" v={rs(r.declared_income)} />
      <KV k="Actual turnover (bank)" v={rs(r.bank_turnover)} />
      <KV k="Reported via POS" v={`${rs(r.pos_reported)} (${Math.round(r.reported_pct || 0)}%)`} />
      <div style={{ height: 12, borderRadius: 6, background: 'rgba(229,86,111,0.25)', overflow: 'hidden', margin: '10px 0' }}><div style={{ height: '100%', width: `${Math.min(100, r.reported_pct || 0)}%`, background: 'var(--green)' }} /></div>
      <KV k="Unreported sales" v={rs(r.unreported)} crit />
      <KV k="Recoverable sales tax (GST 17%)" v={rs(r.recovery)} crit bold />
    </div>
  )
}
const KV = ({ k, v, crit, bold }) => <div className="row" style={{ justifyContent: 'space-between', padding: '7px 0', borderBottom: '1px solid var(--panel-border)' }}><span style={{ fontSize: 12.5, color: 'var(--text-2)' }}>{k}</span><span className="mono" style={{ fontSize: 13, fontWeight: bold ? 800 : 600, color: crit ? 'var(--critical)' : 'var(--text)' }}>{v}</span></div>

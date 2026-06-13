import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { api } from '../../lib/api.js'
import { I } from '../../components/Icons.jsx'
import { PageHead, Card, Loading, ErrorBox } from '../../components/ui.jsx'
import { RiskMeter, Heatmap, DonutChart } from '../../components/charts.jsx'

export default function RiskAnalysis() {
  const nav = useNavigate()
  const [d, setD] = useState(null)
  const [err, setErr] = useState('')

  async function load() {
    setErr('')
    try {
      const lb = await api.leaderboard(1)
      const cnic = lb?.[0]?.cnic || lb?.results?.[0]?.cnic
      const [p, rf, an] = await Promise.all([api.person(cnic), api.riskFactors(cnic), api.analytics()])
      setD({ cnic, p, factors: rf.factors || [], an })
    } catch (e) { setErr(String(e.message || e)) }
  }
  useEffect(() => { load() }, [])

  if (err) return <div className="page"><ErrorBox msg={err} onRetry={load} /></div>
  if (!d) return <div className="page"><Loading label="Scoring compliance deviation…" /></div>

  const sc = d.p.score || {}, id = d.p.identity || {}
  const dev = Math.round(sc.deviation_score || 0)
  const z = d.an.zones || {}, totalZ = (z.Red || 0) + (z.Yellow || 0) + (z.Green || 0) || 1
  const riskDist = [
    { label: 'Green', value: Math.round(((z.Green || 0) / totalZ) * 100), color: '#25C98C' },
    { label: 'Yellow', value: Math.round(((z.Yellow || 0) / totalZ) * 100), color: '#E0B23C' },
    { label: 'Red', value: Math.round(((z.Red || 0) / totalZ) * 100), color: '#E5566F' },
  ]

  return (
    <div className="page">
      <PageHead eyebrow="Compliance Deviation · Live" title="Risk Analysis"
        desc="GNN-derived deviation weighs lifestyle signals against declared income."
        actions={<button className="btn btn-ghost" onClick={() => nav(`/admin/person/${d.cnic}`)}>{I('eye')} Open case</button>} />

      <div className="grid" style={{ gridTemplateColumns: '320px 1fr', alignItems: 'start' }}>
        <Card style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}>
          <RiskMeter value={dev} />
          <div style={{ display: 'flex', gap: 8, marginTop: 22, flexWrap: 'wrap', justifyContent: 'center' }}>
            {[['Low', 'low'], ['Medium', 'med'], ['High', 'high'], ['Critical', 'critical']].map(([l, t]) => <span key={t} className={`tag tag-${t}`}>{l}</span>)}
          </div>
        </Card>
        <Card>
          <div style={{ fontFamily: 'var(--font-display)', fontSize: 16, fontWeight: 600, marginBottom: 4 }}>Factors Influencing Risk</div>
          <div style={{ fontSize: 12, color: 'var(--text-3)', marginBottom: 18 }}>Top case: {id.name} · {id.cnic}</div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
            {d.factors.map((f, i) => {
              const sev = f.sev || 'med'
              return (
                <div key={i}>
                  <div className="row" style={{ gap: 10, marginBottom: 7 }}>
                    <span style={{ color: `var(--${sev === 'critical' ? 'critical' : sev === 'high' ? 'high' : sev === 'med' ? 'med' : 'green'})`, flex: 'none' }}>{I(f.icon || 'alert', { style: { width: 16, height: 16 } })}</span>
                    <span style={{ fontSize: 13, fontWeight: 500, flex: 1, minWidth: 0 }}>{f.label}</span>
                    <span className="mono" style={{ fontSize: 11, color: 'var(--text-3)' }}>{f.detail || ''}</span>
                    <span className="mono" style={{ fontSize: 13, fontWeight: 700, width: 28, textAlign: 'right', color: `var(--${sev === 'critical' ? 'critical' : sev === 'high' ? 'high' : sev === 'med' ? 'med' : 'green'})` }}>{Math.round(f.weight || 0)}</span>
                  </div>
                  <div style={{ height: 7, borderRadius: 6, background: 'var(--panel-2)', overflow: 'hidden' }}><div style={{ height: '100%', width: `${Math.min(100, f.weight || 0)}%`, borderRadius: 6, background: `var(--${sev === 'critical' ? 'critical' : sev === 'high' ? 'high' : sev === 'med' ? 'med' : 'green'})` }} /></div>
                </div>
              )
            })}
            {!d.factors.length && <div style={{ color: 'var(--text-2)', fontSize: 12.5 }}>Assets may be hidden via family/company — see Audit Trail.</div>}
          </div>
        </Card>
      </div>

      <div className="grid" style={{ gridTemplateColumns: '1fr 1fr', marginTop: 18, alignItems: 'start' }}>
        <Card>
          <div className="row" style={{ justifyContent: 'space-between', marginBottom: 16 }}><div style={{ fontFamily: 'var(--font-display)', fontSize: 16, fontWeight: 600 }}>Regional Risk Heatmap</div><div className="mono" style={{ fontSize: 11, color: 'var(--text-3)' }}>district × sector</div></div>
          <Heatmap rows={6} cols={16} />
          <div className="row" style={{ gap: 10, marginTop: 16, fontSize: 11, color: 'var(--text-3)' }}><span>Low</span><div style={{ flex: 1, height: 6, borderRadius: 4, background: 'linear-gradient(90deg,#25C98C,#E0B23C,#E68A4A,#E5566F)' }} /><span>Critical</span></div>
        </Card>
        <Card>
          <div style={{ fontFamily: 'var(--font-display)', fontSize: 16, fontWeight: 600, marginBottom: 18 }}>National Zone Mix</div>
          <DonutChart data={riskDist} size={170} centerLabel={`${riskDist[2].value}%`} centerSub="RED" />
        </Card>
      </div>
    </div>
  )
}

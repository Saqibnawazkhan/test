import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { api, rs } from '../../lib/api.js'
import { listNotifications } from '../../lib/supabase.js'
import { I } from '../../components/Icons.jsx'
import { Loading, ErrorBox } from '../../components/ui.jsx'
import { AnimatedCounter, Sparkline, LineChart, DonutChart } from '../../components/charts.jsx'
import { NetworkBackground } from '../../components/graph.jsx'

export default function Dashboard() {
  const nav = useNavigate()
  const [d, setD] = useState(null)
  const [err, setErr] = useState('')
  const [alerts, setAlerts] = useState([])

  async function load() {
    setErr('')
    try {
      const [stats, analytics] = await Promise.all([api.stats(), api.analytics()])
      setD({ stats, analytics })
      listNotifications('admin').then((n) => setAlerts(n.slice(0, 5))).catch(() => {})
    } catch (e) { setErr(String(e.message || e)) }
  }
  useEffect(() => { load() }, [])

  if (err) return <div className="page"><ErrorBox msg={err} onRetry={load} /></div>
  if (!d) return <div className="page"><Loading label="Loading the national tax net…" /></div>

  const { stats, analytics } = d
  const z = stats.zones || {}
  const totalZ = (z.Red || 0) + (z.Yellow || 0) + (z.Green || 0) || 1
  const KPIS = [
    { id: 'c', label: 'Citizens Analysed', value: stats.total_persons || 0, fmt: 'short', delta: 2.4, icon: 'user', accent: 'var(--blue)', spark: [30, 34, 32, 40, 44, 48, 52, 60, 58, 66, 72, 80] },
    { id: 'f', label: 'Active Tax Filers', value: stats.filers || 0, fmt: 'short', delta: 5.8, icon: 'check', accent: 'var(--green)', spark: [20, 22, 26, 25, 30, 33, 38, 42, 46, 52, 58, 64] },
    { id: 'n', label: 'Non-Filers Detected', value: stats.non_filers || 0, fmt: 'short', delta: 12.1, icon: 'flag', accent: 'var(--high)', spark: [60, 58, 55, 52, 48, 46, 40, 38, 33, 30, 26, 22] },
    { id: 'h', label: 'High-Risk (Red)', value: z.Red || 0, fmt: 'short', delta: 8.3, icon: 'alert', accent: 'var(--critical)', spark: [12, 16, 15, 20, 24, 22, 30, 34, 40, 44, 52, 58] },
    { id: 'u', label: 'Hidden Assets Under Review', value: stats.hidden_assets_under_review || 0, fmt: 'short', delta: 6.7, icon: 'eye', accent: 'var(--violet)', spark: [22, 28, 30, 36, 40, 46, 50, 55, 60, 68, 74, 82] },
    { id: 'r', label: 'Recovery Potential (Rs)', value: analytics.total_recovery_potential || 0, fmt: 'short', delta: 6.7, icon: 'trend', accent: 'var(--green)', spark: [22, 28, 30, 36, 40, 46, 50, 55, 60, 68, 74, 82] },
  ]
  const riskDist = [
    { label: 'Green', value: Math.round(((z.Green || 0) / totalZ) * 100), color: '#25C98C' },
    { label: 'Yellow', value: Math.round(((z.Yellow || 0) / totalZ) * 100), color: '#E0B23C' },
    { label: 'Red', value: Math.round(((z.Red || 0) / totalZ) * 100), color: '#E5566F' },
  ]

  return (
    <div className="page">
      <div className="page-head">
        <div>
          <div className="eyebrow">Operations Command · Live</div>
          <h1 className="page-title">Dashboard Overview</h1>
          <p className="page-desc">Real-time view of national compliance posture across all linked data sources.</p>
        </div>
        <div style={{ display: 'flex', gap: 10 }}>
          <button className="btn btn-ghost" onClick={() => nav('/admin/analytics')}>{I('download')} Reports</button>
          <button className="btn btn-primary" onClick={() => nav('/admin/audit')}>{I('spark')} New Investigation</button>
        </div>
      </div>

      <div className="grid" style={{ gridTemplateColumns: 'repeat(3, 1fr)' }}>
        {KPIS.map((k, i) => (
          <div className="card fade-up" key={k.id} style={{ animationDelay: `${i * 0.05}s`, overflow: 'hidden' }}>
            <div style={{ position: 'absolute', top: 0, left: 0, right: 0, height: 2, background: k.accent, opacity: 0.7 }} />
            <div className="row" style={{ justifyContent: 'space-between' }}>
              <div style={{ width: 38, height: 38, borderRadius: 10, display: 'grid', placeItems: 'center', color: k.accent, background: `color-mix(in srgb, ${k.accent} 12%, transparent)` }}>{I(k.icon)}</div>
              <div className="tag tag-low" style={{ background: 'rgba(37,201,140,0.12)' }}>{I('arrowUp', { style: { width: 11, height: 11 } })} {k.delta}%</div>
            </div>
            <div className="mono" style={{ fontSize: 28, fontWeight: 700, marginTop: 16, letterSpacing: '-0.02em' }}>{k.id === 'r' ? 'Rs ' : ''}<AnimatedCounter value={k.value} fmt={k.fmt} /></div>
            <div style={{ fontSize: 12.5, color: 'var(--text-2)', marginTop: 4 }}>{k.label}</div>
            <div style={{ marginTop: 14 }}><Sparkline data={k.spark} color={k.accent} h={34} /></div>
          </div>
        ))}
      </div>

      <div className="grid" style={{ gridTemplateColumns: '1.6fr 1fr', marginTop: 18 }}>
        <div className="card">
          <div className="row" style={{ justifyContent: 'space-between', marginBottom: 6 }}>
            <div><div style={{ fontFamily: 'var(--font-display)', fontSize: 16, fontWeight: 600 }}>Filer vs Non-Filer Trend</div>
              <div style={{ fontSize: 12, color: 'var(--text-3)', marginTop: 2 }}>Share of analysed population · 12 months</div></div>
            <div style={{ display: 'flex', gap: 14 }}><Legend c="var(--green)" t="Filers" /><Legend c="var(--high)" t="Non-filers" /></div>
          </div>
          <LineChart labels={analytics.trend_months || []} height={236} series={[{ data: analytics.trend_filed || [], color: 'var(--green)' }, { data: analytics.trend_nonfiler || [], color: 'var(--high)' }]} />
        </div>
        <div className="card">
          <div style={{ fontFamily: 'var(--font-display)', fontSize: 16, fontWeight: 600, marginBottom: 18 }}>Risk Distribution</div>
          <DonutChart data={riskDist} size={170} centerLabel={`${Math.round(((z.Red || 0) / totalZ) * 100)}%`} centerSub="RED ZONE" />
        </div>
      </div>

      <div className="grid" style={{ gridTemplateColumns: '1fr 1.4fr', marginTop: 18 }}>
        <div className="card">
          <div className="row" style={{ justifyContent: 'space-between', marginBottom: 16 }}>
            <div style={{ fontFamily: 'var(--font-display)', fontSize: 16, fontWeight: 600 }}>Live Alert Feed</div><span className="dot-pulse" />
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            {alerts.length === 0 && <div style={{ fontSize: 12.5, color: 'var(--text-3)' }}>No alerts yet — citizen actions appear here in real time.</div>}
            {alerts.map((n, i) => (
              <div key={i} className="row" style={{ gap: 12, alignItems: 'flex-start' }}>
                <div style={{ width: 32, height: 32, flex: 'none', borderRadius: 9, display: 'grid', placeItems: 'center', color: tone(n.kind), background: `color-mix(in srgb, ${tone(n.kind)} 12%, transparent)` }}>{I(kindIcon(n.kind))}</div>
                <div><div style={{ fontSize: 13, fontWeight: 500 }}>{n.title}</div><div className="mono" style={{ fontSize: 10.5, color: 'var(--text-3)', marginTop: 2 }}>{n.body || ''}</div></div>
              </div>
            ))}
          </div>
        </div>
        <div className="card" style={{ padding: 0, overflow: 'hidden', position: 'relative', minHeight: 280 }}>
          <div style={{ position: 'absolute', top: 16, left: 18, zIndex: 2 }}>
            <div style={{ fontFamily: 'var(--font-display)', fontSize: 16, fontWeight: 600 }}>Network Snapshot</div>
            <div style={{ fontSize: 12, color: 'var(--text-3)', marginTop: 2 }}>Benami fronts & director clusters</div>
          </div>
          <button className="btn btn-ghost" style={{ position: 'absolute', top: 14, right: 14, zIndex: 2, padding: '8px 12px', fontSize: 12 }} onClick={() => nav('/admin/graph')}>{I('zoom')} Open</button>
          <div style={{ position: 'absolute', inset: 0 }}><NetworkBackground density={40} opacity={0.8} /></div>
        </div>
      </div>
    </div>
  )
}

const Legend = ({ c, t }) => <div className="row" style={{ gap: 7, fontSize: 12, color: 'var(--text-2)' }}><span style={{ width: 9, height: 9, borderRadius: 3, background: c }} />{t}</div>
const tone = (k) => k === 'payment' ? 'var(--green)' : k === 'request' ? 'var(--blue)' : k === 'rejected' ? 'var(--critical)' : k === 'approved' || k === 'accepted' ? 'var(--green)' : 'var(--med)'
const kindIcon = (k) => k === 'payment' ? 'wallet' : k === 'request' ? 'bell' : k === 'announcement' ? 'spark' : 'alert'

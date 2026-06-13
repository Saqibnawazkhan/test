import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { api, rs } from '../../lib/api.js'
import { announce } from '../../lib/supabase.js'
import { I } from '../../components/Icons.jsx'
import { PageHead, Card, Loading, ErrorBox } from '../../components/ui.jsx'
import { LineChart, BarChart, DonutChart } from '../../components/charts.jsx'

export default function Reports() {
  const nav = useNavigate()
  const [d, setD] = useState(null)
  const [err, setErr] = useState('')
  const [lb, setLb] = useState([])
  const [bc, setBc] = useState({ title: '', body: '' })
  const [bcMsg, setBcMsg] = useState('')

  async function load() {
    setErr('')
    try {
      const an = await api.analytics()
      setD(an)
      const l = await api.leaderboard(8)
      setLb(Array.isArray(l) ? l : (l.results || []))
    } catch (e) { setErr(String(e.message || e)) }
  }
  useEffect(() => { load() }, [])

  async function broadcast() {
    if (!bc.title.trim()) { setBcMsg('Enter a title.'); return }
    setBcMsg('Sending…')
    try { await announce(bc.title, bc.body); setBcMsg('✓ Broadcast sent to all citizens (in-app)'); setBc({ title: '', body: '' }) }
    catch (e) { setBcMsg('⚠️ ' + (e.message || e)) }
  }

  if (err) return <div className="page"><ErrorBox msg={err} onRetry={load} /></div>
  if (!d) return <div className="page"><Loading label="Compiling reports…" /></div>

  const z = d.zones || {}, totalZ = (z.Red || 0) + (z.Yellow || 0) + (z.Green || 0) || 1
  const mix = [
    { label: 'Green', value: Math.round(((z.Green || 0) / totalZ) * 100), color: '#25C98C' },
    { label: 'Yellow', value: Math.round(((z.Yellow || 0) / totalZ) * 100), color: '#E0B23C' },
    { label: 'Red', value: Math.round(((z.Red || 0) / totalZ) * 100), color: '#E5566F' },
  ]
  const districts = (d.districts || []).slice(0, 6)
  const maxRec = districts.length ? Math.max(...districts.map((x) => x.recovery || 0)) : 1
  const leak = (d.trend_filed || []).map((v) => Math.round(v * 1.4))

  return (
    <div className="page">
      <PageHead eyebrow="Reporting · Live" title="Reports & Analytics"
        desc="Compliance trends, regional posture and revenue leakage across the tax net." />

      <div className="grid" style={{ gridTemplateColumns: '1.5fr 1fr', alignItems: 'start' }}>
        <Card>
          <div className="row" style={{ justifyContent: 'space-between', marginBottom: 6 }}><div style={{ fontFamily: 'var(--font-display)', fontSize: 16, fontWeight: 600 }}>Revenue Recovery Trend</div><span className="tag tag-info">Rs (indexed)</span></div>
          <LineChart labels={d.trend_months || []} height={240} series={[{ data: leak, color: 'var(--blue)' }]} />
        </Card>
        <Card>
          <div style={{ fontFamily: 'var(--font-display)', fontSize: 16, fontWeight: 600, marginBottom: 18 }}>Fraud Detection Mix</div>
          <DonutChart data={mix} size={168} centerLabel={rs(d.total_recovery_potential)} centerSub="POTENTIAL" />
        </Card>
      </div>

      <div className="grid" style={{ gridTemplateColumns: '1fr 1fr', marginTop: 18, alignItems: 'start' }}>
        <Card>
          <div style={{ fontFamily: 'var(--font-display)', fontSize: 16, fontWeight: 600, marginBottom: 16 }}>Regional Recovery Index</div>
          <BarChart data={districts.map((r) => ({ label: (r.district || '').slice(0, 6), value: Math.round(((r.recovery || 0) / maxRec) * 100), color: undefined }))} height={200} format={(v) => v + '%'} />
        </Card>
        <Card>
          <div className="row" style={{ gap: 8, marginBottom: 16 }}>{I('trophy', { style: { width: 18, height: 18, color: 'var(--med)' } })}<div style={{ fontFamily: 'var(--font-display)', fontSize: 16, fontWeight: 600 }}>Top Suspicious Entities</div></div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {lb.map((e, i) => (
              <div key={e.cnic || i} className="row" style={{ gap: 13, padding: '10px 12px', borderRadius: 11, cursor: 'pointer', background: i === 0 ? 'rgba(229,86,111,0.06)' : 'var(--panel)', border: `1px solid ${i === 0 ? 'rgba(229,86,111,0.25)' : 'var(--panel-border)'}` }} onClick={() => e.cnic && nav(`/admin/person/${e.cnic}`)}>
                <div className="mono" style={{ width: 24, textAlign: 'center', fontWeight: 700, fontSize: 14, color: i < 3 ? 'var(--med)' : 'var(--text-3)' }}>{i + 1}</div>
                <div style={{ flex: 1, minWidth: 0 }}><div style={{ fontSize: 13, fontWeight: 500 }}>{e.name}</div><div className="mono" style={{ fontSize: 10.5, color: 'var(--text-3)' }}>{e.district || ''}</div></div>
                <div className="mono" style={{ fontSize: 12, color: 'var(--green)', fontWeight: 600 }}>{rs(e.recovery)}</div>
                <span className={`tag tag-${e.zone === 'Red' ? 'critical' : e.zone === 'Yellow' ? 'high' : 'low'}`} style={{ width: 32, justifyContent: 'center' }}>{Math.round(e.deviation_score || 0)}</span>
              </div>
            ))}
          </div>
        </Card>
      </div>

      <Card style={{ marginTop: 18 }}>
        <div className="row" style={{ gap: 8, marginBottom: 14 }}>{I('send', { style: { width: 16, height: 16, color: 'var(--blue)' } })}<div style={{ fontFamily: 'var(--font-display)', fontSize: 15, fontWeight: 600 }}>Broadcast to Citizens</div></div>
        <div className="grid" style={{ gridTemplateColumns: '1fr 1fr', gap: 12 }}>
          <input className="input" placeholder="Title (e.g. File your return before 30 Sept)" value={bc.title} onChange={(e) => setBc({ ...bc, title: e.target.value })} />
          <input className="input" placeholder="Message" value={bc.body} onChange={(e) => setBc({ ...bc, body: e.target.value })} />
        </div>
        <div className="row" style={{ gap: 12, marginTop: 12 }}>
          <button className="btn btn-primary" onClick={broadcast}>{I('send')} Send broadcast</button>
          {bcMsg && <span style={{ fontSize: 12.5, color: 'var(--text-2)' }}>{bcMsg}</span>}
        </div>
      </Card>
    </div>
  )
}

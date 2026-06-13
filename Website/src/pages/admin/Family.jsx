import { useEffect, useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { api, rs } from '../../lib/api.js'
import { I } from '../../components/Icons.jsx'
import { PageHead, Card, Tag, Stat, Loading, ErrorBox, zoneSev } from '../../components/ui.jsx'

export default function Family() {
  const { cnic } = useParams()
  const nav = useNavigate()
  const [f, setF] = useState(null)
  const [err, setErr] = useState('')

  async function load() { setErr(''); try { setF(await api.family(cnic)) } catch (e) { setErr(String(e.message || e)) } }
  useEffect(() => { load() }, [cnic])

  if (err) return <div className="page"><ErrorBox msg={err} onRetry={load} /></div>
  if (!f) return <div className="page"><Loading label="Mapping the family network…" /></div>

  const members = f.members || []
  return (
    <div className="page">
      <button className="btn btn-ghost" style={{ marginBottom: 16 }} onClick={() => nav(-1)}>← Back</button>
      <PageHead eyebrow="Benami Detection · Live" title="Family & Asset Network"
        desc="Assets held in the names of relatives — possible fronts are flagged where wealth far exceeds the relative’s own income." />

      <div className="kpi-grid" style={{ marginBottom: 18 }}>
        <Stat icon="wallet" color="var(--blue)" value={rs(f.total_family_assets)} label="Family assets" />
        <Stat icon="alert" color="var(--critical)" value={f.front_count || 0} label="Possible fronts" />
        <Stat icon="eye" color="var(--high)" value={rs(f.hidden_in_fronts)} label="Hidden in fronts" />
      </div>

      <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
        {members.map((m, i) => {
          const front = m.possible_front === true
          const self = m.relation === 'Self'
          const init = (m.name || '?').split(' ').filter(Boolean).map((s) => s[0]).slice(0, 2).join('')
          return (
            <Card key={i} className="row" style={{ gap: 14, borderColor: front ? 'rgba(229,86,111,0.4)' : self ? 'rgba(76,141,246,0.4)' : 'var(--panel-border)' }}>
              <div style={{ width: 46, height: 46, flex: 'none', borderRadius: 12, display: 'grid', placeItems: 'center', fontFamily: 'var(--font-display)', fontWeight: 700, color: self ? 'var(--blue)' : 'var(--violet)', background: self ? 'rgba(76,141,246,0.14)' : 'rgba(139,134,224,0.14)' }}>{init}</div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div className="row" style={{ gap: 8 }}>
                  <span style={{ fontSize: 14, fontWeight: 700 }}>{m.name}</span>
                  {self && <Tag sev="info">SELF</Tag>}
                  {front && <Tag sev="critical">FRONT</Tag>}
                </div>
                <div className="mono" style={{ fontSize: 10.5, color: 'var(--text-3)', marginTop: 3 }}>{m.relation}{m.age ? ` · ${m.age} yrs` : ''} · {m.filer_status || 'Non-Filer'}</div>
                <div style={{ fontSize: 12, color: 'var(--text-2)', marginTop: 5 }}>Assets {rs(m.own_assets)} · Income {rs(m.declared_income)}</div>
              </div>
              <div style={{ textAlign: 'right' }}>
                <Tag sev={zoneSev(m.zone)}>{Math.round(m.deviation_score || 0)}</Tag>
              </div>
            </Card>
          )
        })}
        {!members.length && <Card style={{ textAlign: 'center', color: 'var(--text-3)', padding: 40 }}>No dependent relatives on record for this entity.</Card>}
      </div>
    </div>
  )
}

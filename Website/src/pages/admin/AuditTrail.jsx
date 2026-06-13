import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { api, rs } from '../../lib/api.js'
import { I } from '../../components/Icons.jsx'
import { PageHead, Card, Tag, Loading, ErrorBox, zoneSev } from '../../components/ui.jsx'

export default function AuditTrail() {
  const nav = useNavigate()
  const [people, setPeople] = useState(null)
  const [err, setErr] = useState('')

  async function load() {
    setErr('')
    try { const r = await api.persons({ sort: 'score', limit: 40 }); setPeople(r.results || []) }
    catch (e) { setErr(String(e.message || e)) }
  }
  useEffect(() => { load() }, [])

  if (err) return <div className="page"><ErrorBox msg={err} onRetry={load} /></div>
  if (!people) return <div className="page"><Loading label="Loading flagged entities…" /></div>

  return (
    <div className="page">
      <PageHead eyebrow="Explainable AI · Live" title="Audit Trail"
        desc="Highest-risk flagged entities — open any case for its full investigation report, audit PDF and notice." />
      <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
        {people.map((p) => {
          const initials = (p.name || '?').split(' ').filter(Boolean).map((s) => s[0]).slice(0, 2).join('')
          return (
            <Card key={p.cnic} className="row" style={{ gap: 14, cursor: 'pointer', padding: 16 }} onClick={() => nav(`/admin/person/${p.cnic}`)}>
              <div style={{ width: 44, height: 44, flex: 'none', borderRadius: 12, display: 'grid', placeItems: 'center', fontFamily: 'var(--font-display)', fontWeight: 700, color: 'var(--critical)', background: 'rgba(229,86,111,0.12)' }}>{initials}</div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 14, fontWeight: 600 }}>{p.name}</div>
                <div className="mono" style={{ fontSize: 10.5, color: 'var(--text-3)' }}>{p.cnic} · {p.district || '—'} · {p.filer_status || 'Non-Filer'}</div>
              </div>
              <div style={{ textAlign: 'right' }}><div className="mono" style={{ fontSize: 12, color: 'var(--critical)' }}>{rs(p.recovery)}</div><div style={{ fontSize: 10, color: 'var(--text-3)' }}>recovery</div></div>
              <Tag sev={zoneSev(p.zone)}>{Math.round(p.deviation_score)}</Tag>
              {I('arrowRight', { style: { width: 16, height: 16, color: 'var(--text-3)' } })}
            </Card>
          )
        })}
      </div>
    </div>
  )
}

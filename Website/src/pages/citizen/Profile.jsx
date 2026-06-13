import { useEffect, useState } from 'react'
import { api } from '../../lib/api.js'
import { useApp } from '../../lib/store.jsx'
import { I } from '../../components/Icons.jsx'
import { PageHead, Card, Loading, ErrorBox } from '../../components/ui.jsx'

export default function Profile() {
  const { auth, setAuth } = useApp()
  const [id, setId] = useState(null)
  const [err, setErr] = useState('')
  const [f, setF] = useState({ name: '', email: '', mobile: '', address: '' })
  const [busy, setBusy] = useState(false)
  const [msg, setMsg] = useState('')

  async function load() {
    setErr('')
    try {
      const p = await api.person(auth.cnic)
      setId(p.identity || {})
      setF({ name: p.identity?.name || '', email: p.identity?.email || '', mobile: p.identity?.mobile || '', address: p.identity?.address || '' })
    } catch (e) { setErr(String(e.message || e)) }
  }
  useEffect(() => { load() }, [auth.cnic])

  async function save() {
    setBusy(true); setMsg('')
    try {
      await api.updateProfile(auth.cnic, f)
      setAuth({ ...auth, name: f.name })
      setMsg('✓ Saved to your record')
    } catch (e) { setMsg('⚠️ ' + (e.message || e)) } finally { setBusy(false) }
  }

  if (err) return <div className="page"><ErrorBox msg={err} onRetry={load} /></div>
  if (!id) return <div className="page"><Loading /></div>

  const set = (k) => (e) => setF((x) => ({ ...x, [k]: e.target.value }))
  return (
    <div className="page">
      <PageHead eyebrow="My Account" title="Profile" desc="Your NADRA identity is read-only. You can update your contact details." />
      <div className="grid" style={{ gridTemplateColumns: '1fr 1.2fr', alignItems: 'start' }}>
        <Card>
          <div style={{ fontFamily: 'var(--font-display)', fontWeight: 600, fontSize: 15, marginBottom: 14 }}>Identity (NADRA)</div>
          <RO k="Full name" v={id.name} /><RO k="CNIC" v={id.cnic} /><RO k="Father / Husband" v={id.father} />
          <RO k="Gender" v={id.gender} /><RO k="Date of birth" v={id.dob} /><RO k="District" v={id.district} />
        </Card>
        <Card>
          <div style={{ fontFamily: 'var(--font-display)', fontWeight: 600, fontSize: 15, marginBottom: 14 }}>Contact details</div>
          <div className="field"><label>Name (display)</label><input className="input" value={f.name} onChange={set('name')} /></div>
          <div className="field"><label>Email</label><input className="input" value={f.email} onChange={set('email')} /></div>
          <div className="field"><label>Mobile</label><input className="input" value={f.mobile} onChange={set('mobile')} /></div>
          <div className="field"><label>Address</label><textarea className="input" rows={2} value={f.address} onChange={set('address')} /></div>
          <div className="row" style={{ gap: 12, marginTop: 6 }}>
            <button className="btn btn-primary" onClick={save} disabled={busy}>{I('check')} {busy ? 'Saving…' : 'Save changes'}</button>
            {msg && <span style={{ fontSize: 12.5, color: 'var(--text-2)' }}>{msg}</span>}
          </div>
        </Card>
      </div>
    </div>
  )
}

const RO = ({ k, v }) => <div className="row" style={{ justifyContent: 'space-between', padding: '8px 0', borderBottom: '1px solid var(--panel-border)' }}><span style={{ fontSize: 12.5, color: 'var(--text-3)' }}>{k}</span><span style={{ fontSize: 13 }}>{v || '—'}</span></div>

import { useState } from 'react'
import { useNavigate, useSearchParams } from 'react-router-dom'
import { I } from '../components/Icons.jsx'
import { useApp } from '../lib/store.jsx'
import { api } from '../lib/api.js'
import { login as sbLogin } from '../lib/supabase.js'

// Demo credentials (same as the mobile app): CNIC 42101-1354046-5 / 1234
const DEMO_CITIZEN = '42101-1354046-5'

export default function Login() {
  const [sp] = useSearchParams()
  const role = sp.get('role') === 'admin' ? 'admin' : 'citizen'
  const nav = useNavigate()
  const { setAuth } = useApp()
  const [cnic, setCnic] = useState('')
  const [pwd, setPwd] = useState('')
  const [user, setUser] = useState('')
  const [busy, setBusy] = useState(false)
  const [err, setErr] = useState('')

  async function citizenLogin(e) {
    e.preventDefault()
    setErr(''); setBusy(true)
    try {
      const c = cnic.trim() || DEMO_CITIZEN
      // 1) try the shared Supabase accounts table (same as the mobile app)
      if (pwd) {
        const acc = await sbLogin(c, pwd).catch(() => null)
        if (acc) { setAuth({ role: 'citizen', cnic: c, name: acc.name || 'Citizen' }); return nav('/app/dashboard') }
      }
      // 2) fallback: verify the CNIC exists in the graph (demo-friendly)
      const p = await api.person(c)
      setAuth({ role: 'citizen', cnic: c, name: p?.identity?.name || 'Citizen' })
      nav('/app/dashboard')
    } catch {
      setErr('CNIC not found. Try the demo CNIC 42101-1354046-5 (password 1234).')
    } finally { setBusy(false) }
  }

  function adminLogin(e) {
    e.preventDefault()
    if (user.trim() === 'admin' && pwd === 'admin123') {
      setAuth({ role: 'admin', name: 'S. Investigator' })
      nav('/admin/dashboard')
    } else setErr('Invalid credentials. Demo: admin / admin123')
  }

  return (
    <div style={{ minHeight: '100vh', display: 'grid', placeItems: 'center', padding: 20, background: 'radial-gradient(900px 600px at 70% -10%, rgba(76,141,246,0.08), transparent 60%), var(--bg-0)' }}>
      <div className="card" style={{ width: 420, maxWidth: '94vw', padding: 30 }}>
        <div className="row" style={{ gap: 12, marginBottom: 22, cursor: 'pointer' }} onClick={() => nav('/')}>
          <div className="brand-mark"><svg viewBox="0 0 24 24" fill="none" stroke="#04070D" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="6" cy="7" r="2"/><circle cx="18" cy="9" r="2"/><circle cx="11" cy="17" r="2.4"/><path d="M8 8l1.5 7M16 10l-3.5 5"/></svg></div>
          <div><div className="brand-name">Tax<span>Net</span> AI</div><div className="brand-sub">{role === 'admin' ? 'FBR Investigator' : 'Citizen Portal'}</div></div>
        </div>

        {role === 'citizen' ? (
          <form onSubmit={citizenLogin}>
            <div className="page-title" style={{ fontSize: 20 }}>Citizen Login</div>
            <div className="page-desc" style={{ marginBottom: 18 }}>Sign in with your CNIC to view your tax score and assets.</div>
            <div className="field"><label>CNIC</label>
              <input className="input" placeholder="42101-1354046-5" value={cnic} onChange={(e) => setCnic(e.target.value)} /></div>
            <div className="field"><label>Password <span style={{ color: 'var(--text-3)' }}>(optional for demo)</span></label>
              <input className="input" type="password" placeholder="1234" value={pwd} onChange={(e) => setPwd(e.target.value)} /></div>
            {err && <div style={{ color: 'var(--critical)', fontSize: 12.5, marginBottom: 12 }}>{err}</div>}
            <button className="btn btn-primary" style={{ width: '100%', padding: 13 }} disabled={busy}>{busy ? 'Checking…' : 'Enter Portal'} {I('arrowRight')}</button>
            <button type="button" className="btn btn-ghost" style={{ width: '100%', marginTop: 10 }} onClick={() => nav('/login?role=admin')}>{I('shield')} I’m an FBR investigator</button>
          </form>
        ) : (
          <form onSubmit={adminLogin}>
            <div className="page-title" style={{ fontSize: 20 }}>FBR Command Center</div>
            <div className="page-desc" style={{ marginBottom: 18 }}>Authorised investigators only.</div>
            <div className="field"><label>Username</label>
              <input className="input" placeholder="admin" value={user} onChange={(e) => setUser(e.target.value)} /></div>
            <div className="field"><label>Password</label>
              <input className="input" type="password" placeholder="••••••••" value={pwd} onChange={(e) => setPwd(e.target.value)} /></div>
            {err && <div style={{ color: 'var(--critical)', fontSize: 12.5, marginBottom: 12 }}>{err}</div>}
            <button className="btn btn-primary" style={{ width: '100%', padding: 13 }}>{I('shield')} Enter Command Center</button>
            <button type="button" className="btn btn-ghost" style={{ width: '100%', marginTop: 10 }} onClick={() => nav('/login?role=citizen')}>{I('user')} I’m a citizen</button>
          </form>
        )}
      </div>
    </div>
  )
}

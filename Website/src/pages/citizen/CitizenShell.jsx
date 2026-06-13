import { useState } from 'react'
import { Routes, Route, Navigate, useNavigate, useLocation } from 'react-router-dom'
import { I } from '../../components/Icons.jsx'
import { useApp } from '../../lib/store.jsx'
import Assistant from '../../components/Assistant.jsx'

import CitizenDashboard from './CitizenDashboard.jsx'
import TaxCalculator from './TaxCalculator.jsx'
import Profile from './Profile.jsx'
import MyAssets from './MyAssets.jsx'
import PayTax from './PayTax.jsx'
import ScanReceipt from './ScanReceipt.jsx'

const NAV = [
  { id: 'dashboard', label: 'My Score', icon: 'shield' },
  { id: 'assets', label: 'My Assets', icon: 'layers' },
  { id: 'calculator', label: 'Tax Calculator', icon: 'calc' },
  { id: 'pay', label: 'Pay Tax', icon: 'wallet' },
  { id: 'scan', label: 'Scan Receipt', icon: 'receipt' },
  { id: 'profile', label: 'Profile', icon: 'user' },
]

export default function CitizenShell() {
  const nav = useNavigate()
  const loc = useLocation()
  const { theme, toggleTheme, lang, setLang, t, auth, setAuth } = useApp()
  const [open, setOpen] = useState(false)
  const [assistant, setAssistant] = useState(false)

  if (!auth || auth.role !== 'citizen') return <Navigate to="/login?role=citizen" replace />

  const active = loc.pathname.split('/')[2] || 'dashboard'
  const go = (id) => { nav(`/app/${id}`); setOpen(false) }
  const crumb = NAV.find((n) => n.id === active)?.label || 'Overview'
  const logout = () => { setAuth(null); nav('/') }

  return (
    <div className="app-shell">
      {open && <div className="drawer-scrim" style={{ zIndex: 35 }} onClick={() => setOpen(false)} />}
      <aside className={`sidebar ${open ? 'open' : ''}`}>
        <div className="brand" style={{ cursor: 'pointer' }} onClick={() => nav('/')}>
          <div className="brand-mark"><svg viewBox="0 0 24 24" fill="none" stroke="#04070D" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="6" cy="7" r="2"/><circle cx="18" cy="9" r="2"/><circle cx="11" cy="17" r="2.4"/><path d="M8 8l1.5 7M16 10l-3.5 5"/></svg></div>
          <div><div className="brand-name">Tax<span>Net</span> AI</div><div className="brand-sub">Citizen Portal</div></div>
        </div>
        <div className="nav-label">My Account</div>
        {NAV.map((n) => (
          <div key={n.id} className={`nav-item ${active === n.id ? 'active' : ''}`} onClick={() => go(n.id)}>
            {I(n.icon)}<span>{t(n.label)}</span>
          </div>
        ))}
        <div className="sidebar-foot">
          <div className="nav-item" onClick={() => setAssistant(true)} style={{ color: 'var(--green)' }}>{I('bot')}<span>{t('AI Assistant')}</span><span className="dot-pulse" style={{ marginLeft: 'auto' }} /></div>
          <div className="user-chip" onClick={logout}>
            <div className="avatar">{(auth.name || 'U').slice(0, 2).toUpperCase()}</div>
            <div style={{ flex: 1, minWidth: 0 }}><div style={{ fontSize: 13, fontWeight: 600, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{auth.name}</div><div className="mono" style={{ fontSize: 10, color: 'var(--text-3)' }}>{auth.cnic}</div></div>
            {I('logout', { style: { width: 16, height: 16, color: 'var(--text-3)' } })}
          </div>
        </div>
      </aside>

      <div className="main">
        <header className="topbar">
          <button className="icon-btn mobile-bar" onClick={() => setOpen(true)}>{I('menu')}</button>
          <div className="crumb" style={{ flex: 'none' }}>Portal&nbsp;/&nbsp;<b>{t(crumb)}</b></div>
          <div className="topbar-actions">
            <div className="lang-toggle">
              <button className={lang === 'EN' ? 'active' : ''} onClick={() => setLang('EN')}>EN</button>
              <button className={lang === 'UR' ? 'active' : ''} onClick={() => setLang('UR')}>اردو</button>
            </div>
            <button className="icon-btn" onClick={toggleTheme}>{I(theme === 'dark' ? 'sun' : 'moon')}</button>
            <button className="btn btn-primary" style={{ padding: '9px 14px' }} onClick={() => setAssistant(true)}>{I('bot')}<span className="hide-sm">{t('AI Assistant')}</span></button>
          </div>
        </header>
        <div className="content">
          <Routes>
            <Route index element={<Navigate to="dashboard" replace />} />
            <Route path="dashboard" element={<CitizenDashboard go={go} />} />
            <Route path="calculator" element={<TaxCalculator />} />
            <Route path="profile" element={<Profile />} />
            <Route path="assets" element={<MyAssets />} />
            <Route path="pay" element={<PayTax />} />
            <Route path="scan" element={<ScanReceipt />} />
            <Route path="*" element={<Navigate to="dashboard" replace />} />
          </Routes>
        </div>
      </div>

      {assistant && <Assistant mode="user" cnic={auth.cnic} onClose={() => setAssistant(false)} />}
    </div>
  )
}

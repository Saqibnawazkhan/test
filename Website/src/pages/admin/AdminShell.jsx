import { useState } from 'react'
import { Routes, Route, Navigate, useNavigate, useLocation } from 'react-router-dom'
import { I } from '../../components/Icons.jsx'
import { useApp } from '../../lib/store.jsx'
import Assistant from '../../components/Assistant.jsx'

import Dashboard from './Dashboard.jsx'
import AllRecords from './AllRecords.jsx'
import PersonDetail from './PersonDetail.jsx'
import Settings from './Settings.jsx'
import KnowledgeGraphView from './KnowledgeGraph.jsx'
import EntityResolution from './EntityResolution.jsx'
import RiskAnalysis from './RiskAnalysis.jsx'
import AuditTrail from './AuditTrail.jsx'
import Reports from './Reports.jsx'
import POS from './POS.jsx'
import Payments from './Payments.jsx'
import Inbox from './Inbox.jsx'
import Family from './Family.jsx'

const NAV = [
  { id: 'dashboard', label: 'Dashboard', icon: 'dashboard' },
  { id: 'graph', label: 'Knowledge Graph', icon: 'graph' },
  { id: 'entity', label: 'Entity Resolution', icon: 'entity' },
  { id: 'risk', label: 'Risk Analysis', icon: 'risk' },
  { id: 'audit', label: 'Audit Trail', icon: 'audit', badge: '14' },
  { id: 'records', label: 'All Records', icon: 'layers' },
  { id: 'pos', label: 'POS Verification', icon: 'store' },
  { id: 'payments', label: 'Tax Payments', icon: 'wallet' },
  { id: 'inbox', label: 'Citizen Inbox', icon: 'bell' },
  { id: 'analytics', label: 'Reports', icon: 'reports' },
  { id: 'settings', label: 'Settings', icon: 'settings' },
]

export default function AdminShell() {
  const nav = useNavigate()
  const loc = useLocation()
  const { theme, toggleTheme, lang, setLang, t, setAuth } = useApp()
  const [open, setOpen] = useState(false)
  const [assistant, setAssistant] = useState(false)

  const active = loc.pathname.split('/')[2] || 'dashboard'
  const go = (id) => { nav(`/admin/${id}`); setOpen(false) }
  const crumb = NAV.find((n) => n.id === active)?.label || 'Investigation'

  const logout = () => { setAuth(null); nav('/') }

  return (
    <div className="app-shell">
      {open && <div className="drawer-scrim" style={{ zIndex: 35 }} onClick={() => setOpen(false)} />}
      <aside className={`sidebar ${open ? 'open' : ''}`}>
        <div className="brand" style={{ cursor: 'pointer' }} onClick={() => nav('/')}>
          <div className="brand-mark"><svg viewBox="0 0 24 24" fill="none" stroke="#04070D" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="6" cy="7" r="2"/><circle cx="18" cy="9" r="2"/><circle cx="11" cy="17" r="2.4"/><path d="M8 8l1.5 7M16 10l-3.5 5"/></svg></div>
          <div><div className="brand-name">Tax<span>Net</span> AI</div><div className="brand-sub">FBR Intelligence</div></div>
        </div>
        <div className="nav-label">Modules</div>
        {NAV.map((n) => (
          <div key={n.id} className={`nav-item ${active === n.id ? 'active' : ''}`} onClick={() => go(n.id)}>
            {I(n.icon)}<span>{t(n.label)}</span>{n.badge && <span className="nav-badge">{n.badge}</span>}
          </div>
        ))}
        <div className="sidebar-foot">
          <div className="nav-item" onClick={() => setAssistant(true)} style={{ color: 'var(--green)' }}>{I('bot')}<span>{t('AI Assistant')}</span><span className="dot-pulse" style={{ marginLeft: 'auto' }} /></div>
          <div className="user-chip" onClick={logout}>
            <div className="avatar">SI</div>
            <div style={{ flex: 1, minWidth: 0 }}><div style={{ fontSize: 13, fontWeight: 600 }}>S. Investigator</div><div style={{ fontSize: 10.5, color: 'var(--text-3)' }}>Tier 3 · FBR HQ</div></div>
            {I('logout', { style: { width: 16, height: 16, color: 'var(--text-3)' } })}
          </div>
        </div>
      </aside>

      <div className="main">
        <header className="topbar">
          <button className="icon-btn mobile-bar" onClick={() => setOpen(true)}>{I('menu')}</button>
          <div className="crumb" style={{ flex: 'none' }}>TaxNet&nbsp;/&nbsp;<b>{t(crumb)}</b></div>
          <div className="search-box" style={{ marginLeft: 18 }} onClick={() => go('records')}>
            {I('search')}<input readOnly placeholder={t('Search CNIC, name, property, vehicle…') || 'Search CNIC, name, property, vehicle…'} style={{ pointerEvents: 'none' }} />
          </div>
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
            <Route path="dashboard" element={<Dashboard go={go} />} />
            <Route path="records" element={<AllRecords />} />
            <Route path="person/:cnic" element={<PersonDetail />} />
            <Route path="family/:cnic" element={<Family />} />
            <Route path="settings" element={<Settings />} />
            <Route path="graph" element={<KnowledgeGraphView />} />
            <Route path="entity" element={<EntityResolution />} />
            <Route path="risk" element={<RiskAnalysis />} />
            <Route path="audit" element={<AuditTrail />} />
            <Route path="pos" element={<POS />} />
            <Route path="payments" element={<Payments />} />
            <Route path="inbox" element={<Inbox />} />
            <Route path="analytics" element={<Reports />} />
            <Route path="*" element={<Navigate to="dashboard" replace />} />
          </Routes>
        </div>
      </div>

      {assistant && <Assistant mode="admin" onClose={() => setAssistant(false)} />}
    </div>
  )
}

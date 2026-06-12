// ===== TaxNet AI — App shell =====
const { useState: useA, useEffect: useEA, useRef: useRA } = React;
const Ia = (n, p) => React.createElement(Icons[n], p);

const NAV = [
  { id: 'dashboard', label: 'Dashboard', icon: 'dashboard' },
  { id: 'graph', label: 'Knowledge Graph', icon: 'graph' },
  { id: 'entity', label: 'Entity Resolution', icon: 'entity' },
  { id: 'risk', label: 'Risk Analysis', icon: 'risk' },
  { id: 'audit', label: 'Audit Trail', icon: 'audit', badge: '14' },
  { id: 'analytics', label: 'Reports', icon: 'reports' },
  { id: 'upload', label: 'Data & Leaderboard', icon: 'upload' },
  { id: 'settings', label: 'Settings', icon: 'settings' },
];
const CRUMB = { landing: 'Home', dashboard: 'Dashboard', graph: 'Knowledge Graph', entity: 'Entity Resolution', risk: 'Risk Analysis', audit: 'Audit Trail', analytics: 'Reports', upload: 'Data & Leaderboard', settings: 'Settings' };

function App() {
  const [route, setRoute] = useA('landing');
  const [lang, setLang] = useA('EN');
  const [theme, setTheme] = useA('dark');
  const [sidebarOpen, setSidebarOpen] = useA(false);
  const [assistant, setAssistant] = useA(false);
  const [notifOpen, setNotifOpen] = useA(false);
  const [searchOpen, setSearchOpen] = useA(false);
  const contentRef = useRA();

  useEA(() => { document.documentElement.setAttribute('data-theme', theme); }, [theme]);
  useEA(() => { if (contentRef.current) contentRef.current.scrollTop = 0; }, [route]);
  useEA(() => {
    const onKey = e => { if ((e.metaKey || e.ctrlKey) && e.key === 'k') { e.preventDefault(); setSearchOpen(true); } if (e.key === 'Escape') { setSearchOpen(false); setNotifOpen(false); } };
    window.addEventListener('keydown', onKey); return () => window.removeEventListener('keydown', onKey);
  }, []);

  const go = id => { setRoute(id); setSidebarOpen(false); };

  const renderView = () => {
    switch (route) {
      case 'landing': return <Landing go={go} />;
      case 'dashboard': return <Dashboard go={go} />;
      case 'graph': return <KnowledgeGraphView />;
      case 'entity': return <EntityResolution />;
      case 'risk': return <RiskAnalysis />;
      case 'audit': return <AuditTrail />;
      case 'analytics': return <Analytics />;
      case 'upload': return <Reports />;
      case 'settings': return <Settings lang={lang} setLang={setLang} theme={theme} setTheme={setTheme} />;
      default: return <Dashboard go={go} />;
    }
  };

  return (
    <div className="app-shell">
      {sidebarOpen && <div className="drawer-scrim" style={{ zIndex: 35 }} onClick={() => setSidebarOpen(false)} />}
      <aside className={`sidebar ${sidebarOpen ? 'open' : ''}`}>
        <div className="brand" onClick={() => go('landing')} style={{ cursor: 'pointer' }}>
          <div className="brand-mark">
            <svg viewBox="0 0 24 24" fill="none" stroke="#04070D" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="6" cy="7" r="2"/><circle cx="18" cy="9" r="2"/><circle cx="11" cy="17" r="2.4"/><path d="M8 8l1.5 7M16 10l-3.5 5"/></svg>
          </div>
          <div>
            <div className="brand-name">Tax<span>Net</span> AI</div>
            <div className="brand-sub">FBR Intelligence</div>
          </div>
        </div>
        <div className="nav-label">Modules</div>
        {NAV.map(n => (
          <div key={n.id} className={`nav-item ${route === n.id ? 'active' : ''}`} onClick={() => go(n.id)}>
            {Ia(n.icon)}<span>{n.label}</span>{n.badge && <span className="nav-badge">{n.badge}</span>}
          </div>
        ))}
        <div className="sidebar-foot">
          <div className="nav-item" onClick={() => setAssistant(true)} style={{ color: 'var(--green)' }}>{Ia('bot')}<span>AI Assistant</span><span className="dot-pulse" style={{ marginLeft: 'auto' }} /></div>
          <div className="user-chip">
            <div className="avatar">SI</div>
            <div style={{ flex: 1, minWidth: 0 }}><div style={{ fontSize: 13, fontWeight: 600 }}>S. Investigator</div><div style={{ fontSize: 10.5, color: 'var(--text-3)' }}>Tier 3 · FBR HQ</div></div>
            {Ia('logout', { style: { width: 16, height: 16, color: 'var(--text-3)' } })}
          </div>
        </div>
      </aside>

      <div className="main">
        <header className="topbar">
          <button className="icon-btn mobile-bar" onClick={() => setSidebarOpen(true)}>{Ia('menu')}</button>
          <div className="crumb" style={{ flex: 'none' }}>TaxNet&nbsp;/&nbsp;<b>{CRUMB[route]}</b></div>
          <div className="search-box" onClick={() => setSearchOpen(true)} style={{ marginLeft: 18 }}>
            {Ia('search')}<input readOnly placeholder="Search CNIC, name, property, vehicle…" style={{ pointerEvents: 'none' }} /><span className="kbd">⌘K</span>
          </div>
          <div className="topbar-actions">
            <div className="lang-toggle">
              <button className={lang === 'EN' ? 'active' : ''} onClick={() => setLang('EN')}>EN</button>
              <button className={lang === 'UR' ? 'active' : ''} onClick={() => setLang('UR')}>اردو</button>
            </div>
            <button className="icon-btn" onClick={() => setTheme(t => t === 'dark' ? 'light' : 'dark')}>{Ia(theme === 'dark' ? 'sun' : 'moon')}</button>
            <div style={{ position: 'relative' }}>
              <button className="icon-btn" onClick={() => setNotifOpen(o => !o)}>{Ia('bell')}<span className="dot" /></button>
              {notifOpen && <NotifDropdown onClose={() => setNotifOpen(false)} />}
            </div>
            <button className="btn btn-primary" style={{ padding: '9px 14px' }} onClick={() => setAssistant(true)}>{Ia('bot')} <span className="hide-sm">AI Assistant</span></button>
          </div>
        </header>
        <div className="content" ref={contentRef}>{renderView()}</div>
      </div>

      {assistant && <AssistantPanel onClose={() => setAssistant(false)} go={go} />}
      {searchOpen && <SearchPalette onClose={() => setSearchOpen(false)} go={go} />}
      <style>{`@media(max-width:680px){.hide-sm{display:none}}`}</style>
    </div>
  );
}

function NotifDropdown({ onClose }) {
  return (
    <>
      <div style={{ position: 'fixed', inset: 0, zIndex: 60 }} onClick={onClose} />
      <div className="glass" style={{ position: 'absolute', top: 48, right: 0, width: 320, zIndex: 70, padding: 8, boxShadow: '0 20px 50px -20px rgba(0,0,0,0.7)', animation: 'pageIn .2s' }}>
        <div style={{ padding: '10px 12px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <span style={{ fontWeight: 600, fontSize: 13.5 }}>Notifications</span><span className="tag tag-critical">{NOTIFS.length} new</span>
        </div>
        {NOTIFS.map((n, i) => (
          <div key={i} style={{ display: 'flex', gap: 11, padding: 11, borderRadius: 10, cursor: 'pointer' }} onMouseEnter={e => e.currentTarget.style.background = 'var(--panel)'} onMouseLeave={e => e.currentTarget.style.background = 'transparent'}>
            <div style={{ width: 30, height: 30, flex: 'none', borderRadius: 8, display: 'grid', placeItems: 'center', color: `var(--${n.tone})`, background: `color-mix(in srgb, var(--${n.tone}) 12%, transparent)` }}>{Ia(n.icon, { style: { width: 15, height: 15 } })}</div>
            <div><div style={{ fontSize: 12.5, lineHeight: 1.4 }}>{n.t}</div><div className="mono" style={{ fontSize: 10, color: 'var(--text-3)', marginTop: 2 }}>{n.time}</div></div>
          </div>
        ))}
      </div>
    </>
  );
}

const SEARCH_RESULTS = [
  { type: 'Citizen', label: 'Ahmed Khan', sub: 'CNIC 35202-•••-7 · Critical', route: 'audit', risk: 'critical' },
  { type: 'Citizen', label: 'Imran Sethi', sub: 'CNIC 42101-•••-1 · Critical', route: 'audit', risk: 'critical' },
  { type: 'Vehicle', label: 'LEA-2000 · Land Cruiser', sub: '4600cc · linked to Ahmed Khan', route: 'graph' },
  { type: 'Property', label: 'DHA Phase 6 Villa', sub: '2 Kanal · Lahore', route: 'graph' },
  { type: 'Utility', label: 'K-Electric A/C 8841', sub: 'PKR 312,400 / mo', route: 'graph' },
];
function SearchPalette({ onClose, go }) {
  const [q, setQ] = useA('');
  const inputRef = useRA();
  useEA(() => { inputRef.current && inputRef.current.focus(); }, []);
  const filtered = SEARCH_RESULTS.filter(r => `${r.label} ${r.sub} ${r.type}`.toLowerCase().includes(q.toLowerCase()));
  return (
    <div className="drawer-scrim" style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'center', paddingTop: '12vh' }} onClick={onClose}>
      <div className="glass" style={{ width: 600, maxWidth: '92vw', overflow: 'hidden', boxShadow: '0 30px 80px -20px rgba(0,0,0,0.8)' }} onClick={e => e.stopPropagation()}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '16px 20px', borderBottom: '1px solid var(--panel-border)' }}>
          {Ia('search', { style: { width: 18, height: 18, color: 'var(--green)' } })}
          <input ref={inputRef} value={q} onChange={e => setQ(e.target.value)} placeholder="Search by CNIC, name, property ID, vehicle number, utility account…"
            style={{ flex: 1, background: 'none', border: 'none', outline: 'none', color: 'var(--text)', fontSize: 15, fontFamily: 'var(--font-body)' }} />
          <button className="icon-btn" style={{ width: 28, height: 28 }} title="Voice search">{Ia('mic', { style: { width: 15, height: 15 } })}</button>
          <span className="kbd">ESC</span>
        </div>
        <div style={{ maxHeight: 360, overflowY: 'auto', padding: 8 }}>
          <div style={{ fontSize: 10.5, color: 'var(--text-3)', textTransform: 'uppercase', letterSpacing: '0.12em', padding: '8px 12px', fontFamily: 'var(--font-mono)' }}>{q ? 'Results' : 'Suggested'}</div>
          {filtered.map((r, i) => (
            <div key={i} onClick={() => { go(r.route); onClose(); }} style={{ display: 'flex', alignItems: 'center', gap: 13, padding: '11px 12px', borderRadius: 10, cursor: 'pointer' }}
              onMouseEnter={e => e.currentTarget.style.background = 'var(--panel)'} onMouseLeave={e => e.currentTarget.style.background = 'transparent'}>
              <div style={{ width: 34, height: 34, flex: 'none', borderRadius: 9, display: 'grid', placeItems: 'center', color: r.risk ? `var(--${r.risk})` : 'var(--blue)', background: r.risk ? `color-mix(in srgb,var(--${r.risk}) 12%,transparent)` : 'rgba(46,143,255,0.1)' }}>{Ia(r.risk ? 'user' : 'search', { style: { width: 16, height: 16 } })}</div>
              <div style={{ flex: 1 }}><div style={{ fontSize: 13.5, fontWeight: 500 }}>{r.label}</div><div className="mono" style={{ fontSize: 11, color: 'var(--text-3)' }}>{r.sub}</div></div>
              <span className="tag tag-info">{r.type}</span>
            </div>
          ))}
          {!filtered.length && <div style={{ padding: 30, textAlign: 'center', color: 'var(--text-3)', fontSize: 13 }}>No entities match “{q}”.</div>}
        </div>
      </div>
    </div>
  );
}

const ASSIST_SEED = [
  { from: 'ai', text: 'Assalam-o-Alaikum. I am the TaxNet investigation copilot. Ask me about any citizen, cluster or compliance trend.' },
];
const ASSIST_REPLIES = {
  default: 'Based on the graph, this entity shows a compliance deviation of 94/100 driven primarily by an income–lifestyle mismatch. Would you like me to draft a Section 122(5A) notice?',
  flag: 'I found 14 newly-flagged Critical entities in the last hour, concentrated in Lahore and Karachi. The top recovery opportunity is Ahmed Khan at ₨41.2M. Shall I open his investigation report?',
  recover: 'Estimated national recovery potential across all flagged entities is ₨1.84T. Punjab accounts for 41% of the leakage. Want a regional breakdown?',
};
function AssistantPanel({ onClose, go }) {
  const [msgs, setMsgs] = useA(ASSIST_SEED);
  const [input, setInput] = useA('');
  const [typing, setTyping] = useA(false);
  const bodyRef = useRA();
  useEA(() => { if (bodyRef.current) bodyRef.current.scrollTop = bodyRef.current.scrollHeight; }, [msgs, typing]);
  const send = (text) => {
    const t = text || input; if (!t.trim()) return;
    setMsgs(m => [...m, { from: 'user', text: t }]); setInput(''); setTyping(true);
    setTimeout(() => {
      const key = /flag|critical|new/i.test(t) ? 'flag' : /recover|leak|revenue|potential/i.test(t) ? 'recover' : 'default';
      setTyping(false); setMsgs(m => [...m, { from: 'ai', text: ASSIST_REPLIES[key] }]);
    }, 1100);
  };
  const chips = ['Show new flags', 'Recovery potential', 'Explain Ahmed Khan'];
  return (
    <>
      <div className="drawer-scrim" onClick={onClose} />
      <div className="drawer">
        <div className="drawer-head">
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <div style={{ width: 38, height: 38, borderRadius: 11, background: 'linear-gradient(135deg,var(--green),var(--blue))', display: 'grid', placeItems: 'center', color: '#04070D' }}>{Ia('bot')}</div>
            <div><div style={{ fontFamily: 'var(--font-display)', fontWeight: 600, fontSize: 15 }}>TaxNet Copilot</div><div style={{ fontSize: 11, color: 'var(--green)', display: 'flex', alignItems: 'center', gap: 6 }}><span className="dot-pulse" />online · GNN v4.2</div></div>
          </div>
          <button className="icon-btn" style={{ width: 32, height: 32 }} onClick={onClose}>{Ia('close')}</button>
        </div>
        <div className="drawer-body" ref={bodyRef} style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
          {msgs.map((m, i) => (
            <div key={i} style={{ display: 'flex', justifyContent: m.from === 'user' ? 'flex-end' : 'flex-start' }}>
              <div style={{ maxWidth: '82%', padding: '11px 14px', borderRadius: m.from === 'user' ? '14px 14px 4px 14px' : '14px 14px 14px 4px', fontSize: 13, lineHeight: 1.55,
                background: m.from === 'user' ? 'linear-gradient(135deg,var(--blue),#1E6FE0)' : 'var(--panel-2)', color: m.from === 'user' ? '#fff' : 'var(--text)', border: m.from === 'ai' ? '1px solid var(--panel-border)' : 'none' }}>{m.text}</div>
            </div>
          ))}
          {typing && <div style={{ display: 'flex', gap: 5, padding: '11px 14px', background: 'var(--panel-2)', borderRadius: 14, width: 'fit-content', border: '1px solid var(--panel-border)' }}>
            {[0,1,2].map(i => <span key={i} style={{ width: 6, height: 6, borderRadius: '50%', background: 'var(--text-3)', animation: `blink 1.2s ${i*0.2}s infinite` }} />)}
          </div>}
        </div>
        <div style={{ padding: '12px 16px 8px', display: 'flex', gap: 7, flexWrap: 'wrap' }}>
          {chips.map(c => <button key={c} onClick={() => send(c)} style={{ fontSize: 11.5, padding: '6px 11px', borderRadius: 8, border: '1px solid var(--panel-border)', background: 'var(--panel)', color: 'var(--text-2)', cursor: 'pointer' }}>{c}</button>)}
        </div>
        <div style={{ padding: '8px 16px 18px', display: 'flex', gap: 10, alignItems: 'center' }}>
          <div className="search-box" style={{ flex: 1, maxWidth: 'none' }}>
            <input value={input} onChange={e => setInput(e.target.value)} onKeyDown={e => e.key === 'Enter' && send()} placeholder="Ask the copilot…" />
            <button className="icon-btn" style={{ width: 26, height: 26, border: 'none', background: 'none' }}>{Ia('mic', { style: { width: 15, height: 15 } })}</button>
          </div>
          <button className="btn btn-primary" style={{ padding: '11px 13px' }} onClick={() => send()}>{Ia('send')}</button>
        </div>
        <style>{`@keyframes blink{0%,60%,100%{opacity:.25;transform:translateY(0)}30%{opacity:1;transform:translateY(-3px)}}`}</style>
      </div>
    </>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);

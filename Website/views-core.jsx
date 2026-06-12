// ===== TaxNet AI — Core views =====
const { useState: useS, useEffect: useE } = React;
const I = (name, props) => React.createElement(Icons[name], props);

// ---------- shared bits ----------
function StatStrip() {
  const items = [
    { k: '5', v: 'Linked databases' }, { k: '62M+', v: 'Resolved entities' },
    { k: '94.2%', v: 'Model precision' }, { k: '₨1.84T', v: 'Recovery potential' },
  ];
  return (
    <div style={{ display: 'flex', gap: 0, flexWrap: 'wrap', borderTop: '1px solid var(--panel-border)', marginTop: 8 }}>
      {items.map((it, i) => (
        <div key={i} style={{ flex: 1, minWidth: 140, padding: '20px 22px', borderRight: i < items.length-1 ? '1px solid var(--panel-border)' : 'none' }}>
          <div className="mono" style={{ fontSize: 25, fontWeight: 600, color: 'var(--text)', letterSpacing: '-0.01em' }}>{it.k}</div>
          <div style={{ fontSize: 12, color: 'var(--text-3)', marginTop: 4 }}>{it.v}</div>
        </div>
      ))}
    </div>
  );
}

// ---------- Landing / Hero ----------
function Landing({ go }) {
  return (
    <div className="page" style={{ maxWidth: 1280 }}>
      <div className="glass" style={{ position: 'relative', overflow: 'hidden', borderRadius: 'var(--r-xl)', padding: '0' }}>
        <div style={{ position: 'absolute', inset: 0 }}><NetworkBackground density={70} /></div>
        <div style={{ position: 'absolute', inset: 0, background: 'radial-gradient(800px 460px at 72% 0%, rgba(76,141,246,0.10), transparent 62%), radial-gradient(620px 540px at 0% 100%, rgba(37,201,140,0.07), transparent 58%)' }} />
        <div style={{ position: 'relative', padding: '64px 60px 52px', maxWidth: 760 }}>
          <div className="eyebrow" style={{ marginBottom: 20 }}>FBR · National Tax Intelligence Platform</div>
          <h1 style={{ fontFamily: 'var(--font-display)', fontSize: 'clamp(32px, 4.2vw, 52px)', lineHeight: 1.08, letterSpacing: '-0.025em', fontWeight: 600, color: 'var(--text)' }}>
            Graph AI for Broadening<br />the <span style={{ color: 'var(--green)' }}>National Tax Net</span>
          </h1>
          <p style={{ fontSize: 16, color: 'var(--text-2)', lineHeight: 1.6, marginTop: 20, maxWidth: 560 }}>
            An explainable knowledge-graph engine that fuses vehicle, property, utility, travel and tax records to surface non-filers, resolve hidden identities and score compliance deviation in real time.
          </p>
          <div style={{ display: 'flex', gap: 12, marginTop: 34, flexWrap: 'wrap' }}>
            <button className="btn btn-primary" onClick={() => go('graph')}>{I('graph')} Explore Knowledge Graph</button>
            <button className="btn btn-blue" onClick={() => go('audit')}>{I('spark')} Run Tax Investigation</button>
            <button className="btn btn-ghost" onClick={() => go('analytics')}>{I('trend')} View Analytics</button>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 30, fontSize: 12, color: 'var(--text-3)' }}>
            <span className="dot-pulse" /> Live ingestion · 5 databases connected · last sync 14s ago
          </div>
        </div>
        <StatStrip />
      </div>

      <div className="grid" style={{ gridTemplateColumns: 'repeat(3, 1fr)', marginTop: 18 }}>
        {[
          { t: 'Entity Resolution', d: 'Collapse millions of fragmented records into single canonical citizens with confidence scoring.', ic: 'entity', go: 'entity' },
          { t: 'Explainable AI', d: 'Every flag ships with a step-by-step reasoning trail, evidence sources and recommendation.', ic: 'audit', go: 'audit' },
          { t: 'Risk Scoring', d: 'GNN-driven compliance deviation scores rank where recovery potential is highest.', ic: 'risk', go: 'risk' },
        ].map((f, i) => (
          <div key={i} className="card" style={{ cursor: 'pointer' }} onClick={() => go(f.go)}>
            <div style={{ width: 42, height: 42, borderRadius: 12, background: 'var(--panel-2)', border: '1px solid var(--panel-border)', display: 'grid', placeItems: 'center', color: 'var(--green)', marginBottom: 14 }}>{I(f.ic)}</div>
            <div style={{ fontFamily: 'var(--font-display)', fontSize: 17, fontWeight: 600 }}>{f.t}</div>
            <p style={{ fontSize: 13, color: 'var(--text-2)', marginTop: 8, lineHeight: 1.5 }}>{f.d}</p>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6, color: 'var(--green)', fontSize: 12.5, fontWeight: 600, marginTop: 14 }}>Open module {I('arrowRight')}</div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ---------- KPI card ----------
function KpiCard({ k, i }) {
  const accentMap = { blue: 'var(--blue)', green: 'var(--green)', high: 'var(--high)', critical: 'var(--critical)' };
  const col = accentMap[k.accent];
  const up = k.delta >= 0;
  return (
    <div className="card fade-up" style={{ animationDelay: `${i * 0.06}s`, overflow: 'hidden' }}>
      <div style={{ position: 'absolute', top: 0, left: 0, right: 0, height: 2, background: col, opacity: 0.7 }} />
      <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between' }}>
        <div style={{ width: 38, height: 38, borderRadius: 10, display: 'grid', placeItems: 'center', color: col, background: `color-mix(in srgb, ${col} 12%, transparent)` }}>{I(k.icon)}</div>
        <div className={`tag ${up ? 'tag-low' : 'tag-critical'}`} style={{ background: up ? 'rgba(0,229,153,0.12)' : 'rgba(255,77,109,0.12)' }}>
          {I(up ? 'arrowUp' : 'arrowDown', { style: { width: 11, height: 11 } })} {Math.abs(k.delta)}%
        </div>
      </div>
      <div className="mono" style={{ fontSize: 30, fontWeight: 700, marginTop: 16, letterSpacing: '-0.02em' }}>
        <AnimatedCounter value={k.value} fmt={k.fmt} />
      </div>
      <div style={{ fontSize: 12.5, color: 'var(--text-2)', marginTop: 4 }}>{k.label}</div>
      <div style={{ marginTop: 14 }}><Sparkline data={k.spark} color={col} w={220} h={34} /></div>
    </div>
  );
}

// ---------- Dashboard ----------
function Dashboard({ go }) {
  return (
    <div className="page">
      <div className="page-head">
        <div>
          <div className="eyebrow">Operations Command</div>
          <h1 className="page-title">Dashboard Overview</h1>
          <p className="page-desc">Real-time view of national compliance posture across all linked data sources.</p>
        </div>
        <div style={{ display: 'flex', gap: 10 }}>
          <button className="btn btn-ghost" onClick={() => go('reports')}>{I('download')} Export</button>
          <button className="btn btn-primary" onClick={() => go('audit')}>{I('spark')} New Investigation</button>
        </div>
      </div>

      <div className="grid" style={{ gridTemplateColumns: 'repeat(3, 1fr)' }}>
        {KPIS.map((k, i) => <KpiCard key={k.id} k={k} i={i} />)}
      </div>

      <div className="grid" style={{ gridTemplateColumns: '1.6fr 1fr', marginTop: 18 }}>
        <div className="card">
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 6 }}>
            <div><div style={{ fontFamily: 'var(--font-display)', fontSize: 16, fontWeight: 600 }}>Filer vs Non-Filer Trend</div>
            <div style={{ fontSize: 12, color: 'var(--text-3)', marginTop: 2 }}>Share of analysed population · 12 months</div></div>
            <div style={{ display: 'flex', gap: 14 }}>
              <Legend c="var(--green)" t="Active filers" /><Legend c="var(--high)" t="Non-filers" />
            </div>
          </div>
          <LineChart labels={TREND_MONTHS} height={236} series={[
            { data: TREND_FILED, color: 'var(--green)' },
            { data: TREND_NONFILER, color: 'var(--high)' },
          ]} />
        </div>
        <div className="card">
          <div style={{ fontFamily: 'var(--font-display)', fontSize: 16, fontWeight: 600, marginBottom: 18 }}>Risk Distribution</div>
          <DonutChart data={RIST_OR_RISK()} size={170} centerLabel="318K" centerSub="HIGH+CRITICAL" />
        </div>
      </div>

      <div className="grid" style={{ gridTemplateColumns: '1fr 1.4fr', marginTop: 18 }}>
        <div className="card">
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 16 }}>
            <div style={{ fontFamily: 'var(--font-display)', fontSize: 16, fontWeight: 600 }}>Live Alert Feed</div>
            <span className="dot-pulse" />
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            {NOTIFS.map((n, i) => (
              <div key={i} style={{ display: 'flex', gap: 12, alignItems: 'flex-start' }}>
                <div style={{ width: 32, height: 32, flex: 'none', borderRadius: 9, display: 'grid', placeItems: 'center', color: `var(--${n.tone})`, background: `color-mix(in srgb, var(--${n.tone}) 12%, transparent)` }}>{I(n.icon)}</div>
                <div><div style={{ fontSize: 13, fontWeight: 500 }}>{n.t}</div><div className="mono" style={{ fontSize: 10.5, color: 'var(--text-3)', marginTop: 2 }}>{n.time}</div></div>
              </div>
            ))}
          </div>
        </div>
        <div className="card" style={{ padding: 0, overflow: 'hidden', position: 'relative', minHeight: 280 }}>
          <div style={{ position: 'absolute', top: 16, left: 18, zIndex: 2 }}>
            <div style={{ fontFamily: 'var(--font-display)', fontSize: 16, fontWeight: 600 }}>Network Snapshot</div>
            <div style={{ fontSize: 12, color: 'var(--text-3)', marginTop: 2 }}>Top flagged cluster · Ahmed Khan</div>
          </div>
          <button className="btn btn-ghost" style={{ position: 'absolute', top: 14, right: 14, zIndex: 2, padding: '8px 12px', fontSize: 12 }} onClick={() => go('graph')}>{I('zoom')} Open</button>
          <MiniGraphPreview />
        </div>
      </div>
    </div>
  );
}
function RIST_OR_RISK() { return RISK_DIST; }
function Legend({ c, t }) { return <div style={{ display: 'flex', alignItems: 'center', gap: 7, fontSize: 12, color: 'var(--text-2)' }}><span style={{ width: 9, height: 9, borderRadius: 3, background: c }} />{t}</div>; }

function MiniGraphPreview() {
  return <div style={{ position: 'absolute', inset: 0 }}><NetworkBackground density={40} opacity={0.8} /></div>;
}

// ---------- Knowledge Graph View ----------
function KnowledgeGraphView() {
  const [sel, setSel] = useS(null);
  const [filter, setFilter] = useS('all');
  const [query, setQuery] = useS('');
  return (
    <div className="page" style={{ maxWidth: '100%', paddingBottom: 24 }}>
      <div className="page-head" style={{ marginBottom: 16 }}>
        <div>
          <div className="eyebrow">Graph Intelligence</div>
          <h1 className="page-title">Knowledge Graph</h1>
        </div>
        <div style={{ display: 'flex', gap: 10, alignItems: 'center', flexWrap: 'wrap' }}>
          <div className="search-box" style={{ display: 'flex', maxWidth: 260 }}>
            {I('search')}<input placeholder="Search nodes…" value={query} onChange={e => setQuery(e.target.value)} />
          </div>
        </div>
      </div>

      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginBottom: 14 }}>
        <Chip active={filter === 'all'} onClick={() => setFilter('all')} label="All entities" />
        {Object.entries(GRAPH_TYPES).map(([k, v]) => (
          <Chip key={k} active={filter === k} onClick={() => setFilter(k)} label={v.label} color={v.color} icon={v.icon} />
        ))}
      </div>

      <div className="glass" style={{ position: 'relative', height: 'calc(100vh - 280px)', minHeight: 460, overflow: 'hidden', borderRadius: 'var(--r-lg)' }}>
        <div style={{ position: 'absolute', inset: 0, opacity: 0.5 }}><NetworkBackground density={28} opacity={0.5} /></div>
        <KnowledgeGraph onSelect={setSel} selectedId={sel?.id} filter={filter} query={query} />
        <div style={{ position: 'absolute', left: 14, top: 14, fontSize: 11, color: 'var(--text-3)', fontFamily: 'var(--font-mono)', display: 'flex', gap: 14 }}>
          <span>scroll · zoom</span><span>drag · pan</span><span>click · inspect</span>
        </div>
        {sel && <NodePanel node={sel} onClose={() => setSel(null)} />}
      </div>
    </div>
  );
}

function Chip({ active, onClick, label, color, icon }) {
  return (
    <button onClick={onClick} style={{
      display: 'inline-flex', alignItems: 'center', gap: 8, padding: '8px 13px', borderRadius: 9, cursor: 'pointer',
      border: `1px solid ${active ? (color || 'var(--green)') : 'var(--panel-border)'}`,
      background: active ? `color-mix(in srgb, ${color || 'var(--green)'} 14%, transparent)` : 'var(--panel)',
      color: active ? (color || 'var(--green)') : 'var(--text-2)', fontSize: 12.5, fontWeight: 500, fontFamily: 'var(--font-body)', transition: 'all .15s',
    }}>
      {icon && <span style={{ width: 8, height: 8, borderRadius: '50%', background: color }} />}{label}
    </button>
  );
}

function NodePanel({ node, onClose }) {
  const meta = GRAPH_TYPES[node.type];
  const conns = GRAPH_EDGES.filter(e => e.a === node.id || e.b === node.id).map(e => {
    const oid = e.a === node.id ? e.b : e.a; const o = GRAPH_NODES.find(n => n.id === oid); return { o, label: e.label };
  });
  return (
    <div style={{ position: 'absolute', top: 14, right: 14, bottom: 14, width: 320, maxWidth: '85%', zIndex: 5,
      background: 'rgba(10,15,26,0.86)', backdropFilter: 'blur(20px)', border: '1px solid var(--panel-border-2)', borderRadius: 'var(--r-lg)',
      display: 'flex', flexDirection: 'column', animation: 'slideIn .3s cubic-bezier(.2,.8,.2,1)', boxShadow: '-20px 0 50px -20px rgba(0,0,0,0.6)' }}>
      <div style={{ padding: 18, borderBottom: '1px solid var(--panel-border)', display: 'flex', alignItems: 'flex-start', gap: 12 }}>
        <div style={{ width: 44, height: 44, borderRadius: 12, display: 'grid', placeItems: 'center', color: meta.color, background: `color-mix(in srgb, ${meta.color} 14%, transparent)`, border: `1px solid ${meta.color}55` }}>{I(meta.icon)}</div>
        <div style={{ flex: 1 }}>
          <div style={{ fontFamily: 'var(--font-display)', fontSize: 16, fontWeight: 600 }}>{node.label}</div>
          <div className="mono" style={{ fontSize: 11, color: 'var(--text-3)', marginTop: 2 }}>{node.sub}</div>
        </div>
        <button className="icon-btn" style={{ width: 30, height: 30 }} onClick={onClose}>{I('close')}</button>
      </div>
      <div style={{ padding: 18, overflowY: 'auto' }}>
        <div style={{ display: 'flex', gap: 8, marginBottom: 16 }}>
          <span className="tag tag-info">{meta.label}</span>
          {node.risk && <span className={`tag tag-${node.risk === 'med' ? 'med' : node.risk}`}>{node.risk.toUpperCase()} RISK</span>}
        </div>
        <div style={{ fontSize: 11, color: 'var(--text-3)', textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: 10, fontFamily: 'var(--font-mono)' }}>Connections · {conns.length}</div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {conns.map((c, i) => c.o && (
            <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: 10, borderRadius: 10, background: 'var(--panel)', border: '1px solid var(--panel-border)' }}>
              <span style={{ width: 8, height: 8, borderRadius: '50%', background: GRAPH_TYPES[c.o.type].color, flex: 'none' }} />
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 12.5, fontWeight: 500, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{c.o.label}</div>
                <div className="mono" style={{ fontSize: 10, color: 'var(--text-3)' }}>{c.label}</div>
              </div>
              {I('arrowRight', { style: { width: 14, height: 14, color: 'var(--text-3)' } })}
            </div>
          ))}
        </div>
        <button className="btn btn-ghost" style={{ width: '100%', justifyContent: 'center', marginTop: 16 }}>{I('eye')} Open full profile</button>
      </div>
    </div>
  );
}

Object.assign(window, { Landing, Dashboard, KnowledgeGraphView, KpiCard, Chip });

// ===== TaxNet AI — Detail views =====
const { useState: useSd, useEffect: useEd, useRef: useRd } = React;
const Id = (n, p) => React.createElement(Icons[n], p);

function PageHead({ eyebrow, title, desc, actions }) {
  return (
    <div className="page-head">
      <div>
        <div className="eyebrow">{eyebrow}</div>
        <h1 className="page-title">{title}</h1>
        {desc && <p className="page-desc">{desc}</p>}
      </div>
      {actions}
    </div>
  );
}

// ---------- Entity Resolution ----------
function EntityResolution() {
  const [active, setActive] = useSd(0);
  return (
    <div className="page">
      <PageHead eyebrow="Identity Fusion" title="Entity Resolution"
        desc="AI links fragmented identities across five national databases into a single canonical citizen."
        actions={<button className="btn btn-primary">{Id('entity')} Resolve new entity</button>} />

      <div className="grid" style={{ gridTemplateColumns: '1.1fr 1fr' }}>
        <div className="card">
          <div style={{ fontFamily: 'var(--font-display)', fontSize: 16, fontWeight: 600, marginBottom: 4 }}>Input Data Sources</div>
          <div style={{ fontSize: 12, color: 'var(--text-3)', marginBottom: 18 }}>62 raw records fused · canonical entity #CE-77412</div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {ER_SOURCES.map((s, i) => (
              <div key={i} onClick={() => setActive(i)} style={{ cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 13, padding: 13, borderRadius: 12,
                border: `1px solid ${active === i ? 'var(--green)' : 'var(--panel-border)'}`, background: active === i ? 'rgba(0,229,153,0.06)' : 'var(--panel)', transition: 'all .15s' }}>
                <div style={{ width: 38, height: 38, flex: 'none', borderRadius: 10, display: 'grid', placeItems: 'center', color: 'var(--cyan)', background: 'color-mix(in srgb, var(--cyan) 12%, transparent)' }}>{Id(s.icon)}</div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: 13.5, fontWeight: 500 }}>{s.name}</div>
                  <div className="mono" style={{ fontSize: 10.5, color: 'var(--text-3)' }}>{s.key} · {s.records} records</div>
                </div>
                <div style={{ textAlign: 'right' }}>
                  <div className="mono" style={{ fontSize: 14, fontWeight: 700, color: s.match > 95 ? 'var(--green)' : 'var(--med)' }}>{s.match}%</div>
                  <span className={`tag ${s.status === 'matched' ? 'tag-low' : 'tag-med'}`} style={{ marginTop: 3, fontSize: 9.5, padding: '2px 6px' }}>{s.status === 'matched' ? 'MATCHED' : 'REVIEW'}</span>
                </div>
              </div>
            ))}
          </div>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 18 }}>
          <div className="card" style={{ textAlign: 'center' }}>
            <div style={{ fontFamily: 'var(--font-display)', fontSize: 16, fontWeight: 600, marginBottom: 16 }}>Identity Match Confidence</div>
            <ConfidenceRing value={97.4} />
            <div style={{ display: 'flex', justifyContent: 'space-around', marginTop: 18, gap: 10 }}>
              <MiniStat label="Records fused" value="62" />
              <MiniStat label="Duplicates removed" value="9" color="var(--high)" />
              <MiniStat label="Databases" value="5" color="var(--blue)" />
            </div>
          </div>
          <div className="card">
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 12 }}>
              {Id('spark', { style: { width: 16, height: 16, color: 'var(--green)' } })}
              <div style={{ fontFamily: 'var(--font-display)', fontSize: 15, fontWeight: 600 }}>AI Matching Explanation</div>
            </div>
            <p style={{ fontSize: 13, color: 'var(--text-2)', lineHeight: 2.05 }}>
              The <b style={{ color: 'var(--text)' }}>{ER_SOURCES[active].name}</b> record was linked using a fuzzy match on
              <span className="tag tag-info" style={{ margin: '0 4px' }}>CNIC</span>
              <span className="tag tag-info" style={{ margin: '0 4px' }}>name + father</span> and a
              <span className="tag tag-info" style={{ margin: '0 4px' }}>shared address</span>
              embedding. Cross-database co-occurrence raised confidence to <b style={{ color: 'var(--green)' }}>{ER_SOURCES[active].match}%</b>, above the 92% auto-merge threshold.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
function MiniStat({ label, value, color = 'var(--text)' }) {
  return <div><div className="mono" style={{ fontSize: 22, fontWeight: 700, color }}>{value}</div><div style={{ fontSize: 10.5, color: 'var(--text-3)', marginTop: 2 }}>{label}</div></div>;
}
function ConfidenceRing({ value }) {
  const [v, setV] = useSd(0);
  useEd(() => { const t = setTimeout(() => setV(value), 200); return () => clearTimeout(t); }, []);
  const r = 64, c = 2 * Math.PI * r;
  return (
    <div style={{ position: 'relative', width: 160, height: 160, margin: '0 auto' }}>
      <svg width="160" height="160" style={{ transform: 'rotate(-90deg)' }}>
        <circle cx="80" cy="80" r={r} fill="none" stroke="rgba(255,255,255,0.07)" strokeWidth="12" />
        <circle cx="80" cy="80" r={r} fill="none" stroke="var(--green)" strokeWidth="12" strokeLinecap="round"
          strokeDasharray={`${(v/100)*c} ${c}`} style={{ transition: 'stroke-dasharray 1.4s cubic-bezier(.3,.8,.3,1)', filter: 'drop-shadow(0 0 8px var(--green-glow))' }} />
      </svg>
      <div style={{ position: 'absolute', inset: 0, display: 'grid', placeItems: 'center' }}>
        <div><div className="mono" style={{ fontSize: 30, fontWeight: 700, color: 'var(--green)' }}>{v.toFixed(1)}%</div>
        <div style={{ fontSize: 10, color: 'var(--text-3)', marginTop: 2 }}>match score</div></div>
      </div>
    </div>
  );
}

// ---------- Risk Analysis ----------
function RiskAnalysis() {
  return (
    <div className="page">
      <PageHead eyebrow="Compliance Deviation" title="Risk Analysis"
        desc="GNN-derived deviation score weighs lifestyle signals against declared income."
        actions={<button className="btn btn-ghost">{Id('filter')} Filter cohort</button>} />

      <div className="grid" style={{ gridTemplateColumns: '320px 1fr' }}>
        <div className="card" style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}>
          <RiskMeter value={94} />
          <div style={{ display: 'flex', gap: 8, marginTop: 22, flexWrap: 'wrap', justifyContent: 'center' }}>
            {[['Low','low'],['Medium','med'],['High','high'],['Critical','critical']].map(([l, t]) => (
              <span key={t} className={`tag tag-${t}`}>{l}</span>
            ))}
          </div>
        </div>
        <div className="card">
          <div style={{ fontFamily: 'var(--font-display)', fontSize: 16, fontWeight: 600, marginBottom: 4 }}>Factors Influencing Risk</div>
          <div style={{ fontSize: 12, color: 'var(--text-3)', marginBottom: 18 }}>Citizen: Ahmed Khan · CNIC 35202-•••-7</div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
            {RISK_FACTORS.map((f, i) => (
              <div key={i}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 7 }}>
                  <span style={{ color: `var(--${f.sev})`, flex: 'none' }}>{Id(f.icon, { style: { width: 16, height: 16 } })}</span>
                  <span style={{ fontSize: 13, fontWeight: 500, flex: 1, minWidth: 0 }}>{f.label}</span>
                  <span className="mono" style={{ fontSize: 11, color: 'var(--text-3)', whiteSpace: 'nowrap', flex: 'none' }}>{f.detail}</span>
                  <span className="mono" style={{ fontSize: 13, fontWeight: 700, color: `var(--${f.sev})`, width: 28, textAlign: 'right', flex: 'none' }}>{f.weight}</span>
                </div>
                <div style={{ height: 7, borderRadius: 6, background: 'rgba(255,255,255,0.06)', overflow: 'hidden' }}>
                  <div style={{ height: '100%', width: `${f.weight}%`, borderRadius: 6, background: `var(--${f.sev})`, boxShadow: `0 0 12px var(--${f.sev})` }} />
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      <div className="grid" style={{ gridTemplateColumns: '1fr 1fr', marginTop: 18 }}>
        <div className="card">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
            <div style={{ fontFamily: 'var(--font-display)', fontSize: 16, fontWeight: 600 }}>Regional Risk Heatmap</div>
            <div style={{ fontSize: 11, color: 'var(--text-3)', fontFamily: 'var(--font-mono)' }}>district × sector</div>
          </div>
          <Heatmap rows={6} cols={16} />
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 16, fontSize: 11, color: 'var(--text-3)' }}>
            <span>Low</span>
            <div style={{ flex: 1, height: 6, borderRadius: 4, background: 'linear-gradient(90deg,#00E599,#FFC94D,#FF8A3D,#FF4D6D)' }} />
            <span>Critical</span>
          </div>
        </div>
        <div className="card">
          <div style={{ fontFamily: 'var(--font-display)', fontSize: 16, fontWeight: 600, marginBottom: 18 }}>Cohort Risk Mix</div>
          <DonutChart data={RISK_DIST} size={170} centerLabel="6%" centerSub="CRITICAL" />
        </div>
      </div>
    </div>
  );
}

// ---------- Explainable AI / Audit Trail ----------
function AuditTrail() {
  return (
    <div className="page">
      <PageHead eyebrow="Explainable AI" title="Investigation Report"
        desc="Every flag is fully auditable — reasoning, evidence and recommendation in one trail."
        actions={<div style={{ display: 'flex', gap: 10 }}><button className="btn btn-ghost">{Id('download')} Download PDF</button><button className="btn btn-primary">{Id('flag')} Issue notice</button></div>} />

      <div className="grid" style={{ gridTemplateColumns: '1fr 360px' }}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 18 }}>
          <div className="card" style={{ display: 'flex', alignItems: 'center', gap: 18, flexWrap: 'wrap' }}>
            <div style={{ width: 64, height: 64, borderRadius: 16, background: 'linear-gradient(135deg,var(--critical),var(--high))', display: 'grid', placeItems: 'center', fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 24, color: '#fff', flex: 'none' }}>AK</div>
            <div style={{ flex: 1, minWidth: 180 }}>
              <div style={{ fontFamily: 'var(--font-display)', fontSize: 22, fontWeight: 600 }}>Ahmed Khan</div>
              <div className="mono" style={{ fontSize: 12, color: 'var(--text-3)', marginTop: 3 }}>CNIC 35202-•••-7 · Lahore · Non-Filer</div>
            </div>
            <div style={{ textAlign: 'center' }}>
              <div className="mono" style={{ fontSize: 32, fontWeight: 700, color: 'var(--critical)' }}>94</div>
              <div style={{ fontSize: 10, color: 'var(--text-3)' }}>deviation</div>
            </div>
            <span className="tag tag-critical" style={{ fontSize: 12, padding: '6px 12px' }}>CRITICAL · AUDIT</span>
          </div>

          <div className="card">
            <div style={{ fontFamily: 'var(--font-display)', fontSize: 16, fontWeight: 600, marginBottom: 14 }}>Why was this citizen flagged?</div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
              {[
                ['car', 'Owns 4600cc + 3000cc vehicles'],
                ['bolt', 'Electricity bill: PKR 312,400 / mo'],
                ['plane', '11 foreign trips in 18 months'],
                ['doc', 'Declared tax: PKR 0'],
              ].map(([ic, txt], i) => (
                <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 11, padding: 13, borderRadius: 11, background: 'var(--panel)', border: '1px solid var(--panel-border)' }}>
                  <span style={{ width: 28, height: 28, flex: 'none', borderRadius: 8, display: 'grid', placeItems: 'center', color: 'var(--critical)', background: 'rgba(255,77,109,0.12)' }}>{Id('check', { style: { width: 15, height: 15 } })}</span>
                  <span style={{ fontSize: 12.5 }}>{txt}</span>
                </div>
              ))}
            </div>
          </div>

          <div className="card">
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 20 }}>
              {Id('spark', { style: { width: 18, height: 18, color: 'var(--green)' } })}
              <div style={{ fontFamily: 'var(--font-display)', fontSize: 16, fontWeight: 600 }}>AI Reasoning Timeline</div>
            </div>
            <div style={{ position: 'relative', paddingLeft: 8 }}>
              {AI_TIMELINE.map((s, i) => (
                <div key={i} style={{ display: 'flex', gap: 16, paddingBottom: i < AI_TIMELINE.length - 1 ? 22 : 0, position: 'relative' }}>
                  {i < AI_TIMELINE.length - 1 && <div style={{ position: 'absolute', left: 17, top: 36, bottom: 0, width: 2, background: 'linear-gradient(var(--panel-border-2), transparent)' }} />}
                  <div style={{ width: 36, height: 36, flex: 'none', borderRadius: 10, display: 'grid', placeItems: 'center', color: `var(--${s.tone})`, background: `color-mix(in srgb, var(--${s.tone}) 14%, transparent)`, border: `1px solid color-mix(in srgb, var(--${s.tone}) 40%, transparent)`, zIndex: 1,
                    animation: `pageIn .5s ${i*0.12}s both` }}>{Id(s.icon, { style: { width: 17, height: 17 } })}</div>
                  <div style={{ animation: `pageIn .5s ${i*0.12+0.05}s both` }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                      <span style={{ fontSize: 13.5, fontWeight: 600 }}>{s.t}</span>
                      <span className="mono" style={{ fontSize: 10, color: 'var(--text-3)' }}>STEP {i + 1}</span>
                    </div>
                    <div style={{ fontSize: 12.5, color: 'var(--text-2)', marginTop: 4, lineHeight: 1.5 }}>{s.d}</div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 18 }}>
          <div className="card">
            <div style={{ fontFamily: 'var(--font-display)', fontSize: 15, fontWeight: 600, marginBottom: 14 }}>Confidence</div>
            <ConfidenceRing value={96.1} />
          </div>
          <div className="card">
            <div style={{ fontFamily: 'var(--font-display)', fontSize: 15, fontWeight: 600, marginBottom: 14 }}>Evidence Sources</div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 9 }}>
              {ER_SOURCES.map((s, i) => (
                <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 10, fontSize: 12.5 }}>
                  <span style={{ color: 'var(--cyan)' }}>{Id(s.icon, { style: { width: 15, height: 15 } })}</span>
                  <span style={{ flex: 1 }}>{s.name}</span>
                  <span className="mono" style={{ color: 'var(--text-3)', fontSize: 11 }}>{s.records}</span>
                </div>
              ))}
            </div>
          </div>
          <div className="card" style={{ background: 'linear-gradient(160deg, rgba(255,77,109,0.10), var(--panel))', borderColor: 'rgba(255,77,109,0.3)' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 10 }}>
              {Id('flag', { style: { width: 16, height: 16, color: 'var(--critical)' } })}
              <div style={{ fontFamily: 'var(--font-display)', fontSize: 15, fontWeight: 600 }}>Recommendation</div>
            </div>
            <p style={{ fontSize: 12.5, color: 'var(--text-2)', lineHeight: 1.55 }}>Issue a <b style={{ color: 'var(--text)' }}>Section 122(5A)</b> notice and assign field audit. Estimated recovery: <b style={{ color: 'var(--green)' }}>₨41.2M</b>.</p>
            <button className="btn btn-primary" style={{ width: '100%', justifyContent: 'center', marginTop: 14 }}>{Id('check')} Approve & assign</button>
          </div>
        </div>
      </div>
    </div>
  );
}

// ---------- Analytics ----------
function Analytics() {
  return (
    <div className="page">
      <PageHead eyebrow="Reporting" title="Analytics & Reporting"
        desc="Compliance trends, regional posture and revenue leakage across the tax net."
        actions={<button className="btn btn-ghost">{Id('download')} Export PDF</button>} />
      <div className="grid" style={{ gridTemplateColumns: '1.5fr 1fr' }}>
        <div className="card">
          <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 6 }}>
            <div style={{ fontFamily: 'var(--font-display)', fontSize: 16, fontWeight: 600 }}>Revenue Leakage Estimation</div>
            <Legend c="var(--blue)" t="₨ Billions" />
          </div>
          <LineChart labels={TREND_MONTHS} height={240} series={[{ data: LEAKAGE, color: 'var(--blue)' }]} />
        </div>
        <div className="card">
          <div style={{ fontFamily: 'var(--font-display)', fontSize: 16, fontWeight: 600, marginBottom: 18 }}>Fraud Detection Mix</div>
          <DonutChart data={RISK_DIST} size={168} centerLabel="18.4%" centerSub="FLAGGED" />
        </div>
      </div>
      <div className="grid" style={{ gridTemplateColumns: '1fr 1fr', marginTop: 18 }}>
        <div className="card">
          <div style={{ fontFamily: 'var(--font-display)', fontSize: 16, fontWeight: 600, marginBottom: 16 }}>Regional Compliance Index</div>
          <BarChart data={REGIONS.map(r => ({ label: r.label, value: r.value, color: r.value > 75 ? 'linear-gradient(180deg,var(--green),rgba(0,229,153,0.3))' : r.value > 50 ? 'linear-gradient(180deg,var(--med),rgba(255,201,77,0.3))' : 'linear-gradient(180deg,var(--high),rgba(255,138,61,0.3))' }))} height={200} />
        </div>
        <div className="card">
          <div style={{ fontFamily: 'var(--font-display)', fontSize: 16, fontWeight: 600, marginBottom: 6 }}>Tax Compliance Trend</div>
          <LineChart labels={TREND_MONTHS} height={200} series={[{ data: TREND_FILED, color: 'var(--green)' }]} />
        </div>
      </div>
    </div>
  );
}

// ---------- Reports / Upload + Leaderboard ----------
function Reports() {
  const [prog, setProg] = useSd(null);
  const [drag, setDrag] = useSd(false);
  const startUpload = () => {
    setProg(0);
    let p = 0; const iv = setInterval(() => { p += Math.random() * 14 + 4; if (p >= 100) { p = 100; clearInterval(iv); } setProg(Math.round(p)); }, 220);
  };
  return (
    <div className="page">
      <PageHead eyebrow="Ingestion & Outputs" title="Reports & Data Upload"
        desc="Bring new datasets into the graph and export investigation reports." />
      <div className="grid" style={{ gridTemplateColumns: '1fr 1fr' }}>
        <div className="card">
          <div style={{ fontFamily: 'var(--font-display)', fontSize: 16, fontWeight: 600, marginBottom: 16 }}>Data Upload</div>
          <div onClick={startUpload} onDragOver={e => { e.preventDefault(); setDrag(true); }} onDragLeave={() => setDrag(false)} onDrop={e => { e.preventDefault(); setDrag(false); startUpload(); }}
            style={{ border: `1.5px dashed ${drag ? 'var(--green)' : 'var(--panel-border-2)'}`, borderRadius: 16, padding: '38px 20px', textAlign: 'center', cursor: 'pointer', background: drag ? 'rgba(0,229,153,0.05)' : 'var(--panel)', transition: 'all .15s' }}>
            <div style={{ width: 52, height: 52, margin: '0 auto 14px', borderRadius: 14, display: 'grid', placeItems: 'center', color: 'var(--green)', background: 'rgba(0,229,153,0.1)' }}>{Id('upload', { style: { width: 24, height: 24 } })}</div>
            <div style={{ fontSize: 14, fontWeight: 600 }}>Drag & drop files to ingest</div>
            <div style={{ fontSize: 12, color: 'var(--text-3)', marginTop: 6 }}>or click to browse · CSV · Excel · JSON</div>
          </div>
          {prog !== null && (
            <div style={{ marginTop: 18 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 12, marginBottom: 7 }}>
                <span className="mono" style={{ color: 'var(--text-2)' }}>excise_punjab_q2.csv</span>
                <span className="mono" style={{ color: prog === 100 ? 'var(--green)' : 'var(--text-3)' }}>{prog === 100 ? 'Ingested ✓' : prog + '%'}</span>
              </div>
              <div style={{ height: 8, borderRadius: 6, background: 'rgba(255,255,255,0.07)', overflow: 'hidden' }}>
                <div style={{ height: '100%', width: `${prog}%`, borderRadius: 6, background: 'linear-gradient(90deg,var(--green),var(--blue))', transition: 'width .25s', boxShadow: '0 0 12px var(--green-glow)' }} />
              </div>
              {prog === 100 && <div style={{ fontSize: 12, color: 'var(--text-2)', marginTop: 10 }}>1.2M rows parsed · 48,210 new entities resolved · 312 duplicates merged.</div>}
            </div>
          )}
          <div style={{ display: 'flex', gap: 8, marginTop: 18 }}>
            {['CSV', 'XLSX', 'JSON'].map(f => <span key={f} className="tag tag-info">{f}</span>)}
          </div>
        </div>
        <div className="card">
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 16 }}>
            {Id('trophy', { style: { width: 18, height: 18, color: 'var(--med)' } })}
            <div style={{ fontFamily: 'var(--font-display)', fontSize: 16, fontWeight: 600 }}>Top Suspicious Entities</div>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {LEADERBOARD.map((e, i) => (
              <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 13, padding: '10px 12px', borderRadius: 11, background: i === 0 ? 'rgba(255,77,109,0.06)' : 'var(--panel)', border: `1px solid ${i === 0 ? 'rgba(255,77,109,0.25)' : 'var(--panel-border)'}` }}>
                <div className="mono" style={{ width: 24, textAlign: 'center', fontWeight: 700, fontSize: 14, color: i < 3 ? 'var(--med)' : 'var(--text-3)' }}>{e.rank}</div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: 13, fontWeight: 500 }}>{e.name}</div>
                  <div className="mono" style={{ fontSize: 10.5, color: 'var(--text-3)' }}>{e.region}</div>
                </div>
                <div className="mono" style={{ fontSize: 12, color: 'var(--green)', fontWeight: 600 }}>₨{e.recover}M</div>
                <span className={`tag tag-${e.risk === 'med' ? 'med' : e.risk}`} style={{ width: 30, justifyContent: 'center' }}>{e.score}</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

// ---------- Settings ----------
function Settings({ lang, setLang, theme, setTheme }) {
  const Row = ({ title, desc, children }) => (
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '16px 0', borderBottom: '1px solid var(--panel-border)' }}>
      <div><div style={{ fontSize: 13.5, fontWeight: 500 }}>{title}</div><div style={{ fontSize: 12, color: 'var(--text-3)', marginTop: 3 }}>{desc}</div></div>
      {children}
    </div>
  );
  return (
    <div className="page" style={{ maxWidth: 820 }}>
      <PageHead eyebrow="Configuration" title="Settings" desc="Access control, localisation and security monitoring." />
      <div className="card">
        <div style={{ fontFamily: 'var(--font-display)', fontSize: 15, fontWeight: 600, marginBottom: 4 }}>Preferences</div>
        <Row title="Interface theme" desc="Switch between dark command mode and light.">
          <div className="lang-toggle"><button className={theme === 'dark' ? 'active' : ''} onClick={() => setTheme('dark')}>DARK</button><button className={theme === 'light' ? 'active' : ''} onClick={() => setTheme('light')}>LIGHT</button></div>
        </Row>
        <Row title="Language" desc="Urdu and English are supported across the platform.">
          <div className="lang-toggle"><button className={lang === 'EN' ? 'active' : ''} onClick={() => setLang('EN')}>EN</button><button className={lang === 'UR' ? 'active' : ''} onClick={() => setLang('UR')}>اردو</button></div>
        </Row>
        <Row title="Role-based access" desc="Current role: Senior Investigator · Tier 3 clearance"><span className="tag tag-low">{Id('shield', { style: { width: 13, height: 13 } })} SECURED</span></Row>
        <Row title="Real-time notifications" desc="Critical-entity alerts pushed instantly."><Toggle on /></Row>
        <Row title="Activity & audit logging" desc="All investigator actions are recorded immutably."><Toggle on /></Row>
      </div>
    </div>
  );
}
function Toggle({ on: initial }) {
  const [on, setOn] = useSd(initial);
  return <button onClick={() => setOn(o => !o)} style={{ width: 44, height: 26, borderRadius: 20, border: 'none', cursor: 'pointer', background: on ? 'var(--green)' : 'rgba(255,255,255,0.12)', position: 'relative', transition: 'all .2s' }}>
    <span style={{ position: 'absolute', top: 3, left: on ? 21 : 3, width: 20, height: 20, borderRadius: '50%', background: on ? '#04070D' : '#fff', transition: 'all .2s' }} />
  </button>;
}

Object.assign(window, { EntityResolution, RiskAnalysis, AuditTrail, Analytics, Reports, Settings, PageHead });

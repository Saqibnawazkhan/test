import { useNavigate } from 'react-router-dom'
import { I } from '../components/Icons.jsx'

const FEATURES = [
  { icon: 'graph', t: 'Knowledge Graph', d: 'Citizens, assets, utilities and businesses fused into one queryable graph of the national tax net.' },
  { icon: 'entity', t: 'Entity Resolution', d: 'Fuzzy identity matching collapses duplicate and benami identities into single resolved entities.' },
  { icon: 'risk', t: 'GNN Risk Scoring', d: 'A graph neural network weighs lifestyle signals against declared income to surface deviation.' },
  { icon: 'audit', t: 'Explainable Audit Trail', d: 'Every flag is backed by evidence and a findings-driven Show-Cause Notice citing real FBR sections.' },
]

export default function Landing() {
  const nav = useNavigate()
  return (
    <div style={{ minHeight: '100vh', background: 'radial-gradient(1100px 600px at 80% -10%, rgba(76,141,246,0.07), transparent 60%), radial-gradient(900px 700px at 0% 110%, rgba(37,201,140,0.06), transparent 58%), var(--bg-0)' }}>
      <header className="row" style={{ justifyContent: 'space-between', padding: '20px 32px', maxWidth: 1300, margin: '0 auto' }}>
        <div className="row" style={{ gap: 12 }}>
          <div className="brand-mark"><svg viewBox="0 0 24 24" fill="none" stroke="#04070D" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="6" cy="7" r="2"/><circle cx="18" cy="9" r="2"/><circle cx="11" cy="17" r="2.4"/><path d="M8 8l1.5 7M16 10l-3.5 5"/></svg></div>
          <div><div className="brand-name">Tax<span>Net</span> AI</div><div className="brand-sub">FBR Intelligence</div></div>
        </div>
        <div className="row" style={{ gap: 10 }}>
          <button className="btn btn-ghost" onClick={() => nav('/login?role=citizen')}>{I('user')} Citizen Login</button>
          <button className="btn btn-primary" onClick={() => nav('/login?role=admin')}>{I('shield')} FBR Login</button>
        </div>
      </header>

      <section style={{ maxWidth: 980, margin: '0 auto', padding: '70px 24px 40px', textAlign: 'center' }}>
        <div className="eyebrow" style={{ justifyContent: 'center' }}>Graph AI · Problem #2 · Broadening the National Tax Net</div>
        <h1 style={{ fontFamily: 'var(--font-display)', fontSize: 'clamp(34px, 6vw, 60px)', fontWeight: 700, letterSpacing: '-0.03em', lineHeight: 1.05 }}>
          See the wealth the <span style={{ color: 'var(--green)' }}>tax net misses.</span>
        </h1>
        <p style={{ color: 'var(--text-2)', fontSize: 16, maxWidth: 640, margin: '20px auto 0', lineHeight: 1.6 }}>
          TaxNet AI builds a knowledge graph of Pakistan’s citizens and their assets, resolves hidden identities, and uses a GNN to flag income–lifestyle mismatches — with a fully explainable audit trail for every case.
        </p>
        <div className="row" style={{ gap: 12, justifyContent: 'center', marginTop: 34, flexWrap: 'wrap' }}>
          <button className="btn btn-primary" style={{ padding: '13px 22px', fontSize: 14 }} onClick={() => nav('/login?role=admin')}>{I('dashboard')} Enter FBR Command Center</button>
          <button className="btn btn-ghost" style={{ padding: '13px 22px', fontSize: 14 }} onClick={() => nav('/login?role=citizen')}>{I('wallet')} Open Citizen Portal</button>
        </div>
      </section>

      <section style={{ maxWidth: 1100, margin: '0 auto', padding: '30px 24px 80px', display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', gap: 18 }}>
        {FEATURES.map((f) => (
          <div className="card" key={f.t}>
            <div className="kpi-ic" style={{ color: 'var(--green)', background: 'rgba(37,201,140,0.12)', marginBottom: 14 }}>{I(f.icon)}</div>
            <div style={{ fontFamily: 'var(--font-display)', fontWeight: 600, fontSize: 16 }}>{f.t}</div>
            <div style={{ color: 'var(--text-2)', fontSize: 13, marginTop: 8, lineHeight: 1.55 }}>{f.d}</div>
          </div>
        ))}
      </section>
    </div>
  )
}

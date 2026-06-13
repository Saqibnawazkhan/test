import { I } from './Icons.jsx'
import { PageHead } from './ui.jsx'

// Temporary page for modules being wired to the live graph engine.
export default function Placeholder({ title, icon = 'spark' }) {
  return (
    <div className="page">
      <PageHead eyebrow="Module" title={title} desc="This module is being wired to the live graph engine." />
      <div className="card" style={{ display: 'grid', placeItems: 'center', padding: 60, textAlign: 'center' }}>
        <div className="kpi-ic" style={{ color: 'var(--green)', background: 'rgba(37,201,140,0.12)', width: 56, height: 56, marginBottom: 16 }}>{I(icon)}</div>
        <div style={{ fontFamily: 'var(--font-display)', fontWeight: 600, fontSize: 17 }}>{title} — coming online</div>
        <div style={{ color: 'var(--text-2)', fontSize: 13, marginTop: 8, maxWidth: 420, lineHeight: 1.55 }}>
          The full {title.toLowerCase()} view ships in the next build, wired to the same FastAPI backend as the mobile app.
        </div>
      </div>
    </div>
  )
}

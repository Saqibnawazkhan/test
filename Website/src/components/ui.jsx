import { I } from './Icons.jsx'

export function PageHead({ eyebrow, title, desc, actions }) {
  return (
    <div className="page-head">
      <div>
        {eyebrow && <div className="eyebrow">{eyebrow}</div>}
        <div className="page-title">{title}</div>
        {desc && <div className="page-desc">{desc}</div>}
      </div>
      {actions && <div className="row" style={{ gap: 10, flexWrap: 'wrap' }}>{actions}</div>}
    </div>
  )
}

export function Card({ children, style, className = '', onClick }) {
  return <div className={`card ${className}`} style={style} onClick={onClick}>{children}</div>
}

const SEV = { low: 'tag-low', med: 'tag-med', high: 'tag-high', critical: 'tag-critical', info: 'tag-info' }
export function Tag({ children, sev = 'info', icon }) {
  return <span className={`tag ${SEV[sev] || 'tag-info'}`}>{icon && I(icon, { style: { width: 12, height: 12 } })}{children}</span>
}

export function zoneSev(zone) {
  return zone === 'Red' ? 'critical' : zone === 'Yellow' ? 'high' : zone === 'Green' ? 'low' : 'info'
}
export function zoneColor(zone) {
  return zone === 'Red' ? 'var(--critical)' : zone === 'Yellow' ? 'var(--med)' : zone === 'Green' ? 'var(--green)' : 'var(--text-3)'
}

export function Loading({ label }) {
  return <div className="center-load"><div style={{ display: 'grid', placeItems: 'center', gap: 12 }}><div className="spinner" />{label && <div style={{ fontSize: 12.5, color: 'var(--text-3)' }}>{label}</div>}</div></div>
}

export function ErrorBox({ msg, onRetry }) {
  return (
    <div className="card" style={{ borderColor: 'rgba(229,86,111,0.3)' }}>
      <div className="row" style={{ gap: 10, color: 'var(--critical)' }}>{I('alert')}<b>Couldn’t reach the server</b></div>
      <div style={{ fontSize: 12.5, color: 'var(--text-2)', marginTop: 8 }}>{msg}</div>
      <div style={{ fontSize: 11.5, color: 'var(--text-3)', marginTop: 8 }}>
        Make sure the FastAPI backend is running and <span className="mono">VITE_API_URL</span> points to it.
      </div>
      {onRetry && <button className="btn btn-ghost" style={{ marginTop: 14 }} onClick={onRetry}>{I('clock')} Retry</button>}
    </div>
  )
}

export function Stat({ icon, color = 'var(--blue)', value, label, delta }) {
  return (
    <div className="card kpi">
      <div className="kpi-top">
        <div className="kpi-ic" style={{ color, background: `color-mix(in srgb, ${color} 14%, transparent)` }}>{I(icon)}</div>
        {delta != null && <span className="tag tag-low" style={{ background: 'rgba(37,201,140,0.1)' }}>{I('arrowUp', { style: { width: 11, height: 11 } })}{delta}</span>}
      </div>
      <div className="kpi-val">{value}</div>
      <div className="kpi-label">{label}</div>
    </div>
  )
}

// inline sparkline
export function Spark({ data = [], color = 'var(--green)', height = 40 }) {
  if (!data.length) return null
  const max = Math.max(...data), min = Math.min(...data), rng = max - min || 1
  const w = 100, pts = data.map((v, i) => `${(i / (data.length - 1)) * w},${height - ((v - min) / rng) * height}`).join(' ')
  return (
    <svg viewBox={`0 0 ${w} ${height}`} preserveAspectRatio="none" style={{ width: '100%', height }}>
      <polyline points={pts} fill="none" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" vectorEffect="non-scaling-stroke" />
    </svg>
  )
}

import { useApp } from '../../lib/store.jsx'
import { PageHead, Card } from '../../components/ui.jsx'
import { API_BASE } from '../../lib/api.js'

export default function Settings() {
  const { theme, setTheme, lang, setLang, t } = useApp()
  return (
    <div className="page">
      <PageHead eyebrow={t('Configuration') || 'Configuration'} title={t('Settings')} desc="Appearance, localisation and connection." />
      <Card style={{ maxWidth: 640 }}>
        <Row title={t('Interface theme')} sub={theme === 'dark' ? 'Dark command mode' : 'Light mode'}>
          <Seg opts={[['dark', 'DARK'], ['light', 'LIGHT']]} val={theme} on={setTheme} />
        </Row>
        <Row title={t('Language')} sub="English & Urdu (RTL) supported">
          <Seg opts={[['EN', 'EN'], ['UR', 'اردو']]} val={lang} on={setLang} />
        </Row>
        <Row title="Role-based access" sub="Senior Investigator · Tier 3">
          <span className="tag tag-low">SECURED</span>
        </Row>
        <Row title="Backend endpoint" sub="The FastAPI server this dashboard is wired to">
          <span className="mono" style={{ fontSize: 12, color: 'var(--text-2)' }}>{API_BASE}</span>
        </Row>
      </Card>
    </div>
  )
}

function Row({ title, sub, children }) {
  return (
    <div className="row" style={{ justifyContent: 'space-between', padding: '14px 0', borderBottom: '1px solid var(--panel-border)' }}>
      <div><div style={{ fontSize: 13.5, fontWeight: 500 }}>{title}</div><div style={{ fontSize: 11.5, color: 'var(--text-3)' }}>{sub}</div></div>
      {children}
    </div>
  )
}
function Seg({ opts, val, on }) {
  return (
    <div className="lang-toggle">
      {opts.map(([v, l]) => <button key={v} className={val === v ? 'active' : ''} onClick={() => on(v)}>{l}</button>)}
    </div>
  )
}

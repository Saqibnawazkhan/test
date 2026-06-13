import { useEffect, useState } from 'react'
import { api, rs } from '../../lib/api.js'
import * as sb from '../../lib/supabase.js'
import { useApp } from '../../lib/store.jsx'
import { I } from '../../components/Icons.jsx'
import { PageHead, Card, Tag, Loading, ErrorBox } from '../../components/ui.jsx'

const GROUPS = [
  { key: 'vehicles', label: 'Vehicles', icon: 'car', val: (a) => a.value, line: (a) => `${a.make || ''} ${a.model || ''} · ${a.engine_cc || '?'}cc · ${a.reg_number || ''}` },
  { key: 'properties', label: 'Properties', icon: 'home', val: (a) => a.market_value, line: (a) => `${a.property_type || 'Property'} · ${a.area || ''} · ${a.district || ''}` },
  { key: 'stocks', label: 'Stocks', icon: 'trend', val: (a) => a.market_value, line: (a) => `${a.scrip || ''} · ${a.shares || 0} shares` },
  { key: 'bank_accounts', label: 'Bank Accounts', icon: 'card', val: (a) => a.balance, line: (a) => `${a.bank || ''} · ${a.account_type || ''}` },
]

export default function MyAssets() {
  const { auth } = useApp()
  const [d, setD] = useState(null)
  const [err, setErr] = useState('')
  const [decls, setDecls] = useState([])
  const [expls, setExpls] = useState([])
  const [modal, setModal] = useState(null) // {type:'declare'} | {type:'explain', asset}

  async function load() {
    setErr('')
    try {
      setD(await api.person(auth.cnic))
      sb.listDeclarations(auth.cnic).then(setDecls).catch(() => {})
      sb.listExplanations(auth.cnic).then(setExpls).catch(() => {})
    } catch (e) { setErr(String(e.message || e)) }
  }
  useEffect(() => { load() }, [auth.cnic])

  if (err) return <div className="page"><ErrorBox msg={err} onRetry={load} /></div>
  if (!d) return <div className="page"><Loading label="Loading your assets…" /></div>

  const onRecord = []
  GROUPS.forEach((g) => (d.assets?.[g.key] || []).forEach((a) => onRecord.push({ g, a, label: g.line(a), value: g.val(a) })))

  return (
    <div className="page">
      <PageHead eyebrow="My Account" title="My Assets"
        desc="Assets linked to your CNIC. Declare a new asset, or explain the source of one on record (gift, inheritance, etc.)."
        actions={<button className="btn btn-primary" onClick={() => setModal({ type: 'declare' })}>{I('plus')} Declare asset</button>} />

      <Card style={{ marginBottom: 16 }}>
        <div style={{ fontFamily: 'var(--font-display)', fontWeight: 600, fontSize: 15, marginBottom: 12 }}>Assets on record</div>
        {!onRecord.length && <div style={{ color: 'var(--text-3)', fontSize: 13 }}>No assets linked to your CNIC yet.</div>}
        <div className="grid" style={{ gridTemplateColumns: 'repeat(auto-fit,minmax(260px,1fr))' }}>
          {onRecord.map((it, i) => {
            const ex = expls.find((e) => e.asset_label === it.label)
            return (
              <div key={i} style={{ border: '1px solid var(--panel-border)', borderRadius: 12, padding: 14 }}>
                <div className="row" style={{ gap: 8, color: 'var(--text-2)', marginBottom: 8 }}>{I(it.g.icon, { style: { width: 16, height: 16 } })}<b style={{ fontSize: 12.5 }}>{it.g.label}</b>{ex && <Tag sev={ex.status === 'Accepted' ? 'low' : ex.status === 'Rejected' ? 'critical' : 'med'} >{ex.status === 'Pending' || !ex.status ? 'Explained (pending)' : ex.status}</Tag>}</div>
                <div style={{ fontSize: 13 }}>{it.label}</div>
                <div className="row" style={{ justifyContent: 'space-between', marginTop: 8 }}>
                  <span className="mono" style={{ fontSize: 12.5 }}>{rs(it.value)}</span>
                  {!ex && <button className="btn btn-ghost" style={{ padding: '5px 10px', fontSize: 11.5 }} onClick={() => setModal({ type: 'explain', asset: it })}>{I('doc')} Explain source</button>}
                </div>
              </div>
            )
          })}
        </div>
      </Card>

      {(decls.length > 0 || expls.length > 0) && (
        <Card>
          <div style={{ fontFamily: 'var(--font-display)', fontWeight: 600, fontSize: 15, marginBottom: 12 }}>My submissions</div>
          {decls.map((x) => <Sub key={'d' + x.id} title={`Declared: ${x.asset_type}`} sub={`${x.description || ''} ${x.value ? rs(x.value) : ''}`} status={x.status} />)}
          {expls.map((x) => <Sub key={'e' + x.id} title={`Explained: ${x.asset_label}`} sub={`Source: ${x.source}`} status={x.status} />)}
        </Card>
      )}

      {modal?.type === 'declare' && <DeclareModal cnic={auth.cnic} name={auth.name} onClose={() => setModal(null)} onDone={() => { setModal(null); load() }} />}
      {modal?.type === 'explain' && <ExplainModal cnic={auth.cnic} name={auth.name} asset={modal.asset} onClose={() => setModal(null)} onDone={() => { setModal(null); load() }} />}
    </div>
  )
}

const Sub = ({ title, sub, status }) => (
  <div className="row" style={{ justifyContent: 'space-between', padding: '8px 0', borderBottom: '1px solid var(--panel-border)' }}>
    <div><div style={{ fontSize: 13 }}>{title}</div><div className="mono" style={{ fontSize: 10.5, color: 'var(--text-3)' }}>{sub}</div></div>
    <Tag sev={/Approv|Accept/.test(status) ? 'low' : /Reject/.test(status) ? 'critical' : 'med'}>{status || 'Pending'}</Tag>
  </div>
)

function DeclareModal({ cnic, name, onClose, onDone }) {
  const [f, setF] = useState({ assetType: 'Vehicle', description: '', value: '' })
  const [busy, setBusy] = useState(false)
  async function submit() {
    setBusy(true)
    try { await sb.declareAsset({ cnic, name, assetType: f.assetType, description: f.description, value: Number(f.value || 0) }); onDone() }
    catch (e) { alert(e.message || e) } finally { setBusy(false) }
  }
  return (
    <Modal title="Declare a new asset" onClose={onClose}>
      <div className="field"><label>Asset type</label><select className="select" value={f.assetType} onChange={(e) => setF({ ...f, assetType: e.target.value })}><option>Vehicle</option><option>Property</option><option>Bank Account</option><option>Stocks</option><option>Other</option></select></div>
      <div className="field"><label>Description</label><input className="input" placeholder="e.g. Toyota Corolla 2022, 1800cc" value={f.description} onChange={(e) => setF({ ...f, description: e.target.value })} /></div>
      <div className="field"><label>Value (Rs)</label><input className="input" type="number" value={f.value} onChange={(e) => setF({ ...f, value: e.target.value })} /></div>
      <button className="btn btn-primary" style={{ width: '100%' }} disabled={busy} onClick={submit}>{busy ? 'Submitting…' : 'Submit to FBR'}</button>
    </Modal>
  )
}

function ExplainModal({ cnic, name, asset, onClose, onDone }) {
  const [f, setF] = useState({ source: 'Gift', taxPaid: false, remarks: '' })
  const [busy, setBusy] = useState(false)
  async function submit() {
    setBusy(true)
    try { await sb.explainAsset({ cnic, name, assetType: asset.g.label, assetLabel: asset.label, assetValue: Number(asset.value || 0), source: f.source, taxPaid: f.taxPaid, remarks: f.remarks }); onDone() }
    catch (e) { alert(e.message || e) } finally { setBusy(false) }
  }
  return (
    <Modal title="Explain asset source" onClose={onClose}>
      <div style={{ fontSize: 12.5, color: 'var(--text-2)', marginBottom: 12 }}>{asset.label} · {rs(asset.value)}</div>
      <div className="field"><label>Source of this asset</label><select className="select" value={f.source} onChange={(e) => setF({ ...f, source: e.target.value })}><option>Gift</option><option>Inheritance</option><option>Purchase (own income)</option><option>Loan</option></select></div>
      <label className="row" style={{ gap: 8, fontSize: 12.5, marginBottom: 12, cursor: 'pointer' }}><input type="checkbox" checked={f.taxPaid} onChange={(e) => setF({ ...f, taxPaid: e.target.checked })} /> Tax was already paid on this</label>
      <div className="field"><label>Remarks / proof note</label><textarea className="input" rows={2} placeholder="e.g. Gift from father via bank transfer (non-taxable)" value={f.remarks} onChange={(e) => setF({ ...f, remarks: e.target.value })} /></div>
      <button className="btn btn-primary" style={{ width: '100%' }} disabled={busy} onClick={submit}>{busy ? 'Submitting…' : 'Submit explanation'}</button>
    </Modal>
  )
}

function Modal({ title, children, onClose }) {
  return (
    <div className="drawer-scrim" style={{ display: 'grid', placeItems: 'center' }} onClick={onClose}>
      <div className="modal" style={{ width: 460 }} onClick={(e) => e.stopPropagation()}>
        <div className="drawer-head"><div style={{ fontFamily: 'var(--font-display)', fontWeight: 600, fontSize: 16 }}>{title}</div><button className="icon-btn" style={{ width: 30, height: 30 }} onClick={onClose}>{I('close')}</button></div>
        <div style={{ padding: 22 }}>{children}</div>
      </div>
    </div>
  )
}

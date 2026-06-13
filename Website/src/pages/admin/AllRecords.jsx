import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { api, rs } from '../../lib/api.js'
import { I } from '../../components/Icons.jsx'
import { PageHead, Card, Tag, Loading, zoneSev } from '../../components/ui.jsx'

const SORTS = [
  { v: 'score', l: 'Risk score (high→low)' },
  { v: 'score_asc', l: 'Risk score (low→high)' },
  { v: 'name', l: 'Name (A→Z)' },
  { v: 'district', l: 'District' },
]
const PAGE = 25

export default function AllRecords() {
  const nav = useNavigate()
  const [q, setQ] = useState('')
  const [sort, setSort] = useState('score')
  const [zone, setZone] = useState('')
  const [district, setDistrict] = useState('')
  const [districts, setDistricts] = useState([])
  const [page, setPage] = useState(0)
  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(false)
  const [addOpen, setAddOpen] = useState(false)

  useEffect(() => { api.districts().then(setDistricts).catch(() => {}) }, [])

  async function load() {
    setLoading(true)
    try {
      const r = await api.persons({ q, sort, zone, district, limit: PAGE, offset: page * PAGE })
      setData(r)
    } catch { setData({ total: 0, results: [] }) } finally { setLoading(false) }
  }
  useEffect(() => { load() }, [sort, zone, district, page])
  useEffect(() => { const t = setTimeout(() => { setPage(0); load() }, 350); return () => clearTimeout(t) }, [q])

  const total = data?.total || 0
  const pages = Math.ceil(total / PAGE)

  return (
    <div className="page">
      <PageHead eyebrow="Live · 222k entities" title="All Records"
        desc="Every resolved citizen in the national tax net — search, filter, sort and drill into any case."
        actions={<button className="btn btn-primary" onClick={() => setAddOpen(true)}>{I('plus')} Add Record</button>} />

      <Card style={{ padding: 14, marginBottom: 16 }}>
        <div className="row" style={{ gap: 10, flexWrap: 'wrap' }}>
          <div className="search-box" style={{ flex: '1 1 280px', maxWidth: 'none' }}>
            {I('search')}<input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Search by name or CNIC…" />
          </div>
          <select className="select" style={{ width: 'auto', minWidth: 180 }} value={sort} onChange={(e) => { setPage(0); setSort(e.target.value) }}>
            {SORTS.map((s) => <option key={s.v} value={s.v}>{s.l}</option>)}
          </select>
          <select className="select" style={{ width: 'auto' }} value={zone} onChange={(e) => { setPage(0); setZone(e.target.value) }}>
            <option value="">All zones</option><option value="Red">Red</option><option value="Yellow">Yellow</option><option value="Green">Green</option>
          </select>
          <select className="select" style={{ width: 'auto', maxWidth: 180 }} value={district} onChange={(e) => { setPage(0); setDistrict(e.target.value) }}>
            <option value="">All districts</option>
            {districts.map((d) => <option key={d} value={d}>{d}</option>)}
          </select>
        </div>
      </Card>

      <Card style={{ padding: 0, overflow: 'hidden' }}>
        {loading && !data ? <Loading /> : (
          <table className="tbl">
            <thead><tr><th>Citizen</th><th>District</th><th>Filer</th><th>Declared</th><th>Recovery</th><th style={{ textAlign: 'right' }}>Score</th></tr></thead>
            <tbody>
              {(data?.results || []).map((p) => (
                <tr key={p.cnic} onClick={() => nav(`/admin/person/${p.cnic}`)}>
                  <td><div style={{ color: 'var(--text)', fontWeight: 500 }}>{p.name}</div><div className="mono" style={{ fontSize: 10.5, color: 'var(--text-3)' }}>{p.cnic}</div></td>
                  <td>{p.district || '—'}</td>
                  <td>{p.filer_status === 'Filer' ? <Tag sev="low">Filer</Tag> : <Tag sev="high">Non-filer</Tag>}</td>
                  <td className="mono">{rs(p.declared_income)}</td>
                  <td className="mono" style={{ color: 'var(--critical)' }}>{rs(p.recovery)}</td>
                  <td style={{ textAlign: 'right' }}><Tag sev={zoneSev(p.zone)}>{Math.round(p.deviation_score)}</Tag></td>
                </tr>
              ))}
              {!loading && !(data?.results || []).length && <tr><td colSpan={6} style={{ textAlign: 'center', padding: 40, color: 'var(--text-3)' }}>No records match.</td></tr>}
            </tbody>
          </table>
        )}
      </Card>

      <div className="row" style={{ justifyContent: 'space-between', marginTop: 14 }}>
        <div className="mono" style={{ fontSize: 12, color: 'var(--text-3)' }}>{total.toLocaleString('en-PK')} records · page {page + 1} of {pages || 1}</div>
        <div className="row" style={{ gap: 8 }}>
          <button className="btn btn-ghost" disabled={page === 0} onClick={() => setPage((p) => Math.max(0, p - 1))}>Prev</button>
          <button className="btn btn-ghost" disabled={page + 1 >= pages} onClick={() => setPage((p) => p + 1)}>Next</button>
        </div>
      </div>

      {addOpen && <AddRecord onClose={() => setAddOpen(false)} onDone={() => { setAddOpen(false); setPage(0); load() }} />}
    </div>
  )
}

function AddRecord({ onClose, onDone }) {
  const [f, setF] = useState({ cnic: '', name: '', father: '', district: '', mobile: '', email: '', declared_income: 0, filer_status: 'Non-Filer', vehicle_value: 0, property_value: 0, bank_balance: 0, stock_value: 0 })
  const [busy, setBusy] = useState(false)
  const [err, setErr] = useState('')
  const set = (k) => (e) => setF((x) => ({ ...x, [k]: e.target.value }))

  async function submit() {
    if (!f.cnic || !f.name) { setErr('CNIC and name are required.'); return }
    setBusy(true); setErr('')
    try {
      await api.createPerson({
        ...f,
        declared_income: +f.declared_income || 0, vehicle_value: +f.vehicle_value || 0,
        property_value: +f.property_value || 0, bank_balance: +f.bank_balance || 0, stock_value: +f.stock_value || 0,
      })
      onDone()
    } catch (e) { setErr(String(e.message || e)) } finally { setBusy(false) }
  }

  const F = (label, k, type = 'text') => <div className="field"><label>{label}</label><input className="input" type={type} value={f[k]} onChange={set(k)} /></div>

  return (
    <div className="drawer-scrim" style={{ display: 'grid', placeItems: 'center' }} onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <div className="drawer-head"><div style={{ fontFamily: 'var(--font-display)', fontWeight: 600, fontSize: 16 }}>Add Record — NADRA + Assets</div><button className="icon-btn" style={{ width: 30, height: 30 }} onClick={onClose}>{I('close')}</button></div>
        <div style={{ padding: 22 }}>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14 }}>
            {F('CNIC', 'cnic')}{F('Full name', 'name')}
            {F('Father / Husband', 'father')}{F('District', 'district')}
            {F('Mobile', 'mobile')}{F('Email', 'email')}
          </div>
          <div className="field"><label>Filer status</label>
            <select className="select" value={f.filer_status} onChange={set('filer_status')}><option>Non-Filer</option><option>Filer</option></select></div>
          <div className="divider" />
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14 }}>
            {F('Declared income (Rs)', 'declared_income', 'number')}{F('Vehicle value (Rs)', 'vehicle_value', 'number')}
            {F('Property value (Rs)', 'property_value', 'number')}{F('Bank balance (Rs)', 'bank_balance', 'number')}
            {F('Stocks (Rs)', 'stock_value', 'number')}
          </div>
          {err && <div style={{ color: 'var(--critical)', fontSize: 12.5, marginBottom: 10 }}>{err}</div>}
          <div className="row" style={{ gap: 10, justifyContent: 'flex-end' }}>
            <button className="btn btn-ghost" onClick={onClose}>Cancel</button>
            <button className="btn btn-primary" disabled={busy} onClick={submit}>{busy ? 'Scoring…' : 'Create & Score'}</button>
          </div>
        </div>
      </div>
    </div>
  )
}

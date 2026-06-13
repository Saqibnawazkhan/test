import { useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { api } from '../../lib/api.js'
import { I } from '../../components/Icons.jsx'
import { Loading, ErrorBox } from '../../components/ui.jsx'
import { KnowledgeGraph as Graph, NetworkBackground, layoutHub } from '../../components/graph.jsx'

const TYPES = {
  citizen: { label: 'Citizen', color: '#2E8FFF', icon: 'user' },
  company: { label: 'Company', color: '#8B7CFF', icon: 'entity' },
  vehicle: { label: 'Vehicle', color: '#22D3EE', icon: 'car' },
  property: { label: 'Property', color: '#00E599', icon: 'home' },
}

export default function KnowledgeGraphView() {
  const nav = useNavigate()
  const [raw, setRaw] = useState(null)
  const [err, setErr] = useState('')
  const [sel, setSel] = useState(null)
  const [filter, setFilter] = useState('all')
  const [query, setQuery] = useState('')

  async function load() { setErr(''); setRaw(null); try { setRaw(await api.network(60)) } catch (e) { setErr(String(e.message || e)) } }
  useEffect(() => { load() }, [])

  const { nodes, edges, presentTypes } = useMemo(() => {
    if (!raw) return { nodes: [], edges: [], presentTypes: [] }
    const zoneRisk = (z) => (z === 'Red' ? 'critical' : z === 'Yellow' ? 'med' : null)
    const mapped = (raw.nodes || []).map((n) => ({
      id: n.id, type: n.type || 'citizen', label: n.label, cnic: n.cnic,
      sub: n.cnic ? n.cnic : (TYPES[n.type]?.label || n.type),
      size: n.type === 'citizen' ? 15 + Math.min(17, (n.score || 0) / 4) : 15,
      risk: zoneRisk(n.zone), zone: n.zone, score: n.score,
    }))
    const eds = (raw.edges || []).map((e) => ({ a: e.source ?? e.src ?? e.a, b: e.target ?? e.dst ?? e.b, label: String(e.rel || e.label || '').replace(/_/g, ' ').toLowerCase() }))
    const laid = layoutHub(mapped, eds)
    const present = [...new Set(mapped.map((n) => n.type))].filter((t) => TYPES[t])
    return { nodes: laid, edges: eds, presentTypes: present }
  }, [raw])

  if (err) return <div className="page"><ErrorBox msg={err} onRetry={load} /></div>
  if (!raw) return <div className="page"><Loading label="Building the intelligence network…" /></div>

  return (
    <div className="page" style={{ maxWidth: '100%', paddingBottom: 24 }}>
      <div className="page-head" style={{ marginBottom: 16 }}>
        <div><div className="eyebrow">Graph Intelligence · Live</div><h1 className="page-title">Knowledge Graph</h1></div>
        <div style={{ display: 'flex', gap: 10, alignItems: 'center', flexWrap: 'wrap' }}>
          <div className="mono" style={{ fontSize: 11.5, color: 'var(--text-3)' }}>{nodes.length} entities · {edges.length} links</div>
          <div className="search-box" style={{ display: 'flex', maxWidth: 240 }}>{I('search')}<input placeholder="Search nodes…" value={query} onChange={(e) => setQuery(e.target.value)} /></div>
        </div>
      </div>

      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginBottom: 14 }}>
        <Chip active={filter === 'all'} onClick={() => setFilter('all')} label="All entities" />
        {presentTypes.map((k) => <Chip key={k} active={filter === k} onClick={() => setFilter(k)} label={TYPES[k].label} color={TYPES[k].color} icon />)}
      </div>

      <div className="glass" style={{ position: 'relative', height: 'calc(100vh - 280px)', minHeight: 460, overflow: 'hidden', borderRadius: 'var(--r-lg)' }}>
        <div style={{ position: 'absolute', inset: 0, opacity: 0.5 }}><NetworkBackground density={26} opacity={0.5} /></div>
        <Graph nodes={nodes} edges={edges} types={TYPES} onSelect={setSel} selectedId={sel?.id} filter={filter} query={query} />
        <div style={{ position: 'absolute', left: 14, top: 14, fontSize: 11, color: 'var(--text-3)', fontFamily: 'var(--font-mono)', display: 'flex', gap: 14 }}>
          <span>scroll · zoom</span><span>drag · pan</span><span>click · inspect</span>
        </div>
        {sel && <NodePanel node={sel} nodes={nodes} edges={edges} onClose={() => setSel(null)} onSelect={setSel} onOpen={(cnic) => nav(`/admin/person/${cnic}`)} />}
      </div>
    </div>
  )
}

function Chip({ active, onClick, label, color, icon }) {
  return (
    <button onClick={onClick} style={{
      display: 'inline-flex', alignItems: 'center', gap: 8, padding: '8px 13px', borderRadius: 9, cursor: 'pointer',
      border: `1px solid ${active ? (color || 'var(--green)') : 'var(--panel-border)'}`,
      background: active ? `color-mix(in srgb, ${color || 'var(--green)'} 14%, transparent)` : 'var(--panel)',
      color: active ? (color || 'var(--green)') : 'var(--text-2)', fontSize: 12.5, fontWeight: 500, transition: 'all .15s',
    }}>{icon && <span style={{ width: 8, height: 8, borderRadius: '50%', background: color }} />}{label}</button>
  )
}

function NodePanel({ node, nodes, edges, onClose, onSelect, onOpen }) {
  const meta = TYPES[node.type] || TYPES.citizen
  const conns = edges.filter((e) => e.a === node.id || e.b === node.id).map((e) => {
    const oid = e.a === node.id ? e.b : e.a; return { o: nodes.find((n) => n.id === oid), label: e.label }
  }).filter((c) => c.o)
  return (
    <div style={{ position: 'absolute', top: 14, right: 14, bottom: 14, width: 320, maxWidth: '85%', zIndex: 5,
      background: 'color-mix(in srgb, var(--bg-1) 92%, transparent)', backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)', border: '1px solid var(--panel-border-2)', borderRadius: 'var(--r-lg)', color: 'var(--text)',
      display: 'flex', flexDirection: 'column', animation: 'slideIn .3s cubic-bezier(.2,.8,.2,1)', boxShadow: '-20px 0 50px -20px rgba(0,0,0,0.35)' }}>
      <div style={{ padding: 18, borderBottom: '1px solid var(--panel-border)', display: 'flex', alignItems: 'flex-start', gap: 12 }}>
        <div style={{ width: 44, height: 44, borderRadius: 12, display: 'grid', placeItems: 'center', color: meta.color, background: `color-mix(in srgb, ${meta.color} 14%, transparent)`, border: `1px solid ${meta.color}55` }}>{I(meta.icon)}</div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontFamily: 'var(--font-display)', fontSize: 16, fontWeight: 600 }}>{node.label}</div>
          <div className="mono" style={{ fontSize: 11, color: 'var(--text-3)', marginTop: 2 }}>{node.sub}</div>
        </div>
        <button className="icon-btn" style={{ width: 30, height: 30 }} onClick={onClose}>{I('close')}</button>
      </div>
      <div style={{ padding: 18, overflowY: 'auto' }}>
        <div style={{ display: 'flex', gap: 8, marginBottom: 16, flexWrap: 'wrap' }}>
          <span className="tag tag-info">{meta.label}</span>
          {node.zone && <span className={`tag tag-${node.zone === 'Red' ? 'critical' : node.zone === 'Yellow' ? 'med' : 'low'}`}>{node.zone} · {Math.round(node.score || 0)}</span>}
        </div>
        <div style={{ fontSize: 11, color: 'var(--text-3)', textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: 10, fontFamily: 'var(--font-mono)' }}>Connections · {conns.length}</div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {conns.map((c, i) => (
            <div key={i} onClick={() => onSelect(c.o)} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: 10, borderRadius: 10, background: 'var(--panel)', border: '1px solid var(--panel-border)', cursor: 'pointer' }}>
              <span style={{ width: 8, height: 8, borderRadius: '50%', background: (TYPES[c.o.type] || TYPES.citizen).color, flex: 'none' }} />
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 12.5, fontWeight: 500, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{c.o.label}</div>
                <div className="mono" style={{ fontSize: 10, color: 'var(--text-3)' }}>{c.label}</div>
              </div>
              {I('arrowRight', { style: { width: 14, height: 14, color: 'var(--text-3)' } })}
            </div>
          ))}
          {!conns.length && <div style={{ fontSize: 12, color: 'var(--text-3)' }}>No linked entities.</div>}
        </div>
        {node.cnic
          ? <button className="btn btn-primary" style={{ width: '100%', justifyContent: 'center', marginTop: 16 }} onClick={() => onOpen(node.cnic)}>{I('eye')} Open full profile</button>
          : <div style={{ fontSize: 11.5, color: 'var(--text-3)', marginTop: 16, textAlign: 'center' }}>Company node — open a linked citizen to investigate.</div>}
      </div>
    </div>
  )
}

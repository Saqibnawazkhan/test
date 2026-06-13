import { useEffect, useRef, useState } from 'react'
import { Icons } from './Icons.jsx'

// Ambient particle network for hero / page backgrounds
export function NetworkBackground({ density = 64, opacity = 1 }) {
  const ref = useRef()
  useEffect(() => {
    const canvas = ref.current; if (!canvas) return
    const ctx = canvas.getContext('2d')
    let W, H, dpr, raf, pts = []
    const resize = () => {
      dpr = Math.min(window.devicePixelRatio || 1, 2)
      const rect = canvas.parentElement.getBoundingClientRect()
      W = rect.width; H = rect.height
      canvas.width = W * dpr; canvas.height = H * dpr
      canvas.style.width = W + 'px'; canvas.style.height = H + 'px'
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
      pts = Array.from({ length: density }, () => ({
        x: Math.random() * W, y: Math.random() * H,
        vx: (Math.random() - 0.5) * 0.28, vy: (Math.random() - 0.5) * 0.28,
        r: Math.random() * 1.8 + 0.6, hue: Math.random() > 0.5 ? '37,201,140' : '76,141,246',
      }))
    }
    resize()
    const ro = new ResizeObserver(resize); ro.observe(canvas.parentElement)
    let mx = -999, my = -999
    const onMove = (e) => { const r = canvas.getBoundingClientRect(); mx = e.clientX - r.left; my = e.clientY - r.top }
    const onLeave = () => { mx = -999; my = -999 }
    canvas.parentElement.addEventListener('mousemove', onMove)
    canvas.parentElement.addEventListener('mouseleave', onLeave)
    const draw = () => {
      ctx.clearRect(0, 0, W, H)
      for (const p of pts) {
        p.x += p.vx; p.y += p.vy
        if (p.x < 0 || p.x > W) p.vx *= -1
        if (p.y < 0 || p.y > H) p.vy *= -1
        const dm = Math.hypot(p.x - mx, p.y - my)
        if (dm < 130) { p.x += (p.x - mx) / dm * 0.6; p.y += (p.y - my) / dm * 0.6 }
      }
      for (let i = 0; i < pts.length; i++) for (let j = i + 1; j < pts.length; j++) {
        const a = pts[i], b = pts[j], d = Math.hypot(a.x - b.x, a.y - b.y)
        if (d < 128) { ctx.strokeStyle = `rgba(${a.hue},${(1 - d / 128) * 0.18 * opacity})`; ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.stroke() }
      }
      for (const p of pts) { ctx.fillStyle = `rgba(${p.hue},${0.7 * opacity})`; ctx.beginPath(); ctx.arc(p.x, p.y, p.r, 0, 7); ctx.fill() }
      raf = requestAnimationFrame(draw)
    }
    draw()
    return () => { cancelAnimationFrame(raf); ro.disconnect(); canvas.parentElement.removeEventListener('mousemove', onMove); canvas.parentElement.removeEventListener('mouseleave', onLeave) }
  }, [density, opacity])
  return <canvas ref={ref} style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }} />
}

// Interactive Knowledge Graph — takes real nodes/edges/types.
export function KnowledgeGraph({ nodes = [], edges = [], types = {}, onSelect, selectedId, filter, query }) {
  const ref = useRef()
  const stateRef = useRef({ scale: 1, ox: 0, oy: 0, drag: null, hover: null })
  const [, force] = useState(0)
  const dataRef = useRef({ nodes, edges, types })
  dataRef.current = { nodes, edges, types }

  useEffect(() => {
    const canvas = ref.current; if (!canvas) return
    const ctx = canvas.getContext('2d')
    let W, H, dpr, raf, t = 0
    const S = stateRef.current
    const resize = () => {
      dpr = Math.min(window.devicePixelRatio || 1, 2)
      const rect = canvas.parentElement.getBoundingClientRect()
      W = rect.width; H = rect.height
      canvas.width = W * dpr; canvas.height = H * dpr
      canvas.style.width = W + 'px'; canvas.style.height = H + 'px'
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
    }
    resize()
    const ro = new ResizeObserver(resize); ro.observe(canvas.parentElement)
    const nodePos = (n) => { const m = 70; return { x: (m + n.x * (W - m * 2)) * S.scale + S.ox, y: (m + n.y * (H - m * 2)) * S.scale + S.oy } }
    const isVisible = (n) => !(filter && filter !== 'all' && n.type !== filter)
    const isDimmed = (n) => query && !(`${n.label} ${n.sub || ''}`.toLowerCase().includes(query.toLowerCase()))
    const typeOf = (n) => dataRef.current.types[n.type] || { color: '#4C8DF6', label: n.type }

    const draw = () => {
      t += 0.016; ctx.clearRect(0, 0, W, H)
      const { nodes: NN, edges: EE } = dataRef.current
      for (const e of EE) {
        const na = NN.find((n) => n.id === e.a), nb = NN.find((n) => n.id === e.b)
        if (!na || !nb || !isVisible(na) || !isVisible(nb)) continue
        const pa = nodePos(na), pb = nodePos(nb)
        const sel = selectedId && (e.a === selectedId || e.b === selectedId)
        const hov = S.hover && (e.a === S.hover || e.b === S.hover)
        ctx.strokeStyle = sel || hov ? 'rgba(37,201,140,0.55)' : 'rgba(140,150,170,0.18)'
        ctx.lineWidth = sel || hov ? 1.8 : 1
        const mx = (pa.x + pb.x) / 2, my = (pa.y + pb.y) / 2 - 18
        ctx.beginPath(); ctx.moveTo(pa.x, pa.y); ctx.quadraticCurveTo(mx, my, pb.x, pb.y); ctx.stroke()
        if (sel) { const tt = (t * 0.4) % 1; const px = (1 - tt) * (1 - tt) * pa.x + 2 * (1 - tt) * tt * mx + tt * tt * pb.x; const py = (1 - tt) * (1 - tt) * pa.y + 2 * (1 - tt) * tt * my + tt * tt * pb.y; ctx.fillStyle = '#25C98C'; ctx.beginPath(); ctx.arc(px, py, 2.6, 0, 7); ctx.fill() }
        if (S.scale > 0.85 && (sel || hov) && e.label) { ctx.fillStyle = 'rgba(154,167,186,0.9)'; ctx.font = '10px JetBrains Mono'; ctx.textAlign = 'center'; ctx.fillText(e.label, mx, my - 4) }
      }
      for (const n of NN) {
        if (!isVisible(n)) continue
        const p = nodePos(n), dim = isDimmed(n), meta = typeOf(n)
        const sel = n.id === selectedId, hov = n.id === S.hover
        const R = n.size * S.scale * (1 + Math.sin(t * 2 + n.x * 9) * 0.04)
        ctx.globalAlpha = dim ? 0.18 : 1
        const g = ctx.createRadialGradient(p.x, p.y, 0, p.x, p.y, R * 2.4)
        g.addColorStop(0, meta.color + (sel ? '88' : '44')); g.addColorStop(1, meta.color + '00')
        ctx.fillStyle = g; ctx.beginPath(); ctx.arc(p.x, p.y, R * 2.4, 0, 7); ctx.fill()
        if (sel || hov) { ctx.strokeStyle = meta.color; ctx.lineWidth = 2; ctx.beginPath(); ctx.arc(p.x, p.y, R + 7, 0, 7); ctx.stroke() }
        ctx.fillStyle = '#0A0F1A'; ctx.beginPath(); ctx.arc(p.x, p.y, R, 0, 7); ctx.fill()
        ctx.strokeStyle = meta.color; ctx.lineWidth = 2.2; ctx.beginPath(); ctx.arc(p.x, p.y, R, 0, 7); ctx.stroke()
        ctx.fillStyle = meta.color; ctx.beginPath(); ctx.arc(p.x, p.y, R * 0.42, 0, 7); ctx.fill()
        if (n.risk) { const rc = { critical: '#E5566F', high: '#E68A4A', med: '#E0B23C' }[n.risk]; if (rc) { ctx.fillStyle = rc; ctx.beginPath(); ctx.arc(p.x + R * 0.72, p.y - R * 0.72, 4.5 * S.scale, 0, 7); ctx.fill() } }
        if (S.scale > 0.7 && !dim) { ctx.fillStyle = sel || hov ? '#EAF1FA' : 'rgba(154,167,186,0.85)'; ctx.font = `${sel ? '600 ' : ''}${11 * Math.min(S.scale, 1.3)}px Sora`; ctx.textAlign = 'center'; ctx.fillText(n.label, p.x, p.y + R + 15) }
        ctx.globalAlpha = 1
      }
      raf = requestAnimationFrame(draw)
    }
    draw()

    const hit = (mx, my) => { for (const n of dataRef.current.nodes) { if (!isVisible(n)) continue; const p = nodePos(n); if (Math.hypot(p.x - mx, p.y - my) < n.size * S.scale + 5) return n } return null }
    const getXY = (e) => { const r = canvas.getBoundingClientRect(); return { x: e.clientX - r.left, y: e.clientY - r.top } }
    const onDown = (e) => { const { x, y } = getXY(e); const n = hit(x, y); if (n && onSelect) onSelect(n); S.drag = { x, y, ox: S.ox, oy: S.oy } }
    const onMove = (e) => { const { x, y } = getXY(e); if (S.drag) { S.ox = S.drag.ox + (x - S.drag.x); S.oy = S.drag.oy + (y - S.drag.y) } else { const n = hit(x, y); const nh = n ? n.id : null; if (nh !== S.hover) { S.hover = nh; canvas.style.cursor = n ? 'pointer' : 'grab' } } }
    const onUp = () => { S.drag = null }
    const onWheel = (e) => { e.preventDefault(); const { x, y } = getXY(e); const f = e.deltaY < 0 ? 1.12 : 0.89; const ns = Math.max(0.4, Math.min(2.6, S.scale * f)); S.ox = x - (x - S.ox) * (ns / S.scale); S.oy = y - (y - S.oy) * (ns / S.scale); S.scale = ns; force((v) => v + 1) }
    canvas.addEventListener('mousedown', onDown); window.addEventListener('mousemove', onMove); window.addEventListener('mouseup', onUp); canvas.addEventListener('wheel', onWheel, { passive: false })
    canvas.style.cursor = 'grab'
    return () => { cancelAnimationFrame(raf); ro.disconnect(); canvas.removeEventListener('mousedown', onDown); window.removeEventListener('mousemove', onMove); window.removeEventListener('mouseup', onUp); canvas.removeEventListener('wheel', onWheel) }
  }, [selectedId, filter, query, onSelect])

  const zoom = (dir) => { const S = stateRef.current; S.scale = Math.max(0.4, Math.min(2.6, S.scale * (dir > 0 ? 1.2 : 0.83))); force((v) => v + 1) }
  const reset = () => { const S = stateRef.current; S.scale = 1; S.ox = 0; S.oy = 0; force((v) => v + 1) }

  return (
    <div style={{ position: 'absolute', inset: 0 }}>
      <canvas ref={ref} />
      <div style={{ position: 'absolute', right: 14, bottom: 14, display: 'flex', flexDirection: 'column', gap: 8 }}>
        <button className="icon-btn" onClick={() => zoom(1)} title="Zoom in">{Icons.plus()}</button>
        <button className="icon-btn" onClick={() => zoom(-1)} title="Zoom out"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round"><path d="M5 12h14" /></svg></button>
        <button className="icon-btn" onClick={reset} title="Reset view">{Icons.zoom()}</button>
      </div>
    </div>
  )
}

// Clean, deterministic layout: split the graph into connected components, lay each
// out as a hub (highest-degree node) with its neighbours on a ring, then tile the
// components across the canvas in a grid. No overlap, always tidy.
export function layoutHub(nodes, edges) {
  if (!nodes.length) return []
  const adj = {}
  nodes.forEach((n) => { adj[n.id] = [] })
  edges.forEach((e) => { const a = e.a ?? e.src, b = e.b ?? e.dst; if (adj[a] && adj[b]) { adj[a].push(b); adj[b].push(a) } })

  const seen = new Set(), comps = []
  for (const n of nodes) {
    if (seen.has(n.id)) continue
    const comp = [], q = [n.id]; seen.add(n.id)
    while (q.length) { const id = q.shift(); comp.push(id); for (const m of adj[id]) if (!seen.has(m)) { seen.add(m); q.push(m) } }
    comps.push(comp)
  }
  // biggest components first → top-left, prominent
  comps.sort((a, b) => b.length - a.length)

  const local = {}
  for (const comp of comps) {
    if (comp.length === 1) { local[comp[0]] = { x: 0, y: 0 }; continue }
    const hub = comp.reduce((best, id) => (adj[id].length > adj[best].length ? id : best), comp[0])
    local[hub] = { x: 0, y: 0 }
    const ring = comp.filter((id) => id !== hub)
    ring.forEach((id, i) => { const a = (i / ring.length) * 2 * Math.PI - Math.PI / 2; local[id] = { x: Math.cos(a), y: Math.sin(a) } })
  }

  const C = comps.length
  const cols = Math.ceil(Math.sqrt(C)), rows = Math.ceil(C / cols)
  const cellW = 1 / cols, cellH = 1 / rows
  const out = {}
  comps.forEach((comp, ci) => {
    const cx = (ci % cols + 0.5) * cellW
    const cy = (Math.floor(ci / cols) + 0.5) * cellH
    const rad = Math.min(cellW, cellH) * (comp.length > 1 ? 0.36 : 0)
    comp.forEach((id) => { const l = local[id]; out[id] = { x: cx + l.x * rad, y: cy + l.y * rad } })
  })
  return nodes.map((n) => ({ ...n, x: Math.max(0.06, Math.min(0.94, out[n.id].x)), y: Math.max(0.09, Math.min(0.91, out[n.id].y)) }))
}

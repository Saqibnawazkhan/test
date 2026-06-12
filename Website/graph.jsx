// ===== TaxNet AI — Canvas graph engine =====
const { useState: useStateG, useEffect: useEffectG, useRef: useRefG } = React;

// Ambient particle network for hero / page backgrounds
function NetworkBackground({ density = 64, opacity = 1 }) {
  const ref = useRefG();
  useEffectG(() => {
    const canvas = ref.current; if (!canvas) return;
    const ctx = canvas.getContext('2d');
    let W, H, dpr, raf, pts = [], roPaint = null;
    const resize = () => {
      dpr = Math.min(window.devicePixelRatio || 1, 2);
      const rect = canvas.parentElement.getBoundingClientRect();
      W = rect.width; H = rect.height;
      canvas.width = W * dpr; canvas.height = H * dpr;
      canvas.style.width = W + 'px'; canvas.style.height = H + 'px';
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      pts = Array.from({ length: density }, () => ({
        x: Math.random() * W, y: Math.random() * H,
        vx: (Math.random() - 0.5) * 0.28, vy: (Math.random() - 0.5) * 0.28,
        r: Math.random() * 1.8 + 0.6, hue: Math.random() > 0.5 ? '0,229,153' : '46,143,255',
      }));
    };
    resize();
    const ro = new ResizeObserver(() => { resize(); if (roPaint) roPaint(); }); ro.observe(canvas.parentElement);
    let mx = -999, my = -999;
    const onMove = e => { const r = canvas.getBoundingClientRect(); mx = e.clientX - r.left; my = e.clientY - r.top; };
    const onLeave = () => { mx = -999; my = -999; };
    canvas.parentElement.addEventListener('mousemove', onMove);
    canvas.parentElement.addEventListener('mouseleave', onLeave);
    const draw = () => {
      ctx.clearRect(0, 0, W, H);
      for (const p of pts) {
        p.x += p.vx; p.y += p.vy;
        if (p.x < 0 || p.x > W) p.vx *= -1;
        if (p.y < 0 || p.y > H) p.vy *= -1;
        const dm = Math.hypot(p.x - mx, p.y - my);
        if (dm < 130) { p.x += (p.x - mx) / dm * 0.6; p.y += (p.y - my) / dm * 0.6; }
      }
      for (let i = 0; i < pts.length; i++) {
        for (let j = i + 1; j < pts.length; j++) {
          const a = pts[i], b = pts[j];
          const d = Math.hypot(a.x - b.x, a.y - b.y);
          if (d < 128) {
            ctx.strokeStyle = `rgba(${a.hue},${(1 - d / 128) * 0.18 * opacity})`;
            ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.stroke();
          }
        }
      }
      for (const p of pts) {
        ctx.fillStyle = `rgba(${p.hue},${0.7 * opacity})`;
        ctx.beginPath(); ctx.arc(p.x, p.y, p.r, 0, 7); ctx.fill();
      }
    };
    const loop = () => { draw(); raf = requestAnimationFrame(loop); };
    loop();
    roPaint = draw;
    return () => { cancelAnimationFrame(raf); ro.disconnect();
      canvas.parentElement.removeEventListener('mousemove', onMove);
      canvas.parentElement.removeEventListener('mouseleave', onLeave); };
  }, []);
  return <canvas ref={ref} style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }} />;
}

// Interactive Knowledge Graph
function KnowledgeGraph({ onSelect, selectedId, filter, query }) {
  const ref = useRefG();
  const stateRef = useRefG({ scale: 1, ox: 0, oy: 0, drag: null, hover: null });
  const [, force] = useStateG(0);

  useEffectG(() => {
    const canvas = ref.current; if (!canvas) return;
    const ctx = canvas.getContext('2d');
    let W, H, dpr, raf, t = 0, roPaintG = null;
    const S = stateRef.current;
    const resize = () => {
      dpr = Math.min(window.devicePixelRatio || 1, 2);
      const rect = canvas.parentElement.getBoundingClientRect();
      W = rect.width; H = rect.height;
      canvas.width = W * dpr; canvas.height = H * dpr;
      canvas.style.width = W + 'px'; canvas.style.height = H + 'px';
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    };
    resize();
    const ro = new ResizeObserver(() => { resize(); if (roPaintG) roPaintG(); }); ro.observe(canvas.parentElement);

    const nodePos = n => {
      const margin = 70;
      const bx = margin + n.x * (W - margin * 2);
      const by = margin + n.y * (H - margin * 2);
      return { x: bx * S.scale + S.ox, y: by * S.scale + S.oy };
    };
    const isVisible = n => {
      if (filter && filter !== 'all' && n.type !== filter) return false;
      return true;
    };
    const isDimmed = n => {
      if (query && !(`${n.label} ${n.sub}`.toLowerCase().includes(query.toLowerCase()))) return true;
      return false;
    };

    const draw = () => {
      t += 0.016;
      ctx.clearRect(0, 0, W, H);
      // edges
      for (const e of GRAPH_EDGES) {
        const na = GRAPH_NODES.find(n => n.id === e.a), nb = GRAPH_NODES.find(n => n.id === e.b);
        if (!na || !nb || !isVisible(na) || !isVisible(nb)) continue;
        const pa = nodePos(na), pb = nodePos(nb);
        const sel = selectedId && (e.a === selectedId || e.b === selectedId);
        const hov = S.hover && (e.a === S.hover || e.b === S.hover);
        ctx.strokeStyle = sel || hov ? 'rgba(0,229,153,0.55)' : 'rgba(255,255,255,0.10)';
        ctx.lineWidth = sel || hov ? 1.8 : 1;
        ctx.beginPath(); ctx.moveTo(pa.x, pa.y);
        const mx = (pa.x + pb.x) / 2, my = (pa.y + pb.y) / 2 - 18;
        ctx.quadraticCurveTo(mx, my, pb.x, pb.y); ctx.stroke();
        // animated pulse along selected edges
        if (sel) {
          const tt = (t * 0.4) % 1;
          const px = (1-tt)*(1-tt)*pa.x + 2*(1-tt)*tt*mx + tt*tt*pb.x;
          const py = (1-tt)*(1-tt)*pa.y + 2*(1-tt)*tt*my + tt*tt*pb.y;
          ctx.fillStyle = '#00E599'; ctx.beginPath(); ctx.arc(px, py, 2.6, 0, 7); ctx.fill();
        }
        if (S.scale > 0.85 && (sel || hov)) {
          ctx.fillStyle = 'rgba(167,180,198,0.9)'; ctx.font = '10px JetBrains Mono'; ctx.textAlign = 'center';
          ctx.fillText(e.label, mx, my - 4);
        }
      }
      // nodes
      for (const n of GRAPH_NODES) {
        if (!isVisible(n)) continue;
        const p = nodePos(n);
        const dim = isDimmed(n);
        const meta = GRAPH_TYPES[n.type];
        const sel = n.id === selectedId, hov = n.id === S.hover;
        const pulse = 1 + Math.sin(t * 2 + n.x * 9) * 0.04;
        const R = n.size * S.scale * pulse;
        ctx.globalAlpha = dim ? 0.18 : 1;
        // glow
        const g = ctx.createRadialGradient(p.x, p.y, 0, p.x, p.y, R * 2.4);
        g.addColorStop(0, meta.color + (sel ? '88' : '44'));
        g.addColorStop(1, meta.color + '00');
        ctx.fillStyle = g; ctx.beginPath(); ctx.arc(p.x, p.y, R * 2.4, 0, 7); ctx.fill();
        // ring
        if (sel || hov) {
          ctx.strokeStyle = meta.color; ctx.lineWidth = 2;
          ctx.beginPath(); ctx.arc(p.x, p.y, R + 7, 0, 7); ctx.stroke();
        }
        // core
        ctx.fillStyle = '#0A0F1A'; ctx.beginPath(); ctx.arc(p.x, p.y, R, 0, 7); ctx.fill();
        ctx.strokeStyle = meta.color; ctx.lineWidth = 2.2; ctx.beginPath(); ctx.arc(p.x, p.y, R, 0, 7); ctx.stroke();
        ctx.fillStyle = meta.color; ctx.beginPath(); ctx.arc(p.x, p.y, R * 0.42, 0, 7); ctx.fill();
        // risk badge
        if (n.risk) {
          const rc = { critical:'#FF4D6D', high:'#FF8A3D', med:'#FFC94D' }[n.risk];
          ctx.fillStyle = rc; ctx.beginPath(); ctx.arc(p.x + R*0.72, p.y - R*0.72, 4.5*S.scale, 0, 7); ctx.fill();
        }
        // label
        if (S.scale > 0.7 && !dim) {
          ctx.fillStyle = sel || hov ? '#EAF1FA' : 'rgba(167,180,198,0.85)';
          ctx.font = `${sel ? '600 ' : ''}${11 * Math.min(S.scale,1.3)}px Sora`; ctx.textAlign = 'center';
          ctx.fillText(n.label, p.x, p.y + R + 15);
        }
        ctx.globalAlpha = 1;
      }
    };
    const loop = () => { draw(); raf = requestAnimationFrame(loop); };
    loop();
    roPaintG = draw;

    // interaction
    const hit = (mx, my) => {
      for (const n of GRAPH_NODES) {
        if (!isVisible(n)) continue;
        const p = nodePos(n);
        if (Math.hypot(p.x - mx, p.y - my) < n.size * S.scale + 5) return n;
      }
      return null;
    };
    const getXY = e => { const r = canvas.getBoundingClientRect(); return { x: e.clientX - r.left, y: e.clientY - r.top }; };
    const onDown = e => { const { x, y } = getXY(e); const n = hit(x, y); if (n) { onSelect(n); } S.drag = { x, y, ox: S.ox, oy: S.oy, moved: false }; };
    const onMove = e => {
      const { x, y } = getXY(e);
      if (S.drag) { S.ox = S.drag.ox + (x - S.drag.x); S.oy = S.drag.oy + (y - S.drag.y); if (Math.hypot(x-S.drag.x,y-S.drag.y)>3) S.drag.moved = true; }
      else { const n = hit(x, y); const nh = n ? n.id : null; if (nh !== S.hover) { S.hover = nh; canvas.style.cursor = n ? 'pointer' : 'grab'; } }
    };
    const onUp = () => { S.drag = null; };
    const onWheel = e => {
      e.preventDefault();
      const { x, y } = getXY(e);
      const factor = e.deltaY < 0 ? 1.12 : 0.89;
      const ns = Math.max(0.4, Math.min(2.6, S.scale * factor));
      S.ox = x - (x - S.ox) * (ns / S.scale); S.oy = y - (y - S.oy) * (ns / S.scale);
      S.scale = ns; force(v => v + 1);
    };
    canvas.addEventListener('mousedown', onDown);
    window.addEventListener('mousemove', onMove);
    window.addEventListener('mouseup', onUp);
    canvas.addEventListener('wheel', onWheel, { passive: false });
    canvas.style.cursor = 'grab';
    return () => { cancelAnimationFrame(raf); ro.disconnect();
      canvas.removeEventListener('mousedown', onDown);
      window.removeEventListener('mousemove', onMove);
      window.removeEventListener('mouseup', onUp);
      canvas.removeEventListener('wheel', onWheel); };
  }, [selectedId, filter, query]);

  const zoom = dir => { const S = stateRef.current; S.scale = Math.max(0.4, Math.min(2.6, S.scale * (dir > 0 ? 1.2 : 0.83))); force(v => v + 1); };
  const reset = () => { const S = stateRef.current; S.scale = 1; S.ox = 0; S.oy = 0; force(v => v + 1); };

  return (
    <div style={{ position: 'absolute', inset: 0 }}>
      <canvas ref={ref} />
      <div style={{ position: 'absolute', right: 14, bottom: 14, display: 'flex', flexDirection: 'column', gap: 8 }}>
        <button className="icon-btn" onClick={() => zoom(1)} title="Zoom in">{React.createElement(Icons.plus)}</button>
        <button className="icon-btn" onClick={() => zoom(-1)} title="Zoom out"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round"><path d="M5 12h14"/></svg></button>
        <button className="icon-btn" onClick={reset} title="Reset view">{React.createElement(Icons.zoom)}</button>
      </div>
    </div>
  );
}

Object.assign(window, { NetworkBackground, KnowledgeGraph });

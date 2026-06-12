// ===== TaxNet AI — Charts (SVG, animated) =====
const { useState, useEffect, useRef } = React;

// Animated number counter
function AnimatedCounter({ value, fmt, duration = 1400 }) {
  const [v, setV] = useState(0);
  const ref = useRef();
  useEffect(() => {
    let raf, start;
    const step = (ts) => {
      if (!start) start = ts;
      const p = Math.min((ts - start) / duration, 1);
      const eased = 1 - Math.pow(1 - p, 3);
      setV(value * eased);
      if (p < 1) raf = requestAnimationFrame(step);
    };
    raf = requestAnimationFrame(step);
    // fallback: if rAF is throttled/paused, snap to final value so nothing reads 0
    const fb = setTimeout(() => setV(value), duration + 250);
    return () => { cancelAnimationFrame(raf); clearTimeout(fb); };
  }, [value]);
  return <span ref={ref}>{fmtKpi(v, fmt)}</span>;
}

// Mini sparkline
function Sparkline({ data, color = 'var(--green)', w = 120, h = 36, fill = true }) {
  const max = Math.max(...data), min = Math.min(...data);
  const rng = max - min || 1;
  const pts = data.map((d, i) => [ (i / (data.length - 1)) * w, h - ((d - min) / rng) * (h - 6) - 3 ]);
  const line = pts.map((p, i) => `${i ? 'L' : 'M'}${p[0].toFixed(1)} ${p[1].toFixed(1)}`).join(' ');
  const area = `${line} L${w} ${h} L0 ${h} Z`;
  const id = 'sg' + Math.random().toString(36).slice(2, 7);
  return (
    <svg width={w} height={h} style={{ display: 'block', overflow: 'visible' }}>
      <defs><linearGradient id={id} x1="0" y1="0" x2="0" y2="1">
        <stop offset="0%" stopColor={color} stopOpacity="0.32" /><stop offset="100%" stopColor={color} stopOpacity="0" />
      </linearGradient></defs>
      {fill && <path d={area} fill={`url(#${id})`} />}
      <path d={line} fill="none" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
      <circle cx={pts[pts.length-1][0]} cy={pts[pts.length-1][1]} r="2.6" fill={color} />
    </svg>
  );
}

// Multi-line chart with grid + animated draw
function LineChart({ series, labels, height = 240 }) {
  const wrapRef = useRef();
  const [w, setW] = useState(640);
  useEffect(() => {
    const ro = new ResizeObserver(es => setW(es[0].contentRect.width));
    if (wrapRef.current) ro.observe(wrapRef.current);
    return () => ro.disconnect();
  }, []);
  const padL = 34, padB = 26, padT = 12, padR = 8;
  const iw = w - padL - padR, ih = height - padB - padT;
  const all = series.flatMap(s => s.data);
  const max = Math.max(...all) * 1.1, min = 0;
  const xx = i => padL + (i / (labels.length - 1)) * iw;
  const yy = v => padT + ih - ((v - min) / (max - min)) * ih;
  return (
    <div ref={wrapRef} style={{ width: '100%' }}>
      <svg width={w} height={height} style={{ display: 'block' }}>
        {[0, 0.25, 0.5, 0.75, 1].map((g, i) => (
          <g key={i}>
            <line x1={padL} x2={w - padR} y1={padT + ih * g} y2={padT + ih * g} stroke="rgba(255,255,255,0.05)" />
            <text x={padL - 8} y={padT + ih * g + 3} textAnchor="end" fontSize="9" fill="var(--text-3)" fontFamily="var(--font-mono)">{Math.round(max * (1 - g))}</text>
          </g>
        ))}
        {labels.map((l, i) => i % 2 === 0 && (
          <text key={i} x={xx(i)} y={height - 8} textAnchor="middle" fontSize="9.5" fill="var(--text-3)" fontFamily="var(--font-mono)">{l}</text>
        ))}
        {series.map((s, si) => {
          const line = s.data.map((d, i) => `${i ? 'L' : 'M'}${xx(i).toFixed(1)} ${yy(d).toFixed(1)}`).join(' ');
          const area = `${line} L${xx(s.data.length-1)} ${padT+ih} L${padL} ${padT+ih} Z`;
          const gid = 'lg' + si;
          return (
            <g key={si}>
              <defs><linearGradient id={gid} x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor={s.color} stopOpacity="0.22" /><stop offset="100%" stopColor={s.color} stopOpacity="0" />
              </linearGradient></defs>
              {s.fill !== false && <path d={area} fill={`url(#${gid})`} />}
              <path d={line} fill="none" stroke={s.color} strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" />
              {s.data.map((d, i) => <circle key={i} cx={xx(i)} cy={yy(d)} r="3" fill="var(--bg-0)" stroke={s.color} strokeWidth="2" />)}
            </g>
          );
        })}
      </svg>
      <style>{`@keyframes draw{to{stroke-dashoffset:0}}@keyframes fadeDot{to{opacity:1}}`}</style>
    </div>
  );
}

// Bar chart (vertical)
function BarChart({ data, height = 200, format }) {
  const max = Math.max(...data.map(d => d.value)) * 1.12;
  return (
    <div style={{ display: 'flex', alignItems: 'flex-end', gap: 14, height, paddingTop: 8 }}>
      {data.map((d, i) => (
        <div key={i} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', height: '100%', justifyContent: 'flex-end', gap: 8 }}>
          <div className="mono" style={{ fontSize: 11, color: 'var(--text)', fontWeight: 600 }}>{format ? format(d.value) : d.value}</div>
          <div style={{ width: '70%', maxWidth: 40, borderRadius: '6px 6px 3px 3px', background: d.color || 'linear-gradient(180deg,var(--green),rgba(0,229,153,0.3))',
            height: `${(d.value / max) * 100}%`, minHeight: 4, boxShadow: '0 0 18px -6px var(--green-glow)' }} />
          <div style={{ fontSize: 10.5, color: 'var(--text-3)', fontFamily: 'var(--font-mono)' }}>{d.label}</div>
        </div>
      ))}
      <style>{`@keyframes growBar{from{transform:scaleY(0)}to{transform:scaleY(1)}}`}</style>
    </div>
  );
}

// Donut chart
function DonutChart({ data, size = 180, thickness = 22, centerLabel, centerSub }) {
  const r = (size - thickness) / 2, c = 2 * Math.PI * r, cx = size / 2;
  const total = data.reduce((s, d) => s + d.value, 0);
  let acc = 0;
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 22, flexWrap: 'wrap' }}>
      <div style={{ position: 'relative', width: size, height: size, flex: 'none' }}>
        <svg width={size} height={size} style={{ transform: 'rotate(-90deg)' }}>
          <circle cx={cx} cy={cx} r={r} fill="none" stroke="rgba(255,255,255,0.06)" strokeWidth={thickness} />
          {data.map((d, i) => {
            const len = (d.value / total) * c;
            const seg = <circle key={i} cx={cx} cy={cx} r={r} fill="none" stroke={d.color} strokeWidth={thickness}
              strokeDasharray={`${len} ${c - len}`} strokeDashoffset={-acc} strokeLinecap="butt"
              style={{ filter: 'drop-shadow(0 0 6px rgba(0,0,0,0.4))' }} />;
            acc += len; return seg;
          })}
        </svg>
        <div style={{ position: 'absolute', inset: 0, display: 'grid', placeItems: 'center', textAlign: 'center' }}>
          <div>
            <div className="mono" style={{ fontSize: 26, fontWeight: 700, lineHeight: 1 }}>{centerLabel}</div>
            <div style={{ fontSize: 10.5, color: 'var(--text-3)', marginTop: 4, letterSpacing: '0.06em' }}>{centerSub}</div>
          </div>
        </div>
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 11, flex: 1, minWidth: 130 }}>
        {data.map((d, i) => (
          <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <span style={{ width: 10, height: 10, borderRadius: 3, background: d.color, flex: 'none', boxShadow: `0 0 8px ${d.color}` }} />
            <span style={{ fontSize: 12.5, color: 'var(--text-2)' }}>{d.label}</span>
            <span className="mono" style={{ marginLeft: 'auto', fontSize: 12.5, fontWeight: 600 }}>{d.value}%</span>
          </div>
        ))}
      </div>
      <style>{`@keyframes dashGrow{from{stroke-dasharray:0 ${c}}}`}</style>
    </div>
  );
}

// Heatmap grid
function Heatmap({ rows = 6, cols = 14, seed = 7 }) {
  const cells = [];
  let s = seed;
  const rnd = () => { s = (s * 9301 + 49297) % 233280; return s / 233280; };
  const colorFor = v => v > 0.78 ? '#FF4D6D' : v > 0.58 ? '#FF8A3D' : v > 0.36 ? '#FFC94D' : v > 0.16 ? '#00E599' : 'rgba(0,229,153,0.18)';
  for (let r = 0; r < rows; r++) for (let c = 0; c < cols; c++) cells.push({ r, c, v: rnd() });
  return (
    <div style={{ display: 'grid', gridTemplateColumns: `repeat(${cols}, 1fr)`, gap: 5 }}>
      {cells.map((cell, i) => (
        <div key={i} title={`Risk ${(cell.v*100).toFixed(0)}%`} style={{
          aspectRatio: '1', borderRadius: 4, background: colorFor(cell.v),
          boxShadow: cell.v > 0.58 ? `0 0 10px -2px ${colorFor(cell.v)}` : 'none', cursor: 'pointer',
        }} />
      ))}
      <style>{`@keyframes cellIn{from{opacity:0;transform:scale(.4)}to{opacity:1;transform:scale(1)}}`}</style>
    </div>
  );
}

// Circular risk meter / gauge
function RiskMeter({ value = 94, size = 220, label = 'Compliance Deviation' }) {
  const [v, setV] = useState(0);
  useEffect(() => { const t = setTimeout(() => setV(value), 200); return () => clearTimeout(t); }, [value]);
  const r = size / 2 - 18, cx = size / 2;
  const start = 135, sweep = 270;
  const c = 2 * Math.PI * r;
  const arcLen = (sweep / 360) * c;
  const prog = (v / 100) * arcLen;
  const sev = value >= 80 ? '#FF4D6D' : value >= 60 ? '#FF8A3D' : value >= 35 ? '#FFC94D' : '#00E599';
  const sevLabel = value >= 80 ? 'CRITICAL' : value >= 60 ? 'HIGH' : value >= 35 ? 'MEDIUM' : 'LOW';
  const ticks = Array.from({ length: 28 });
  return (
    <div style={{ position: 'relative', width: size, height: size }}>
      <svg width={size} height={size} style={{ transform: `rotate(${start}deg)` }}>
        <defs>
          <linearGradient id="riskGrad" x1="0" y1="0" x2="1" y2="1">
            <stop offset="0%" stopColor="#00E599" /><stop offset="50%" stopColor="#FFC94D" /><stop offset="100%" stopColor="#FF4D6D" />
          </linearGradient>
        </defs>
        <circle cx={cx} cy={cx} r={r} fill="none" stroke="rgba(255,255,255,0.06)" strokeWidth="14"
          strokeDasharray={`${arcLen} ${c}`} strokeLinecap="round" />
        <circle cx={cx} cy={cx} r={r} fill="none" stroke="url(#riskGrad)" strokeWidth="14"
          strokeDasharray={`${prog} ${c}`} strokeLinecap="round"
          style={{ transition: 'stroke-dasharray 1.4s cubic-bezier(.3,.8,.3,1)', filter: `drop-shadow(0 0 10px ${sev})` }} />
      </svg>
      <div style={{ position: 'absolute', inset: 0, display: 'grid', placeItems: 'center', textAlign: 'center' }}>
        <div>
          <div className="mono" style={{ fontSize: 52, fontWeight: 700, lineHeight: 1, color: sev }}>
            {Math.round(v)}
          </div>
          <div style={{ fontFamily: 'var(--font-mono)', fontSize: 12, fontWeight: 700, letterSpacing: '0.18em', color: sev, marginTop: 6 }}>{sevLabel}</div>
          <div style={{ fontSize: 10.5, color: 'var(--text-3)', marginTop: 6, maxWidth: 120 }}>{label}</div>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { AnimatedCounter, Sparkline, LineChart, BarChart, DonutChart, Heatmap, RiskMeter });

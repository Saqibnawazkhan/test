// TaxNet AI — icon set (stroke-based, currentColor)
const Ic = ({ d, children, fill, vb = '0 0 24 24', sw = 1.7, ...rest }) => (
  <svg width="20" height="20" viewBox={vb} fill={fill || 'none'} stroke="currentColor" strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round" {...rest}>
    {d ? <path d={d} /> : children}
  </svg>
)

export const Icons = {
  dashboard: (p) => <Ic {...p}><rect x="3" y="3" width="7" height="9" rx="1.5"/><rect x="14" y="3" width="7" height="5" rx="1.5"/><rect x="14" y="12" width="7" height="9" rx="1.5"/><rect x="3" y="16" width="7" height="5" rx="1.5"/></Ic>,
  graph: (p) => <Ic {...p}><circle cx="5" cy="6" r="2.2"/><circle cx="19" cy="7" r="2.2"/><circle cx="12" cy="17" r="2.4"/><circle cx="6" cy="18" r="1.8"/><path d="M7 7l3.5 8M17 8.5l-3.5 7M7.5 17.4l2.6-1.4"/></Ic>,
  entity: (p) => <Ic {...p}><circle cx="8" cy="8" r="3"/><circle cx="17" cy="15" r="3"/><path d="M10.5 10.2l4 2.6M8 11v3.5M14.5 8H18"/></Ic>,
  risk: (p) => <Ic {...p}><path d="M12 3l8 4v5c0 4.4-3.1 7.7-8 9-4.9-1.3-8-4.6-8-9V7z"/><path d="M12 8.5v4M12 15.4v.1"/></Ic>,
  audit: (p) => <Ic {...p}><path d="M9 4h6a2 2 0 0 1 2 2v13a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2"/><path d="M9 9h6M9 13h6M9 17h3"/></Ic>,
  reports: (p) => <Ic {...p}><path d="M5 3h9l5 5v13a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1"/><path d="M14 3v5h5"/><path d="M8 13l2.5 2.5L16 11" /></Ic>,
  settings: (p) => <Ic {...p}><circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M4.9 4.9l2.1 2.1M17 17l2.1 2.1M2 12h3M19 12h3M4.9 19.1l2.1-2.1M17 7l2.1-2.1"/></Ic>,
  search: (p) => <Ic {...p}><circle cx="11" cy="11" r="7"/><path d="M21 21l-4-4"/></Ic>,
  bell: (p) => <Ic {...p}><path d="M18 8a6 6 0 0 0-12 0c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.7 21a2 2 0 0 1-3.4 0"/></Ic>,
  sun: (p) => <Ic {...p}><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/></Ic>,
  moon: (p) => <Ic {...p} d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8"/>,
  spark: (p) => <Ic {...p}><path d="M12 3v4M12 17v4M3 12h4M17 12h4" /><path d="M12 8.5a3.5 3.5 0 0 0 0 7 3.5 3.5 0 0 0 0-7"/></Ic>,
  bot: (p) => <Ic {...p}><rect x="4" y="8" width="16" height="11" rx="3"/><path d="M12 4v4M8.5 13v1.5M15.5 13v1.5"/><circle cx="12" cy="4" r="1.3"/></Ic>,
  mic: (p) => <Ic {...p}><rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5 11a7 7 0 0 0 14 0M12 18v3"/></Ic>,
  close: (p) => <Ic {...p} d="M6 6l12 12M18 6L6 18"/>,
  menu: (p) => <Ic {...p} d="M4 7h16M4 12h16M4 17h16"/>,
  arrowUp: (p) => <Ic {...p} d="M12 19V5M5 12l7-7 7 7"/>,
  arrowDown: (p) => <Ic {...p} d="M12 5v14M19 12l-7 7-7-7"/>,
  arrowRight: (p) => <Ic {...p} d="M5 12h14M13 6l6 6-6 6"/>,
  user: (p) => <Ic {...p}><circle cx="12" cy="8" r="4"/><path d="M5 21c0-3.9 3.1-7 7-7s7 3.1 7 7"/></Ic>,
  car: (p) => <Ic {...p}><path d="M5 16V12l2-5h10l2 5v4"/><path d="M3 16h18M6.5 19v-3M17.5 19v-3"/></Ic>,
  home: (p) => <Ic {...p} d="M4 11l8-7 8 7M6 10v9h12v-9"/>,
  bolt: (p) => <Ic {...p} d="M13 3L5 13h6l-1 8 8-10h-6z" fill="currentColor"/>,
  plane: (p) => <Ic {...p} d="M10.5 13.5L3 11l1-2 7 1 4-6 2 .5-2 6.5 6 2-1 2-6-1-2 4-1.5-.5z"/>,
  doc: (p) => <Ic {...p}><path d="M6 3h8l4 4v14H6z"/><path d="M14 3v4h4M9 12h6M9 16h6"/></Ic>,
  upload: (p) => <Ic {...p}><path d="M12 16V4M7 9l5-5 5 5"/><path d="M4 17v2a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-2"/></Ic>,
  trophy: (p) => <Ic {...p}><path d="M7 4h10v4a5 5 0 0 1-10 0z"/><path d="M7 6H4v1a3 3 0 0 0 3 3M17 6h3v1a3 3 0 0 1-3 3M9 14h6M8 20h8M12 14v3"/></Ic>,
  shield: (p) => <Ic {...p}><path d="M12 3l8 3v5c0 4.5-3.2 8-8 9-4.8-1-8-4.5-8-9V6z"/><path d="M9 12l2 2 4-4"/></Ic>,
  filter: (p) => <Ic {...p} d="M3 5h18l-7 8v5l-4 2v-7z"/>,
  zoom: (p) => <Ic {...p}><circle cx="11" cy="11" r="7"/><path d="M21 21l-3.5-3.5M11 8v6M8 11h6"/></Ic>,
  check: (p) => <Ic {...p} d="M5 12l4.5 4.5L19 7"/>,
  alert: (p) => <Ic {...p}><path d="M12 3l9 16H3z"/><path d="M12 10v4M12 17v.1"/></Ic>,
  trend: (p) => <Ic {...p} d="M3 17l6-6 4 4 8-8M21 11V7h-4"/>,
  layers: (p) => <Ic {...p} d="M12 3l9 5-9 5-9-5zM3 13l9 5 9-5M3 17l9 5 9-5"/>,
  pin: (p) => <Ic {...p}><path d="M12 21s7-5.5 7-11a7 7 0 0 0-14 0c0 5.5 7 11 7 11"/><circle cx="12" cy="10" r="2.5"/></Ic>,
  clock: (p) => <Ic {...p}><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></Ic>,
  link: (p) => <Ic {...p}><path d="M9 12a3 3 0 0 0 3 3h2a3 3 0 0 0 0-6"/><path d="M15 12a3 3 0 0 0-3-3h-2a3 3 0 0 0 0 6"/></Ic>,
  download: (p) => <Ic {...p}><path d="M12 4v12M7 11l5 5 5-5"/><path d="M4 19h16"/></Ic>,
  eye: (p) => <Ic {...p}><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7"/><circle cx="12" cy="12" r="3"/></Ic>,
  flag: (p) => <Ic {...p} d="M5 21V4h13l-2.5 4L18 12H5"/>,
  logout: (p) => <Ic {...p} d="M9 4H6a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h3M16 17l5-5-5-5M21 12H9"/>,
  send: (p) => <Ic {...p} d="M4 12l16-7-7 16-2.5-6.5z"/>,
  plus: (p) => <Ic {...p} d="M12 5v14M5 12h14"/>,
  globe: (p) => <Ic {...p}><circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c2.5 2.5 2.5 15 0 18M12 3c-2.5 2.5-2.5 15 0 18"/></Ic>,
  card: (p) => <Ic {...p}><rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3 10h18"/></Ic>,
  store: (p) => <Ic {...p}><path d="M4 9l1-5h14l1 5M5 9v10h14V9M4 9h16"/></Ic>,
  wallet: (p) => <Ic {...p}><path d="M3 7a2 2 0 0 1 2-2h13v4M3 7v10a2 2 0 0 0 2 2h14V11H5a2 2 0 0 1-2-2"/><circle cx="16" cy="14" r="1.2"/></Ic>,
  calc: (p) => <Ic {...p}><rect x="5" y="3" width="14" height="18" rx="2"/><path d="M8 7h8M8 11h.01M12 11h.01M16 11h.01M8 15h.01M12 15h.01M16 15v3M8 18h4"/></Ic>,
  receipt: (p) => <Ic {...p}><path d="M5 3v18l2-1 2 1 2-1 2 1 2-1 2 1V3l-2 1-2-1-2 1-2-1-2 1z"/><path d="M9 8h6M9 12h6"/></Ic>,
  edit: (p) => <Ic {...p}><path d="M4 20h4l10-10-4-4L4 16z"/><path d="M13.5 6.5l4 4"/></Ic>,
  family: (p) => <Ic {...p}><circle cx="7" cy="7" r="2.5"/><circle cx="17" cy="7" r="2.5"/><path d="M3 20c0-2.5 2-4 4-4s4 1.5 4 4M13 20c0-2.5 2-4 4-4s4 1.5 4 4M9.5 7h5"/></Ic>,
}

export const I = (n, p) => {
  const C = Icons[n]
  return C ? C(p) : null
}

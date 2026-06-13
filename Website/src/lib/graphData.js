// Exact knowledge-graph data from the original prototype (legacy/data.jsx) — same
// entities, same fixed positions, same edges. Do not recompute these coordinates.
export const GRAPH_TYPES = {
  citizen: { label: 'Citizen', color: '#2E8FFF', icon: 'user' },
  vehicle: { label: 'Vehicle', color: '#22D3EE', icon: 'car' },
  property: { label: 'Property', color: '#00E599', icon: 'home' },
  utility: { label: 'Utility Bill', color: '#FFC94D', icon: 'bolt' },
  taxreturn: { label: 'Tax Return', color: '#8B7CFF', icon: 'doc' },
  travel: { label: 'Travel Record', color: '#FF8A3D', icon: 'plane' },
}

export const GRAPH_NODES = [
  { id: 'c1', type: 'citizen', label: 'Ahmed Khan', sub: 'CNIC 35202-•••-7', x: 0.50, y: 0.50, size: 30, risk: 'critical' },
  { id: 'v1', type: 'vehicle', label: 'Toyota Land Cruiser', sub: 'LEA-2000 · 4600cc', x: 0.74, y: 0.30, size: 19 },
  { id: 'v2', type: 'vehicle', label: 'BMW X5', sub: 'ATV-119 · 3000cc', x: 0.80, y: 0.50, size: 18 },
  { id: 'p1', type: 'property', label: 'DHA Phase 6 Villa', sub: '2 Kanal · Lahore', x: 0.27, y: 0.28, size: 20 },
  { id: 'p2', type: 'property', label: 'Bahria Apartment', sub: '1800 sqft · Karachi', x: 0.20, y: 0.52, size: 17 },
  { id: 'u1', type: 'utility', label: 'K-Electric A/C', sub: 'PKR 312,400 / mo', x: 0.30, y: 0.76, size: 18 },
  { id: 't1', type: 'taxreturn', label: 'FY24 Return', sub: 'Declared: PKR 0', x: 0.55, y: 0.78, size: 18, risk: 'high' },
  { id: 'tr1', type: 'travel', label: 'DXB · LHR · IST', sub: '11 trips / 18mo', x: 0.74, y: 0.72, size: 18 },
  { id: 'c2', type: 'citizen', label: 'Sara Ahmed', sub: 'CNIC 42101-•••-3', x: 0.90, y: 0.74, size: 17, risk: 'med' },
  { id: 'c3', type: 'citizen', label: 'M. Bilal', sub: 'CNIC 35201-•••-9', x: 0.10, y: 0.80, size: 16 },
]

export const GRAPH_EDGES = [
  { a: 'c1', b: 'v1', label: 'owns' }, { a: 'c1', b: 'v2', label: 'owns' },
  { a: 'c1', b: 'p1', label: 'owns' }, { a: 'c1', b: 'p2', label: 'co-owns' },
  { a: 'c1', b: 'u1', label: 'pays' }, { a: 'c1', b: 't1', label: 'filed' },
  { a: 'c1', b: 'tr1', label: 'travelled' }, { a: 'p1', b: 'u1', label: 'metered at' },
  { a: 'c2', b: 'tr1', label: 'co-travelled' }, { a: 'c2', b: 'p2', label: 'linked' },
  { a: 'c3', b: 'p2', label: 'tenant' }, { a: 'tr1', b: 'v2', label: 'airport pickup' },
]

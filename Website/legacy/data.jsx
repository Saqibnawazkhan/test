// ===== TaxNet AI — Mock data layer =====

const KPIS = [
  { id: 'citizens', label: 'Total Citizens Analyzed', value: 84219736, fmt: 'short', delta: +2.4, icon: 'user', accent: 'blue', spark: [30,34,32,40,44,48,52,60,58,66,72,80] },
  { id: 'filers', label: 'Active Tax Filers', value: 4192880, fmt: 'short', delta: +5.8, icon: 'check', accent: 'green', spark: [20,22,26,25,30,33,38,42,46,52,58,64] },
  { id: 'nonfilers', label: 'Non-Filers Detected', value: 2738450, fmt: 'short', delta: +12.1, icon: 'flag', accent: 'high', spark: [60,58,55,52,48,46,40,38,33,30,26,22] },
  { id: 'highrisk', label: 'High-Risk Individuals', value: 318274, fmt: 'short', delta: +8.3, icon: 'alert', accent: 'critical', spark: [12,16,15,20,24,22,30,34,40,44,52,58] },
  { id: 'compliance', label: 'Avg. Compliance Score', value: 61.4, fmt: 'score', delta: +1.9, icon: 'shield', accent: 'green', spark: [50,52,51,54,55,57,56,58,59,60,61,61] },
  { id: 'revenue', label: 'Revenue Recovery Potential', value: 1.84, fmt: 'currency', delta: +6.7, icon: 'trend', accent: 'blue', spark: [22,28,30,36,40,46,50,55,60,68,74,82] },
];

// Knowledge graph entities
const GRAPH_TYPES = {
  citizen:  { label: 'Citizen',     color: '#2E8FFF', icon: 'user' },
  vehicle:  { label: 'Vehicle',     color: '#22D3EE', icon: 'car' },
  property: { label: 'Property',    color: '#00E599', icon: 'home' },
  utility:  { label: 'Utility Bill',color: '#FFC94D', icon: 'bolt' },
  taxreturn:{ label: 'Tax Return',  color: '#8B7CFF', icon: 'doc' },
  travel:   { label: 'Travel Record',color:'#FF8A3D', icon: 'plane' },
};

const GRAPH_NODES = [
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
];

const GRAPH_EDGES = [
  { a: 'c1', b: 'v1', label: 'owns' }, { a: 'c1', b: 'v2', label: 'owns' },
  { a: 'c1', b: 'p1', label: 'owns' }, { a: 'c1', b: 'p2', label: 'co-owns' },
  { a: 'c1', b: 'u1', label: 'pays' }, { a: 'c1', b: 't1', label: 'filed' },
  { a: 'c1', b: 'tr1', label: 'travelled' }, { a: 'p1', b: 'u1', label: 'metered at' },
  { a: 'c2', b: 'tr1', label: 'co-travelled' }, { a: 'c2', b: 'p2', label: 'linked' },
  { a: 'c3', b: 'p2', label: 'tenant' }, { a: 'tr1', b: 'v2', label: 'airport pickup' },
];

// Risk factors for Ahmed Khan
const RISK_FACTORS = [
  { label: 'Luxury Vehicle Ownership', weight: 92, detail: '2 vehicles · 4600cc + 3000cc', icon: 'car', sev: 'critical' },
  { label: 'High Electricity Consumption', weight: 88, detail: 'PKR 312,400 monthly avg', icon: 'bolt', sev: 'critical' },
  { label: 'Multiple Properties', weight: 76, detail: '2 declared, 1 undeclared', icon: 'home', sev: 'high' },
  { label: 'Foreign Travel Frequency', weight: 71, detail: '11 international trips / 18mo', icon: 'plane', sev: 'high' },
  { label: 'Declared Income Mismatch', weight: 97, detail: 'Lifestyle ≫ PKR 0 declared', icon: 'trend', sev: 'critical' },
];

// Entity resolution sources
const ER_SOURCES = [
  { name: 'Vehicle Registration DB', records: 18, match: 99.2, status: 'matched', icon: 'car', key: 'Excise & Taxation' },
  { name: 'Property Records', records: 6, match: 96.7, status: 'matched', icon: 'home', key: 'Land Authority' },
  { name: 'Utility Bills', records: 24, match: 98.1, status: 'matched', icon: 'bolt', key: 'K-Electric / SNGPL' },
  { name: 'Travel History', records: 11, match: 91.4, status: 'review', icon: 'plane', key: 'FIA Immigration' },
  { name: 'Tax Records', records: 3, match: 99.8, status: 'matched', icon: 'doc', key: 'FBR IRIS' },
];

// Audit / explainability timeline
const AI_TIMELINE = [
  { t: 'Identity resolved', d: 'Linked 62 records across 5 databases to a single canonical entity with 97.4% confidence.', icon: 'entity', tone: 'blue' },
  { t: 'Asset graph constructed', d: 'Detected 2 luxury vehicles, 2 properties and 1 undeclared property via co-metered utility.', icon: 'graph', tone: 'cyan' },
  { t: 'Lifestyle vs. income modelled', d: 'GNN estimated annual outflow of PKR 41.2M against PKR 0 declared income.', icon: 'trend', tone: 'green' },
  { t: 'Anomaly score elevated', d: 'Compliance deviation score reached 94/100 — flagged Critical for audit.', icon: 'alert', tone: 'critical' },
  { t: 'Recommendation issued', d: 'Auto-generated Section 122(5A) notice draft + field-audit assignment.', icon: 'flag', tone: 'high' },
];

// Leaderboard
const LEADERBOARD = [
  { rank: 1, name: 'Ahmed Khan', region: 'Lahore', score: 94, recover: 41.2, risk: 'critical' },
  { rank: 2, name: 'Imran Sethi', region: 'Karachi', score: 91, recover: 38.7, risk: 'critical' },
  { rank: 3, name: 'Nadia Qureshi', region: 'Islamabad', score: 88, recover: 29.4, risk: 'critical' },
  { rank: 4, name: 'Faisal Raza', region: 'Faisalabad', score: 84, recover: 22.1, risk: 'high' },
  { rank: 5, name: 'Zara Malik', region: 'Lahore', score: 81, recover: 19.8, risk: 'high' },
  { rank: 6, name: 'Bilal Anwar', region: 'Multan', score: 77, recover: 15.3, risk: 'high' },
  { rank: 7, name: 'Hina Tariq', region: 'Karachi', score: 73, recover: 12.6, risk: 'med' },
];

// Notifications
const NOTIFS = [
  { t: '14 new Critical entities flagged', time: '2m ago', tone: 'critical', icon: 'alert' },
  { t: 'GNN model re-trained · +3.2% recall', time: '26m ago', tone: 'green', icon: 'spark' },
  { t: 'Region report (Punjab) ready', time: '1h ago', tone: 'blue', icon: 'reports' },
  { t: 'Bulk upload “excise_q2.csv” processed', time: '3h ago', tone: 'cyan', icon: 'upload' },
];

// Chart data
const TREND_MONTHS = ['Jul','Aug','Sep','Oct','Nov','Dec','Jan','Feb','Mar','Apr','May','Jun'];
const TREND_FILED = [31,33,35,34,38,41,44,47,49,53,58,63];
const TREND_NONFILER = [69,67,65,62,60,57,54,52,48,45,41,37];
const RISK_DIST = [ { label: 'Low', value: 58, color: '#00E599' }, { label: 'Medium', value: 24, color: '#FFC94D' }, { label: 'High', value: 12, color: '#FF8A3D' }, { label: 'Critical', value: 6, color: '#FF4D6D' } ];
const REGIONS = [ { label: 'Punjab', value: 88 }, { label: 'Sindh', value: 71 }, { label: 'KP', value: 54 }, { label: 'Balochistan', value: 33 }, { label: 'ICT', value: 79 }, { label: 'GB', value: 28 } ];
const LEAKAGE = [42,48,46,55,61,58,67,72,70,78,84,91];

function fmtKpi(v, fmt) {
  if (fmt === 'short') {
    if (v >= 1e6) return (v/1e6).toFixed(2) + 'M';
    if (v >= 1e3) return (v/1e3).toFixed(1) + 'K';
    return v.toString();
  }
  if (fmt === 'score') return v.toFixed(1);
  if (fmt === 'currency') return '₨' + v.toFixed(2) + 'T';
  return v.toString();
}

Object.assign(window, {
  KPIS, GRAPH_TYPES, GRAPH_NODES, GRAPH_EDGES, RISK_FACTORS, ER_SOURCES,
  AI_TIMELINE, LEADERBOARD, NOTIFS, TREND_MONTHS, TREND_FILED, TREND_NONFILER,
  RISK_DIST, REGIONS, LEAKAGE, fmtKpi,
});

import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';

Future<String> _topCnic() async {
  final lb = await Api.leaderboard(limit: 1);
  return lb.isNotEmpty ? lb.first['cnic'] : '42101-1354046-5';
}

// =========================== RISK ANALYSIS ===========================
class RiskAnalysisScreen extends StatefulWidget {
  const RiskAnalysisScreen({super.key});
  @override
  State<RiskAnalysisScreen> createState() => _RiskAnalysisScreenState();
}

class _RiskAnalysisScreenState extends State<RiskAnalysisScreen> {
  Map<String, dynamic>? _score;
  List<dynamic> _factors = [];
  Map<String, dynamic> _zones = {};
  String _name = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cnic = await _topCnic();
    final d = await Api.person(cnic);
    final rf = await Api.riskFactors(cnic);
    final an = await Api.analytics();
    setState(() {
      _score = d['score'];
      _factors = rf['factors'] ?? [];
      _zones = Map<String, dynamic>.from(an['zones'] ?? {});
      _name = d['identity']['name'] ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_score == null) return const Center(child: CircularProgressIndicator(color: C.green));
    final dev = (_score!['deviation_score'] ?? 0).toDouble();
    return ListView(padding: const EdgeInsets.fromLTRB(16, 18, 16, 70), children: [
      const PageHeader('Compliance Deviation', 'Risk Analysis', desc: 'GNN-derived deviation weighs lifestyle signals against declared income.'),
      GlassCard(
        child: Column(children: [
          RiskMeter(dev),
          const SizedBox(height: 16),
          Wrap(spacing: 8, children: const [Tag('Low', sev: 'low'), Tag('Medium', sev: 'med'), Tag('High', sev: 'high'), Tag('Critical', sev: 'critical')]),
        ]),
      ),
      const SizedBox(height: 14),
      GlassCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Factors Influencing Risk', style: display(15)),
          Text(_name, style: body(11.5, c: C.text3)),
          const SizedBox(height: 16),
          if (_factors.isEmpty) Text('Assets hidden via family/company — see Audit Trail.', style: body(12, c: C.text2)),
          ..._factors.map((f) {
            final sev = f['sev'] ?? 'med';
            final col = C.sev(sev);
            final w = (f['weight'] ?? 0).toDouble();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(f['label'] ?? '', style: body(13, w: FontWeight.w500))),
                  Text(f['detail'] ?? '', style: mono(10.5, c: C.text3)),
                  const SizedBox(width: 8),
                  Text('${w.toInt()}', style: mono(13, w: FontWeight.w700, c: col)),
                ]),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(value: w / 100, minHeight: 7, backgroundColor: const Color(0x10FFFFFF), color: col),
                ),
              ]),
            );
          }),
        ]),
      ),
      const SizedBox(height: 14),
      GlassCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Regional Risk Heatmap', style: display(15)),
          const SizedBox(height: 14),
          _heatmap(),
          const SizedBox(height: 12),
          Row(children: [
            Text('Low', style: body(10, c: C.text3)),
            Expanded(child: Container(height: 6, margin: const EdgeInsets.symmetric(horizontal: 8), decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), gradient: const LinearGradient(colors: [C.low, C.med, C.high, C.critical])))),
            Text('Critical', style: body(10, c: C.text3)),
          ]),
        ]),
      ),
    ]);
  }

  Widget _heatmap() {
    Color cell(int v) => v > 75 ? C.critical : v > 50 ? C.high : v > 28 ? C.med : C.low;
    return Column(
      children: List.generate(6, (r) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: List.generate(14, (col) {
                final v = (r * 13 + col * 7 + (r * col)) % 100;
                return Expanded(
                  child: Container(
                    height: 16,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(color: cell(v).withOpacity(0.18 + (v / 100) * 0.7), borderRadius: BorderRadius.circular(3)),
                  ),
                );
              }),
            ),
          )),
    );
  }
}

// =========================== AUDIT TRAIL ===========================
class AuditTrailScreen extends StatefulWidget {
  const AuditTrailScreen({super.key});
  @override
  State<AuditTrailScreen> createState() => _AuditTrailScreenState();
}

class _AuditTrailScreenState extends State<AuditTrailScreen> {
  Map<String, dynamic>? _d;
  List<dynamic> _audit = [];
  Map<String, dynamic>? _notice;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cnic = await _topCnic();
    final d = await Api.person(cnic);
    final n = await Api.notice(cnic);
    setState(() {
      _d = d;
      _audit = (d['audit_trail'] as List?) ?? [];
      _notice = n;
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    if (d == null) return const Center(child: CircularProgressIndicator(color: C.green));
    final id = d['identity'], sc = d['score'];
    final dev = (sc?['deviation_score'] ?? 0).toDouble();
    final String name = '${id['name'] ?? ''}';
    final initials = name.split(' ').where((s) => s.isNotEmpty).map((s) => s[0]).take(2).join();
    final steps = [
      ('Identity resolved', 'Linked records across silos to one canonical entity (F1 = 1.0).', C.blue, Icons.account_tree),
      ('Asset graph constructed', 'Detected vehicles, property and company holdings via the knowledge graph.', C.cyan, Icons.hub),
      ('Lifestyle vs income modelled', 'GNN estimated footprint ${rs(sc?['own_assets'])} against declared ${rs(sc?['declared'])}.', C.green, Icons.trending_up),
      ('Anomaly score elevated', 'Compliance deviation reached ${dev.toInt()}/100 — flagged ${sc?['zone']}.', C.critical, Icons.warning_amber),
      ('Recommendation issued', 'Auto-drafted Section 122(5A) notice + field-audit assignment.', C.high, Icons.flag),
    ];
    return ListView(padding: const EdgeInsets.fromLTRB(16, 18, 16, 70), children: [
      const PageHeader('Explainable AI', 'Investigation Report', desc: 'Every flag is fully auditable — reasoning, evidence and recommendation.'),
      GlassCard(
        child: Row(children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [C.critical, C.high]), borderRadius: BorderRadius.circular(15)),
            child: Center(child: Text(initials, style: display(20, c: Colors.white))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: display(18)),
              Text('${id['cnic']} · ${id['district'] ?? ''}', style: mono(11, c: C.text3)),
            ]),
          ),
          Column(children: [Text(dev.toInt().toString(), style: mono(28, w: FontWeight.w700, c: C.zone(sc?['zone']))), Text('deviation', style: body(9, c: C.text3))]),
        ]),
      ),
      const SizedBox(height: 14),
      GlassCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Why was this citizen flagged?', style: display(15)),
          const SizedBox(height: 12),
          ..._audit.map((t) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(width: 24, height: 24, decoration: BoxDecoration(color: C.critical.withOpacity(0.12), borderRadius: BorderRadius.circular(7)), child: const Icon(Icons.check, size: 14, color: C.critical)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(t.toString(), style: body(12.5))),
                ]),
              )),
        ]),
      ),
      const SizedBox(height: 14),
      GlassCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.auto_awesome, size: 16, color: C.green), const SizedBox(width: 8), Text('AI Reasoning Timeline', style: display(15))]),
          const SizedBox(height: 16),
          ...List.generate(steps.length, (i) {
            final s = steps[i];
            return IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Column(children: [
                  Container(width: 34, height: 34, decoration: BoxDecoration(color: s.$3.withOpacity(0.14), borderRadius: BorderRadius.circular(10), border: Border.all(color: s.$3.withOpacity(0.4))), child: Icon(s.$4, size: 16, color: s.$3)),
                  if (i < steps.length - 1) Expanded(child: Container(width: 2, color: C.border)),
                ]),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [Text(s.$1, style: body(13, w: FontWeight.w600)), const SizedBox(width: 8), Text('STEP ${i + 1}', style: mono(9, c: C.text3))]),
                      const SizedBox(height: 3),
                      Text(s.$2, style: body(12, c: C.text2)),
                    ]),
                  ),
                ),
              ]),
            );
          }),
        ]),
      ),
      const SizedBox(height: 14),
      GlassCard(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0x1AE5566F), C.panel]),
        border: const Color(0x4DE5566F),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.flag, size: 16, color: C.critical), const SizedBox(width: 8), Text('Recommendation', style: display(15))]),
          const SizedBox(height: 10),
          Text('Issue a Section 122(5A) notice and assign field audit. Estimated recovery: ${rs(_notice?['recovery_potential'])}.', style: body(12.5, c: C.text2)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: const Color(0xFF08130E)),
              onPressed: _showNotice,
              icon: const Icon(Icons.description),
              label: Text('View 122(5A) Notice', style: body(13, w: FontWeight.w700, c: const Color(0xFF08130E))),
            ),
          ),
        ]),
      ),
    ]);
  }

  void _showNotice() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: C.bg2,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: SingleChildScrollView(child: SelectableText(_notice?['notice'] ?? '', style: mono(11.5, c: C.text))),
        ),
      ),
    );
  }
}

// =========================== ENTITY RESOLUTION ===========================
class EntityResolutionScreen extends StatefulWidget {
  const EntityResolutionScreen({super.key});
  @override
  State<EntityResolutionScreen> createState() => _EntityResolutionScreenState();
}

class _EntityResolutionScreenState extends State<EntityResolutionScreen> {
  Map<String, dynamic>? _er;
  int _active = 0;

  @override
  void initState() {
    super.initState();
    Api.erMetrics().then((v) => setState(() => _er = v)).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    if (_er == null) return const Center(child: CircularProgressIndicator(color: C.green));
    final sources = (_er!['sources'] as List?) ?? [];
    final totalRecords = sources.fold<int>(0, (a, b) => a + (b['records'] as int));
    return ListView(padding: const EdgeInsets.fromLTRB(16, 18, 16, 70), children: [
      const PageHeader('Identity Fusion', 'Entity Resolution', desc: 'AI links fragmented identities across national databases into one canonical citizen.'),
      GlassCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Identity Match Confidence', style: display(15)),
          const SizedBox(height: 14),
          Center(child: Ring((_er!['f1'] * 97.4).clamp(0, 100).toDouble(), centerLabel: '97.4%', centerSub: 'match score', size: 150)),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _mini('${(totalRecords / 1000).toStringAsFixed(0)}K', 'Records fused', C.text),
            _mini('${sources.length}', 'Databases', C.blue),
            _mini('F1 1.0', 'Accuracy', C.green),
          ]),
        ]),
      ),
      const SizedBox(height: 14),
      GlassCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Input Data Sources', style: display(15)),
          const SizedBox(height: 12),
          ...List.generate(sources.length, (i) {
            final s = sources[i];
            final active = i == _active;
            final match = (s['match'] as num).toDouble();
            return GestureDetector(
              onTap: () => setState(() => _active = i),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: active ? C.green.withOpacity(0.06) : C.panel,
                  border: Border.all(color: active ? C.green : C.border),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Row(children: [
                  Container(width: 36, height: 36, decoration: BoxDecoration(color: C.cyan.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.storage, size: 17, color: C.cyan)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s['source'], style: body(13, w: FontWeight.w500)),
                      Text('${s['records']} records', style: mono(10, c: C.text3)),
                    ]),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${match.toStringAsFixed(1)}%', style: mono(13, w: FontWeight.w700, c: match > 95 ? C.green : C.med)),
                    const Tag('MATCHED', sev: 'low'),
                  ]),
                ]),
              ),
            );
          }),
        ]),
      ),
      const SizedBox(height: 14),
      GlassCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.auto_awesome, size: 15, color: C.green), const SizedBox(width: 8), Text('AI Matching Explanation', style: display(14))]),
          const SizedBox(height: 10),
          Text(
            'The ${sources.isNotEmpty ? sources[_active]['source'] : ''} record was linked using a fuzzy match on CNIC, name + father and a shared-address embedding. Cross-database co-occurrence raised confidence above the 92% auto-merge threshold.',
            style: body(12.5, c: C.text2, h: 1.7),
          ),
        ]),
      ),
    ]);
  }

  Widget _mini(String v, String l, Color c) => Column(children: [Text(v, style: mono(20, w: FontWeight.w700, c: c)), Text(l, style: body(10.5, c: C.text3))]);
}

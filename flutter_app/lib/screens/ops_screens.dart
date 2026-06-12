import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../api.dart';
import '../theme.dart';
import 'person_detail.dart';

// =========================== ANALYTICS ===========================
class AnalyticsScreen2 extends StatefulWidget {
  const AnalyticsScreen2({super.key});
  @override
  State<AnalyticsScreen2> createState() => _AnalyticsScreen2State();
}

class _AnalyticsScreen2State extends State<AnalyticsScreen2> {
  Map<String, dynamic>? _a;
  @override
  void initState() {
    super.initState();
    Api.analytics().then((v) => setState(() => _a = v)).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final a = _a;
    if (a == null) return const Center(child: CircularProgressIndicator(color: C.green));
    final z = Map<String, dynamic>.from(a['zones'] ?? {});
    final districts = (a['districts'] as List?) ?? [];
    final filed = ((a['trend_filed'] as List?) ?? []).map((e) => (e as num).toDouble()).toList();
    return ListView(padding: const EdgeInsets.fromLTRB(16, 18, 16, 70), children: [
      const PageHeader('Reporting', 'Analytics & Reporting', desc: 'Compliance trends, regional posture and revenue leakage across the tax net.'),
      GlassCard(
        gradient: const LinearGradient(colors: [Color(0x1225C98C), C.panel]),
        child: Row(children: [
          Container(width: 46, height: 46, decoration: BoxDecoration(color: C.green.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.savings, color: C.green)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(rs(a['total_recovery_potential']), style: display(20, c: C.green)),
            Text('National Revenue Recovery Potential', style: body(11.5, c: C.text2)),
          ])),
        ]),
      ),
      const SizedBox(height: 14),
      GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Revenue Leakage Estimation', style: display(15)),
        const SizedBox(height: 14),
        SizedBox(height: 160, child: _line(filed.map((e) => e * 1.4).toList(), C.blue)),
      ])),
      const SizedBox(height: 14),
      GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Regional Compliance Index', style: display(15)),
        const SizedBox(height: 16),
        ...districts.take(6).map((d) {
          final maxV = (districts.first['recovery'] as num).toDouble();
          final v = (d['recovery'] as num).toDouble();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(d['district'] ?? '', style: body(12.5, w: FontWeight.w600)),
                Text(rs(v), style: mono(11, c: C.green)),
              ]),
              const SizedBox(height: 4),
              ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: maxV > 0 ? v / maxV : 0, minHeight: 8, backgroundColor: const Color(0x10FFFFFF), color: C.green)),
            ]),
          );
        }),
      ])),
      const SizedBox(height: 14),
      GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Fraud Detection Mix', style: display(15)),
        const SizedBox(height: 14),
        Center(
          child: SizedBox(
            width: 150, height: 150,
            child: PieChart(PieChartData(centerSpaceRadius: 42, sectionsSpace: 2, sections: [
              for (final e in ['Red', 'Yellow', 'Green'])
                PieChartSectionData(value: (z[e] ?? 0).toDouble(), color: C.zone(e), radius: 20, showTitle: false),
            ])),
          ),
        ),
      ])),
    ]);
  }

  Widget _line(List<double> v, Color c) => LineChart(LineChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: C.border, strokeWidth: 1)),
        titlesData: const FlTitlesData(leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false))),
        borderData: FlBorderData(show: false),
        lineBarsData: [LineChartBarData(spots: [for (int i = 0; i < v.length; i++) FlSpot(i.toDouble(), v[i])], isCurved: true, color: c, barWidth: 3, dotData: const FlDotData(show: false), belowBarData: BarAreaData(show: true, color: c.withOpacity(0.1)))],
      ));
}

// =========================== REPORTS (upload + leaderboard) ===========================
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List<dynamic> _lb = [];
  int? _prog;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    Api.leaderboard(limit: 12).then((v) => setState(() => _lb = v)).catchError((_) {});
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void _upload() {
    setState(() => _prog = 0);
    _t?.cancel();
    _t = Timer.periodic(const Duration(milliseconds: 220), (t) {
      setState(() {
        _prog = math.min(100, (_prog ?? 0) + (math.Random().nextInt(14) + 5));
        if (_prog! >= 100) t.cancel();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.fromLTRB(16, 18, 16, 70), children: [
      const PageHeader('Ingestion & Outputs', 'Reports & Data Upload', desc: 'Bring new datasets into the graph and export investigation reports.'),
      GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Data Upload', style: display(15)),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: _upload,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(border: Border.all(color: C.border2, width: 1.5, style: BorderStyle.solid), borderRadius: BorderRadius.circular(16), color: C.panel),
            child: Column(children: [
              Container(width: 50, height: 50, decoration: BoxDecoration(color: C.green.withOpacity(0.1), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.cloud_upload, color: C.green, size: 24)),
              const SizedBox(height: 12),
              Text('Tap to ingest dataset', style: body(14, w: FontWeight.w600)),
              Text('CSV · Excel · JSON', style: body(11.5, c: C.text3)),
            ]),
          ),
        ),
        if (_prog != null) ...[
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('excise_punjab_q2.csv', style: mono(11, c: C.text2)),
            Text(_prog == 100 ? 'Ingested ✓' : '$_prog%', style: mono(11, c: _prog == 100 ? C.green : C.text3)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: _prog! / 100, minHeight: 8, backgroundColor: const Color(0x12FFFFFF), color: C.green)),
          if (_prog == 100) Padding(padding: const EdgeInsets.only(top: 10), child: Text('1.2M rows parsed · 48,210 new entities resolved · 312 duplicates merged.', style: body(11.5, c: C.text2))),
        ],
        const SizedBox(height: 14),
        Row(children: const [Tag('CSV', sev: 'info'), SizedBox(width: 8), Tag('XLSX', sev: 'info'), SizedBox(width: 8), Tag('JSON', sev: 'info')]),
      ])),
      const SizedBox(height: 14),
      GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.emoji_events, size: 17, color: C.med), const SizedBox(width: 8), Text('Top Suspicious Entities', style: display(15))]),
        const SizedBox(height: 12),
        ...List.generate(_lb.length, (i) {
          final e = _lb[i];
          return GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PersonDetail(cnic: e['cnic'], admin: true))),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 3),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: i == 0 ? C.critical.withOpacity(0.06) : C.panel,
                border: Border.all(color: i == 0 ? C.critical.withOpacity(0.25) : C.border),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(children: [
                SizedBox(width: 22, child: Text('${i + 1}', textAlign: TextAlign.center, style: mono(13, w: FontWeight.w700, c: i < 3 ? C.med : C.text3))),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e['name'] ?? '', style: body(13, w: FontWeight.w500)),
                  Text(e['district'] ?? '', style: mono(10, c: C.text3)),
                ])),
                Text(rs(e['recovery']), style: mono(11.5, w: FontWeight.w600, c: C.green)),
                const SizedBox(width: 8),
                Tag('${(e['deviation_score'] ?? 0).toStringAsFixed(0)}', sev: e['zone'] == 'Red' ? 'critical' : 'med'),
              ]),
            ),
          );
        }),
      ])),
    ]);
  }
}

// =========================== SETTINGS ===========================
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _lang = 'EN';
  bool _notif = true, _logging = true;

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.fromLTRB(16, 18, 16, 70), children: [
      const PageHeader('Configuration', 'Settings', desc: 'Access control, localisation and security monitoring.'),
      GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Preferences', style: display(15)),
        _row('Interface theme', 'Dark command mode', _segment(['DARK', 'LIGHT'], 'DARK', (_) {})),
        _row('Language', 'Urdu & English supported', _segment(['EN', 'اردو'], _lang == 'EN' ? 'EN' : 'اردو', (v) => setState(() => _lang = v == 'EN' ? 'EN' : 'UR'))),
        _row('Role-based access', 'Senior Investigator · Tier 3', const Tag('SECURED', sev: 'low', icon: Icons.shield)),
        _row('Real-time notifications', 'Critical-entity alerts pushed instantly', _toggle(_notif, (v) => setState(() => _notif = v))),
        _row('Activity & audit logging', 'All actions recorded immutably', _toggle(_logging, (v) => setState(() => _logging = v))),
      ])),
    ]);
  }

  Widget _row(String t, String d, Widget trailing) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t, style: body(13.5, w: FontWeight.w500)),
            Text(d, style: body(11.5, c: C.text3)),
          ])),
          trailing,
        ]),
      );

  Widget _segment(List<String> opts, String sel, void Function(String) on) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: C.panel, border: Border.all(color: C.border), borderRadius: BorderRadius.circular(9)),
        child: Row(mainAxisSize: MainAxisSize.min, children: opts.map((o) {
          final a = o == sel;
          return GestureDetector(
            onTap: () => on(o),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(color: a ? C.panel2 : Colors.transparent, borderRadius: BorderRadius.circular(6)),
              child: Text(o, style: mono(11, w: FontWeight.w600, c: a ? C.text : C.text3)),
            ),
          );
        }).toList()),
      );

  Widget _toggle(bool on, void Function(bool) ch) => GestureDetector(
        onTap: () => ch(!on),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 44, height: 26,
          decoration: BoxDecoration(color: on ? C.green : const Color(0x1FFFFFFF), borderRadius: BorderRadius.circular(20)),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 180),
            alignment: on ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(margin: const EdgeInsets.all(3), width: 20, height: 20, decoration: BoxDecoration(color: on ? const Color(0xFF04070D) : Colors.white, shape: BoxShape.circle)),
          ),
        ),
      );
}

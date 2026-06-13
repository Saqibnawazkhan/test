import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../api.dart';
import '../theme.dart';
import 'person_detail.dart';

/// Dashboard — KPI strip, search, trend, risk donut, network snapshot, top-flagged table.
class DashboardScreen extends StatefulWidget {
  final void Function(int moduleIndex)? go;
  final VoidCallback? onSearch;
  const DashboardScreen({this.go, this.onSearch, super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _an;
  List<dynamic> _flagged = [];
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await Api.stats();
      final a = await Api.analytics();
      List<dynamic> lb = [];
      try {
        lb = await Api.leaderboard(limit: 6);
      } catch (_) {}
      setState(() {
        _stats = s;
        _an = a;
        _flagged = lb;
        _err = null;
      });
    } catch (e) {
      setState(() => _err = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_err != null) return _errView();
    if (_stats == null) return const Center(child: CircularProgressIndicator(color: C.green));
    final s = _stats!;
    final z = Map<String, dynamic>.from(s['zones'] ?? {});
    final total = (s['total_persons'] ?? 0) as int;
    final highCrit = ((z['Red'] ?? 0) + (z['Yellow'] ?? 0)) as int;
    final kpis = [
      _Kpi('Citizens Analysed', _short(total), Icons.groups_2, C.blue, 2.4, [30, 34, 32, 40, 44, 52, 60, 66, 72, 80]),
      _Kpi('Active Filers', _short(s['filers']), Icons.verified_user, C.green, 5.8, [20, 26, 30, 38, 42, 46, 52, 58, 64, 70]),
      _Kpi('Non-Filers', _short(s['non_filers']), Icons.person_off, C.high, 12.1, [60, 55, 52, 46, 40, 38, 33, 30, 26, 22]),
      _Kpi('High Risk', _short(z['Red'] ?? 0), Icons.warning_amber, C.critical, 8.3, [12, 16, 20, 24, 30, 34, 40, 48, 54, 60]),
      _Kpi('Recovery Est.', rs(_an?['total_recovery_potential']), Icons.savings, C.green, 6.7, [22, 30, 36, 44, 50, 58, 66, 74, 80, 88]),
      _Kpi('Flagged Share', '${(100 * highCrit / (total == 0 ? 1 : total)).toStringAsFixed(1)}%', Icons.shield, C.violet, 1.9, [40, 42, 44, 46, 48, 50, 52, 54, 56, 58]),
    ];
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), children: [
      // compact header
      const Eyebrow('Operations Command'),
      const SizedBox(height: 6),
      Text('Dashboard', style: display(20)),
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.3,
        children: kpis.map(_kpiCard).toList(),
      ),
      const SizedBox(height: 14),
      _trendCard(),
      const SizedBox(height: 12),
      _donutCard(z, highCrit),
      const SizedBox(height: 12),
      _networkCard(),
      const SizedBox(height: 12),
      _topFlaggedTable(),
    ]);
  }

  // ---- colourful KPI card ----
  Widget _kpiCard(_Kpi k) {
    final up = k.delta >= 0;
    return GlassCard(
      padding: const EdgeInsets.all(13),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(color: k.color.withOpacity(0.13), borderRadius: BorderRadius.circular(9)), child: Icon(k.icon, size: 17, color: k.color)),
          const Spacer(),
          Tag('${up ? '▲' : '▼'} ${k.delta.abs()}%', sev: up ? 'low' : 'critical'),
        ]),
        const Spacer(),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(k.value, style: mono(21, w: FontWeight.w700, c: C.text))),
        const SizedBox(height: 2),
        Text(k.label, style: body(11, c: C.text2)),
        const SizedBox(height: 6),
        Sparkline(k.spark, color: k.color, height: 22),
      ]),
    );
  }

  Widget _trendCard() {
    final filed = ((_an?['trend_filed'] as List?) ?? []).map((e) => (e as num).toDouble()).toList();
    final nonf = ((_an?['trend_nonfiler'] as List?) ?? []).map((e) => (e as num).toDouble()).toList();
    LineChartBarData ln(List<double> v, Color c) => LineChartBarData(
          spots: [for (int i = 0; i < v.length; i++) FlSpot(i.toDouble(), v[i])],
          isCurved: true, color: c, barWidth: 2.5, dotData: const FlDotData(show: false), belowBarData: BarAreaData(show: true, color: c.withOpacity(0.06)),
        );
    return GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Filer vs Non-Filer Trend', style: display(14)),
        Row(children: [_legend(C.green, 'Filers'), const SizedBox(width: 10), _legend(C.text3, 'Non')]),
      ]),
      const SizedBox(height: 14),
      SizedBox(height: 150, child: LineChart(LineChartData(
        minY: 0, maxY: 100,
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: C.border, strokeWidth: 1)),
        titlesData: const FlTitlesData(leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24, interval: 25)), rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false))),
        borderData: FlBorderData(show: false),
        lineBarsData: [ln(filed, C.green), ln(nonf, C.high)],
      ))),
    ]));
  }

  Widget _donutCard(Map<String, dynamic> z, int highCrit) {
    final data = [('Red', (z['Red'] ?? 0).toDouble()), ('Yellow', (z['Yellow'] ?? 0).toDouble()), ('Green', (z['Green'] ?? 0).toDouble())];
    final tot = data.fold<double>(0, (a, b) => a + b.$2);
    return GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Risk Distribution', style: display(14)),
      const SizedBox(height: 12),
      Row(children: [
        SizedBox(width: 130, height: 130, child: Stack(alignment: Alignment.center, children: [
          PieChart(PieChartData(centerSpaceRadius: 40, sectionsSpace: 2, sections: data.map((d) => PieChartSectionData(value: d.$2, color: C.zone(d.$1), radius: 16, showTitle: false)).toList())),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_short(highCrit), style: mono(18, w: FontWeight.w700)),
            Text('HIGH+CRITICAL', style: mono(7.5, c: C.text3, ls: 0.6)),
          ]),
        ])),
        const SizedBox(width: 18),
        Expanded(child: Column(children: data.map((d) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            Container(width: 9, height: 9, decoration: BoxDecoration(color: C.zone(d.$1), borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Text(d.$1, style: body(12.5, w: FontWeight.w600)),
            const Spacer(),
            Text('${(tot > 0 ? 100 * d.$2 / tot : 0).toStringAsFixed(0)}%', style: mono(12, c: C.text2)),
          ]),
        )).toList())),
      ]),
    ]));
  }

  Widget _networkCard() => GestureDetector(
        onTap: () => widget.go?.call(1),
        child: GlassCard(
          padding: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 200,
              child: Stack(children: [
                Positioned.fill(child: CustomPaint(painter: _NetworkPainter())),
                Positioned(left: 16, top: 14, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Network Snapshot', style: display(14)),
                  Text('Top flagged cluster', style: body(11, c: C.text3)),
                ])),
                Positioned(right: 14, top: 12, child: Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7), decoration: BoxDecoration(color: C.panel2, border: Border.all(color: C.border), borderRadius: BorderRadius.circular(8)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.open_in_full, size: 13, color: C.text2), const SizedBox(width: 6), Text('Open', style: body(11, c: C.text2))]))),
              ]),
            ),
          ),
        ),
      );

  Widget _topFlaggedTable() => GlassCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Top Flagged Entities', style: display(14)),
            const Spacer(),
            GestureDetector(onTap: () => widget.go?.call(6), child: Row(children: [Text('View all', style: body(11.5, c: C.green)), const Icon(Icons.chevron_right, size: 16, color: C.green)])),
          ]),
          const SizedBox(height: 8),
          ..._flagged.asMap().entries.map((e) {
            final i = e.key;
            final p = e.value;
            return InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PersonDetail(cnic: p['cnic'], admin: true))),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(children: [
                  SizedBox(width: 20, child: Text('${i + 1}', style: mono(12, w: FontWeight.w700, c: C.text3))),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p['name'] ?? '', style: body(13, w: FontWeight.w500)),
                    Text(p['district'] ?? '', style: mono(10, c: C.text3)),
                  ])),
                  Text(rs(p['recovery']), style: mono(11.5, w: FontWeight.w600, c: C.text2)),
                  const SizedBox(width: 10),
                  Container(
                    width: 34, alignment: Alignment.center, padding: const EdgeInsets.symmetric(vertical: 3),
                    decoration: BoxDecoration(color: C.zone(p['zone']).withOpacity(0.14), borderRadius: BorderRadius.circular(6)),
                    child: Text('${(p['deviation_score'] ?? 0).toStringAsFixed(0)}', style: mono(11, w: FontWeight.w700, c: C.zone(p['zone']))),
                  ),
                ]),
              ),
            );
          }),
        ]),
      );

  Widget _legend(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))), const SizedBox(width: 5), Text(t, style: body(11, c: C.text2))]);

  String _short(num? v) {
    final n = (v ?? 0).toDouble();
    if (n >= 1e6) return '${(n / 1e6).toStringAsFixed(2)}M';
    if (n >= 1e3) return '${(n / 1e3).toStringAsFixed(1)}K';
    return n.toStringAsFixed(0);
  }

  Widget _errView() => Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.wifi_off, size: 44, color: C.high),
        const SizedBox(height: 12),
        Text('Can’t reach the backend', style: display(15)),
        const SizedBox(height: 6),
        Text('Run the server + connect_phone.bat', style: body(12, c: C.text2), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton.icon(onPressed: () { setState(() => _err = null); _load(); }, icon: const Icon(Icons.refresh), label: const Text('Retry')),
      ])));
}

class _Kpi {
  final String label, value;
  final IconData icon;
  final Color color;
  final double delta;
  final List<double> spark;
  _Kpi(this.label, this.value, this.icon, this.color, this.delta, List<int> s) : spark = s.map((e) => e.toDouble()).toList();
}

/// small living network for the dashboard snapshot
class _NetworkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(11);
    final n = 14;
    final pts = <Offset>[Offset(size.width * 0.5, size.height * 0.55)]; // centre = flagged
    for (int i = 1; i < n; i++) {
      pts.add(Offset(rnd.nextDouble() * size.width * 0.86 + size.width * 0.07, rnd.nextDouble() * size.height * 0.7 + size.height * 0.22));
    }
    // edges to centre + a few cross links
    final ep = Paint()..color = C.border2..strokeWidth = 1;
    for (int i = 1; i < n; i++) canvas.drawLine(pts[0], pts[i], ep);
    for (int i = 1; i < n - 1; i += 3) canvas.drawLine(pts[i], pts[i + 1], ep..color = const Color(0x0D101926));
    // nodes
    for (int i = 0; i < n; i++) {
      final isCentre = i == 0;
      final col = isCentre ? C.critical : (i % 4 == 0 ? C.cyan : i % 3 == 0 ? C.green : C.text3);
      final r = isCentre ? 9.0 : 4.5;
      canvas.drawCircle(pts[i], r + 4, Paint()..color = col.withOpacity(0.18));
      canvas.drawCircle(pts[i], r, Paint()..color = col);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

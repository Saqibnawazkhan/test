import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../api.dart';
import '../common.dart';

/// Reports & Analytics — zone donut, filed-vs-nonfiler trend, regional recovery bars.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Map<String, dynamic>? _a;

  @override
  void initState() {
    super.initState();
    Api.analytics().then((v) => setState(() => _a = v)).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final a = _a;
    return Scaffold(
      appBar: AppBar(title: const Text('Reports & Analytics'), backgroundColor: kSeed, foregroundColor: Colors.white),
      body: a == null
          ? loading()
          : ListView(padding: const EdgeInsets.all(16), children: [
              _recoveryCard(a),
              const SectionTitle('Compliance Zones', Icons.pie_chart),
              _zoneDonut(Map<String, dynamic>.from(a['zones'] ?? {})),
              const SectionTitle('Filed vs Non-Filer Trend', Icons.show_chart),
              _trendChart(a),
              const SectionTitle('Recovery Potential by Region', Icons.bar_chart),
              _regionBars((a['districts'] as List?) ?? []),
            ]),
    );
  }

  Widget _recoveryCard(Map<String, dynamic> a) {
    return Card(
      color: kSeed.withOpacity(0.07),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(color: kSeed.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.savings, color: kSeed),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(money(a['total_recovery_potential']),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kSeed)),
              const Text('National Revenue Recovery Potential', style: TextStyle(fontSize: 12)),
            ]),
          ),
          Column(children: [
            Text('${a['non_filers']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const Text('non-filers', style: TextStyle(fontSize: 10, color: Colors.grey)),
          ]),
        ]),
      ),
    );
  }

  Widget _zoneDonut(Map<String, dynamic> z) {
    final data = [
      ('Red', (z['Red'] ?? 0).toDouble()),
      ('Yellow', (z['Yellow'] ?? 0).toDouble()),
      ('Green', (z['Green'] ?? 0).toDouble()),
    ];
    final total = data.fold<double>(0, (s, d) => s + d.$2);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          SizedBox(
            width: 130, height: 130,
            child: PieChart(PieChartData(
              centerSpaceRadius: 34,
              sections: data
                  .map((d) => PieChartSectionData(
                      value: d.$2, color: zoneColor(d.$1),
                      title: total > 0 ? '${(100 * d.$2 / total).toStringAsFixed(0)}%' : '',
                      radius: 28, titleStyle: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)))
                  .toList(),
            )),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: data
                  .map((d) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(children: [
                          Icon(Icons.circle, size: 11, color: zoneColor(d.$1)),
                          const SizedBox(width: 8),
                          Text('${d.$1}  ', style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text('${d.$2.toInt()}', style: TextStyle(color: Colors.grey[600])),
                        ]),
                      ))
                  .toList(),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _trendChart(Map<String, dynamic> a) {
    final filed = ((a['trend_filed'] as List?) ?? []).map((e) => (e as num).toDouble()).toList();
    final nonf = ((a['trend_nonfiler'] as List?) ?? []).map((e) => (e as num).toDouble()).toList();
    final months = ((a['trend_months'] as List?) ?? []).map((e) => e.toString()).toList();
    line(List<double> v, Color c) => LineChartBarData(
          spots: [for (int i = 0; i < v.length; i++) FlSpot(i.toDouble(), v[i])],
          isCurved: true, color: c, barWidth: 3, dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: true, color: c.withOpacity(0.10)),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 18, 16, 12),
        child: SizedBox(
          height: 180,
          child: LineChart(LineChartData(
            minY: 0, maxY: 100,
            gridData: const FlGridData(show: true, drawVerticalLine: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, interval: 25)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 3,
                  getTitlesWidget: (v, _) => Text(v.toInt() < months.length ? months[v.toInt()] : '',
                      style: const TextStyle(fontSize: 9)))),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [line(filed, kSeed), line(nonf, const Color(0xFFFF8A3D))],
          )),
        ),
      ),
    );
  }

  Widget _regionBars(List districts) {
    final top = districts.take(6).toList();
    final maxV = top.isEmpty ? 1.0 : (top.first['recovery'] as num).toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: top.map((d) {
            final v = (d['recovery'] as num).toDouble();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(d['district'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(money(v), style: const TextStyle(fontSize: 12, color: kSeed)),
                ]),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: maxV > 0 ? v / maxV : 0, minHeight: 8,
                    backgroundColor: Colors.grey.withOpacity(0.15), color: kSeed,
                  ),
                ),
              ]),
            );
          }).toList(),
        ),
      ),
    );
  }
}

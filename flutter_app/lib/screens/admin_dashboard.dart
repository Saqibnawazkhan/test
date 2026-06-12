import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../api.dart';
import '../common.dart';
import 'person_detail.dart';
import 'requests_screen.dart';
import 'analytics_screen.dart';
import 'leaderboard_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  Map<String, dynamic>? _stats;
  List<dynamic> _people = [];
  String? _zone;
  String _q = '';
  bool _loadingList = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await Api.stats();
      setState(() {
        _stats = s;
        _error = null;
      });
      _loadList();
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  Future<void> _loadList() async {
    setState(() => _loadingList = true);
    try {
      final r = await Api.persons(zone: _zone, q: _q, limit: 50);
      setState(() {
        _people = r['results'] as List<dynamic>;
        _loadingList = false;
      });
    } catch (_) {
      setState(() => _loadingList = false);
    }
  }

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off, size: 48, color: Colors.orange),
            const SizedBox(height: 14),
            const Text('Can’t reach the backend', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('Make sure the server is running, then\ndouble-click connect_phone.bat to re-link the phone.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 13)),
            const SizedBox(height: 18),
            FilledButton.icon(
                onPressed: () {
                  setState(() => _error = null);
                  _load();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry')),
            const SizedBox(height: 16),
            SelectableText(_error ?? '', style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final z = Map<String, dynamic>.from(_stats?['zones'] ?? {});
    return Scaffold(
      appBar: AppBar(
        title: const Text('FBR Tax Net — Admin'),
        backgroundColor: kSeed,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Reports & Analytics',
            icon: const Icon(Icons.bar_chart),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const AnalyticsScreen())),
          ),
          IconButton(
            tooltip: 'Top Recovery Targets',
            icon: const Icon(Icons.leaderboard),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
          ),
          IconButton(
            tooltip: 'Correction Requests',
            icon: const Icon(Icons.inbox),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const RequestsScreen())),
          ),
        ],
      ),
      body: _error != null
          ? _errorView()
          : _stats == null
          ? loading()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                // summary cards
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [
                    StatCard('Total Citizens', '${_stats!['total_persons']}', Icons.people, kSeed),
                    StatCard('Non-Filers', '${_stats!['non_filers']}', Icons.person_off, Colors.orange),
                    StatCard('High Risk (Red)', '${z['Red'] ?? 0}', Icons.warning, zoneColor('Red')),
                    StatCard('Hidden Assets', money(_stats!['hidden_assets_under_review']),
                        Icons.account_balance_wallet, Colors.deepPurple),
                  ],
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Compliance Zones', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      SizedBox(height: 140, child: _pie(z)),
                    ]),
                  ),
                ),
                const SectionTitle('Audit Triage', Icons.fact_check),
                // filters
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search name or CNIC…',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onSubmitted: (v) {
                    _q = v;
                    _loadList();
                  },
                ),
                const SizedBox(height: 10),
                Row(children: [
                  for (final zn in [null, 'Red', 'Yellow', 'Green'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(zn ?? 'All'),
                        selected: _zone == zn,
                        selectedColor: zoneColor(zn).withOpacity(0.2),
                        onSelected: (_) {
                          setState(() => _zone = zn);
                          _loadList();
                        },
                      ),
                    ),
                ]),
                const SizedBox(height: 8),
                if (_loadingList)
                  loading()
                else
                  ..._people.map((p) => _personTile(p)),
              ]),
            ),
    );
  }

  Widget _pie(Map<String, dynamic> z) {
    final data = [
      ('Red', (z['Red'] ?? 0).toDouble()),
      ('Yellow', (z['Yellow'] ?? 0).toDouble()),
      ('Green', (z['Green'] ?? 0).toDouble()),
    ];
    return Row(children: [
      Expanded(
        child: PieChart(PieChartData(
          sections: data
              .map((d) => PieChartSectionData(
                  value: d.$2, color: zoneColor(d.$1), title: '', radius: 45))
              .toList(),
          centerSpaceRadius: 22,
        )),
      ),
      Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: data
            .map((d) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Icon(Icons.circle, size: 10, color: zoneColor(d.$1)),
                    const SizedBox(width: 6),
                    Text('${d.$1}: ${d.$2.toInt()}'),
                  ]),
                ))
            .toList(),
      ),
    ]);
  }

  Widget _personTile(dynamic p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(p['name'] ?? '—', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${p['cnic']} · ${p['district'] ?? ''}\nDeclared: ${money(p['declared_income'])}'),
        isThreeLine: true,
        trailing: ZoneChip(p['zone'], score: (p['deviation_score'] ?? 0).toDouble()),
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => PersonDetail(cnic: p['cnic'], admin: true))),
      ),
    );
  }
}

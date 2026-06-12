import 'package:flutter/material.dart';
import '../api.dart';
import '../common.dart';
import 'person_detail.dart';

/// Top tax-evasion targets ranked by estimated recovery potential.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});
  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<dynamic>? _rows;

  @override
  void initState() {
    super.initState();
    Api.leaderboard(limit: 30).then((v) => setState(() => _rows = v)).catchError((_) {});
  }

  Color _rankColor(int i) =>
      i == 0 ? const Color(0xFFFFC94D) : (i == 1 ? const Color(0xFFB0B6BE) : (i == 2 ? const Color(0xFFCD7F32) : Colors.grey));

  @override
  Widget build(BuildContext context) {
    final r = _rows;
    return Scaffold(
      appBar: AppBar(title: const Text('Top Recovery Targets'), backgroundColor: kSeed, foregroundColor: Colors.white),
      body: r == null
          ? loading()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: r.length,
              itemBuilder: (_, i) {
                final p = r[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _rankColor(i).withOpacity(0.18),
                      child: Text('${i + 1}', style: TextStyle(color: _rankColor(i), fontWeight: FontWeight.bold)),
                    ),
                    title: Text(p['name'] ?? '—', style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${p['district'] ?? ''} · ${p['cnic']}'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(money(p['recovery']),
                            style: const TextStyle(color: kSeed, fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 2),
                        ZoneChip(p['zone'], score: (p['deviation_score'] ?? 0).toDouble()),
                      ],
                    ),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => PersonDetail(cnic: p['cnic'], admin: true))),
                  ),
                );
              },
            ),
    );
  }
}

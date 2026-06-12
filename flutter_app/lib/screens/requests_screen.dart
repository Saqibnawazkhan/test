import 'package:flutter/material.dart';
import '../common.dart';
import '../supa.dart';

/// Admin inbox of citizen correction requests — live from Supabase, approve/reject notifies the citizen.
class RequestsScreen extends StatelessWidget {
  const RequestsScreen({super.key});

  Color _statusColor(String s) =>
      s == 'Approved' ? Colors.green : (s == 'Rejected' ? Colors.red : Colors.orange);

  Future<void> _resolve(Map<String, dynamic> r, String decision) =>
      Supa.resolveRequest(r['id'] as int, r['cnic'], r['name'], decision);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Correction Requests'), backgroundColor: kSeed, foregroundColor: Colors.white),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Supa.requests(),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) return loading();
          final reqs = snap.data ?? [];
          if (reqs.isEmpty) return const Center(child: Text('No requests yet.'));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: reqs.map((r) {
              final status = r['status'] ?? 'Pending';
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text('${r['name'] ?? r['cnic']}', style: const TextStyle(fontWeight: FontWeight.bold))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: _statusColor(status).withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                        child: Text(status, style: TextStyle(color: _statusColor(status), fontSize: 12)),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Text('Field: ${r['field']}'),
                    Text('“${r['current_value'] ?? ''}” → “${r['requested_value']}”'),
                    if ((r['reason'] ?? '').toString().isNotEmpty)
                      Text('Reason: ${r['reason']}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    if ((r['proof_url'] ?? '').toString().isNotEmpty)
                      TextButton.icon(onPressed: () {}, icon: const Icon(Icons.attach_file, size: 16), label: const Text('Proof attached')),
                    if (status == 'Pending') ...[
                      const SizedBox(height: 8),
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        TextButton(onPressed: () => _resolve(r, 'Rejected'), child: const Text('Reject')),
                        const SizedBox(width: 8),
                        FilledButton(onPressed: () => _resolve(r, 'Approved'), child: const Text('Approve')),
                      ]),
                    ],
                  ]),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

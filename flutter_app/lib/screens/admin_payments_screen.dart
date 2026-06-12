import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api.dart';
import '../theme.dart';

/// Admin view of all tax payments made through the gateway, with receipt download.
class AdminPaymentsScreen extends StatefulWidget {
  const AdminPaymentsScreen({super.key});
  @override
  State<AdminPaymentsScreen> createState() => _AdminPaymentsScreenState();
}

class _AdminPaymentsScreenState extends State<AdminPaymentsScreen> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = Api.payments();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => setState(() => _future = Api.payments()),
      child: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: C.green));
          }
          final list = snap.data ?? [];
          return ListView(padding: const EdgeInsets.fromLTRB(16, 18, 16, 40), children: [
            const PageHeader('Collections', 'Tax Payments', desc: 'Payments received through the Zindigi gateway.'),
            const SizedBox(height: 12),
            if (list.isEmpty)
              Padding(padding: const EdgeInsets.all(30), child: Center(child: Text('No payments yet.', style: body(13, c: C.text3))))
            else
              ...list.map((p) {
                final paid = p['status'] == 'Paid';
                return GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Icon(paid ? Icons.check_circle : Icons.schedule, color: paid ? C.green : C.high),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${p['name'] ?? p['cnic']} · ${rs(p['amount'])}', style: body(13, w: FontWeight.w700)),
                        Text('${p['cnic']} · PSID ${p['psid']}', style: mono(10, c: C.text3)),
                        Text('${'${p['created_at'] ?? ''}'.split('T').first} · ${p['status']}', style: body(10.5, c: C.text2)),
                      ]),
                    ),
                    if (paid)
                      IconButton(
                        icon: const Icon(Icons.picture_as_pdf, color: C.blue),
                        tooltip: 'Receipt',
                        onPressed: () => launchUrl(Uri.parse(Api.receiptUrl('${p['psid']}')), mode: LaunchMode.externalApplication),
                      ),
                  ]),
                );
              }),
          ]);
        },
      ),
    );
  }
}

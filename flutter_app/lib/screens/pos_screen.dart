import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';

/// POS verification & turnover reconciliation — pick a registered business, verify
/// its FBR POS integration, and reconcile declared income vs actual (bank) sales.
class POSVerifyScreen extends StatefulWidget {
  const POSVerifyScreen({super.key});
  @override
  State<POSVerifyScreen> createState() => _POSVerifyScreenState();
}

class _POSVerifyScreenState extends State<POSVerifyScreen> {
  List<dynamic> _biz = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await Api.posBusinesses('');
      setState(() {
        _biz = (r['results'] as List?) ?? [];
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _open(String cnic) => Navigator.push(context, MaterialPageRoute(builder: (_) => POSResultScreen(cnic: cnic)));

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.fromLTRB(16, 18, 16, 70), children: [
      const PageHeader('Tax Net', 'POS Verification', desc: 'Verify a business’s FBR POS integration and reconcile its reported sales.'),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.white, padding: const EdgeInsets.all(13)),
          onPressed: _biz.isEmpty ? null : () => _open(_biz.first['cnic']),
          icon: const Icon(Icons.trending_up),
          label: const Text('Audit highest-turnover business'),
        ),
      ),
      const SizedBox(height: 14),
      if (_loading)
        const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: C.green)))
      else if (_biz.isEmpty)
        Padding(padding: const EdgeInsets.all(40), child: Center(child: Text('No businesses found.', style: body(13, c: C.text3))))
      else
        ..._biz.map(_row),
    ]);
  }

  Widget _row(dynamic b) {
    final zone = '${b['zone'] ?? ''}';
    final sev = zone == 'Red' ? 'critical' : zone == 'Yellow' ? 'high' : 'low';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _open(b['cnic']),
        child: GlassCard(
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: C.blue.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.storefront, color: C.blue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${b['name']}', style: body(13.5, w: FontWeight.w700)),
                Text('${b['business_desc'] ?? 'Business'} · ${b['district'] ?? ''}', style: mono(10.5, c: C.text3)),
                const SizedBox(height: 3),
                Text('Turnover ${rs(b['turnover'])}', style: body(11.5, c: C.text2)),
              ]),
            ),
            const SizedBox(width: 8),
            if (zone.isNotEmpty && zone != '-') Tag(zone.toUpperCase(), sev: sev),
            Icon(Icons.chevron_right, color: C.text3),
          ]),
        ),
      ),
    );
  }
}

class POSResultScreen extends StatefulWidget {
  final String cnic;
  const POSResultScreen({required this.cnic, super.key});
  @override
  State<POSResultScreen> createState() => _POSResultScreenState();
}

class _POSResultScreenState extends State<POSResultScreen> {
  Map<String, dynamic>? _r;
  String? _err;

  @override
  void initState() {
    super.initState();
    Api.posVerify(widget.cnic).then((v) => setState(() => _r = v)).catchError((e) => setState(() => _err = '$e'));
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    return Scaffold(
      appBar: AppBar(title: const Text('POS Verification'), backgroundColor: C.bg2, foregroundColor: C.text, elevation: 0.5),
      body: _err != null
          ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(_err!, style: body(12, c: C.text3))))
          : r == null
              ? const Center(child: CircularProgressIndicator(color: C.green))
              : _content(r),
    );
  }

  Widget _content(Map<String, dynamic> r) {
    final integrated = r['pos_integrated'] == true;
    final unreported = (r['unreported'] ?? 0) as num;
    final turnover = (r['bank_turnover'] ?? 0) as num;
    final reportedPct = (r['reported_pct'] ?? 0) as num;
    final col = integrated ? (unreported < turnover * 0.15 ? C.green : C.high) : C.critical;
    final invoices = (r['invoices'] as List?) ?? [];
    return ListView(padding: const EdgeInsets.fromLTRB(16, 18, 16, 40), children: [
      // business header
      GlassCard(
        child: Row(children: [
          Container(width: 50, height: 50, decoration: BoxDecoration(color: C.blue.withOpacity(0.12), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.storefront, color: C.blue)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${r['name']}', style: display(16)),
            Text('${r['business']} · ${r['district'] ?? ''}', style: body(11.5, c: C.text2)),
            Text('NTN ${r['ntn'] ?? '—'} · CNIC ${r['cnic']}', style: mono(10, c: C.text3)),
          ])),
        ]),
      ),
      const SizedBox(height: 14),
      // verification banner with QR
      GlassCard(
        child: Column(children: [
          Icon(Icons.qr_code_2, size: 80, color: col),
          const SizedBox(height: 8),
          Icon(integrated ? Icons.verified : Icons.gpp_bad, color: col, size: 22),
          const SizedBox(height: 4),
          Text(integrated ? 'FBR POS INTEGRATED' : 'NOT POS-INTEGRATED', style: display(15, c: col)),
          const SizedBox(height: 4),
          Text('${r['verdict']}', textAlign: TextAlign.center, style: body(12.5, c: C.text2)),
          const SizedBox(height: 4),
          Text('Simulated POS verification (demo).', style: body(10, c: C.text3)),
        ]),
      ),
      const SizedBox(height: 14),
      // reconciliation
      GlassCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Turnover Reconciliation', style: display(14)),
          const SizedBox(height: 12),
          _kv('Declared income', rs(r['declared_income'])),
          _kv('Actual turnover (bank)', rs(turnover)),
          _kv('Reported via POS', '${rs(r['pos_reported'])}  (${reportedPct.toInt()}%)'),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(children: [
              Container(height: 12, color: C.critical.withOpacity(0.25)),
              FractionallySizedBox(widthFactor: (reportedPct / 100).clamp(0.0, 1.0).toDouble(), child: Container(height: 12, color: C.green)),
            ]),
          ),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Reported', style: body(10, c: C.green)),
            Text('Unreported', style: body(10, c: C.critical)),
          ]),
          const Divider(height: 22),
          _kv('Unreported sales', rs(unreported), c: C.critical),
          _kv('Recoverable sales tax (GST 17%)', rs(r['recovery']), c: C.critical, bold: true),
        ]),
      ),
      const SizedBox(height: 14),
      Text('Sample POS invoices', style: display(14)),
      const SizedBox(height: 8),
      ...invoices.map((i) {
        final reported = i['status'] == 'Reported';
        return GlassCard(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Icon(Icons.receipt_long, size: 20, color: reported ? C.green : C.critical),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${i['invoice_no']}', style: mono(11.5, w: FontWeight.w700)),
              Text('Amount ${rs(i['amount'])} · GST ${rs(i['sales_tax'])}', style: body(11, c: C.text2)),
            ])),
            Tag(reported ? 'REPORTED' : 'NOT REPORTED', sev: reported ? 'low' : 'critical'),
          ]),
        );
      }),
    ]);
  }

  Widget _kv(String k, String v, {Color? c, bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Flexible(child: Text(k, style: body(12, c: C.text2))),
          Text(v, style: body(12.5, w: bold ? FontWeight.w800 : FontWeight.w600, c: c ?? C.text)),
        ]),
      );
}

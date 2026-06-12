import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../api.dart';
import '../common.dart';
import '../supa.dart';
import 'person_detail.dart';
import 'notifications_screen.dart';
import 'receipt_verify_screen.dart';
import 'tax_calculator_screen.dart';
import 'chat_screen.dart';

/// Citizen view of their own record + ability to raise a correction request.
class UserDashboard extends StatefulWidget {
  final String cnic;
  const UserDashboard({required this.cnic, super.key});
  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  Map<String, dynamic>? _d;
  String? _error;
  StreamSubscription<List<Map<String, dynamic>>>? _notifSub;

  @override
  void initState() {
    super.initState();
    _load();
    // refetch profile (assets + score) live whenever a notification arrives (e.g. an approval)
    _notifSub = Supa.notifications(widget.cnic).skip(1).listen((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await Api.person(widget.cnic);
      setState(() => _d = d);
    } catch (e) {
      setState(() => _error = 'Could not load record for ${widget.cnic}.\n\n($e)');
    }
  }

  Future<void> _requestCorrection() async {
    final field = TextEditingController();
    final value = TextEditingController();
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Request a Correction'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: field, decoration: const InputDecoration(labelText: 'Field (e.g. Address, Income)')),
          TextField(controller: value, decoration: const InputDecoration(labelText: 'Corrected value')),
          TextField(controller: reason, decoration: const InputDecoration(labelText: 'Reason')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Submit')),
        ],
      ),
    );
    if (ok == true && field.text.isNotEmpty) {
      await Supa.createRequest(
        cnic: widget.cnic,
        name: _d?['identity']?['name'],
        field: field.text,
        requested: value.text,
        reason: reason.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Request sent to FBR Admin.')));
      }
    }
  }

  Future<String?> _pickProof() async {
    final res = await FilePicker.platform.pickFiles(withData: true);
    if (res != null && res.files.single.bytes != null) {
      final f = res.files.single;
      return Supa.uploadProof(f.name, f.bytes!);
    }
    return null;
  }

  // Structured fields captured per asset type so the declared asset is written
  // into the record completely (matching the seeded data) — not a placeholder.
  static const Map<String, List<List<String>>> _assetFields = {
    'Vehicle': [['make', 'Make (e.g. Toyota)'], ['model', 'Model (e.g. Corolla)'], ['year', 'Year'], ['engine_cc', 'Engine (cc)']],
    'Property': [['property_type', 'Type (e.g. House / Plot)'], ['area', 'Area (e.g. 10 Marla)'], ['district', 'District']],
    'Bank': [['bank', 'Bank name'], ['account_type', 'Account type (Savings / Current)']],
    'Stock': [['scrip', 'Scrip / Symbol (e.g. HBL)'], ['shares', 'Number of shares']],
    'Other': [['name', 'What is the asset?']],
  };
  static const _numericKeys = {'year', 'engine_cc', 'shares'};

  String _describeAsset(String type, Map<String, dynamic> d) {
    List<dynamic> parts;
    switch (type) {
      case 'Vehicle':
        parts = [d['make'], d['model'], d['year'], d['engine_cc'] != null ? '${d['engine_cc']}cc' : null];
        break;
      case 'Property':
        parts = [d['property_type'], d['area'], d['district']];
        break;
      case 'Bank':
        parts = [d['bank'], d['account_type']];
        break;
      case 'Stock':
        parts = [d['scrip'], d['shares'] != null ? '${d['shares']} shares' : null];
        break;
      default:
        parts = [d['name']];
    }
    final s = parts.where((e) => e != null && '$e'.trim().isNotEmpty).join(' · ');
    return s.isEmpty ? type : s;
  }

  Future<void> _declareAsset() async {
    String type = 'Vehicle';
    final value = TextEditingController();
    final ctrls = <String, TextEditingController>{};
    TextEditingController c(String k) => ctrls.putIfAbsent(k, () => TextEditingController());
    String? proofUrl;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setD) {
        final fields = _assetFields[type] ?? const [];
        return AlertDialog(
          title: const Text('Declare an Asset'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                initialValue: type,
                items: _assetFields.keys.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setD(() => type = v ?? 'Vehicle'),
                decoration: const InputDecoration(labelText: 'Asset type'),
              ),
              for (final f in fields)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: TextField(
                    controller: c(f[0]),
                    keyboardType: _numericKeys.contains(f[0]) ? TextInputType.number : TextInputType.text,
                    decoration: InputDecoration(labelText: f[1]),
                  ),
                ),
              TextField(controller: value, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Estimated value (PKR)')),
              TextButton.icon(
                onPressed: () async { final u = await _pickProof(); if (u != null) setD(() => proofUrl = u); },
                icon: const Icon(Icons.attach_file, size: 18),
                label: Text(proofUrl == null ? 'Attach proof (optional)' : 'Proof attached ✓'),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Declare')),
          ],
        );
      }),
    );
    if (ok == true) {
      final details = <String, dynamic>{};
      for (final f in (_assetFields[type] ?? const [])) {
        final t = c(f[0]).text.trim();
        if (t.isEmpty) continue;
        details[f[0]] = _numericKeys.contains(f[0]) ? (num.tryParse(t) ?? t) : t;
      }
      final val = num.tryParse(value.text.trim());
      if (val != null) details['value'] = val;
      await Supa.declareAsset(
        cnic: widget.cnic, name: _d?['identity']?['name'], assetType: type,
        description: _describeAsset(type, details), value: val, details: details, proofUrl: proofUrl,
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Declaration submitted to FBR for monitoring.')));
    }
  }

  void _verifyReceipt() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ReceiptVerifyScreen(cnic: widget.cnic, name: '${_d?['identity']?['name'] ?? ''}')),
      );

  void _openTaxCalculator() => Navigator.push(context, MaterialPageRoute(builder: (_) => const TaxCalculatorScreen()));

  Future<void> _reportIssue() async {
    String category = 'Wrong record';
    final desc = TextEditingController();
    String? proofUrl;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
        title: const Text('Report a Problem'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            initialValue: category,
            items: const ['Wrong record', 'Asset not mine', 'Duplicate entry', 'Other'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => category = v ?? 'Other',
            decoration: const InputDecoration(labelText: 'Category'),
          ),
          TextField(controller: desc, maxLines: 2, decoration: const InputDecoration(labelText: 'Describe the issue')),
          TextButton.icon(
            onPressed: () async { final u = await _pickProof(); if (u != null) setD(() => proofUrl = u); },
            icon: const Icon(Icons.upload_file, size: 18),
            label: Text(proofUrl == null ? 'Upload proof' : 'Proof attached ✓'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit')),
        ],
      )),
    );
    if (ok == true) {
      await Supa.reportIssue(cnic: widget.cnic, name: _d?['identity']?['name'], category: category, description: desc.text, proofUrl: proofUrl);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Issue reported with proof. FBR will review.')));
    }
  }

  Widget _serviceBtn(String label, IconData icon, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(children: [Icon(icon, color: kSeed), const SizedBox(height: 6), Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))]),
          ),
        ),
      );

  Widget _miniStream(String title, Stream<List<Map<String, dynamic>>> stream, String Function(Map<String, dynamic>) line) =>
      StreamBuilder<List<Map<String, dynamic>>>(
        stream: stream,
        builder: (_, snap) {
          final items = snap.data ?? [];
          if (items.isEmpty) return const SizedBox.shrink();
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionTitle(title, Icons.assignment_turned_in),
            ...items.map((r) {
              final st = r['status'] ?? 'Pending';
              final col = st == 'Approved' || st == 'Resolved' ? Colors.green : (st == 'Rejected' ? Colors.red : Colors.orange);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.description_outlined),
                  title: Text(line(r), maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Text('$st', style: TextStyle(color: col, fontWeight: FontWeight.w600, fontSize: 12)),
                ),
              );
            }),
          ]);
        },
      );

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Profile')),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(child: SelectableText(_error!, style: const TextStyle(fontSize: 13))),
        ),
      );
    }
    final d = _d;
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tax Profile'), backgroundColor: kSeed, foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.smart_toy_outlined),
            tooltip: 'AI Tax Assistant',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen(title: 'AI Tax Assistant'))),
          ),
          NotificationBell(recipient: widget.cnic),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _requestCorrection,
        icon: const Icon(Icons.edit),
        label: const Text('Request Correction'),
      ),
      body: d == null
          ? loading()
          : ListView(padding: const EdgeInsets.all(16), children: [
              _complianceCard(d),
              const SectionTitle('My Tax', Icons.receipt_long),
              _taxCard(d['tax']),
              const SectionTitle('My Assets', Icons.account_balance_wallet),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: Supa.declarations(cnic: widget.cnic),
                builder: (_, snap) => _assetsSummary(Map<String, dynamic>.from(d['assets'] ?? {}), snap.data ?? []),
              ),
              FilledButton.tonalIcon(
                onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => PersonDetail(cnic: widget.cnic))),
                icon: const Icon(Icons.list_alt),
                label: const Text('View full asset details'),
              ),
              const SectionTitle('Services', Icons.apps),
              Row(children: [
                Expanded(child: _serviceBtn('Declare Asset', Icons.add_box, _declareAsset)),
                const SizedBox(width: 10),
                Expanded(child: _serviceBtn('Report Issue', Icons.report_problem, _reportIssue)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _serviceBtn('Verify Receipt', Icons.qr_code_scanner, _verifyReceipt)),
                const SizedBox(width: 10),
                Expanded(child: _serviceBtn('Tax Calculator', Icons.calculate, _openTaxCalculator)),
              ]),
              _miniStream('My Declarations', Supa.declarations(cnic: widget.cnic),
                  (r) => '${r['asset_type']} · ${(r['description'] ?? '')}'),
              _miniStream('My Issues', Supa.issues(cnic: widget.cnic),
                  (r) => '${r['category']} · ${(r['description'] ?? '')}'),
              const SectionTitle('My Requests', Icons.history),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: Supa.requests(cnic: widget.cnic),
                builder: (_, snap) {
                  final reqs = snap.data ?? [];
                  if (reqs.isEmpty) {
                    return const Padding(padding: EdgeInsets.all(8), child: Text('No requests yet.'));
                  }
                  return Column(
                    children: reqs.map((r) {
                      final st = r['status'] ?? 'Pending';
                      final col = st == 'Approved' ? Colors.green : (st == 'Rejected' ? Colors.red : Colors.orange);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.edit_note),
                          title: Text('${r['field']} → ${r['requested_value']}'),
                          subtitle: r['reason'] != null && r['reason'].toString().isNotEmpty ? Text(r['reason']) : null,
                          trailing: Text(st, style: TextStyle(color: col, fontWeight: FontWeight.w600)),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ]),
    );
  }

  Widget _complianceCard(Map<String, dynamic> d) {
    final sc = d['score'];
    final zone = sc?['zone'] ?? 'Green';
    final score = (sc?['deviation_score'] ?? 0).toDouble();
    return Card(
      color: zoneColor(zone).withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(children: [
          Text(d['identity']['name'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(widget.cnic, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          const SizedBox(height: 14),
          Text(score.toStringAsFixed(0),
              style: TextStyle(fontSize: 44, fontWeight: FontWeight.bold, color: zoneColor(zone))),
          const Text('Tax Compliance Deviation Score'),
          const SizedBox(height: 8),
          ZoneChip(zone, score: score),
          if (zone != 'Green') ...[
            const SizedBox(height: 12),
            Text(
              zone == 'Red'
                  ? 'Your declared income appears far below your assets/lifestyle. You may be selected for audit.'
                  : 'Some deviation detected between your declared income and footprint.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700], fontSize: 13),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text('You are tax-compliant. Thank you.', style: TextStyle(color: Color(0xFF2E7D32))),
            ),
        ]),
      ),
    );
  }

  Widget _taxCard(dynamic tax) {
    if (tax == null) {
      return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('You have no tax return on record (Non-Filer).')));
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          _kv('Declared Income', money(tax['declared_income'])),
          _kv('Tax Paid', money(tax['tax_paid'])),
          _kv('Filer Status', tax['filer_status'] ?? '—'),
        ]),
      ),
    );
  }

  Widget _assetsSummary(Map<String, dynamic> a, List<Map<String, dynamic>> decls) {
    int c(String k) => (a[k] as List).length;
    // count only PENDING declarations (approved ones are now in the real record below)
    int dc(String type) => decls.where((x) => x['asset_type'] == type && x['status'] == 'Pending').length;
    // (label, icon, base count, declared count)
    final items = [
      ('Vehicles', Icons.directions_car, c('vehicles'), dc('Vehicle')),
      ('Properties', Icons.home_work, c('properties'), dc('Property')),
      ('Bank A/Cs', Icons.account_balance, c('bank_accounts'), dc('Bank')),
      ('Stocks', Icons.show_chart, c('stocks'), dc('Stock')),
      ('Companies', Icons.business, c('directorships'), 0),
      ('Trips', Icons.flight, c('travel'), 0),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.1,
      children: items
          .map((i) => Card(
                child: Stack(children: [
                  Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(i.$2, color: kSeed),
                      const SizedBox(height: 6),
                      Text('${i.$3 + i.$4}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(i.$1, style: const TextStyle(fontSize: 11)),
                    ]),
                  ),
                  if (i.$4 > 0)
                    Positioned(
                      top: 6, right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: kSeed.withOpacity(0.14), borderRadius: BorderRadius.circular(8)),
                        child: Text('+${i.$4} declared', style: const TextStyle(fontSize: 8.5, color: kSeed, fontWeight: FontWeight.w700)),
                      ),
                    ),
                ]),
              ))
          .toList(),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(k, style: TextStyle(color: Colors.grey[600])),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      );
}

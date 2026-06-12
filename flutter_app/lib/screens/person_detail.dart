import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api.dart';
import '../common.dart';
import '../supa.dart';

class PersonDetail extends StatefulWidget {
  final String cnic;
  final bool admin;
  const PersonDetail({required this.cnic, this.admin = false, super.key});
  @override
  State<PersonDetail> createState() => _PersonDetailState();
}

class _PersonDetailState extends State<PersonDetail> {
  Map<String, dynamic>? _d;
  Map<String, dynamic>? _explain;
  bool _explaining = false;

  @override
  void initState() {
    super.initState();
    Api.person(widget.cnic).then((v) => setState(() => _d = v));
  }

  Future<void> _runExplain() async {
    setState(() => _explaining = true);
    try {
      final e = await Api.explain(widget.cnic);
      setState(() => _explain = e);
    } catch (_) {
    } finally {
      setState(() => _explaining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile'), backgroundColor: kSeed, foregroundColor: Colors.white),
      body: d == null
          ? loading()
          : ListView(padding: const EdgeInsets.all(16), children: [
              _header(d),
              if (widget.admin) ...[
                const SectionTitle('Why was this person flagged?', Icons.psychology),
                _auditCard(d),
                _explainCard(),
                _downloadAuditButton(),
              ],
              const SectionTitle('Tax Declaration', Icons.receipt_long),
              _taxCard(d['tax']),
              const SectionTitle('Assets & Footprint', Icons.account_balance_wallet),
              ..._assets(Map<String, dynamic>.from(d['assets'] ?? {})),
            ]),
    );
  }

  Widget _header(Map<String, dynamic> d) {
    final id = d['identity'], sc = d['score'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          CircleAvatar(radius: 26, backgroundColor: kSeed.withOpacity(0.15), child: const Icon(Icons.person, color: kSeed)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(id['name'] ?? '—', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('${id['cnic']} · ${id['district'] ?? ''}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ]),
          ),
          if (sc != null)
            Column(children: [
              ZoneChip(sc['zone'], score: (sc['deviation_score'] ?? 0).toDouble()),
              const SizedBox(height: 4),
              const Text('Deviation', style: TextStyle(fontSize: 10, color: Colors.grey)),
            ]),
        ]),
      ),
    );
  }

  Widget _downloadAuditButton() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: kSeed, foregroundColor: Colors.white, padding: const EdgeInsets.all(14)),
            onPressed: _downloadAudit,
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Download Audit Report (PDF)'),
          ),
        ),
      );

  Future<void> _downloadAudit() async {
    final uri = Uri.parse(Api.auditReportUrl(widget.cnic));
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the report — is the backend running?')),
      );
    }
  }

  Widget _auditCard(Map<String, dynamic> d) {
    final trail = (d['audit_trail'] as List?) ?? [];
    if (trail.isEmpty) {
      return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No deviation evidence — compliant.')));
    }
    return Card(
      color: zoneColor(d['score']?['zone']).withOpacity(0.06),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: trail
              .map((t) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.chevron_right, size: 18, color: kSeed),
                      Expanded(child: Text(t.toString())),
                    ]),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _explainCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.hub, color: Colors.deepPurple, size: 18),
            const SizedBox(width: 8),
            const Expanded(child: Text('GNN Graph Evidence', style: TextStyle(fontWeight: FontWeight.bold))),
            if (_explain == null)
              FilledButton.tonal(
                onPressed: _explaining ? null : _runExplain,
                child: _explaining
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Explain with AI'),
              ),
          ]),
          if (_explain != null) ...[
            const SizedBox(height: 8),
            Text('Anomaly probability: ${_explain!['anomaly_prob']}',
                style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...(_explain!['evidence'] as List).map((e) {
              final val = (e['value'] ?? 0) as int;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.deepPurple.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                    child: Text('+${e['contribution']}', style: const TextStyle(fontSize: 11, color: Colors.deepPurple)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        '${e['relation']}${e['hop'] == 2 ? ' → (2-hop)' : ''}  ·  ${e['node_type']} ${e['label']}'
                        '${val > 0 ? ' (${money(val)})' : ''}',
                        style: const TextStyle(fontSize: 12)),
                  ),
                ]),
              );
            }),
          ],
        ]),
      ),
    );
  }

  Widget _taxCard(dynamic tax) {
    if (tax == null) {
      return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No tax return on record (Non-Filer).')));
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          _kv('Declared Income', money(tax['declared_income'])),
          _kv('Tax Paid', money(tax['tax_paid'])),
          _kv('Filer Status', tax['filer_status'] ?? '—'),
          _kv('Source', tax['source_of_income'] ?? '—'),
        ]),
      ),
    );
  }

  List<Widget> _assets(Map<String, dynamic> a) {
    final out = <Widget>[];
    // type: the explainable asset class (null = footprint, not explainable); valOf: its value.
    void block(String title, IconData ic, List items, String Function(dynamic) line,
        {String? type, num Function(dynamic)? valOf}) {
      if (items.isEmpty) return;
      out.add(Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(ic, size: 18, color: kSeed), const SizedBox(width: 8), Text('$title (${items.length})', style: const TextStyle(fontWeight: FontWeight.bold))]),
            const Divider(),
            ...items.take(12).map((e) => InkWell(
                  onTap: () => _showAssetSheet(title, line(e), Map<String, dynamic>.from(e as Map), type, valOf?.call(e)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Expanded(child: Text(line(e))),
                      const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                    ]),
                  ),
                )),
          ]),
        ),
      ));
    }

    block('Vehicles', Icons.directions_car, a['vehicles'] ?? [],
        (v) => '${v['make']} ${v['model']} ${v['variant']} · ${v['engine_cc']}cc · ${money(v['value'])}',
        type: 'Vehicle', valOf: (v) => (v['value'] ?? 0) as num);
    block('Properties', Icons.home_work, a['properties'] ?? [],
        (p) => '${p['property_type']} · ${p['area']} · ${p['district']} · ${money(p['market_value'])}',
        type: 'Property', valOf: (p) => (p['market_value'] ?? 0) as num);
    block('Bank Accounts', Icons.account_balance, a['bank_accounts'] ?? [],
        (b) => '${b['bank']} · ${b['account_type']} · Bal ${money(b['balance'])}',
        type: 'Bank', valOf: (b) => (b['balance'] ?? 0) as num);
    block('Stocks', Icons.show_chart, a['stocks'] ?? [],
        (s) => '${s['scrip']} · ${s['shares']} shares · ${money(s['market_value'])}',
        type: 'Stock', valOf: (s) => (s['market_value'] ?? 0) as num);
    block('Directorships', Icons.business, a['directorships'] ?? [],
        (d) => '${d['name']} · ${d['role']} · ${d['pct']}%');
    block('Travel', Icons.flight, a['travel'] ?? [],
        (t) => '${t['airline']} → ${t['destination']} · ${money(t['ticket_cost'])}');
    block('Electricity', Icons.bolt, a['electricity'] ?? [],
        (e) => '${e['disco']} · ${e['units']} units · ${money(e['bill_amount'])}/mo');
    if (out.isEmpty) out.add(const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No assets on record.'))));
    return out;
  }

  // ---- asset drill-down: full details + (citizen-only) Explain ----
  void _showAssetSheet(String title, String headline, Map<String, dynamic> fields, String? type, num? value) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 14),
          Row(children: [Icon(_iconFor(title), color: kSeed), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
          const SizedBox(height: 4),
          Text(headline, style: TextStyle(color: Colors.grey[700])),
          const Divider(height: 22),
          ...fields.entries
              .where((e) => e.value != null && '${e.value}'.isNotEmpty)
              .map((e) => _kv(_pretty(e.key), _isMoney(e.key) ? money(e.value as num?) : '${e.value}')),
          if (type != null && !widget.admin) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: kSeed, foregroundColor: Colors.white, padding: const EdgeInsets.all(13)),
                onPressed: () {
                  Navigator.pop(context);
                  _explainAsset(type, headline, value);
                },
                icon: const Icon(Icons.verified_user),
                label: const Text('Explain this asset (source / proof)'),
              ),
            ),
            const SizedBox(height: 6),
            Text('Tell FBR how you acquired this (purchase, gift, inheritance…) so it is not flagged.',
                style: TextStyle(fontSize: 11.5, color: Colors.grey[600])),
          ],
        ]),
      ),
    );
  }

  IconData _iconFor(String t) => t == 'Vehicles'
      ? Icons.directions_car
      : t == 'Properties'
          ? Icons.home_work
          : t == 'Bank Accounts'
              ? Icons.account_balance
              : t == 'Stocks'
                  ? Icons.show_chart
                  : Icons.account_balance_wallet;

  bool _isMoney(String k) => ['value', 'market_value', 'balance', 'turnover', 'ticket_cost', 'bill_amount', 'dividend', 'dc_valuation'].contains(k);

  String _pretty(String k) => k.replaceAll('_', ' ').split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

  Future<void> _explainAsset(String type, String label, num? value) async {
    String source = 'Purchase';
    bool taxPaid = false;
    final remarks = TextEditingController();
    String? proofUrl;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
        title: const Text('Explain this asset'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 12)),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: source,
              items: const ['Purchase', 'Gift', 'Inheritance', 'Loan', 'Agricultural income', 'Other']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => source = v ?? 'Purchase',
              decoration: const InputDecoration(labelText: 'How did you acquire it?'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tax already paid on it', style: TextStyle(fontSize: 14)),
              value: taxPaid,
              onChanged: (v) => setD(() => taxPaid = v),
            ),
            TextField(controller: remarks, maxLines: 2, decoration: const InputDecoration(labelText: 'Remarks / details')),
            TextButton.icon(
              onPressed: () async { final u = await _pickProof(); if (u != null) setD(() => proofUrl = u); },
              icon: const Icon(Icons.attach_file, size: 18),
              label: Text(proofUrl == null ? 'Attach proof (succession cert, receipt…)' : 'Proof attached ✓'),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit')),
        ],
      )),
    );
    if (ok == true) {
      try {
        await Supa.explainAsset(
          cnic: widget.cnic, name: _d?['identity']?['name'], assetType: type, assetLabel: label,
          assetValue: value, source: source, taxPaid: taxPaid, remarks: remarks.text, proofUrl: proofUrl,
        );
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Explanation submitted to FBR for review.')));
      } catch (_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not submit — check your connection and try again.')));
      }
    }
  }

  Future<String?> _pickProof() async {
    try {
      final res = await FilePicker.platform.pickFiles(withData: true);
      if (res == null || res.files.isEmpty || res.files.single.bytes == null) return null;
      return await Supa.uploadProof(res.files.single.name, res.files.single.bytes!);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Proof upload failed — please try again.')));
      return null;
    }
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(k, style: TextStyle(color: Colors.grey[600])),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      );
}

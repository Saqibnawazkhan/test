import 'package:flutter/material.dart';
import '../api.dart';
import '../common.dart';

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
    void block(String title, IconData ic, List items, String Function(dynamic) line) {
      if ((items).isEmpty) return;
      out.add(Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(ic, size: 18, color: kSeed), const SizedBox(width: 8), Text('$title (${items.length})', style: const TextStyle(fontWeight: FontWeight.bold))]),
            const Divider(),
            ...items.take(8).map((e) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(line(e)))),
          ]),
        ),
      ));
    }

    block('Vehicles', Icons.directions_car, a['vehicles'],
        (v) => '${v['make']} ${v['model']} ${v['variant']} · ${v['engine_cc']}cc · ${money(v['value'])}');
    block('Properties', Icons.home_work, a['properties'],
        (p) => '${p['property_type']} · ${p['area']} · ${p['district']} · ${money(p['market_value'])}');
    block('Bank Accounts', Icons.account_balance, a['bank_accounts'],
        (b) => '${b['bank']} · ${b['account_type']} · Bal ${money(b['balance'])}');
    block('Stocks', Icons.show_chart, a['stocks'],
        (s) => '${s['scrip']} · ${s['shares']} shares · ${money(s['market_value'])}');
    block('Directorships', Icons.business, a['directorships'],
        (d) => '${d['name']} · ${d['role']} · ${d['pct']}%');
    block('Travel', Icons.flight, a['travel'],
        (t) => '${t['airline']} → ${t['destination']} · ${money(t['ticket_cost'])}');
    block('Electricity', Icons.bolt, a['electricity'],
        (e) => '${e['disco']} · ${e['units']} units · ${money(e['bill_amount'])}/mo');
    if (out.isEmpty) out.add(const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No assets on record.'))));
    return out;
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(k, style: TextStyle(color: Colors.grey[600])),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      );
}

import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';

/// Ego-centric family & asset network — surfaces benami fronts (relatives holding
/// wealth with little/no income of their own). Reliable, accurate, readable.
class FamilyTreeScreen extends StatefulWidget {
  final String cnic;
  const FamilyTreeScreen({required this.cnic, super.key});
  @override
  State<FamilyTreeScreen> createState() => _FamilyTreeScreenState();
}

class _FamilyTreeScreenState extends State<FamilyTreeScreen> {
  Map<String, dynamic>? _f;
  String? _err;

  @override
  void initState() {
    super.initState();
    Api.family(widget.cnic).then((v) => setState(() => _f = v)).catchError((e) => setState(() => _err = '$e'));
  }

  @override
  Widget build(BuildContext context) {
    final f = _f;
    return Scaffold(
      appBar: AppBar(title: const Text('Family & Asset Network'), backgroundColor: C.bg2, foregroundColor: C.text, elevation: 0.5),
      body: _err != null
          ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(_err!, style: body(12, c: C.text3))))
          : f == null
              ? const Center(child: CircularProgressIndicator(color: C.green))
              : _content(f),
    );
  }

  Widget _content(Map<String, dynamic> f) {
    final members = (f['members'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final ego = members.firstWhere((m) => m['relation'] == 'Self', orElse: () => members.first);
    final parent = members.where((m) => m['relation'] == 'Father / Husband').toList();
    final deps = members.where((m) => m['relation'] != 'Self' && m['relation'] != 'Father / Husband').toList();
    return ListView(padding: const EdgeInsets.fromLTRB(16, 18, 16, 40), children: [
      const PageHeader('Benami Detection', 'Family & Asset Network', desc: 'Assets held in the names of relatives — possible fronts are flagged.'),
      const SizedBox(height: 14),
      _summary(f),
      const SizedBox(height: 18),
      if (parent.isNotEmpty) ...[
        _memberCard(parent.first, head: true),
        _connector(),
      ],
      _memberCard(ego, ego: true),
      if (deps.isNotEmpty) ...[
        const SizedBox(height: 12),
        Row(children: [
          Icon(Icons.subdirectory_arrow_right, size: 18, color: C.text3),
          const SizedBox(width: 6),
          Text('Assets held through ${deps.length} relative${deps.length > 1 ? 's' : ''}',
              style: body(12.5, w: FontWeight.w700, c: C.text2)),
        ]),
        const SizedBox(height: 10),
        ...deps.map(_branchCard),
      ] else ...[
        const SizedBox(height: 14),
        Center(child: Text('No dependent relatives on record for this entity.', style: body(12, c: C.text3))),
      ],
    ]);
  }

  Widget _summary(Map<String, dynamic> f) {
    Widget stat(String label, String val, Color col, IconData ic) => Expanded(
          child: GlassCard(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(ic, size: 18, color: col),
              const SizedBox(height: 8),
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(val, style: display(15, c: col))),
              const SizedBox(height: 2),
              Text(label, style: body(10, c: C.text3)),
            ]),
          ),
        );
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        stat('Family assets', rs(f['total_family_assets']), C.blue, Icons.account_balance_wallet),
        const SizedBox(width: 10),
        stat('Possible fronts', '${f['front_count']}', C.critical, Icons.warning_amber_rounded),
        const SizedBox(width: 10),
        stat('Hidden in fronts', rs(f['hidden_in_fronts']), C.high, Icons.visibility_off),
      ]),
    );
  }

  Widget _connector() => Center(child: Container(width: 2, height: 22, color: C.border));

  Color _gcol(String g) => g == 'F' ? const Color(0xFFB14AE0) : C.blue;

  Widget _chip(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Text(text, style: body(10, w: FontWeight.w600, c: fg)),
      );

  Widget _memberCard(Map<String, dynamic> m, {bool ego = false, bool head = false}) {
    final init = '${m['name']}'.split(' ').where((s) => s.isNotEmpty).map((s) => s[0]).take(2).join();
    final front = m['possible_front'] == true;
    final g = '${m['gender']}';
    return Container(
      decoration: BoxDecoration(
        color: ego ? const Color(0x142E6FE0) : C.bg2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: front ? C.critical : ego ? C.blue : C.border, width: (front || ego) ? 1.4 : 1),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        CircleAvatar(radius: 22, backgroundColor: _gcol(g).withOpacity(0.16), child: Text(init, style: display(14, c: _gcol(g)))),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text('${m['name']}', style: body(14, w: FontWeight.w700))),
              if (ego) ...[const SizedBox(width: 6), _chip('SELF', C.blue.withOpacity(0.14), C.blue)],
              if (head) ...[const SizedBox(width: 6), _chip('HEAD', C.text3.withOpacity(0.14), C.text2)],
            ]),
            const SizedBox(height: 4),
            Row(children: [
              _chip('${m['relation']}', _gcol(g).withOpacity(0.12), _gcol(g)),
              if (m['age'] != null) ...[const SizedBox(width: 6), Text('${m['age']} yrs', style: mono(10.5, c: C.text3))],
            ]),
            const SizedBox(height: 7),
            Text('Assets ${rs(m['own_assets'])}   ·   Income ${rs(m['declared_income'])}', style: body(11.5, c: C.text2)),
            Text('${m['filer_status']}', style: mono(10, c: C.text3)),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (front)
            _chip('FRONT', C.critical.withOpacity(0.14), C.critical)
          else
            Container(width: 10, height: 10, decoration: BoxDecoration(color: C.zone('${m['zone']}'), shape: BoxShape.circle)),
          const SizedBox(height: 8),
          Text('${(m['deviation_score'] as num).toInt()}', style: mono(16, w: FontWeight.w700, c: C.zone('${m['zone']}'))),
          Text('dev', style: body(8.5, c: C.text3)),
        ]),
      ]),
    );
  }

  Widget _branchCard(Map<String, dynamic> d) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: d['possible_front'] == true ? C.critical : C.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: _memberCard(d)),
          ]),
        ),
      );
}

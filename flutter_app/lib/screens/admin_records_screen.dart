import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';
import 'person_detail.dart';

/// Admin: browse ALL citizen records with search, zone/area filters, sort, and
/// pagination — plus add a new record.
class AllRecordsScreen extends StatefulWidget {
  const AllRecordsScreen({super.key});
  @override
  State<AllRecordsScreen> createState() => _AllRecordsScreenState();
}

class _AllRecordsScreenState extends State<AllRecordsScreen> {
  List<dynamic> _people = [];
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _zone;
  String? _district;
  String _sort = 'score';
  List<String> _districts = [];

  @override
  void initState() {
    super.initState();
    Api.districts().then((d) => setState(() => _districts = d.map((e) => '$e').toList())).catchError((_) => []);
    _query(reset: true);
  }

  Future<void> _query({required bool reset}) async {
    setState(() { if (reset) _loading = true; else _loadingMore = true; });
    try {
      final r = await Api.persons(
        zone: _zone, district: _district, sort: _sort,
        limit: 50, offset: reset ? 0 : _people.length,
      );
      final res = (r['results'] as List?) ?? [];
      setState(() {
        _total = (r['total'] ?? 0) as int;
        if (reset) _people = res; else _people.addAll(res);
        _loading = false;
        _loadingMore = false;
      });
    } catch (_) {
      setState(() { _loading = false; _loadingMore = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: C.green, foregroundColor: Colors.white,
        onPressed: () async {
          final added = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const AddRecordScreen()));
          if (added == true) _query(reset: true);
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Add Record'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(child: PageHeader('Registry', 'All Records', desc: 'Every citizen on the national tax net.')),
            ]),
            const SizedBox(height: 10),
            SizedBox(
              height: 38,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                _zoneChip(null, 'All', C.text2),
                _zoneChip('Red', 'Red', C.critical),
                _zoneChip('Yellow', 'Yellow', C.med),
                _zoneChip('Green', 'Green', C.low),
                const SizedBox(width: 8),
                _sortMenu(),
                const SizedBox(width: 8),
                _districtMenu(),
              ]),
            ),
            const SizedBox(height: 6),
            Text('${_total.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')} records', style: body(11.5, c: C.text3)),
          ]),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: C.green))
              : _people.isEmpty
                  ? Center(child: Text('No matching records.', style: body(13, c: C.text3)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                      itemCount: _people.length + 1,
                      itemBuilder: (_, i) {
                        if (i == _people.length) {
                          if (_people.length >= _total) return Padding(padding: const EdgeInsets.all(16), child: Center(child: Text('— end of ${_total} records —', style: body(11, c: C.text3))));
                          return Padding(
                            padding: const EdgeInsets.all(12),
                            child: Center(child: _loadingMore
                                ? const CircularProgressIndicator(color: C.green)
                                : OutlinedButton(onPressed: () => _query(reset: false), child: const Text('Load more'))),
                          );
                        }
                        return _row(_people[i]);
                      },
                    ),
        ),
      ]),
    );
  }

  Widget _zoneChip(String? z, String label, Color c) {
    final active = _zone == z;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () { setState(() => _zone = z); _query(reset: true); },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(color: active ? c.withOpacity(0.14) : C.bg2, border: Border.all(color: active ? c : C.border), borderRadius: BorderRadius.circular(9)),
          child: Text(label, style: body(12, w: FontWeight.w500, c: active ? c : C.text2)),
        ),
      ),
    );
  }

  Widget _sortMenu() => PopupMenuButton<String>(
        onSelected: (v) { setState(() => _sort = v); _query(reset: true); },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'score', child: Text('Score: High → Low')),
          PopupMenuItem(value: 'score_asc', child: Text('Score: Low → High')),
          PopupMenuItem(value: 'name', child: Text('Name (A–Z)')),
          PopupMenuItem(value: 'district', child: Text('Area / District')),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(color: C.bg2, border: Border.all(color: C.border), borderRadius: BorderRadius.circular(9)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.swap_vert, size: 15, color: C.text2), const SizedBox(width: 5), Text('Sort', style: body(12, c: C.text2))]),
        ),
      );

  Widget _districtMenu() => PopupMenuButton<String?>(
        onSelected: (v) { setState(() => _district = v); _query(reset: true); },
        itemBuilder: (_) => [
          const PopupMenuItem(value: null, child: Text('All areas')),
          ..._districts.map((d) => PopupMenuItem(value: d, child: Text(d))),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(color: C.bg2, border: Border.all(color: C.border), borderRadius: BorderRadius.circular(9)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.place_outlined, size: 15, color: C.text2), const SizedBox(width: 5), Text(_district ?? 'Area', style: body(12, c: C.text2))]),
        ),
      );

  Widget _row(dynamic p) {
    final zone = '${p['zone'] ?? '-'}';
    final sev = zone == 'Red' ? 'critical' : zone == 'Yellow' ? 'high' : 'low';
    final dev = (p['deviation_score'] ?? 0) as num;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PersonDetail(cnic: p['cnic'], admin: true))),
        child: GlassCard(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${p['name']}', style: body(13.5, w: FontWeight.w700)),
              Text('${p['cnic']} · ${p['district'] ?? ''}', style: mono(10.5, c: C.text3)),
            ])),
            if (zone != '-') Tag(zone.toUpperCase(), sev: sev),
            const SizedBox(width: 10),
            Text('${dev.toInt()}', style: mono(18, w: FontWeight.w700, c: C.zone(zone))),
          ]),
        ),
      ),
    );
  }
}

// =========================== ADD RECORD ===========================
class AddRecordScreen extends StatefulWidget {
  const AddRecordScreen({super.key});
  @override
  State<AddRecordScreen> createState() => _AddRecordScreenState();
}

class _AddRecordScreenState extends State<AddRecordScreen> {
  final _c = <String, TextEditingController>{};
  String _gender = 'M';
  String _filer = 'Non-Filer';
  bool _saving = false;

  TextEditingController _ctrl(String k) => _c.putIfAbsent(k, () => TextEditingController());

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  num _num(String k) => num.tryParse(_ctrl(k).text.trim().replaceAll(',', '')) ?? 0;

  Future<void> _save() async {
    final cnic = _ctrl('cnic').text.trim();
    final name = _ctrl('name').text.trim();
    if (cnic.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CNIC and Name are required.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final r = await Api.createPerson({
        'cnic': cnic, 'name': name, 'father': _ctrl('father').text.trim(), 'gender': _gender,
        'dob': _ctrl('dob').text.trim(), 'district': _ctrl('district').text.trim(),
        'address': _ctrl('address').text.trim(), 'mobile': _ctrl('mobile').text.trim(), 'email': _ctrl('email').text.trim(),
        'declared_income': _num('income'), 'filer_status': _filer,
        'vehicle_value': _num('vehicle'), 'property_value': _num('property'),
        'bank_balance': _num('bank'), 'stock_value': _num('stock'),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Record created — score ${r['score']} (${r['zone']}).')));
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create — ${e.toString().contains('400') ? 'CNIC already exists.' : 'is the backend running?'}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Record'), backgroundColor: C.bg2, foregroundColor: C.text, elevation: 0.5),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('NADRA Identity', style: display(14)),
        const SizedBox(height: 8),
        _field('cnic', 'CNIC *', Icons.badge_outlined),
        _field('name', 'Full name *', Icons.person_outline),
        _field('father', 'Father / Husband name', Icons.family_restroom),
        Row(children: [
          Expanded(child: _dropdown('Gender', _gender, const ['M', 'F'], (v) => setState(() => _gender = v))),
          const SizedBox(width: 10),
          Expanded(child: _field('dob', 'DOB (YYYY-MM-DD)', Icons.cake_outlined)),
        ]),
        _field('district', 'District', Icons.place_outlined),
        _field('address', 'Address', Icons.home_outlined),
        Row(children: [
          Expanded(child: _field('mobile', 'Mobile', Icons.phone_outlined)),
          const SizedBox(width: 10),
          Expanded(child: _field('email', 'Email', Icons.email_outlined)),
        ]),
        const SizedBox(height: 14),
        Text('Tax & Income (FBR)', style: display(14)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _field('income', 'Declared income (PKR)', Icons.payments_outlined, num: true)),
          const SizedBox(width: 10),
          Expanded(child: _dropdown('Filer status', _filer, const ['Filer', 'Non-Filer'], (v) => setState(() => _filer = v))),
        ]),
        const SizedBox(height: 14),
        Text('Assets (optional)', style: display(14)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _field('vehicle', 'Vehicle value', Icons.directions_car_outlined, num: true)),
          const SizedBox(width: 10),
          Expanded(child: _field('property', 'Property value', Icons.home_work_outlined, num: true)),
        ]),
        Row(children: [
          Expanded(child: _field('bank', 'Bank balance', Icons.account_balance_outlined, num: true)),
          const SizedBox(width: 10),
          Expanded(child: _field('stock', 'Stock value', Icons.show_chart, num: true)),
        ]),
        const SizedBox(height: 20),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.white, padding: const EdgeInsets.all(14)),
          onPressed: _saving ? null : _save,
          icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
          label: const Text('Create Record'),
        ),
      ]),
    );
  }

  Widget _field(String k, String label, IconData icon, {bool num = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: _ctrl(k),
          keyboardType: num ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 20), border: const OutlineInputBorder(), isDense: true),
        ),
      );

  Widget _dropdown(String label, String value, List<String> items, ValueChanged<String> onChanged) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: DropdownButtonFormField<String>(
          initialValue: value,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => onChanged(v ?? value),
        ),
      );
}

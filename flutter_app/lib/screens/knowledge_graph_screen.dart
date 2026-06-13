import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';
import 'person_detail.dart';
import 'family_tree_screen.dart';

/// Knowledge Graph — clean ego/hub view: a flagged entity at the centre with its
/// connected fronts, relatives and companies radiating around it. Switch between
/// the top flagged evaders with the selector. (Far clearer than a force blob.)
class KnowledgeGraphScreen extends StatefulWidget {
  const KnowledgeGraphScreen({super.key});
  @override
  State<KnowledgeGraphScreen> createState() => _KnowledgeGraphScreenState();
}

class _KnowledgeGraphScreenState extends State<KnowledgeGraphScreen> {
  List<dynamic> _nodes = [];
  List<dynamic> _edges = [];
  final Map<String, dynamic> _byId = {};
  List<String> _hubs = [];
  String? _focus;
  Map<String, dynamic>? _sel;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final n = await Api.network(limit: 16);
      _nodes = n['nodes'] as List;
      _edges = n['edges'] as List;
      _byId.clear();
      for (final nd in _nodes) {
        _byId[nd['id']] = nd;
      }
      // hubs = the most-connected flagged citizens (benami centres)
      final deg = <String, int>{};
      for (final e in _edges) {
        deg[e['source']] = (deg[e['source']] ?? 0) + 1;
        deg[e['target']] = (deg[e['target']] ?? 0) + 1;
      }
      final cits = _nodes.where((n) => n['type'] == 'citizen').toList()
        ..sort((a, b) => (deg[b['id']] ?? 0).compareTo(deg[a['id']] ?? 0));
      _hubs = cits.take(12).map((n) => n['id'] as String).toList();
      _focus = _hubs.isNotEmpty ? _hubs.first : (_nodes.isNotEmpty ? _nodes.first['id'] as String : null);
      setState(() => _err = null);
    } catch (e) {
      setState(() => _err = '$e');
    }
  }

  List<String> _neighbors(String hub) {
    final s = <String>{};
    for (final e in _edges) {
      if (e['source'] == hub) s.add('${e['target']}');
      else if (e['target'] == hub) s.add('${e['source']}');
    }
    return s.where((id) => _byId.containsKey(id)).take(9).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_err != null) {
      return Center(child: FilledButton.icon(onPressed: () { setState(() => _err = null); _load(); }, icon: const Icon(Icons.refresh), label: const Text('Retry')));
    }
    if (_nodes.isEmpty) return const Center(child: CircularProgressIndicator(color: C.green));
    final hub = _focus != null ? _byId[_focus] : null;
    final neigh = _focus != null ? _neighbors(_focus!) : <String>[];
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Eyebrow('Graph Intelligence'),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: Text('Knowledge Graph', style: display(22))),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: C.blue, side: BorderSide(color: C.border), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AllEntitiesScreen())),
              icon: const Icon(Icons.travel_explore, size: 16),
              label: Text('See all', style: body(12, w: FontWeight.w600, c: C.blue)),
            ),
          ]),
          Text('Tap an evader below for their network, or "See all" to browse every flagged citizen', style: body(11, c: C.text3)),
        ]),
      ),
      _hubSelector(),
      Expanded(
        child: Stack(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(AppCtl.dark.value ? 0.05 : 0.30),
                    border: Border.all(color: Colors.white.withOpacity(AppCtl.dark.value ? 0.14 : 0.5)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: LayoutBuilder(builder: (ctx, cons) {
              final view = cons.biggest;
              final center = Offset(view.width / 2, view.height * 0.44);
              final r = math.min(view.width, view.height) * 0.32;
              final pos = <String, Offset>{};
              if (_focus != null) pos[_focus!] = center;
              for (int i = 0; i < neigh.length; i++) {
                final a = 2 * math.pi * i / neigh.length - math.pi / 2;
                pos[neigh[i]] = center + Offset(r * math.cos(a), r * math.sin(a));
              }
              return Stack(children: [
                Positioned.fill(child: CustomPaint(painter: _EgoPainter(_focus, neigh, pos, _byId))),
                if (hub != null) _node(hub, pos[_focus!]!, true),
                ...neigh.map((id) => _node(_byId[id], pos[id]!, false)),
              ]);
            }),
                ),
              ),
            ),
          ),
          if (neigh.isEmpty)
            Center(child: Text('No linked entities for this person.', style: body(12, c: C.text3))),
          if (_sel != null) _nodePanel(_sel!),
        ]),
      ),
    ]);
  }

  Widget _hubSelector() => SizedBox(
        height: 92,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: _hubs.map((id) {
            final n = _byId[id];
            final active = _focus == id;
            final col = C.zone(n['zone']);
            final initials = '${n['label'] ?? ''}'.split(' ').where((s) => s.isNotEmpty).map((s) => s[0]).take(2).join();
            return GestureDetector(
              onTap: () => setState(() { _focus = id; _sel = null; }),
              child: Container(
                width: 92,
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: active ? col.withOpacity(0.16) : Colors.white.withOpacity(AppCtl.dark.value ? 0.07 : 0.45),
                  border: Border.all(color: active ? col : Colors.white.withOpacity(AppCtl.dark.value ? 0.16 : 0.6), width: active ? 1.5 : 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  CircleAvatar(radius: 16, backgroundColor: col.withOpacity(0.16), child: Text(initials, style: display(11, c: col))),
                  const SizedBox(height: 5),
                  Text('${n['label'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: body(10, w: FontWeight.w600)),
                ]),
              ),
            );
          }).toList(),
        ),
      );

  Widget _node(dynamic n, Offset p, bool hub) {
    final isC = n['type'] == 'citizen';
    final col = isC ? C.zone(n['zone']) : C.high;
    final size = hub ? 62.0 : 44.0;
    final selected = _sel?['id'] == n['id'];
    return Positioned(
      left: p.dx - 52,
      top: p.dy - size / 2,
      width: 104,
      child: GestureDetector(
        onTap: () => setState(() => _sel = n),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: size, height: size,
            decoration: BoxDecoration(
              color: col, shape: BoxShape.circle,
              border: Border.all(color: selected ? C.text : Colors.white, width: selected ? 3.5 : 2.5),
              boxShadow: [BoxShadow(color: col.withOpacity(hub ? 0.5 : 0.4), blurRadius: hub ? 16 : 10, spreadRadius: hub ? 2 : 1)],
            ),
            child: Icon(isC ? Icons.person : Icons.business, color: Colors.white, size: size * 0.5),
          ),
          const SizedBox(height: 3),
          Text('${n['label'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: body(hub ? 10.5 : 9.5, w: hub ? FontWeight.w700 : FontWeight.w500, c: C.text2)),
        ]),
      ),
    );
  }

  Widget _nodePanel(dynamic n) {
    final isC = n['type'] == 'citizen';
    final col = isC ? C.zone(n['zone']) : C.high;
    return Positioned(
      left: 16, right: 16, bottom: 16,
      child: GlassCard(
        border: C.border2,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 46, height: 46, decoration: BoxDecoration(color: col.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: col.withOpacity(0.4))), child: Icon(isC ? Icons.person : Icons.business, color: col)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${n['label'] ?? ''}', style: display(15)),
              Text(isC ? '${n['cnic']}' : 'SECP Company', style: mono(11, c: C.text3)),
            ])),
            if (isC) Column(children: [
              Text('${(n['score'] ?? 0).toStringAsFixed(0)}', style: mono(24, w: FontWeight.w700, c: col)),
              Text('deviation', style: body(8.5, c: C.text3)),
            ]),
            IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => setState(() => _sel = null)),
          ]),
          if (isC) ...[
            const SizedBox(height: 6),
            Row(children: [
              Tag('${n['zone']} ZONE', sev: n['zone'] == 'Red' ? 'critical' : n['zone'] == 'Yellow' ? 'med' : 'low'),
              const Spacer(),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 14)),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PersonDetail(cnic: n['cnic'], admin: true))),
                icon: const Icon(Icons.open_in_new, size: 15),
                label: Text('Open profile', style: body(12, w: FontWeight.w600, c: Colors.white)),
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}

class _EgoPainter extends CustomPainter {
  final String? hub;
  final List<String> neigh;
  final Map<String, Offset> pos;
  final Map<String, dynamic> byId;
  _EgoPainter(this.hub, this.neigh, this.pos, this.byId);

  @override
  void paint(Canvas canvas, Size size) {
    final c = hub != null ? pos[hub] : null;
    if (c == null) return;
    for (final id in neigh) {
      final p = pos[id];
      if (p == null) continue;
      final isCompany = byId[id]?['type'] == 'company';
      final paint = Paint()
        ..color = (isCompany ? C.high : C.text2).withOpacity(isCompany ? 0.55 : 0.4)
        ..strokeWidth = isCompany ? 2.0 : 1.4;
      canvas.drawLine(c, p, paint);
    }
  }

  @override
  bool shouldRepaint(_EgoPainter o) => o.hub != hub || o.pos != pos;
}

/// Searchable list of EVERY flagged entity. Tap one to open its full network.
class AllEntitiesScreen extends StatefulWidget {
  const AllEntitiesScreen({super.key});
  @override
  State<AllEntitiesScreen> createState() => _AllEntitiesScreenState();
}

class _AllEntitiesScreenState extends State<AllEntitiesScreen> {
  final _qc = TextEditingController();
  List<dynamic> _people = [];
  bool _loading = true;
  String _q = '';
  Timer? _deb;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _deb?.cancel();
    _qc.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await Api.persons(q: _q.isEmpty ? null : _q, limit: 80);
      setState(() {
        _people = (r['results'] as List?) ?? [];
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _onSearch(String v) {
    _q = v.trim();
    _deb?.cancel();
    _deb = Timer(const Duration(milliseconds: 350), _load);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All Entities'), backgroundColor: C.bg2, foregroundColor: C.text, elevation: 0.5),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: Row(children: [
              Icon(Icons.search, color: C.text3, size: 20),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: _qc, onChanged: _onSearch, decoration: const InputDecoration(border: InputBorder.none, hintText: 'Search any CNIC or name…'))),
            ]),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: C.green))
              : _people.isEmpty
                  ? Center(child: Text('No matching entities.', style: body(13, c: C.text3)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                      itemCount: _people.length,
                      itemBuilder: (_, i) {
                        final p = _people[i];
                        final zone = '${p['zone'] ?? ''}';
                        final sev = zone == 'Red' ? 'critical' : zone == 'Yellow' ? 'high' : 'low';
                        final dev = (p['deviation_score'] ?? 0) as num;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FamilyTreeScreen(cnic: p['cnic']))),
                            child: GlassCard(
                              child: Row(children: [
                                Container(width: 44, height: 44, decoration: BoxDecoration(color: C.zone(zone).withOpacity(0.14), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.account_tree, color: C.zone(zone))),
                                const SizedBox(width: 12),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('${p['name']}', style: body(13.5, w: FontWeight.w700)),
                                  Text('${p['cnic']} · ${p['district'] ?? ''}', style: mono(10.5, c: C.text3)),
                                ])),
                                if (zone.isNotEmpty && zone != '-') Tag(zone.toUpperCase(), sev: sev),
                                const SizedBox(width: 10),
                                Text('${dev.toInt()}', style: mono(18, w: FontWeight.w700, c: C.zone(zone))),
                                Icon(Icons.chevron_right, color: C.text3),
                              ]),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}

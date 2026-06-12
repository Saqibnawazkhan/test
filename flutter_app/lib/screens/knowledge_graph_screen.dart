import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';
import 'person_detail.dart';

/// Knowledge Graph — full multi-entity intelligence network (force-directed).
class KnowledgeGraphScreen extends StatefulWidget {
  const KnowledgeGraphScreen({super.key});
  @override
  State<KnowledgeGraphScreen> createState() => _KnowledgeGraphScreenState();
}

const double _cv = 1500; // layout canvas

class _KnowledgeGraphScreenState extends State<KnowledgeGraphScreen> {
  List<dynamic> _nodes = [];
  List<dynamic> _edges = [];
  final Map<String, dynamic> _byId = {};
  final Map<String, Offset> _pos = {};
  Map<String, dynamic>? _sel;
  String _filter = 'all';
  String? _err;
  final TransformationController _tc = TransformationController();
  bool _fitted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  /// centre + scale the viewport so the whole network is visible on first show
  void _fit(Size view) {
    if (_pos.isEmpty || view.width < 10) return;
    final xs = _pos.values.map((p) => p.dx);
    final ys = _pos.values.map((p) => p.dy);
    final minX = xs.reduce(math.min), maxX = xs.reduce(math.max);
    final minY = ys.reduce(math.min), maxY = ys.reduce(math.max);
    final bw = (maxX - minX) + 160, bh = (maxY - minY) + 200;
    final cx = (minX + maxX) / 2, cy = (minY + maxY) / 2;
    final scale = math.min(view.width / bw, view.height / bh).clamp(0.12, 1.2);
    _tc.value = Matrix4.identity()
      ..translate(view.width / 2 - scale * cx, view.height / 2 - scale * cy)
      ..scale(scale);
  }

  Future<void> _load() async {
    try {
      final n = await Api.network(limit: 40);
      _nodes = n['nodes'] as List;
      _edges = n['edges'] as List;
      _byId.clear();
      for (final nd in _nodes) {
        _byId[nd['id']] = nd;
      }
      _layout();
      _fitted = false;
      setState(() => _err = null);
    } catch (e) {
      setState(() => _err = '$e');
    }
  }

  /// simple Fruchterman–Reingold force-directed layout, run once
  void _layout() {
    final rnd = math.Random(42);
    final ids = _nodes.map((n) => n['id'] as String).toList();
    for (final id in ids) {
      _pos[id] = Offset(_cv / 2 + rnd.nextDouble() * 500 - 250, _cv / 2 + rnd.nextDouble() * 500 - 250);
    }
    const k = 95.0;
    for (int it = 0; it < 320; it++) {
      final disp = <String, Offset>{for (final id in ids) id: Offset.zero};
      for (int i = 0; i < ids.length; i++) {
        for (int j = i + 1; j < ids.length; j++) {
          var d = _pos[ids[i]]! - _pos[ids[j]]!;
          var dist = d.distance.clamp(0.01, 2000).toDouble();
          final f = (k * k) / dist;
          final dir = d / dist;
          disp[ids[i]] = disp[ids[i]]! + dir * f;
          disp[ids[j]] = disp[ids[j]]! - dir * f;
        }
      }
      for (final e in _edges) {
        final s = e['source'], t = e['target'];
        if (_pos[s] == null || _pos[t] == null) continue;
        var d = _pos[s]! - _pos[t]!;
        var dist = d.distance.clamp(0.01, 2000).toDouble();
        final f = (dist * dist) / k;
        final dir = d / dist;
        disp[s] = disp[s]! - dir * f;
        disp[t] = disp[t]! + dir * f;
      }
      final temp = 34.0 * (1 - it / 320);
      for (final id in ids) {
        final dp = disp[id]!;
        final dist = dp.distance.clamp(0.01, 2000).toDouble();
        _pos[id] = _pos[id]! + dp / dist * math.min(dist, temp);
      }
    }
    // recentre to canvas
    final xs = _pos.values.map((p) => p.dx);
    final ys = _pos.values.map((p) => p.dy);
    final cx = (xs.reduce(math.min) + xs.reduce(math.max)) / 2;
    final cy = (ys.reduce(math.min) + ys.reduce(math.max)) / 2;
    final shift = Offset(_cv / 2 - cx, _cv / 2 - cy);
    _pos.updateAll((_, p) => p + shift);
  }

  bool _visible(dynamic nd) {
    if (_filter == 'all') return true;
    if (_filter == 'company') return nd['type'] == 'company';
    return nd['type'] == 'citizen' && nd['zone'] == _filter;
  }

  @override
  Widget build(BuildContext context) {
    if (_err != null) {
      return Center(child: FilledButton.icon(onPressed: () { setState(() => _err = null); _load(); }, icon: const Icon(Icons.refresh), label: const Text('Retry')));
    }
    if (_nodes.isEmpty) return const Center(child: CircularProgressIndicator(color: C.green));
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Eyebrow('Graph Intelligence'),
          const SizedBox(height: 6),
          Row(children: [
            Text('Knowledge Graph', style: display(22)),
            const Spacer(),
            Text('${_nodes.length} nodes · ${_edges.length} links', style: mono(10.5, c: C.text3)),
          ]),
          Text('National network · flagged citizens, family fronts & companies', style: body(11.5, c: C.text3)),
        ]),
      ),
      SizedBox(
        height: 44,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
          _chip('all', 'All', C.text2),
          _chip('Red', 'High Risk', C.critical),
          _chip('Yellow', 'Medium', C.med),
          _chip('Green', 'Linked (fronts)', C.low),
          _chip('company', 'Companies', C.high),
        ]),
      ),
      Expanded(
        child: Stack(children: [
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(gradient: const RadialGradient(center: Alignment.center, radius: 0.95, colors: [C.bg2, C.bg1]), border: Border.all(color: C.border), borderRadius: BorderRadius.circular(14)),
            clipBehavior: Clip.antiAlias,
            child: LayoutBuilder(builder: (ctx, cons) {
              if (!_fitted && _pos.isNotEmpty) {
                _fitted = true;
                WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _fit(cons.biggest); });
              }
              return InteractiveViewer(
                transformationController: _tc,
                constrained: false,
                boundaryMargin: const EdgeInsets.all(600),
                minScale: 0.1,
                maxScale: 3,
                child: SizedBox(
                  width: _cv, height: _cv,
                  child: Stack(children: [
                    Positioned.fill(child: CustomPaint(painter: _NetPainter(_edges, _pos, _byId, _filter, _visible))),
                    ..._nodes.map(_nodeWidget),
                  ]),
                ),
              );
            }),
          ),
          Positioned(left: 26, top: 26, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: C.bg1.withOpacity(0.8), borderRadius: BorderRadius.circular(8)), child: Text('drag · pinch · tap to inspect', style: mono(10, c: C.text3)))),
          if (_sel != null) _nodePanel(_sel!),
        ]),
      ),
    ]);
  }

  Widget _chip(String id, String label, Color c) {
    final active = _filter == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _filter = id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(color: active ? c.withOpacity(0.14) : C.bg2, border: Border.all(color: active ? c : C.border), borderRadius: BorderRadius.circular(9)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(label, style: body(12, w: FontWeight.w500, c: active ? c : C.text2)),
          ]),
        ),
      ),
    );
  }

  Widget _nodeWidget(dynamic nd) {
    final p = _pos[nd['id']]!;
    final isC = nd['type'] == 'citizen';
    final col = isC ? C.zone(nd['zone']) : C.high;
    final score = (nd['score'] ?? 0).toDouble();
    final size = isC ? (26.0 + score / 100 * 20) : 36.0;
    final selected = _sel?['id'] == nd['id'];
    final vis = _visible(nd);
    return Positioned(
      left: p.dx - 50,
      top: p.dy - size / 2,
      width: 100,
      child: Opacity(
        opacity: vis ? 1 : 0.16,
        child: GestureDetector(
          onTap: () => setState(() => _sel = nd),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: size, height: size,
              decoration: BoxDecoration(
                color: C.bg2, shape: BoxShape.circle,
                border: Border.all(color: selected ? C.text : col, width: selected ? 3 : 2),
                boxShadow: [BoxShadow(color: col.withOpacity(0.34), blurRadius: 12, spreadRadius: -2)],
              ),
              child: Icon(isC ? Icons.person : Icons.business, color: col, size: size * 0.46),
            ),
            const SizedBox(height: 3),
            Text(nd['label'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: body(8.5, c: C.text2)),
          ]),
        ),
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
              Text(n['label'] ?? '', style: display(15)),
              Text(isC ? n['cnic'] : 'SECP Company', style: mono(11, c: C.text3)),
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

class _NetPainter extends CustomPainter {
  final List<dynamic> edges;
  final Map<String, Offset> pos;
  final Map<String, dynamic> byId;
  final String filter;
  final bool Function(dynamic) visible;
  _NetPainter(this.edges, this.pos, this.byId, this.filter, this.visible);

  @override
  void paint(Canvas canvas, Size size) {
    for (final e in edges) {
      final a = pos[e['source']], b = pos[e['target']];
      if (a == null || b == null) continue;
      final on = filter == 'all' || (visible(byId[e['source']]) && visible(byId[e['target']]));
      final director = e['rel'] == 'DIRECTOR_OF';
      final col = (director ? C.high : C.text3).withOpacity(on ? (director ? 0.5 : 0.28) : 0.06);
      canvas.drawLine(a, b, Paint()..color = col..strokeWidth = director ? 1.6 : 1.0);
    }
  }

  @override
  bool shouldRepaint(_NetPainter o) => o.filter != filter || o.pos != pos;
}

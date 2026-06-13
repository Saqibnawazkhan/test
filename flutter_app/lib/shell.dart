import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'theme.dart';
import 'api.dart';
import 'screens/dashboard_screen.dart';
import 'screens/knowledge_graph_screen.dart';
import 'screens/investigation_screens.dart';
import 'screens/chat_screen.dart';
import 'screens/pos_screen.dart';
import 'screens/admin_payments_screen.dart';
import 'screens/admin_records_screen.dart';
import 'screens/ops_screens.dart';
import 'screens/notifications_screen.dart';
import 'screens/admin_inbox.dart';
import 'search.dart';

/// The TaxNet AI admin shell — sidebar drawer + topbar + module routing.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _Module {
  final String id, label;
  final IconData icon;
  final String? badge;
  const _Module(this.id, this.label, this.icon, [this.badge]);
}

const _modules = [
  _Module('dashboard', 'Dashboard', Icons.dashboard_outlined),
  _Module('records', 'All Records', Icons.groups_outlined),
  _Module('graph', 'Knowledge Graph', Icons.hub_outlined),
  _Module('entity', 'Entity Resolution', Icons.account_tree_outlined),
  _Module('risk', 'Risk Analysis', Icons.speed_outlined),
  _Module('audit', 'Audit Trail', Icons.fact_check_outlined, '14'),
  _Module('pos', 'POS Verification', Icons.qr_code_scanner_outlined),
  _Module('payments', 'Tax Payments', Icons.payments_outlined),
  _Module('analytics', 'Reports', Icons.bar_chart_outlined),
  _Module('leaderboard', 'Leaderboard', Icons.leaderboard_outlined),
  _Module('inbox', 'Citizen Inbox', Icons.move_to_inbox_outlined),
  _Module('settings', 'Settings', Icons.settings_outlined),
];

class _AdminShellState extends State<AdminShell> {
  int _i = 0;

  void _go(int i) => setState(() => _i = i);

  @override
  Widget build(BuildContext context) {
    final m = _modules[_i];
    final topPad = MediaQuery.of(context).padding.top + kToolbarHeight;
    return Scaffold(
      drawer: _drawer(),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        titleSpacing: 4,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(AppCtl.dark.value ? 0.06 : 0.55),
                border: Border(bottom: BorderSide(color: C.border)),
              ),
            ),
          ),
        ),
        title: Row(children: [
          Text('TaxNet ', style: mono(12, c: C.text3)),
          Text('/ ${t(m.label)}', style: mono(12, c: C.text)),
        ]),
        actions: [
          const NotificationBell(recipient: 'admin'),
          Padding(
            padding: const EdgeInsets.only(right: 10, left: 2),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: const Color(0xFF08130E), padding: const EdgeInsets.symmetric(horizontal: 12)),
              onPressed: _openCopilot,
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: Text('AI', style: body(12, w: FontWeight.w700, c: const Color(0xFF08130E))),
            ),
          ),
        ],
      ),
      body: GlowBackground(
        child: Column(children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, topPad + 8, 16, 2),
            child: GestureDetector(
              onTap: _openSearch,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(AppCtl.dark.value ? 0.07 : 0.5), border: Border.all(color: Colors.white.withOpacity(AppCtl.dark.value ? 0.16 : 0.55)), borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: Color(0x10101926), blurRadius: 10, offset: Offset(0, 3))],
                    ),
                    child: Row(children: [
                      Icon(Icons.search, size: 20, color: C.text3),
                      const SizedBox(width: 12),
                      Expanded(child: Text(t('Search CNIC, name, property, vehicle…'), style: body(13.5, c: C.text3))),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(border: Border.all(color: C.border), borderRadius: BorderRadius.circular(5)), child: Text('GO', style: mono(10, c: C.text3))),
                    ]),
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: _moduleBody(m.id)),
        ]),
      ),
    );
  }

  Widget _moduleBody(String id) {
    switch (id) {
      case 'dashboard':
        return DashboardScreen(go: _go, onSearch: _openSearch);
      case 'records':
        return const AllRecordsScreen();
      case 'graph':
        return const KnowledgeGraphScreen();
      case 'entity':
        return const EntityResolutionScreen();
      case 'risk':
        return const RiskAnalysisScreen();
      case 'audit':
        return const AuditTrailScreen();
      case 'pos':
        return const POSVerifyScreen();
      case 'payments':
        return const AdminPaymentsScreen();
      case 'analytics':
        return const AnalyticsScreen2();
      case 'leaderboard':
        return const ReportsScreen();
      case 'inbox':
        return const AdminInbox();
      case 'settings':
        return const SettingsScreen();
      default:
        return _ComingSoon(module: _modules[_i]);
    }
  }

  // ---- drawer (sidebar) ----
  Widget _drawer() => Drawer(
        width: 264,
        backgroundColor: C.bg1,
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              child: Row(children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [C.green, C.blue]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.hub, color: Color(0xFF04070D), size: 20),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [Text('Tax', style: display(18)), Text('Net', style: display(18, c: C.green)), Text(' AI', style: display(18))]),
                  Text('FBR INTELLIGENCE', style: mono(9, c: C.text3, ls: 1.6)),
                ]),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
              child: Align(alignment: Alignment.centerLeft, child: Text('MODULES', style: mono(10, c: C.text3, ls: 1.6))),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (int i = 0; i < _modules.length; i++) _navItem(i),
                ],
              ),
            ),
            Divider(color: C.border, height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [C.blue, C.violet]), borderRadius: BorderRadius.circular(9)),
                  child: Center(child: Text('SI', style: body(12, w: FontWeight.w700, c: Colors.white))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('S. Investigator', style: body(13, w: FontWeight.w600)),
                    Text('Tier 3 · FBR HQ', style: body(10.5, c: C.text3)),
                  ]),
                ),
                IconButton(
                  icon: Icon(Icons.logout, size: 16, color: C.text3),
                  onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                ),
              ]),
            ),
          ]),
        ),
      );

  Widget _navItem(int i) {
    final m = _modules[i];
    final active = i == _i;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        _go(i);
        Navigator.pop(context);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: active ? C.panel2 : Colors.transparent,
          border: Border.all(color: active ? C.border : Colors.transparent),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Icon(m.icon, size: 18, color: active ? C.green : C.text2),
          const SizedBox(width: 12),
          Text(t(m.label), style: body(13.5, w: FontWeight.w500, c: active ? C.text : C.text2)),
          const Spacer(),
          if (m.badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(color: C.critical.withOpacity(0.16), borderRadius: BorderRadius.circular(20)),
              child: Text(m.badge!, style: mono(10, w: FontWeight.w600, c: C.critical)),
            ),
        ]),
      ),
    );
  }

  // ---- topbar actions ----
  void _openSearch() => showSearch(context: context, delegate: EntitySearch());

  void _openCopilot() {
    // Real grounded assistant (replaces the old scripted sheet).
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen(title: 'AI Copilot')));
  }
}

/// On-brand placeholder for modules still being built out (Phase 4-5).
class _ComingSoon extends StatelessWidget {
  final _Module module;
  const _ComingSoon({required this.module});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(16, 20, 16, 60), children: [
        PageHeader(module.label.toUpperCase(), module.label, desc: 'This module is being wired to the live graph engine.'),
        GlassCard(
          child: Column(children: [
            Icon(module.icon, size: 40, color: C.green),
            const SizedBox(height: 12),
            Text('${module.label} — coming online', style: display(15)),
            const SizedBox(height: 6),
            Text('Full ${module.label.toLowerCase()} view ships in the next build.', style: body(12, c: C.text2), textAlign: TextAlign.center),
          ]),
        ),
      ]);
}

// ---- AI Copilot bottom sheet (scripted, like the website) ----
class CopilotSheet extends StatefulWidget {
  const CopilotSheet({super.key});
  @override
  State<CopilotSheet> createState() => _CopilotSheetState();
}

class _CopilotSheetState extends State<CopilotSheet> {
  final _msgs = <(bool, String)>[(false, 'Assalam-o-Alaikum. I am the TaxNet investigation copilot. Ask me about any citizen, cluster or compliance trend.')];
  final _ctrl = TextEditingController();

  void _send([String? text]) {
    final t = (text ?? _ctrl.text).trim();
    if (t.isEmpty) return;
    setState(() {
      _msgs.add((true, t));
      _ctrl.clear();
      final reply = RegExp('flag|critical|new', caseSensitive: false).hasMatch(t)
          ? 'I found 14 newly-flagged Critical entities in the last hour, concentrated in Lahore and Karachi. Top recovery opportunity ≈ ₨41.2M.'
          : RegExp('recover|leak|revenue', caseSensitive: false).hasMatch(t)
              ? 'Estimated national recovery potential across all flagged entities is ₨1.71T. Punjab accounts for ~41% of the leakage.'
              : 'Based on the graph, this entity shows a compliance deviation driven by an income–lifestyle mismatch. Shall I draft a Section 122(5A) notice?';
      _msgs.add((false, reply));
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [C.green, C.blue]), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.auto_awesome, color: Color(0xFF04070D), size: 18),
              ),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('TaxNet Copilot', style: display(15)),
                Text('online · GNN v4.2', style: body(10.5, c: C.green)),
              ]),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
            ]),
          ),
          Divider(color: C.border, height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: _msgs
                  .map((m) => Align(
                        alignment: m.$1 ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                          decoration: BoxDecoration(
                            color: m.$1 ? C.blue : C.panel2,
                            border: m.$1 ? null : Border.all(color: C.border),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(m.$2, style: body(13, c: m.$1 ? Colors.white : C.text)),
                        ),
                      ))
                  .toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: Wrap(spacing: 7, children: [
              for (final c in ['Show new flags', 'Recovery potential', 'Explain a case'])
                ActionChip(label: Text(c, style: body(11.5, c: C.text2)), backgroundColor: C.panel, side: BorderSide(color: C.border), onPressed: () => _send(c)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  style: body(13),
                  onSubmitted: _send,
                  decoration: InputDecoration(
                    hintText: 'Ask the copilot…',
                    hintStyle: body(13, c: C.text3),
                    filled: true, fillColor: C.panel,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: C.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: C.border)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(style: IconButton.styleFrom(backgroundColor: C.green), onPressed: () => _send(), icon: const Icon(Icons.send, size: 18, color: Color(0xFF04070D))),
            ]),
          ),
        ]),
      ),
    );
  }
}


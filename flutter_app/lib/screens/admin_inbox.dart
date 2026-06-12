import 'package:flutter/material.dart';
import '../api.dart';
import '../supa.dart';
import '../theme.dart';

/// Admin inbox — live citizen submissions (requests, declarations, issues) + broadcast announcements.
class AdminInbox extends StatelessWidget {
  const AdminInbox({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(children: [
            const Expanded(child: PageHeader('Citizen Submissions', 'Inbox', desc: 'Live requests, declarations and disputes from citizens.')),
          ]),
        ),
        const TabBar(
          labelColor: C.green, unselectedLabelColor: C.text3, indicatorColor: C.green,
          tabs: [Tab(text: 'Requests'), Tab(text: 'Declarations'), Tab(text: 'Issues')],
        ),
        Expanded(
          child: TabBarView(children: [
            _StreamList(
              stream: Supa.requests(),
              title: (r) => '${r['name'] ?? r['cnic']}',
              subtitle: (r) => 'Field: ${r['field']}\n“${r['current_value'] ?? ''}” → “${r['requested_value']}”${(r['reason'] ?? '').toString().isNotEmpty ? '\nReason: ${r['reason']}' : ''}',
              onApprove: (r) => Supa.resolveRequest(r['id'], r['cnic'], r['name'], 'Approved'),
              onReject: (r) => Supa.resolveRequest(r['id'], r['cnic'], r['name'], 'Rejected'),
              approveLabel: 'Approve', rejectLabel: 'Reject',
            ),
            _StreamList(
              stream: Supa.declarations(),
              title: (r) => '${r['name'] ?? r['cnic']}',
              subtitle: (r) => '${r['asset_type']} · ${rs(r['value'])}\n${r['description'] ?? ''}',
              onApprove: (r) async {
                // persist the asset into the record + recompute the score (throws if backend down)
                await Api.approveDeclaration(
                  r['cnic'], r['asset_type'] ?? 'Other', r['description'] ?? '', (r['value'] ?? 0) as num,
                  details: r['details'] == null ? null : Map<String, dynamic>.from(r['details'] as Map),
                  declId: r['id'] as int?,
                );
                // only mark approved + notify once the asset is actually written
                await Supa.resolveDeclaration(r['id'], r['cnic'], r['name'], 'Approved');
              },
              onReject: (r) => Supa.resolveDeclaration(r['id'], r['cnic'], r['name'], 'Rejected'),
              approveLabel: 'Accept', rejectLabel: 'Reject',
            ),
            _StreamList(
              stream: Supa.issues(),
              title: (r) => '${r['name'] ?? r['cnic']}',
              subtitle: (r) => '${r['category']}\n${r['description'] ?? ''}',
              onApprove: (r) => Supa.resolveIssue(r['id'], r['cnic'], r['name'], 'Resolved'),
              onReject: (r) => Supa.resolveIssue(r['id'], r['cnic'], r['name'], 'Rejected'),
              approveLabel: 'Resolve', rejectLabel: 'Reject',
              pendingStatus: 'Open',
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: C.blue, foregroundColor: Colors.white, padding: const EdgeInsets.all(13)),
              onPressed: () => _announce(context),
              icon: const Icon(Icons.campaign),
              label: Text('Broadcast announcement to all citizens', style: body(13, w: FontWeight.w600, c: Colors.white)),
            ),
          ),
        ),
      ]),
    );
  }

  void _announce(BuildContext context) {
    final title = TextEditingController(text: 'Early-payment rebate');
    final bodyC = TextEditingController(text: 'Pay your tax before 20 June 2026 and get 20% off. — FBR');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: C.bg2,
        title: Text('New announcement', style: display(15)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
          TextField(controller: bodyC, maxLines: 3, decoration: const InputDecoration(labelText: 'Message')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              await Supa.announce(title.text, bodyC.text);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Announcement broadcast to all citizens.')));
              }
            },
            child: const Text('Broadcast'),
          ),
        ],
      ),
    );
  }
}

class _StreamList extends StatefulWidget {
  final Stream<List<Map<String, dynamic>>> stream;
  final String Function(Map<String, dynamic>) title, subtitle;
  final Future<void> Function(Map<String, dynamic>) onApprove, onReject;
  final String approveLabel, rejectLabel, pendingStatus;
  const _StreamList({
    required this.stream, required this.title, required this.subtitle,
    required this.onApprove, required this.onReject,
    this.approveLabel = 'Approve', this.rejectLabel = 'Reject', this.pendingStatus = 'Pending',
  });

  @override
  State<_StreamList> createState() => _StreamListState();
}

class _StreamListState extends State<_StreamList> {
  final Set<Object> _busy = {}; // row ids currently being actioned (blocks double-clicks)

  @override
  Widget build(BuildContext context) {
    Future<void> act(Future<void> Function(Map<String, dynamic>) fn, Map<String, dynamic> r) async {
      final id = r['id'] as Object? ?? r;
      if (_busy.contains(id)) return; // already processing this row
      setState(() => _busy.add(id));
      try {
        await fn(r);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Action failed — is the backend running? (restart it for declarations)')),
          );
        }
      } finally {
        if (mounted) setState(() => _busy.remove(id));
      }
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: widget.stream,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: C.green));
        }
        final items = snap.data ?? [];
        if (items.isEmpty) return Center(child: Text('Nothing here yet.', style: body(13, c: C.text3)));
        return ListView(
          padding: const EdgeInsets.all(16),
          children: items.map((r) {
            final status = r['status'] ?? widget.pendingStatus;
            final pending = status == widget.pendingStatus;
            final busy = _busy.contains(r['id'] as Object? ?? r);
            final col = status == 'Approved' || status == 'Resolved' ? C.low : status == 'Rejected' ? C.critical : C.high;
            return GlassCard(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(widget.title(r), style: body(13.5, w: FontWeight.w700))),
                  Tag(status.toString().toUpperCase(), sev: col == C.low ? 'low' : col == C.critical ? 'critical' : 'high'),
                ]),
                const SizedBox(height: 6),
                Text(widget.subtitle(r), style: body(12.5, c: C.text2)),
                if ((r['proof_url'] ?? '').toString().isNotEmpty)
                  Padding(padding: const EdgeInsets.only(top: 6), child: Row(children: [const Icon(Icons.attach_file, size: 14, color: C.blue), const SizedBox(width: 5), Text('Proof attached', style: body(11.5, c: C.blue))])),
                if (pending) ...[
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(onPressed: busy ? null : () => act(widget.onReject, r), child: Text(widget.rejectLabel, style: body(13, c: busy ? C.text3 : C.critical))),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.white),
                      onPressed: busy ? null : () => act(widget.onApprove, r),
                      child: busy
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(widget.approveLabel),
                    ),
                  ]),
                ],
              ]),
            );
          }).toList(),
        );
      },
    );
  }
}

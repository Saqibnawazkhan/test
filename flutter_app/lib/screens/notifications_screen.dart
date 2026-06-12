import 'package:flutter/material.dart';
import '../supa.dart';
import '../theme.dart';
import 'admin_inbox.dart';
import 'admin_payments_screen.dart';

IconData _kindIcon(String? k) {
  switch (k) {
    case 'request': return Icons.inbox;
    case 'approved': return Icons.check_circle;
    case 'rejected': return Icons.cancel;
    case 'payment': return Icons.payments;
    case 'announcement': return Icons.campaign;
    default: return Icons.notifications;
  }
}

Color _kindColor(String? k) {
  switch (k) {
    case 'approved': return C.low;
    case 'rejected': return C.critical;
    case 'payment': return C.green;
    case 'announcement': return C.blue;
    case 'request': return C.high;
    default: return C.text3;
  }
}

/// Bell with a live unread badge -> opens NotificationsScreen.
class NotificationBell extends StatelessWidget {
  final String recipient;
  const NotificationBell({required this.recipient, super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supa.notifications(recipient),
      builder: (_, snap) {
        final unread = (snap.data ?? []).where((n) => n['read'] != true).length;
        return Stack(clipBehavior: Clip.none, children: [
          IconButton(
            icon: const Icon(Icons.notifications_none, size: 22),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationsScreen(recipient: recipient))),
          ),
          if (unread > 0)
            Positioned(
              right: 6, top: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: C.critical, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.bg2, width: 1.5)),
                constraints: const BoxConstraints(minWidth: 16),
                child: Text('$unread', textAlign: TextAlign.center, style: mono(9, w: FontWeight.w700, c: Colors.white)),
              ),
            ),
        ]);
      },
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  final String recipient;
  const NotificationsScreen({required this.recipient, super.key});

  bool get _isAdmin => recipient == 'admin';

  /// Mark read + jump to the relevant place based on the notification type.
  Future<void> _open(BuildContext context, Map<String, dynamic> n) async {
    if (n['read'] != true) await Supa.markRead(n['id'] as int);
    if (!context.mounted) return;
    final title = '${n['title'] ?? ''}'.toLowerCase();
    final kind = '${n['kind'] ?? ''}';
    void go(Widget body, String t) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: Text(t)), body: body)));
    if (_isAdmin) {
      if (title.contains('correction')) {
        go(const AdminInbox(initialTab: 0), 'Citizen Submissions');
      } else if (title.contains('declaration')) {
        go(const AdminInbox(initialTab: 1), 'Citizen Submissions');
      } else if (title.contains('explanation')) {
        go(const AdminInbox(initialTab: 2), 'Citizen Submissions');
      } else if (title.contains('issue')) {
        go(const AdminInbox(initialTab: 3), 'Citizen Submissions');
      } else if (kind == 'payment' || title.contains('payment')) {
        go(const AdminPaymentsScreen(), 'Tax Payments');
      }
      // announcements: no destination
    } else {
      // citizen: the relevant section (payments, declarations, requests…) lives on the
      // dashboard — return there. Announcements stay (already shown in the card).
      if (kind != 'announcement' && kind != 'info') Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Supa.notifications(recipient),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: C.green));
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return Center(child: Text('No notifications yet.', style: body(13, c: C.text3)));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final n = items[i];
              final col = _kindColor(n['kind']);
              final unread = n['read'] != true;
              return GestureDetector(
                onTap: () => _open(context, n),
                child: GlassCard(
                  padding: const EdgeInsets.all(14),
                  border: unread ? col.withOpacity(0.4) : C.border,
                  child: Row(children: [
                    Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(color: col.withOpacity(0.13), borderRadius: BorderRadius.circular(10)),
                      child: Icon(_kindIcon(n['kind']), size: 18, color: col),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(n['title'] ?? '', style: body(13.5, w: FontWeight.w600)),
                      if ((n['body'] ?? '').toString().isNotEmpty)
                        Text(n['body'], style: body(12, c: C.text2)),
                      Text(_ago(n['created_at']), style: mono(10, c: C.text3)),
                    ])),
                    if (unread) Container(width: 8, height: 8, decoration: const BoxDecoration(color: C.critical, shape: BoxShape.circle)),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _ago(dynamic ts) {
    if (ts == null) return '';
    try {
      final d = DateTime.parse(ts.toString()).toLocal();
      final diff = DateTime.now().difference(d);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }
}

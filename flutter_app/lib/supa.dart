import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';

/// Supabase service — realtime notifications, requests, declarations, issues,
/// payments + proof-document storage. The live (user-generated) layer.
class Supa {
  static SupabaseClient get _c => Supabase.instance.client;

  static Future<void> init() async {
    await Supabase.initialize(url: Config.supabaseUrl, anonKey: Config.supabaseAnonKey);
  }

  // ---------------- notifications ----------------
  static Future<void> notify({
    required String recipient, // 'admin' or a CNIC
    String audience = 'citizen',
    required String title,
    String body = '',
    String kind = 'info',
    int? refId,
  }) async {
    await _c.from('notifications').insert({
      'recipient': recipient, 'audience': audience, 'title': title,
      'body': body, 'kind': kind, if (refId != null) 'ref_id': refId,
    });
  }

  /// Live stream of notifications for a recipient (+ broadcast 'all').
  static Stream<List<Map<String, dynamic>>> notifications(String recipient) =>
      _c.from('notifications').stream(primaryKey: ['id']).order('created_at', ascending: false).map(
            (rows) => rows.where((n) => n['recipient'] == recipient || n['audience'] == 'all').toList(),
          );

  static Future<void> markRead(int id) async =>
      _c.from('notifications').update({'read': true}).eq('id', id);

  static Future<void> announce(String title, String body) =>
      notify(recipient: 'all', audience: 'all', title: title, body: body, kind: 'announcement');

  // ---------------- correction requests ----------------
  static Future<void> createRequest({
    required String cnic, String? name, required String field,
    String current = '', required String requested, String reason = '', String? proofUrl,
  }) async {
    final res = await _c.from('correction_requests').insert({
      'cnic': cnic, 'name': name, 'field': field, 'current_value': current,
      'requested_value': requested, 'reason': reason, 'proof_url': proofUrl,
    }).select('id').single();
    await notify(recipient: 'admin', audience: 'admin', kind: 'request',
        title: 'Correction request', body: '${name ?? cnic} → change "$field"', refId: res['id'] as int);
  }

  static Future<void> resolveRequest(int id, String cnic, String? name, String decision) async {
    await _c.from('correction_requests').update({'status': decision}).eq('id', id);
    await notify(recipient: cnic, kind: decision.toLowerCase(),
        title: 'Correction $decision', body: 'Your correction request was $decision by FBR.', refId: id);
  }

  static Stream<List<Map<String, dynamic>>> requests({String? cnic}) {
    final s = _c.from('correction_requests').stream(primaryKey: ['id']).order('created_at', ascending: false);
    return cnic == null ? s : s.map((r) => r.where((x) => x['cnic'] == cnic).toList());
  }

  // ---------------- asset declarations ----------------
  static Future<void> declareAsset({
    required String cnic, String? name, required String assetType,
    String description = '', num? value, String? proofUrl, Map<String, dynamic>? details,
  }) async {
    final res = await _c.from('asset_declarations').insert({
      'cnic': cnic, 'name': name, 'asset_type': assetType, 'description': description,
      'value': value, 'proof_url': proofUrl, 'details': details,
    }).select('id').single();
    await notify(recipient: 'admin', audience: 'admin', kind: 'request',
        title: 'Asset declaration', body: '${name ?? cnic} declared a $assetType', refId: res['id'] as int);
  }

  static Future<void> resolveDeclaration(int id, String cnic, String? name, String decision) async {
    await _c.from('asset_declarations').update({'status': decision}).eq('id', id);
    await notify(recipient: cnic, kind: decision.toLowerCase(),
        title: 'Declaration $decision', body: 'Your asset declaration was $decision.', refId: id);
  }

  static Stream<List<Map<String, dynamic>>> declarations({String? cnic}) {
    final s = _c.from('asset_declarations').stream(primaryKey: ['id']).order('created_at', ascending: false);
    return cnic == null ? s : s.map((r) => r.where((x) => x['cnic'] == cnic).toList());
  }

  // ---------------- issue reports ----------------
  static Future<void> reportIssue({
    required String cnic, String? name, required String category,
    String description = '', String? proofUrl,
  }) async {
    final res = await _c.from('issue_reports').insert({
      'cnic': cnic, 'name': name, 'category': category, 'description': description, 'proof_url': proofUrl,
    }).select('id').single();
    await notify(recipient: 'admin', audience: 'admin', kind: 'request',
        title: 'Issue reported', body: '${name ?? cnic}: $category', refId: res['id'] as int);
  }

  static Stream<List<Map<String, dynamic>>> issues({String? cnic}) {
    final s = _c.from('issue_reports').stream(primaryKey: ['id']).order('created_at', ascending: false);
    return cnic == null ? s : s.map((r) => r.where((x) => x['cnic'] == cnic).toList());
  }

  static Future<void> resolveIssue(int id, String cnic, String? name, String decision) async {
    await _c.from('issue_reports').update({'status': decision}).eq('id', id);
    await notify(recipient: cnic, kind: decision == 'Resolved' ? 'approved' : 'rejected',
        title: 'Issue $decision', body: 'Your reported issue was $decision by FBR.', refId: id);
  }

  // ---------------- payments ----------------
  static Future<int> createPayment({required String cnic, String? name, required num amount, String method = 'card'}) async {
    final res = await _c.from('payments').insert({
      'cnic': cnic, 'name': name, 'amount': amount, 'method': method, 'status': 'Paid',
      'reference': 'TXN-${DateTime.now().millisecondsSinceEpoch}',
    }).select('id').single();
    await notify(recipient: cnic, kind: 'payment', title: 'Tax payment received',
        body: 'PKR ${amount.toStringAsFixed(0)} paid to FBR. Thank you.', refId: res['id'] as int);
    return res['id'] as int;
  }

  static Stream<List<Map<String, dynamic>>> payments(String cnic) =>
      _c.from('payments').stream(primaryKey: ['id']).order('created_at', ascending: false).map((r) => r.where((x) => x['cnic'] == cnic).toList());

  // ---------------- storage (proof uploads) ----------------
  static Future<String> uploadProof(String filename, Uint8List bytes) async {
    final path = '${DateTime.now().millisecondsSinceEpoch}_$filename';
    await _c.storage.from('proofs').uploadBinary(path, bytes);
    return _c.storage.from('proofs').getPublicUrl(path);
  }
}

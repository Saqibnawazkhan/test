import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

/// Thin API client for the FastAPI backend. All dashboards go through this.
class Api {
  static Uri _u(String path, [Map<String, String>? q]) =>
      Uri.parse('${Config.apiBase}$path').replace(queryParameters: q);

  static Future<dynamic> _get(String path, [Map<String, String>? q]) async {
    final res = await http.get(_u(path, q)).timeout(const Duration(seconds: 60));
    if (res.statusCode != 200) {
      throw Exception('GET $path → ${res.statusCode}');
    }
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  static Future<dynamic> _post(String path, [Map<String, dynamic>? body, Map<String, String>? q,
      Duration timeout = const Duration(seconds: 30)]) async {
    final res = await http
        .post(_u(path, q),
            headers: {'Content-Type': 'application/json'},
            body: body == null ? null : jsonEncode(body))
        .timeout(timeout);
    if (res.statusCode >= 300) throw Exception('POST $path → ${res.statusCode}');
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  static Future<Map<String, dynamic>> stats() async => await _get('/stats');

  static Future<Map<String, dynamic>> persons(
      {String? zone, String? district, String? q, int limit = 50, int offset = 0}) async {
    final p = <String, String>{'limit': '$limit', 'offset': '$offset'};
    if (zone != null) p['zone'] = zone;
    if (district != null) p['district'] = district;
    if (q != null && q.isNotEmpty) p['q'] = q;
    return await _get('/persons', p);
  }

  static Future<Map<String, dynamic>> person(String cnic) async => await _get('/person/$cnic');
  static Future<Map<String, dynamic>> explain(String cnic) async => await _get('/person/$cnic/explain');
  static Future<Map<String, dynamic>> graph(String cnic) async => await _get('/person/$cnic/graph');
  static Future<List<dynamic>> districts() async => await _get('/districts');

  static Future<List<dynamic>> requests({String? status, String? cnic}) async {
    final p = <String, String>{};
    if (status != null) p['status'] = status;
    if (cnic != null) p['cnic'] = cnic;
    return await _get('/requests', p);
  }

  static Future<dynamic> createRequest(
          String cnic, String field, String current, String requested, String reason) async =>
      await _post('/requests', {
        'cnic': cnic,
        'field': field,
        'current_value': current,
        'requested_value': requested,
        'reason': reason,
      });

  static Future<dynamic> resolveRequest(int id, String decision) async =>
      await _post('/requests/$id/resolve', null, {'decision': decision});

  // ---- new analytics / investigation endpoints ----
  static Future<List<dynamic>> leaderboard({int limit = 20}) async =>
      await _get('/leaderboard', {'limit': '$limit'});
  static Future<Map<String, dynamic>> analytics() async => await _get('/analytics');
  static Future<Map<String, dynamic>> riskFactors(String cnic) async => await _get('/person/$cnic/risk-factors');
  static Future<Map<String, dynamic>> notice(String cnic) async => await _get('/person/$cnic/notice');
  static Future<Map<String, dynamic>> erMetrics() async => await _get('/er-metrics');
  static Future<List<dynamic>> search(String q) async => await _get('/search', {'q': q});
  static Future<Map<String, dynamic>> network({int limit = 35}) async => await _get('/network', {'limit': '$limit'});
  static Future<Map<String, dynamic>> family(String cnic) async => await _get('/person/$cnic/family');

  // ---- POS verification / turnover reconciliation ----
  static Future<Map<String, dynamic>> posBusinesses(String q) async =>
      await _get('/pos/businesses', q.isEmpty ? null : {'q': q});
  static Future<Map<String, dynamic>> posVerify(String cnic) async => await _get('/pos/verify/$cnic');

  // ---- FBR tax calculator ----
  static Future<Map<String, dynamic>> calculateTax(num income, String year, String kind) async =>
      await _get('/tax/calculate', {'income': '$income', 'year': year, 'kind': kind});

  // ---- grounded AI assistant ----
  static Future<Map<String, dynamic>> chat(List<Map<String, String>> messages, {String mode = 'user', String? cnic}) async =>
      await _post('/chat', {'messages': messages, 'mode': mode, 'cnic': cnic ?? ''}, null, const Duration(seconds: 90));

  // ---- tax payment (Zindigi IPG) ----
  static Future<Map<String, dynamic>> payInitiate(String cnic, num amount, {String name = '', String email = '', String mobile = ''}) async =>
      await _post('/payments/initiate', {'cnic': cnic, 'amount': amount, 'name': name, 'email': email, 'mobile': mobile});
  static Future<List<dynamic>> payments(String cnic) async => (await _get('/payments', {'cnic': cnic}))['results'] ?? [];

  /// Direct URL to the downloadable findings-driven audit report PDF.
  static String auditReportUrl(String cnic) => '${Config.apiBase}/person/$cnic/audit-report';

  /// Direct URL to the downloadable Show-Cause Notice PDF (letter to the taxpayer).
  static String noticeUrl(String cnic) => '${Config.apiBase}/person/$cnic/notice-pdf';

  /// On approval, persist a declared asset into the record + recompute the score.
  static Future<dynamic> approveDeclaration(String cnic, String assetType, String description, num value,
          {Map<String, dynamic>? details, int? declId}) async =>
      await _post('/declarations/approve',
          {'cnic': cnic, 'asset_type': assetType, 'description': description, 'value': value, 'details': details ?? {}, 'decl_id': declId ?? 0});

  /// On accepting an explanation, treat the asset value as accounted-for + recompute score.
  static Future<dynamic> approveExplanation(String cnic, num assetValue, {int? explId}) async =>
      await _post('/explanations/approve', {'cnic': cnic, 'asset_value': assetValue, 'expl_id': explId ?? 0});
}

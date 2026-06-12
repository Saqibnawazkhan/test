import 'package:flutter/material.dart';
import 'api.dart';
import 'theme.dart';
import 'screens/person_detail.dart';

/// Global entity search (CNIC, name, vehicle) used from the topbar and dashboard.
class EntitySearch extends SearchDelegate {
  @override
  ThemeData appBarTheme(BuildContext context) => buildDarkTheme();
  @override
  String get searchFieldLabel => 'Search CNIC, name, vehicle…';
  @override
  List<Widget> buildActions(BuildContext context) => [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];
  @override
  Widget buildLeading(BuildContext context) => IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));
  @override
  Widget buildSuggestions(BuildContext context) => buildResults(context);
  @override
  Widget buildResults(BuildContext context) {
    if (query.trim().isEmpty) return Center(child: Text('Search CNIC, name, vehicle…', style: body(13, c: C.text3)));
    return FutureBuilder<List<dynamic>>(
      future: Api.search(query),
      builder: (_, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: C.green));
        final r = snap.data!;
        if (r.isEmpty) return Center(child: Text('No entities match “$query”.', style: body(13, c: C.text3)));
        return ListView(
          children: r
              .map((e) => ListTile(
                    leading: Icon(e['type'] == 'Vehicle' ? Icons.directions_car : Icons.person, color: C.text2),
                    title: Text(e['label'] ?? '', style: body(14)),
                    subtitle: Text(e['sub'] ?? '', style: mono(11, c: C.text3)),
                    trailing: Tag(e['type'] ?? '', sev: 'info'),
                    onTap: () {
                      final cnic = e['cnic'];
                      if (cnic != null && cnic.toString().isNotEmpty) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => PersonDetail(cnic: cnic, admin: true)));
                      }
                    },
                  ))
              .toList(),
        );
      },
    );
  }
}

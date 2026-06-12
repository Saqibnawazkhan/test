import 'package:flutter/material.dart';

/// Shared theme, formatting helpers, and small widgets.

const kSeed = Color(0xFF0B6E4F); // FBR-ish green

ThemeData buildTheme() => ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: kSeed),
      useMaterial3: true,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white,
        margin: EdgeInsets.zero,
      ),
      scaffoldBackgroundColor: const Color(0xFFF4F6F8),
    );

Color zoneColor(String? zone) {
  switch (zone) {
    case 'Red':
      return const Color(0xFFD32F2F);
    case 'Yellow':
      return const Color(0xFFF9A825);
    case 'Green':
      return const Color(0xFF2E7D32);
    default:
      return Colors.grey;
  }
}

/// Pakistani money formatting: Cr (crore=10M) / Lac (lakh=100k) / commas.
String money(num? v) {
  final n = (v ?? 0).toDouble();
  if (n.abs() >= 1e7) return 'PKR ${(n / 1e7).toStringAsFixed(2)} Cr';
  if (n.abs() >= 1e5) return 'PKR ${(n / 1e5).toStringAsFixed(2)} Lac';
  final s = n.toStringAsFixed(0);
  final b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return 'PKR $b';
}

class ZoneChip extends StatelessWidget {
  final String? zone;
  final double? score;
  const ZoneChip(this.zone, {this.score, super.key});
  @override
  Widget build(BuildContext context) {
    final c = zoneColor(zone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.circle, size: 9, color: c),
        const SizedBox(width: 6),
        Text(score != null ? '$zone · ${score!.toStringAsFixed(0)}' : (zone ?? '—'),
            style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12)),
      ]),
    );
  }
}

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const StatCard(this.label, this.value, this.icon, this.color, {super.key});
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 10),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ]),
        ),
      );
}

class SectionTitle extends StatelessWidget {
  final String text;
  final IconData icon;
  const SectionTitle(this.text, this.icon, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Row(children: [
          Icon(icon, size: 18, color: kSeed),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ]),
      );
}

Widget loading() => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));

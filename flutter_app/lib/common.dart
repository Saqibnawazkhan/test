import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared theme, formatting helpers, and small widgets.

const kSeed = Color(0xFF1AA978); // FBR brand green (matches the premium design system)
const _ink = Color(0xFF101926);

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
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withOpacity(0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle, boxShadow: [BoxShadow(color: c.withOpacity(0.5), blurRadius: 5)])),
        const SizedBox(width: 7),
        Text(score != null ? '$zone · ${score!.toStringAsFixed(0)}' : (zone ?? '—'),
            style: GoogleFonts.spaceGrotesk(color: c, fontWeight: FontWeight.w700, fontSize: 12.5)),
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
        padding: const EdgeInsets.only(top: 20, bottom: 10),
        child: Row(children: [
          Container(width: 3.5, height: 17, decoration: BoxDecoration(color: kSeed, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 9),
          Icon(icon, size: 16, color: kSeed),
          const SizedBox(width: 7),
          Text(text, style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 15.5, color: _ink)),
        ]),
      );
}

Widget loading() => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: kSeed)));

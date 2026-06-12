import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// ===== TaxNet AI — dark "command" design system (ported from the website CSS) =====
class C {
  // backgrounds (LIGHT)
  static const bg0 = Color(0xFFEDF1F6); // page
  static const bg1 = Color(0xFFF4F7FB); // drawer / bars
  static const bg2 = Color(0xFFFFFFFF); // cards
  // subtle fills / borders (faint dark tints over light)
  static const panel = Color(0x08101926);
  static const panel2 = Color(0x12101926);
  static const border = Color(0x1A101926);
  static const border2 = Color(0x29101926);
  // accents
  static const green = Color(0xFF1AA978);
  static const green2 = Color(0xFF12B57F);
  static const blue = Color(0xFF2E6FE0);
  static const blue2 = Color(0xFF4C8DF6);
  static const cyan = Color(0xFF0E9FBC);
  static const violet = Color(0xFF6F66D8);
  // text
  static const text = Color(0xFF101926);
  static const text2 = Color(0xFF495568);
  static const text3 = Color(0xFF7A8799);
  // risk
  static const low = Color(0xFF1AA978);
  static const med = Color(0xFFD79A1E);
  static const high = Color(0xFFE07A36);
  static const critical = Color(0xFFE03B59);

  static Color sev(String? s) {
    switch (s) {
      case 'low':
      case 'Green':
        return low;
      case 'med':
      case 'Yellow':
        return med;
      case 'high':
        return high;
      case 'critical':
      case 'Red':
        return critical;
      case 'info':
        return blue2;
      default:
        return text3;
    }
  }

  /// zone -> colour (Red/Yellow/Green)
  static Color zone(String? z) =>
      z == 'Red' ? critical : (z == 'Yellow' ? med : (z == 'Green' ? low : text3));
}

// ---- fonts ----
TextStyle display(double size, {FontWeight w = FontWeight.w600, Color? c, double ls = -0.02}) =>
    GoogleFonts.spaceGrotesk(fontSize: size, fontWeight: w, color: c ?? C.text, letterSpacing: ls * size / 16);
TextStyle body(double size, {FontWeight w = FontWeight.w400, Color? c, double h = 1.5}) =>
    GoogleFonts.sora(fontSize: size, fontWeight: w, color: c ?? C.text, height: h);
TextStyle mono(double size, {FontWeight w = FontWeight.w500, Color? c, double ls = 0}) =>
    GoogleFonts.jetBrainsMono(fontSize: size, fontWeight: w, color: c ?? C.text, letterSpacing: ls);

ThemeData buildTheme() {
  final scheme = const ColorScheme.light(
    primary: C.green, secondary: C.blue, surface: C.bg2,
    error: C.critical, onPrimary: Colors.white, onSurface: C.text,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: C.bg0,
    canvasColor: C.bg1,
    textTheme: GoogleFonts.soraTextTheme(ThemeData.light().textTheme).apply(bodyColor: C.text, displayColor: C.text),
    dividerColor: C.border,
    iconTheme: const IconThemeData(color: C.text2),
    appBarTheme: AppBarTheme(
      backgroundColor: C.bg2, foregroundColor: C.text, elevation: 0,
      titleTextStyle: display(17), surfaceTintColor: Colors.transparent,
      iconTheme: const IconThemeData(color: C.text2),
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: C.bg1),
  );
}

// back-compat alias
ThemeData buildDarkTheme() => buildTheme();

/// the radial-glow page background used across the app
class GlowBackground extends StatelessWidget {
  final Widget child;
  const GlowBackground({required this.child, super.key});
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.7, -1.1), radius: 1.3,
            colors: [Color(0x0F4C8DF6), Color(0x000A0E15)], stops: [0, 0.7],
          ),
        ),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.9, 1.2), radius: 1.2,
              colors: [Color(0x0A25C98C), Color(0x000A0E15)], stops: [0, 0.6],
            ),
          ),
          child: child,
        ),
      );
}

// ---- reusable widgets ----
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? border;
  final Gradient? gradient;
  final VoidCallback? onTap;
  const GlassCard({required this.child, this.padding = const EdgeInsets.all(18), this.border, this.gradient, this.onTap, super.key});
  @override
  Widget build(BuildContext context) {
    final w = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? C.bg2 : null,
        gradient: gradient,
        border: Border.all(color: border ?? C.border),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x14101926), blurRadius: 18, offset: Offset(0, 6), spreadRadius: -8)],
      ),
      child: child,
    );
    return onTap == null ? w : GestureDetector(onTap: onTap, child: w);
  }
}

class Tag extends StatelessWidget {
  final String text;
  final String sev; // low/med/high/critical/info
  final IconData? icon;
  const Tag(this.text, {this.sev = 'info', this.icon, super.key});
  @override
  Widget build(BuildContext context) {
    final col = C.sev(sev);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: col.withOpacity(0.13), borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 12, color: col), const SizedBox(width: 5)],
        Text(text, style: mono(10.5, w: FontWeight.w600, c: col)),
      ]),
    );
  }
}

class Eyebrow extends StatelessWidget {
  final String text;
  const Eyebrow(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(width: 18, height: 1, color: C.green),
        const SizedBox(width: 8),
        Text(text.toUpperCase(), style: mono(10.5, c: C.text3, ls: 1.6)),
      ]);
}

class PageHeader extends StatelessWidget {
  final String eyebrow, title;
  final String? desc;
  final List<Widget> actions;
  const PageHeader(this.eyebrow, this.title, {this.desc, this.actions = const [], super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Eyebrow(eyebrow),
          const SizedBox(height: 10),
          Text(title, style: display(24)),
          if (desc != null) ...[const SizedBox(height: 6), Text(desc!, style: body(13, c: C.text2))],
          if (actions.isNotEmpty) ...[const SizedBox(height: 14), Wrap(spacing: 10, runSpacing: 10, children: actions)],
        ]),
      );
}

/// money — Pakistani Cr/Lac formatting, e.g. "₨ 1.71 Cr"
String rs(num? v) {
  final n = (v ?? 0).toDouble();
  if (n.abs() >= 1e12) return 'Rs ${(n / 1e12).toStringAsFixed(2)}T';
  if (n.abs() >= 1e7) return 'Rs ${(n / 1e7).toStringAsFixed(2)} Cr';
  if (n.abs() >= 1e5) return 'Rs ${(n / 1e5).toStringAsFixed(2)} Lac';
  return 'Rs ${n.toStringAsFixed(0)}';
}

// ---- custom painters ----
class Sparkline extends StatelessWidget {
  final List<double> data;
  final Color color;
  final double height;
  const Sparkline(this.data, {this.color = C.green, this.height = 34, super.key});
  @override
  Widget build(BuildContext context) =>
      SizedBox(height: height, width: double.infinity, child: CustomPaint(painter: _SparkPainter(data, color)));
}

class _SparkPainter extends CustomPainter {
  final List<double> d;
  final Color color;
  _SparkPainter(this.d, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    if (d.isEmpty) return;
    final mn = d.reduce(math.min), mx = d.reduce(math.max);
    final rng = (mx - mn) == 0 ? 1 : (mx - mn);
    final pts = <Offset>[
      for (int i = 0; i < d.length; i++)
        Offset(i / (d.length - 1) * size.width, size.height - (d[i] - mn) / rng * size.height)
    ];
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) path.lineTo(p.dx, p.dy);
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fill, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color.withOpacity(0.22), color.withOpacity(0)]).createShader(Offset.zero & size));
    canvas.drawPath(path, Paint()..color = color..strokeWidth = 2..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_) => false;
}

/// circular confidence/score ring with centre label
class Ring extends StatelessWidget {
  final double value; // 0-100
  final String centerLabel, centerSub;
  final Color color;
  final double size;
  const Ring(this.value, {this.centerLabel = '', this.centerSub = '', this.color = C.green, this.size = 150, super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: size, height: size,
        child: CustomPaint(
          painter: _RingPainter(value, color),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(centerLabel, style: mono(size * 0.18, w: FontWeight.w700, c: color)),
              if (centerSub.isNotEmpty) Text(centerSub, style: body(size * 0.065, c: C.text3)),
            ]),
          ),
        ),
      );
}

class _RingPainter extends CustomPainter {
  final double v;
  final Color color;
  _RingPainter(this.v, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 9;
    canvas.drawCircle(c, r, Paint()..color = const Color(0x12FFFFFF)..strokeWidth = 11..style = PaintingStyle.stroke);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, 2 * math.pi * (v / 100), false,
        Paint()..color = color..strokeWidth = 11..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.v != v;
}

/// semicircular risk meter gauge (0-100)
class RiskMeter extends StatelessWidget {
  final double value;
  const RiskMeter(this.value, {super.key});
  @override
  Widget build(BuildContext context) {
    final col = value >= 80 ? C.critical : value >= 60 ? C.high : value >= 35 ? C.med : C.low;
    return SizedBox(
      width: 200, height: 130,
      child: CustomPaint(
        painter: _MeterPainter(value, col),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 34),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(value.toStringAsFixed(0), style: mono(40, w: FontWeight.w700, c: col)),
              Text('DEVIATION SCORE', style: mono(9, c: C.text3, ls: 1.2)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _MeterPainter extends CustomPainter {
  final double v;
  final Color col;
  _MeterPainter(this.v, this.col);
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final r = size.width / 2 - 8;
    final rect = Rect.fromCircle(center: center, radius: r);
    canvas.drawArc(rect, math.pi, math.pi, false, Paint()..color = const Color(0x12FFFFFF)..strokeWidth = 14..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
    canvas.drawArc(rect, math.pi, math.pi * (v / 100), false, Paint()..color = col..strokeWidth = 14..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_MeterPainter o) => o.v != v;
}

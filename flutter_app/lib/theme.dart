import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Global UI state: dark/light theme + English/Urdu. Toggling rebuilds the app.
class AppCtl {
  static final ValueNotifier<bool> dark = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> urdu = ValueNotifier<bool>(false);
}

const Map<String, String> _ur = {
  'Dashboard': 'ڈیش بورڈ', 'All Records': 'تمام ریکارڈز', 'Knowledge Graph': 'نالج گراف',
  'Entity Resolution': 'شناخت کی تطبیق', 'Risk Analysis': 'خطرے کا تجزیہ', 'Audit Trail': 'آڈٹ ٹریل',
  'POS Verification': 'پی او ایس تصدیق', 'Tax Payments': 'ٹیکس ادائیگیاں', 'Reports': 'رپورٹس',
  'Leaderboard': 'لیڈر بورڈ', 'Citizen Inbox': 'شہری ان باکس', 'Settings': 'ترتیبات',
  'Search CNIC, name, property, vehicle…': 'شناختی کارڈ، نام، جائیداد یا گاڑی تلاش کریں…',
  'Preferences': 'ترجیحات', 'Interface theme': 'انٹرفیس تھیم', 'Language': 'زبان',
  'Role-based access': 'کردار کی بنیاد پر رسائی', 'Real-time notifications': 'فوری اطلاعات',
  'Activity & audit logging': 'سرگرمی اور آڈٹ ریکارڈ', 'Configuration': 'تشکیل',
};

/// Translate a UI string to Urdu when Urdu mode is on (falls back to English).
String t(String en) => AppCtl.urdu.value ? (_ur[en] ?? en) : en;

/// ===== TaxNet AI — dark "command" design system (ported from the website CSS) =====
class C {
  static bool get _d => AppCtl.dark.value;
  // backgrounds — theme-aware (dark/light)
  static Color get bg0 => _d ? const Color(0xFF0A0F1A) : const Color(0xFFEDF1F6); // page
  static Color get bg1 => _d ? const Color(0xFF111A2B) : const Color(0xFFF4F7FB); // drawer / bars
  static Color get bg2 => _d ? const Color(0xFF18233A) : const Color(0xFFFFFFFF); // cards / surfaces
  // subtle fills / borders
  static Color get panel => _d ? const Color(0x14FFFFFF) : const Color(0x08101926);
  static Color get panel2 => _d ? const Color(0x1FFFFFFF) : const Color(0x12101926);
  static Color get border => _d ? const Color(0x24FFFFFF) : const Color(0x1A101926);
  static Color get border2 => _d ? const Color(0x38FFFFFF) : const Color(0x29101926);
  // accents (same on both themes)
  static const green = Color(0xFF1AA978);
  static const green2 = Color(0xFF12B57F);
  static const blue = Color(0xFF2E6FE0);
  static const blue2 = Color(0xFF4C8DF6);
  static const cyan = Color(0xFF0E9FBC);
  static const violet = Color(0xFF6F66D8);
  // text — theme-aware
  static Color get text => _d ? const Color(0xFFEAEFF7) : const Color(0xFF101926);
  static Color get text2 => _d ? const Color(0xFFAEB9CC) : const Color(0xFF495568);
  static Color get text3 => _d ? const Color(0xFF7E8CA3) : const Color(0xFF7A8799);
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

ThemeData buildTheme([bool dark = false]) {
  final scheme = ColorScheme.light(
    primary: C.green, secondary: C.blue, surface: C.bg2,
    error: C.critical, onPrimary: Colors.white, onSurface: C.text,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent, // global glass wash shows through (see AppRoot)
    canvasColor: dark ? const Color(0xFF111A2B) : C.bg1,
    textTheme: GoogleFonts.soraTextTheme(ThemeData.light().textTheme).apply(bodyColor: C.text, displayColor: C.text),
    dividerColor: C.border,
    iconTheme: IconThemeData(color: C.text2),
    appBarTheme: AppBarTheme(
      backgroundColor: C.bg2, foregroundColor: C.text, elevation: 0,
      titleTextStyle: display(17), surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: C.text2),
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    ),
    drawerTheme: DrawerThemeData(backgroundColor: C.bg1),
    // ---- premium component styling (lifts every Material screen, incl. citizen) ----
    cardTheme: CardThemeData(
      elevation: 0, color: Colors.white.withOpacity(dark ? 0.92 : 0.55), surfaceTintColor: Colors.transparent, margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.white.withOpacity(dark ? 0.7 : 0.55))),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: dark ? Colors.white.withOpacity(0.85) : C.bg1,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      labelStyle: body(12.5, c: C.text3), prefixIconColor: C.text3, hintStyle: body(13, c: C.text3),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: C.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: C.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.green, width: 1.5)),
    ),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), textStyle: body(13.5, w: FontWeight.w700), elevation: 0,
    )),
    elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0,
    )),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: BorderSide(color: C.border2), textStyle: body(13, w: FontWeight.w600),
    )),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(textStyle: body(13, w: FontWeight.w600))),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(elevation: 2, highlightElevation: 2),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating, backgroundColor: C.text,
      contentTextStyle: body(12.5, c: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: C.bg1, side: BorderSide(color: C.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      labelStyle: body(11.5, c: C.text2),
    ),
    dialogTheme: DialogThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), backgroundColor: C.bg2),
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

/// Global soft colour wash placed behind every screen (via MaterialApp.builder),
/// so translucent cards/app-bars across the whole app frost over real colour.
class GlassBackground extends StatelessWidget {
  final Widget child;
  const GlassBackground({required this.child, super.key});
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppCtl.dark.value
              ? const LinearGradient(
                  begin: Alignment.topRight, end: Alignment.bottomLeft,
                  colors: [Color(0xFF0A0F1A), Color(0xFF0E1626), Color(0xFF150F22)],
                  stops: [0.0, 0.55, 1.0],
                )
              : const LinearGradient(
                  begin: Alignment.topRight, end: Alignment.bottomLeft,
                  colors: [Color(0xFFDCE7F7), Color(0xFFDCEFE7), Color(0xFFE7E2F5)],
                  stops: [0.0, 0.55, 1.0],
                ),
        ),
        child: child,
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
    final w = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            // translucent frosted sheen — coloured background shows through the glass
            gradient: gradient ??
                LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: AppCtl.dark.value
                      ? [Colors.white.withOpacity(0.12), Colors.white.withOpacity(0.05)]
                      : [Colors.white.withOpacity(0.42), Colors.white.withOpacity(0.16)],
                ),
            border: Border.all(color: border ?? Colors.white.withOpacity(AppCtl.dark.value ? 0.18 : 0.55)),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Color(0x18101926), blurRadius: 22, offset: Offset(0, 8), spreadRadius: -8)],
          ),
          child: child,
        ),
      ),
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

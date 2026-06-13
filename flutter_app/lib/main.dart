import 'package:flutter/material.dart';
import 'theme.dart';
import 'supa.dart';
import 'screens/auth_screens.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Supa.init();
  } catch (_) {/* offline-safe: app still runs, realtime features degrade */}
  runApp(const TaxNetApp());
}

class TaxNetApp extends StatelessWidget {
  const TaxNetApp({super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: Listenable.merge([AppCtl.dark, AppCtl.urdu]),
        builder: (context, _) => MaterialApp(
          title: 'TaxNet AI',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(AppCtl.dark.value),
          builder: (context, child) {
            Widget app = GlassBackground(child: child ?? const SizedBox.shrink());
            if (AppCtl.urdu.value) app = Directionality(textDirection: TextDirection.rtl, child: app);
            return app;
          },
          home: const CitizenLoginScreen(),
        ),
      );
}

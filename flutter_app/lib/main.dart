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
  Widget build(BuildContext context) => MaterialApp(
        title: 'TaxNet AI',
        debugShowCheckedModeBanner: false,
        theme: buildDarkTheme(),
        home: const CitizenLoginScreen(),
      );
}

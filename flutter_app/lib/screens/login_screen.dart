import 'package:flutter/material.dart';
import '../theme.dart';
import '../shell.dart';
import 'user_dashboard.dart';

/// Role-based entry — TaxNet AI (FBR Intelligence). Admin → command shell, Citizen → portal.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _cnic = TextEditingController(text: '42101-1354046-5');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GlowBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [C.green, C.blue]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: C.green.withOpacity(0.4), blurRadius: 24, spreadRadius: -6)],
                  ),
                  child: const Icon(Icons.hub, color: Color(0xFF04070D), size: 32),
                ),
                const SizedBox(height: 16),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Tax', style: display(28)),
                  Text('Net', style: display(28, c: C.green)),
                  Text(' AI', style: display(28)),
                ]),
                Text('GRAPH INTELLIGENCE · NATIONAL TAX NET', style: mono(10, c: C.text3, ls: 1.4)),
                const SizedBox(height: 36),
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Eyebrow('Citizen Access'),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _cnic,
                      style: body(14),
                      decoration: InputDecoration(
                        labelText: 'CNIC',
                        labelStyle: body(12, c: C.text3),
                        prefixIcon: Icon(Icons.badge_outlined, color: C.text3),
                        filled: true, fillColor: C.panel,
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: C.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: C.blue)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: const Color(0xFF08130E), padding: const EdgeInsets.all(14)),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserDashboard(cnic: _cnic.text.trim()))),
                        icon: const Icon(Icons.login),
                        label: Text('Enter as Citizen', style: body(13.5, w: FontWeight.w700, c: const Color(0xFF08130E))),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: C.text, side: BorderSide(color: C.border2), padding: const EdgeInsets.all(16)),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminShell())),
                    icon: const Icon(Icons.shield_outlined, color: C.green),
                    label: Text('Enter as FBR Investigator', style: body(13.5, w: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 18),
                Text('Live ingestion · 14 databases connected', style: body(11, c: C.text3)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

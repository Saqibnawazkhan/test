import 'package:flutter/material.dart';
import '../theme.dart';
import '../supa.dart';
import '../shell.dart';
import 'user_dashboard.dart';

// ---- shared building blocks ----
Widget _brand() => Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 60, height: 60,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [C.green, C.blue]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: C.green.withOpacity(0.4), blurRadius: 24, spreadRadius: -6)],
        ),
        child: const Icon(Icons.hub, color: Colors.white, size: 30),
      ),
      const SizedBox(height: 14),
      Row(mainAxisSize: MainAxisSize.min, children: [
        Text('Tax', style: display(26)),
        Text('Net', style: display(26, c: C.green)),
        Text(' AI', style: display(26)),
      ]),
      Text('NATIONAL TAX NET · FBR', style: mono(9.5, c: C.text3, ls: 1.4)),
    ]);

Widget _field(TextEditingController c, String label, IconData icon, {bool obscure = false, TextInputType? kb}) =>
    TextField(
      controller: c,
      obscureText: obscure,
      keyboardType: kb,
      style: body(14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: body(12, c: C.text3),
        prefixIcon: Icon(icon, color: C.text3, size: 20),
        filled: true, fillColor: C.panel,
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: C.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: C.blue)),
      ),
    );

// =========================== CITIZEN LOGIN ===========================
class CitizenLoginScreen extends StatefulWidget {
  const CitizenLoginScreen({super.key});
  @override
  State<CitizenLoginScreen> createState() => _CitizenLoginScreenState();
}

class _CitizenLoginScreenState extends State<CitizenLoginScreen> {
  final _cnic = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  String? _err;

  Future<void> _signIn() async {
    final cnic = _cnic.text.trim();
    if (cnic.isEmpty || _pass.text.isEmpty) {
      setState(() => _err = 'Enter your CNIC and password.');
      return;
    }
    setState(() { _loading = true; _err = null; });
    try {
      final acc = await Supa.login(cnic, _pass.text);
      if (!mounted) return;
      if (acc == null) {
        setState(() { _loading = false; _err = 'Invalid CNIC or password.'; });
      } else if (acc['role'] == 'admin') {
        setState(() { _loading = false; _err = 'This is an admin account. Use Admin login.'; });
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => UserDashboard(cnic: cnic)));
      }
    } catch (_) {
      setState(() { _loading = false; _err = 'Could not sign in — check your connection.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GlowBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const SizedBox(height: 24),
              _brand(),
              const SizedBox(height: 30),
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Eyebrow('Citizen Login'),
                  const SizedBox(height: 14),
                  _field(_cnic, 'CNIC', Icons.badge_outlined, kb: TextInputType.text),
                  const SizedBox(height: 12),
                  _field(_pass, 'Password', Icons.lock_outline, obscure: true),
                  if (_err != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_err!, style: body(12, c: C.critical))),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.white, padding: const EdgeInsets.all(14)),
                      onPressed: _loading ? null : _signIn,
                      icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.login),
                      label: Text('Sign In', style: body(13.5, w: FontWeight.w700, c: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CitizenSignUpScreen())),
                      child: Text.rich(TextSpan(style: body(12.5, c: C.text3), children: [
                        const TextSpan(text: "Don't have an account?  "),
                        TextSpan(text: 'Sign up', style: body(12.5, w: FontWeight.w700, c: C.green)),
                      ])),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
              Text('Demo citizen — 42101-1354046-5 / 1234', style: body(10.5, c: C.text3)),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminLoginScreen())),
                  icon: const Icon(Icons.shield_outlined, size: 16, color: C.blue),
                  label: Text('Enter as Admin', style: body(12.5, w: FontWeight.w600, c: C.blue)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// =========================== CITIZEN SIGN UP ===========================
class CitizenSignUpScreen extends StatefulWidget {
  const CitizenSignUpScreen({super.key});
  @override
  State<CitizenSignUpScreen> createState() => _CitizenSignUpScreenState();
}

class _CitizenSignUpScreenState extends State<CitizenSignUpScreen> {
  final _cnic = TextEditingController();
  final _name = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _err;

  Future<void> _create() async {
    final cnic = _cnic.text.trim();
    if (cnic.isEmpty || _pass.text.isEmpty) {
      setState(() => _err = 'Enter your CNIC and a password.');
      return;
    }
    if (_pass.text.length < 4) {
      setState(() => _err = 'Password must be at least 4 characters.');
      return;
    }
    if (_pass.text != _confirm.text) {
      setState(() => _err = 'Passwords do not match.');
      return;
    }
    setState(() { _loading = true; _err = null; });
    try {
      final err = await Supa.signUp(cnic: cnic, name: _name.text.trim(), password: _pass.text);
      if (!mounted) return;
      if (err != null) {
        setState(() { _loading = false; _err = err; });
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => UserDashboard(cnic: cnic)));
      }
    } catch (_) {
      setState(() { _loading = false; _err = 'Could not create account — check your connection.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: C.text, elevation: 0),
      body: GlowBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              _brand(),
              const SizedBox(height: 26),
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Eyebrow('Create Citizen Account'),
                  const SizedBox(height: 14),
                  _field(_cnic, 'CNIC', Icons.badge_outlined),
                  const SizedBox(height: 12),
                  _field(_name, 'Full name', Icons.person_outline),
                  const SizedBox(height: 12),
                  _field(_pass, 'Password', Icons.lock_outline, obscure: true),
                  const SizedBox(height: 12),
                  _field(_confirm, 'Confirm password', Icons.lock_outline, obscure: true),
                  if (_err != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_err!, style: body(12, c: C.critical))),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.white, padding: const EdgeInsets.all(14)),
                      onPressed: _loading ? null : _create,
                      icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.person_add),
                      label: Text('Create Account', style: body(13.5, w: FontWeight.w700, c: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text.rich(TextSpan(style: body(12.5, c: C.text3), children: [
                        const TextSpan(text: 'Already have an account?  '),
                        TextSpan(text: 'Sign in', style: body(12.5, w: FontWeight.w700, c: C.green)),
                      ])),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// =========================== ADMIN LOGIN (no sign-up) ===========================
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});
  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  String? _err;

  Future<void> _signIn() async {
    final user = _user.text.trim();
    if (user.isEmpty || _pass.text.isEmpty) {
      setState(() => _err = 'Enter your username and password.');
      return;
    }
    setState(() { _loading = true; _err = null; });
    try {
      final acc = await Supa.login(user, _pass.text);
      if (!mounted) return;
      if (acc != null && acc['role'] == 'admin') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminShell()));
      } else {
        setState(() { _loading = false; _err = 'Invalid admin credentials.'; });
      }
    } catch (_) {
      setState(() { _loading = false; _err = 'Could not sign in — check your connection.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: C.text, elevation: 0),
      body: GlowBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              _brand(),
              const SizedBox(height: 30),
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [const Icon(Icons.shield, color: C.blue, size: 18), const SizedBox(width: 8), const Eyebrow('FBR Investigator Login')]),
                  const SizedBox(height: 14),
                  _field(_user, 'Username / CNIC', Icons.account_circle_outlined),
                  const SizedBox(height: 12),
                  _field(_pass, 'Password', Icons.lock_outline, obscure: true),
                  if (_err != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_err!, style: body(12, c: C.critical))),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: C.blue, foregroundColor: Colors.white, padding: const EdgeInsets.all(14)),
                      onPressed: _loading ? null : _signIn,
                      icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.login),
                      label: Text('Sign In', style: body(13.5, w: FontWeight.w700, c: Colors.white)),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
              Text('Demo admin — admin / admin123', style: body(10.5, c: C.text3)),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, size: 16, color: C.green),
                  label: Text('Citizen login', style: body(12.5, w: FontWeight.w600, c: C.green)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../api.dart';
import '../supa.dart';
import '../common.dart';
import 'auth_screens.dart';

/// Citizen profile — view details, update contact info (persists to the DB),
/// change password, and log out.
class ProfileScreen extends StatefulWidget {
  final String cnic;
  const ProfileScreen({required this.cnic, super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _mobile = TextEditingController();
  final _address = TextEditingController();
  final _newPass = TextEditingController();
  final _confirm = TextEditingController();
  Map<String, dynamic>? _d;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.person(widget.cnic);
      final id = Map<String, dynamic>.from(d['identity'] ?? {});
      setState(() {
        _d = d;
        _name.text = '${id['name'] ?? ''}';
        _email.text = '${id['email'] ?? ''}';
        _mobile.text = '${id['mobile'] ?? ''}';
        _address.text = '${id['present_address'] ?? ''}';
      });
    } catch (_) {/* keep blank */}
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await Api.updateProfile(widget.cnic,
          name: _name.text.trim(), email: _email.text.trim(), mobile: _mobile.text.trim(), address: _address.text.trim());
      await Supa.updateAccount(widget.cnic, name: _name.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated.')));
        _load();
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save — check your connection.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    if (_newPass.text.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password must be at least 4 characters.')));
      return;
    }
    if (_newPass.text != _confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match.')));
      return;
    }
    try {
      await Supa.updateAccount(widget.cnic, password: _newPass.text);
      _newPass.clear();
      _confirm.clear();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not change password.')));
    }
  }

  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const CitizenLoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final id = _d?['identity'] ?? {};
    final sc = _d?['score'];
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile'), backgroundColor: kSeed, foregroundColor: Colors.white),
      body: _d == null
          ? loading()
          : ListView(padding: const EdgeInsets.all(16), children: [
              // header
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    CircleAvatar(radius: 30, backgroundColor: kSeed.withOpacity(0.15), child: Text(
                      '${id['name'] ?? ''}'.split(' ').where((s) => s.isNotEmpty).map((s) => s[0]).take(2).join(),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kSeed))),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${id['name'] ?? ''}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      Text('${widget.cnic} · ${id['district'] ?? ''}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ])),
                    if (sc != null)
                      ZoneChip(sc['zone'], score: (sc['deviation_score'] ?? 0).toDouble()),
                  ]),
                ),
              ),
              const SectionTitle('Contact Details', Icons.edit),
              Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
                TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline))),
                const SizedBox(height: 10),
                TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined))),
                const SizedBox(height: 10),
                TextField(controller: _mobile, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile', prefixIcon: Icon(Icons.phone_outlined))),
                const SizedBox(height: 10),
                TextField(controller: _address, maxLines: 2, decoration: const InputDecoration(labelText: 'Address', prefixIcon: Icon(Icons.home_outlined))),
                const SizedBox(height: 14),
                SizedBox(width: double.infinity, child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: kSeed, foregroundColor: Colors.white, padding: const EdgeInsets.all(13)),
                  onPressed: _saving ? null : _save,
                  icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
                  label: const Text('Save changes'),
                )),
              ]))),
              const SectionTitle('Change Password', Icons.lock_outline),
              Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
                TextField(controller: _newPass, obscureText: true, decoration: const InputDecoration(labelText: 'New password', prefixIcon: Icon(Icons.lock_outline))),
                const SizedBox(height: 10),
                TextField(controller: _confirm, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm password', prefixIcon: Icon(Icons.lock_outline))),
                const SizedBox(height: 14),
                SizedBox(width: double.infinity, child: OutlinedButton.icon(
                  onPressed: _changePassword,
                  icon: const Icon(Icons.password),
                  label: const Text('Update password'),
                )),
              ]))),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC62828), foregroundColor: Colors.white, padding: const EdgeInsets.all(14)),
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: const Text('Log out'),
              )),
            ]),
    );
  }
}

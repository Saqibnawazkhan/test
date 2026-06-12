import 'package:flutter/material.dart';
import '../api.dart';
import '../common.dart';

/// FBR income-tax calculator (citizen). Deterministic, verified slabs computed
/// on the backend — accurate for FY2024-25 and FY2025-26, salaried & business.
class TaxCalculatorScreen extends StatefulWidget {
  const TaxCalculatorScreen({super.key});
  @override
  State<TaxCalculatorScreen> createState() => _TaxCalculatorScreenState();
}

class _TaxCalculatorScreenState extends State<TaxCalculatorScreen> {
  final _income = TextEditingController();
  String _year = '2025-26';
  String _kind = 'salaried';
  bool _monthly = false; // user entered a monthly figure?
  Map<String, dynamic>? _r;
  bool _loading = false;
  String? _err;

  Future<void> _calc() async {
    final raw = num.tryParse(_income.text.trim().replaceAll(',', ''));
    if (raw == null || raw <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter your income amount.')));
      return;
    }
    final annual = _monthly ? raw * 12 : raw;
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final r = await Api.calculateTax(annual, _year, _kind);
      setState(() {
        _r = r;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _err = 'Could not reach the calculator — is the backend running?';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tax Calculator'), backgroundColor: kSeed, foregroundColor: Colors.white),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          color: kSeed.withOpacity(0.06),
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Row(children: [
              Icon(Icons.calculate, color: kSeed),
              SizedBox(width: 12),
              Expanded(child: Text('Estimate your income tax using the official FBR slabs. Figures are exact, not AI-guessed.')),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _income,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: _monthly ? 'Monthly income (PKR)' : 'Annual income (PKR)',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.payments),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('I entered a monthly figure', style: TextStyle(fontSize: 14)),
          value: _monthly,
          onChanged: (v) => setState(() => _monthly = v),
        ),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _year,
              decoration: const InputDecoration(labelText: 'Tax year', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: '2025-26', child: Text('FY 2025-26')),
                DropdownMenuItem(value: '2024-25', child: Text('FY 2024-25')),
              ],
              onChanged: (v) => setState(() => _year = v ?? '2025-26'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _kind,
              decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'salaried', child: Text('Salaried')),
                DropdownMenuItem(value: 'business', child: Text('Business')),
              ],
              onChanged: (v) => setState(() => _kind = v ?? 'salaried'),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: kSeed, foregroundColor: Colors.white, padding: const EdgeInsets.all(14)),
          onPressed: _loading ? null : _calc,
          icon: _loading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.calculate),
          label: const Text('Calculate tax'),
        ),
        if (_err != null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(_err!, style: const TextStyle(color: Colors.red))),
        if (_r != null) ...[const SizedBox(height: 18), _result(_r!)],
      ]),
    );
  }

  Widget _result(Map<String, dynamic> r) {
    final brackets = (r['brackets'] as List?) ?? [];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Card(
        color: kSeed.withOpacity(0.09),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(children: [
            const Text('Total income tax payable', style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 6),
            Text(money(r['total_tax']), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: kSeed)),
            const SizedBox(height: 4),
            Text('Effective rate ${r['effective_rate']}%  ·  Marginal ${r['marginal_rate']}%',
                style: const TextStyle(color: Colors.black54, fontSize: 12.5)),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _kv('Annual income', money(r['income'])),
            _kv('Income tax', money(r['tax'])),
            if ((r['surcharge'] ?? 0) as num > 0) _kv('Surcharge (${r['surcharge_rate']}%)', money(r['surcharge'])),
            _kv('Monthly tax', money(r['monthly_tax'])),
            const Divider(),
            _kv('Take-home (annual)', money(r['take_home_annual']), strong: true),
            _kv('Take-home (monthly)', money(r['take_home_monthly']), strong: true),
          ]),
        ),
      ),
      if (brackets.isNotEmpty) ...[
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Slab breakdown', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...brackets.map((b) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Expanded(child: Text('${b['range']}  @ ${b['rate']}%', style: const TextStyle(fontSize: 12.5))),
                      Text(money(b['tax']), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                    ]),
                  )),
            ]),
          ),
        ),
      ],
      const SizedBox(height: 8),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Text('Based on official FBR slabs. For salaried, surcharge applies above PKR 10M.',
            style: TextStyle(fontSize: 11, color: Colors.black45)),
      ),
    ]);
  }

  Widget _kv(String k, String v, {bool strong = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(k, style: TextStyle(color: Colors.grey[700])),
          Text(v, style: TextStyle(fontWeight: strong ? FontWeight.bold : FontWeight.w600, color: strong ? kSeed : null)),
        ]),
      );
}

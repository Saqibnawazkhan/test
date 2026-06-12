import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../api.dart';
import '../common.dart';

/// Citizen tax payment via Zindigi IPG. Generates a PSID, opens the secure Zindigi
/// checkout in an in-app browser; on success the backend records the payment,
/// adds to tax_paid and recomputes the compliance score.
class PayTaxScreen extends StatefulWidget {
  final String cnic;
  final String? name;
  final num? suggested; // suggested amount (e.g. computed tax due)
  const PayTaxScreen({required this.cnic, this.name, this.suggested, super.key});
  @override
  State<PayTaxScreen> createState() => _PayTaxScreenState();
}

class _PayTaxScreenState extends State<PayTaxScreen> {
  final _amount = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.suggested != null && widget.suggested! > 0) _amount.text = '${widget.suggested!.round()}';
  }

  Future<void> _pay() async {
    final amt = num.tryParse(_amount.text.trim().replaceAll(',', ''));
    if (amt == null || amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter the amount to pay.')));
      return;
    }
    setState(() => _loading = true);
    try {
      final r = await Api.payInitiate(widget.cnic, amt, name: widget.name ?? '');
      final url = '${r['checkout_url']}';
      final psid = '${r['psid']}';
      if (!mounted) return;
      final ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => _CheckoutWebView(url: url, psid: psid)),
      );
      if (!mounted) return;
      setState(() => _loading = false);
      if (ok == true) {
        Navigator.pop(context, true); // signal dashboard to refresh
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: const Color(0xFF2E7D32),
          content: Text('Payment successful — Rs ${amt.round()} paid. PSID $psid'),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment was not completed.')));
      }
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not start payment — is the backend running?')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pay Tax'), backgroundColor: kSeed, foregroundColor: Colors.white),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          color: kSeed.withOpacity(0.06),
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Row(children: [
              Icon(Icons.account_balance_wallet, color: kSeed),
              SizedBox(width: 12),
              Expanded(child: Text('Pay your income tax securely via Zindigi (JS Bank). We generate a Payment Slip ID (PSID) for your record.')),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _amount,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Amount to pay (PKR)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.payments),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: kSeed, foregroundColor: Colors.white, padding: const EdgeInsets.all(14)),
          onPressed: _loading ? null : _pay,
          icon: _loading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.lock),
          label: const Text('Proceed to secure payment'),
        ),
        const SizedBox(height: 10),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('You will pay via bank account, card or wallet with OTP. This is a live gateway — use a small amount while testing.',
              style: TextStyle(fontSize: 11.5, color: Colors.black45)),
        ),
      ]),
    );
  }
}

class _CheckoutWebView extends StatefulWidget {
  final String url;
  final String psid;
  const _CheckoutWebView({required this.url, required this.psid});
  @override
  State<_CheckoutWebView> createState() => _CheckoutWebViewState();
}

class _CheckoutWebViewState extends State<_CheckoutWebView> {
  late final WebViewController _controller;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (url) {
          // The backend processes /payments/return (updates record), then shows a result page.
          if (!_done && url.contains('/payments/return')) {
            _done = true;
            final ok = url.contains('r=ok') && !url.contains('r=fail');
            if (mounted) Navigator.pop(context, ok);
          }
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zindigi Secure Payment'), backgroundColor: kSeed, foregroundColor: Colors.white),
      body: WebViewWidget(controller: _controller),
    );
  }
}

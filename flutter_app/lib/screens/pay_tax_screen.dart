import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api.dart';
import '../supa.dart';
import '../common.dart';

/// Citizen tax payment via Zindigi IPG. Generates a PSID, opens the secure Zindigi
/// checkout; on success the backend records the payment, adds to tax_paid and
/// recomputes the score (proportional). Shows a downloadable receipt.
class PayTaxScreen extends StatefulWidget {
  final String cnic;
  final String? name;
  final num? suggested;
  const PayTaxScreen({required this.cnic, this.name, this.suggested, super.key});
  @override
  State<PayTaxScreen> createState() => _PayTaxScreenState();
}

class _PayTaxScreenState extends State<PayTaxScreen> {
  final _amount = TextEditingController();
  bool _loading = false;
  String? _paidPsid;
  num _paidAmount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.suggested != null && widget.suggested! > 0) _amount.text = '${widget.suggested!.round()}';
  }

  Future<bool> _isPaid(String psid) async {
    try {
      final list = await Api.payments(cnic: widget.cnic);
      final p = list.cast<Map<String, dynamic>>().firstWhere((x) => x['psid'] == psid, orElse: () => {});
      return p['status'] == 'Paid';
    } catch (_) {
      return false;
    }
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
      final res = await Navigator.push<bool?>(context, MaterialPageRoute(builder: (_) => _CheckoutWebView(url: url)));
      // Robustness: if the WebView return was inconclusive, verify with the backend.
      bool paid = res == true;
      if (res == null) paid = await _isPaid(psid);
      if (!mounted) return;
      setState(() => _loading = false);
      if (paid) {
        await Supa.recordPayment(cnic: widget.cnic, name: widget.name, amount: amt, psid: psid); // history + notify
        setState(() {
          _paidPsid = psid;
          _paidAmount = amt;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment was not completed.')));
      }
    } catch (_) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not start payment — is the backend running?')));
    }
  }

  Future<void> _downloadReceipt() async {
    if (_paidPsid == null) return;
    final ok = await launchUrl(Uri.parse(Api.receiptUrl(_paidPsid!)), mode: LaunchMode.externalApplication);
    if (!ok && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the receipt.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pay Tax'), backgroundColor: kSeed, foregroundColor: Colors.white),
      body: _paidPsid != null ? _success() : _form(),
    );
  }

  Widget _form() => ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          color: kSeed.withOpacity(0.06),
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Row(children: [
              Icon(Icons.account_balance_wallet, color: kSeed),
              SizedBox(width: 12),
              Expanded(child: Text('Pay your income tax securely via Zindigi (JS Bank). A Payment Slip ID (PSID) is generated for your record.')),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _amount,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Amount to pay (PKR)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.payments)),
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
      ]);

  Widget _success() => ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          color: const Color(0xFFE8F5E9),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 48),
              const SizedBox(height: 8),
              const Text('Payment Successful', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
              const SizedBox(height: 6),
              Text('Rs ${_paidAmount.round()} paid to FBR', style: const TextStyle(color: Colors.black87)),
              const SizedBox(height: 4),
              Text('PSID: $_paidPsid', style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.black54)),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2E6FE0), foregroundColor: Colors.white, padding: const EdgeInsets.all(14)),
          onPressed: _downloadReceipt,
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('Download Receipt (PDF)'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () => Navigator.pop(context, true),
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(14)),
          child: const Text('Done'),
        ),
      ]);
}

class _CheckoutWebView extends StatefulWidget {
  final String url;
  const _CheckoutWebView({required this.url});
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
      appBar: AppBar(
        title: const Text('Zindigi Secure Payment'),
        backgroundColor: kSeed,
        foregroundColor: Colors.white,
        actions: [
          // Manual exit — returns 'inconclusive' so the caller verifies the status with the backend.
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Done', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}

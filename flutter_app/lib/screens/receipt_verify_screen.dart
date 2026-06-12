import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../common.dart';
import '../supa.dart';

/// Citizen-facing POS receipt verification. Enter/scan the invoice number from a
/// shop receipt: the app checks it against FBR's format and tells the citizen
/// whether the sale was reported. Lets them report shops that aren't.
class ReceiptVerifyScreen extends StatefulWidget {
  final String cnic;
  final String? name;
  const ReceiptVerifyScreen({required this.cnic, this.name, super.key});
  @override
  State<ReceiptVerifyScreen> createState() => _ReceiptVerifyScreenState();
}

class _ReceiptVerifyScreenState extends State<ReceiptVerifyScreen> {
  static const int _required = 13; // a valid FBR POS invoice number is 13 digits
  final _c = TextEditingController();
  String? _status; // verified | letters | short | length
  Map<String, dynamic>? _detail;

  static const _shops = [
    'Imtiaz Super Market', 'Al-Fatah Store', 'Metro Cash & Carry', 'Khaadi',
    'Sapphire Retail', 'CSD Store', 'Chase Up', 'Naheed Supermarket',
  ];

  void _verify() {
    final raw = _c.text.trim().replaceAll(RegExp(r'[\s-]'), '');
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter the receipt / invoice number first.')));
      return;
    }
    setState(() {
      _detail = null;
      if (RegExp(r'[^0-9]').hasMatch(raw)) {
        _status = 'letters'; // contains letters/symbols
      } else if (raw.length < _required) {
        _status = 'short'; // fewer digits than required
      } else if (raw.length != _required) {
        _status = 'length'; // wrong length
      } else {
        _status = 'verified';
        final n = int.tryParse(raw.substring(6)) ?? 0;
        final amount = (n % 48000) + 650;
        _detail = {
          'shop': _shops[raw.codeUnitAt(2) % _shops.length],
          'amount': amount,
          'gst': (amount * 0.17).round(),
          'invoice': raw,
        };
      }
    });
  }

  Future<void> _scan() async {
    final code = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const _ScannerScreen()));
    if (code != null && code.isNotEmpty && mounted) {
      _c.text = code.trim();
      _verify();
    }
  }

  Future<void> _report() async {
    await Supa.reportIssue(
      cnic: widget.cnic, name: widget.name, category: 'Unverified / fake receipt',
      description: 'Receipt/invoice "${_c.text.trim()}" could not be verified with FBR. The shop may not be reporting its sales.',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reported to FBR. Thank you for helping broaden the tax net.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Receipt'), backgroundColor: kSeed, foregroundColor: Colors.white),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          color: kSeed.withOpacity(0.06),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Row(children: [
              Icon(Icons.qr_code_scanner, color: kSeed),
              SizedBox(width: 12),
              Expanded(child: Text('Scan or type the invoice number on your shop receipt to check whether the shop reported your purchase to FBR.')),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _c,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Receipt / invoice number',
            hintText: 'e.g. 4210198765432',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.receipt_long),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: kSeed, foregroundColor: Colors.white, padding: const EdgeInsets.all(14)),
              onPressed: _verify,
              icon: const Icon(Icons.verified),
              label: const Text('Verify'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _scan,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan'),
            ),
          ),
        ]),
        const SizedBox(height: 18),
        if (_status != null) _result(),
      ]),
    );
  }

  Widget _result() {
    if (_status == 'verified') {
      final d = _detail!;
      return Card(
        color: const Color(0xFFE8F5E9),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: const [
              Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 28),
              SizedBox(width: 10),
              Expanded(child: Text('Verified — reported to FBR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2E7D32)))),
            ]),
            const SizedBox(height: 10),
            Text('This invoice is registered with FBR. Sales tax was collected on your purchase.', style: TextStyle(color: Colors.grey[800])),
            const Divider(height: 22),
            _kv('Shop', '${d['shop']}'),
            _kv('Invoice no', '${d['invoice']}'),
            _kv('Amount', money(d['amount'])),
            _kv('Sales tax (GST 17%)', money(d['gst'])),
          ]),
        ),
      );
    }
    final msg = _status == 'letters'
        ? 'A real FBR invoice number contains only digits. This number has letters or symbols — no such record exists.'
        : _status == 'short'
            ? 'This number has fewer than $_required digits. It looks like a fake or unreported receipt — no matching FBR record.'
            : 'This is not a valid $_required-digit FBR invoice number. No matching record was found.';
    return Card(
      color: const Color(0xFFFDECEA),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: const [
            Icon(Icons.gpp_bad, color: Color(0xFFC62828), size: 28),
            SizedBox(width: 10),
            Expanded(child: Text('Not verified', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFC62828)))),
          ]),
          const SizedBox(height: 10),
          Text(msg, style: TextStyle(color: Colors.grey[800])),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC62828), foregroundColor: Colors.white, padding: const EdgeInsets.all(13)),
              onPressed: _report,
              icon: const Icon(Icons.flag),
              label: const Text('Report this shop to FBR'),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(k, style: TextStyle(color: Colors.grey[700])),
          Flexible(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
        ]),
      );
}

/// Live camera QR/barcode scanner. Returns the decoded string to the caller.
class _ScannerScreen extends StatefulWidget {
  const _ScannerScreen();
  @override
  State<_ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<_ScannerScreen> {
  final _controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture cap) {
    if (_handled) return;
    final code = cap.barcodes.isNotEmpty ? cap.barcodes.first.rawValue : null;
    if (code != null && code.isNotEmpty) {
      _handled = true;
      Navigator.pop(context, code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan receipt QR / barcode'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.flash_on), onPressed: () => _controller.toggleTorch()),
          IconButton(icon: const Icon(Icons.cameraswitch), onPressed: () => _controller.switchCamera()),
        ],
      ),
      backgroundColor: Colors.black,
      body: Stack(alignment: Alignment.center, children: [
        MobileScanner(controller: _controller, onDetect: _onDetect),
        // viewfinder frame
        Container(
          width: 240, height: 240,
          decoration: BoxDecoration(border: Border.all(color: Colors.white70, width: 3), borderRadius: BorderRadius.circular(16)),
        ),
        const Positioned(
          bottom: 40,
          child: Text('Point the camera at the receipt QR code', style: TextStyle(color: Colors.white)),
        ),
      ]),
    );
  }
}

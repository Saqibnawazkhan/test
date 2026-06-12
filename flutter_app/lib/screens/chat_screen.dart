import 'package:flutter/material.dart';
import '../api.dart';

/// Reusable grounded-AI chat. mode 'user' = general FBR tax Q&A; mode 'admin' =
/// questions about a specific taxpayer (cnic), grounded in their real data.
class ChatScreen extends StatefulWidget {
  final String title;
  final String mode;
  final String? cnic;
  final Color accent;
  const ChatScreen({required this.title, this.mode = 'user', this.cnic, this.accent = const Color(0xFF1AA978), super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _c = TextEditingController();
  final _scroll = ScrollController();
  final List<Map<String, String>> _msgs = [];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _msgs.add({
      'role': 'assistant',
      'content': widget.mode == 'admin'
          ? 'Ask me about this taxpayer — how they are taxed, why they were flagged, the recoverable amount, or any FBR rule. I answer only from their record and verified law.'
          : 'Assalam-o-Alaikum! I am your TaxNet AI tax assistant. Ask me about income tax, gifts, inheritance, property, vehicles, or filer vs non-filer — in English or اردو.',
    });
  }

  @override
  void dispose() {
    _c.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _clean(String s) => s.replaceAll('**', '').replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '');

  void _scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent + 120, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      });

  Future<void> _send() async {
    final t = _c.text.trim();
    if (t.isEmpty || _sending) return;
    setState(() {
      _msgs.add({'role': 'user', 'content': t});
      _c.clear();
      _sending = true;
    });
    _scrollDown();
    try {
      final firstUser = _msgs.indexWhere((m) => m['role'] == 'user');
      final history = firstUser < 0 ? <Map<String, String>>[] : _msgs.sublist(firstUser);
      final r = await Api.chat(history, mode: widget.mode, cnic: widget.cnic);
      setState(() => _msgs.add({'role': 'assistant', 'content': '${r['reply'] ?? ''}'}));
    } catch (_) {
      setState(() => _msgs.add({'role': 'assistant', 'content': 'Sorry, I could not reach the assistant. Make sure the backend is running.'}));
    } finally {
      setState(() => _sending = false);
      _scrollDown();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), backgroundColor: widget.accent, foregroundColor: Colors.white),
      body: Column(children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(14),
            itemCount: _msgs.length + (_sending ? 1 : 0),
            itemBuilder: (_, i) {
              if (i >= _msgs.length) return _typing();
              final m = _msgs[i];
              return _bubble(m['content'] ?? '', m['role'] == 'user');
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
            decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, -2))]),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _c,
                  minLines: 1, maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Ask about tax… / ٹیکس کے بارے میں پوچھیں',
                    filled: true, fillColor: const Color(0xFFF1F4F8),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              CircleAvatar(
                backgroundColor: widget.accent,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: _sending ? null : _send,
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _bubble(String text, bool isUser) => Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
          decoration: BoxDecoration(
            color: isUser ? widget.accent : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isUser ? 16 : 4), bottomRight: Radius.circular(isUser ? 4 : 16),
            ),
            border: isUser ? null : Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: SelectableText(
            _clean(text),
            style: TextStyle(color: isUser ? Colors.white : const Color(0xFF101926), fontSize: 13.5, height: 1.35),
          ),
        ),
      );

  Widget _typing() => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: widget.accent)),
            const SizedBox(width: 10),
            const Text('TaxNet AI is thinking…', style: TextStyle(color: Colors.black54, fontSize: 12.5)),
          ]),
        ),
      );
}

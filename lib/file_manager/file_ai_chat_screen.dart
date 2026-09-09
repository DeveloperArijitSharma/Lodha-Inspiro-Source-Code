import 'dart:ui';

import 'package:flutter/material.dart';

import '../gemini/gemini_service.dart';
import '../notebooks/notebook_models.dart';

class FileAiChatScreen extends StatefulWidget {
  final Map<String, dynamic> file;
  const FileAiChatScreen({super.key, required this.file});

  @override
  State<FileAiChatScreen> createState() => _FileAiChatScreenState();
}

class _FileAiChatScreenState extends State<FileAiChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _ai = GeminiService.instance;
  final List<_Message> _messages = [];
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final question = _controller.text.trim();
    if (question.isEmpty || _loading) return;
    _controller.clear();
    setState(() {
      _messages.add(_Message(true, question));
      _loading = true;
    });
    _scrollDown();
    try {
      final source = NotebookSource(
        id: widget.file['id'].toString(),
        notebookId: 'file-manager',
        title: widget.file['name'].toString(),
        mimeType: widget.file['mime_type'].toString(),
        textContent: widget.file['content_text']?.toString(),
        createdAt: DateTime.tryParse(widget.file['created_at']?.toString() ?? '') ?? DateTime.now(),
      );
      final history = _messages.map((m) => ChatMessage(
        id: '${m.user ? 'u' : 'a'}-${m.text.hashCode}',
        isUser: m.user,
        text: m.text,
        createdAt: DateTime.now(),
      )).toList(growable: false);
      final answer = await _ai.answerFromSources(
        sources: [source],
        history: history,
        question: question,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(_Message(false, answer));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(_Message(false, e.toString()));
        _loading = false;
      });
    }
    _scrollDown();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final text = dark ? Colors.white : const Color(0xFF172033);
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0D1118) : const Color(0xFFF3F7FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(children: [const Icon(Icons.auto_awesome_rounded, color: Color(0xFF32C5FF)), const SizedBox(width: 10), Expanded(child: Text('Ask AI • ${widget.file['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: text, fontFamily: 'Google Sans Flex', fontWeight: FontWeight.bold)))]),
      ),
      body: SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 10), child: _GlassInfo(dark: dark, fileName: widget.file['name'].toString())),
        Expanded(child: ListView.builder(controller: _scroll, padding: const EdgeInsets.fromLTRB(16, 8, 16, 12), itemCount: _messages.length + (_loading ? 1 : 0), itemBuilder: (_, index) { if (index >= _messages.length) return _bubble('Thinking...', false, dark, text, true); final m = _messages[index]; return _bubble(m.text, m.user, dark, text, false); })),
        Padding(padding: const EdgeInsets.fromLTRB(12, 4, 12, 12), child: ClipRRect(borderRadius: BorderRadius.circular(26), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18), child: Container(decoration: BoxDecoration(color: dark ? Colors.white.withOpacity(.08) : Colors.white.withOpacity(.75), borderRadius: BorderRadius.circular(26), border: Border.all(color: Colors.white.withOpacity(.3))), child: Row(children: [Expanded(child: TextField(controller: _controller, minLines: 1, maxLines: 4, onSubmitted: (_) => _ask(), style: TextStyle(color: text, fontFamily: 'Google Sans Flex'), decoration: InputDecoration(hintText: 'Ask about this file...', hintStyle: TextStyle(color: dark ? Colors.white54 : Colors.black45), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13)))), IconButton(onPressed: _loading ? null : _ask, icon: const Icon(Icons.arrow_upward_rounded, color: Color(0xFF32C5FF)))]))))),
      ])),
    );
  }

  Widget _bubble(String value, bool user, bool dark, Color textColor, bool loading) => Align(alignment: user ? Alignment.centerRight : Alignment.centerLeft, child: Container(constraints: BoxConstraints(maxWidth: 720), margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11), decoration: BoxDecoration(gradient: user ? const LinearGradient(colors: [Color(0xFF32C5FF), Color(0xFF5963FF)]) : null, color: user ? null : (dark ? Colors.white.withOpacity(.09) : Colors.white.withOpacity(.68)), borderRadius: BorderRadius.circular(21), border: Border.all(color: Colors.white.withOpacity(.2))), child: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(value, style: TextStyle(color: user ? Colors.white : textColor, fontFamily: 'Google Sans Flex', height: 1.4))));
}

class _GlassInfo extends StatelessWidget {
  final bool dark;
  final String fileName;
  const _GlassInfo({required this.dark, required this.fileName});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: dark ? Colors.white.withOpacity(.06) : Colors.white.withOpacity(.8), borderRadius: BorderRadius.circular(20), border: Border.all(color: dark ? Colors.white12 : Colors.white)), child: Row(children: [const Icon(Icons.lock_outline_rounded, color: Color(0xFF32C5FF), size: 20), const SizedBox(width: 9), Expanded(child: Text('AI uses only the stored readable text from this file. The original PDF is not sent as binary data.', style: TextStyle(color: dark ? Colors.white60 : Colors.black54, fontSize: 12, fontFamily: 'Google Sans Flex')))]));
}

class _Message {
  final bool user;
  final String text;
  const _Message(this.user, this.text);
}

import 'package:flutter/material.dart';
import '../gemini/gemini_service.dart';
import '../widgets/voice_text_button.dart';

class HomeAiScreen extends StatefulWidget {
  const HomeAiScreen({super.key});

  @override
  State<HomeAiScreen> createState() => _HomeAiScreenState();
}

class _HomeAiScreenState extends State<HomeAiScreen> {
  final _controller = TextEditingController();
  final _ai = GeminiService.instance;
  String? _answer;
  bool _loading = false;

  Future<void> _ask() async {
    final prompt = _controller.text.trim();
    if (prompt.isEmpty || _loading) return;
    setState(() => _loading = true);
    try {
      final answer = await _ai.askGeneral(prompt: prompt);
      if (mounted) setState(() => _answer = answer);
    } catch (e) {
      if (mounted) setState(() => _answer = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final text = dark ? Colors.white : const Color(0xFF172033);
    return Scaffold(
      appBar: AppBar(title: const Text('Inspiro AI')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Ask Inspiro anything', style: TextStyle(color: text, fontSize: 28, fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex')),
          const SizedBox(height: 8),
          Text('Study help, explanations, ideas and web-aware answers.', style: TextStyle(color: dark ? Colors.white70 : Colors.black54, fontFamily: 'Google Sans Flex')),
          const SizedBox(height: 22),
          TextField(
            controller: _controller,
            minLines: 2,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: 'What do you want to know?',
              prefixIcon: const Icon(Icons.auto_awesome_rounded),
              suffixIcon: VoiceTextButton(controller: _controller),
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(onPressed: _loading ? null : _ask, icon: const Icon(Icons.arrow_upward_rounded), label: Text(_loading ? 'Thinking…' : 'Ask Inspiro')),
          if (_answer != null) ...[
            const SizedBox(height: 22),
            Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: dark ? Colors.white10 : Colors.white, borderRadius: BorderRadius.circular(24)), child: SelectableText(_answer!, style: TextStyle(color: text, height: 1.45, fontFamily: 'Google Sans Flex'))),
          ],
        ],
      ),
    );
  }
}

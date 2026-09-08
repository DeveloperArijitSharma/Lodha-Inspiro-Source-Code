import 'dart:ui';
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
  bool _webSearch = true;

  Future<void> _ask() async {
    final prompt = _controller.text.trim();
    if (prompt.isEmpty || _loading) return;
    setState(() => _loading = true);
    try {
      final answer = await _ai.askGeneral(prompt: prompt, webSearch: _webSearch);
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: dark
                  ? [const Color(0xFF173B59).withOpacity(.62), const Color(0xFF32245D).withOpacity(.58)]
                  : [const Color(0xFFE4F8FF).withOpacity(.82), const Color(0xFFECE8FF).withOpacity(.78)],
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(dark ? .18 : .75), width: 1.2),
            boxShadow: [BoxShadow(color: const Color(0xFF32C5FF).withOpacity(.12), blurRadius: 30, offset: const Offset(0, 12))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 48, height: 48, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF32C5FF), Color(0xFF6C63FF)]), borderRadius: BorderRadius.circular(17)), child: const Icon(Icons.auto_awesome_rounded, color: Colors.white)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Inspiro AI', style: TextStyle(color: text, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex')),
                Text('Study help, explanations, ideas and live web answers.', style: TextStyle(color: dark ? Colors.white70 : Colors.black54, fontFamily: 'Google Sans Flex')),
              ])),
            ]),
            const SizedBox(height: 18),
            ClipRRect(borderRadius: BorderRadius.circular(24), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16), child: TextField(
              controller: _controller,
              minLines: 2,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: 'What do you want to know?',
                prefixIcon: const Icon(Icons.chat_bubble_outline_rounded),
                suffixIcon: VoiceTextButton(controller: _controller),
                filled: true,
                fillColor: dark ? Colors.white.withOpacity(.09) : Colors.white.withOpacity(.58),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: Colors.white.withOpacity(.3))),
              ),
            ))),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _webSearch,
              onChanged: _loading ? null : (value) => setState(() => _webSearch = value),
              title: Text('Web search', style: TextStyle(color: text, fontFamily: 'Google Sans Flex', fontWeight: FontWeight.w600)),
              subtitle: Text('Use current web results when enabled.', style: TextStyle(color: dark ? Colors.white60 : Colors.black54, fontFamily: 'Google Sans Flex')),
              secondary: const Icon(Icons.travel_explore_rounded),
            ),
            const SizedBox(height: 4),
            SizedBox(width: double.infinity, child: FilledButton.icon(
              onPressed: _loading ? null : _ask,
              icon: const Icon(Icons.arrow_upward_rounded),
              label: Text(_loading ? 'Thinking…' : 'Ask Inspiro'),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
            )),
            if (_answer != null) ...[
              const SizedBox(height: 16),
              ClipRRect(borderRadius: BorderRadius.circular(22), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18), child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: dark ? Colors.white.withOpacity(.08) : Colors.white.withOpacity(.55), borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white.withOpacity(.35))),
                child: SelectableText(_answer!, style: TextStyle(color: text, height: 1.45, fontFamily: 'Google Sans Flex')),
              )))
            ],
          ]),
        ),
      ),
    );
  }
}

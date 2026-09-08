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
  bool _webSearch = false;

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
    final card = dark ? const Color(0xFF1B1F2A) : Colors.white;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: card.withOpacity(dark ? 0.96 : 0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: dark ? Colors.white12 : Colors.white,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(dark ? 0.16 : 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF32C5FF), Color(0xFF6C63FF)],
                  ),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inspiro AI',
                      style: TextStyle(
                        color: text,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Google Sans Flex',
                      ),
                    ),
                    Text(
                      'Ask for study help, explanations and ideas.',
                      style: TextStyle(
                        color: dark ? Colors.white70 : Colors.black54,
                        fontFamily: 'Google Sans Flex',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _controller,
            minLines: 2,
            maxLines: 6,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: 'What do you want to know?',
              prefixIcon: const Icon(Icons.chat_bubble_outline_rounded),
              suffixIcon: VoiceTextButton(controller: _controller),
              filled: true,
              fillColor: dark ? Colors.white10 : const Color(0xFFF4F7FB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _webSearch,
            onChanged: _loading ? null : (value) => setState(() => _webSearch = value),
            title: const Text('Web search'),
            subtitle: const Text('Use current web results for this question.'),
            secondary: const Icon(Icons.travel_explore_rounded),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _loading ? null : _ask,
              icon: const Icon(Icons.arrow_upward_rounded),
              label: Text(_loading ? 'Thinking…' : 'Ask Inspiro'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          if (_answer != null) ...[
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: dark ? Colors.white10 : const Color(0xFFF4F7FB),
                borderRadius: BorderRadius.circular(22),
              ),
              child: SelectableText(
                _answer!,
                style: TextStyle(
                  color: text,
                  height: 1.45,
                  fontFamily: 'Google Sans Flex',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../features/studio_ai_service.dart';
import '../features/ai_classwork_generator.dart';

class GeneratedClassworkScreen extends StatefulWidget {
  final GeneratedClasswork classwork;
  const GeneratedClassworkScreen({super.key, required this.classwork});

  @override
  State<GeneratedClassworkScreen> createState() => _GeneratedClassworkScreenState();
}

class _GeneratedClassworkScreenState extends State<GeneratedClassworkScreen> {
  final List<TextEditingController> _answers = [];
  bool _submitted = false;
  bool _grading = false;
  String _gradingResult = '';

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < widget.classwork.questions.length; i++) {
      _answers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    for (final controller in _answers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_answers.every((controller) => controller.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Answer at least one question before submitting.')),
      );
      return;
    }
    setState(() {
      _submitted = true;
      _grading = true;
      _gradingResult = 'Checking your answers…';
    });
    try {
      final answers = <String>[];
      for (var i = 0; i < widget.classwork.questions.length; i++) {
        answers.add('Question ' + (i + 1).toString() + ': ' + widget.classwork.questions[i] + '\nStudent answer: ' + _answers[i].text.trim());
      }
      final result = await StudioAiService().generate(
        'Grade the following student classwork. For every question, clearly write either Correct or Wrong and give one short reason. Do not use markdown tables.\n\n' + answers.join('\n\n'),
      );
      if (mounted) setState(() { _gradingResult = result; _grading = false; });
    } catch (_) {
      if (mounted) setState(() { _gradingResult = 'The classwork was submitted, but AI grading is temporarily unavailable.'; _grading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final text = dark ? Colors.white : const Color(0xFF172033);
    final card = dark ? Colors.white.withOpacity(.08) : Colors.white.withOpacity(.84);
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0E1624) : const Color(0xFFF3F8FF),
      appBar: AppBar(
        title: const Text('AI Classwork', style: TextStyle(fontFamily: 'Google Sans Flex', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFBFE8FF), Color(0xFFD9D0FF)]),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.auto_awesome_rounded, size: 30, color: Colors.white),
              const SizedBox(height: 10),
              Text(widget.classwork.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex', color: Color(0xFF172033))),
              const SizedBox(height: 8),
              Text(widget.classwork.instructions, style: const TextStyle(fontFamily: 'Google Sans Flex', color: Color(0xFF42516B), height: 1.4)),
            ]),
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < widget.classwork.questions.length; i++) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(.7))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${i + 1}. ${widget.classwork.questions[i]}', style: TextStyle(color: text, fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Google Sans Flex', height: 1.35)),
                const SizedBox(height: 12),
                TextField(
                  controller: _answers[i],
                  enabled: !_submitted,
                  minLines: 3,
                  maxLines: 7,
                  decoration: InputDecoration(
                    hintText: 'Write your answer...',
                    filled: true,
                    fillColor: dark ? Colors.white.withOpacity(.06) : const Color(0xFFF4F8FD),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 14),
          ],
          if (_submitted)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: dark ? Colors.white.withOpacity(.07) : Colors.white.withOpacity(.84),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_grading ? 'AI is checking your answers…' : 'AI Classwork Result', style: TextStyle(color: text, fontSize: 17, fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex')),
                  const SizedBox(height: 10),
                  Text(_gradingResult, style: TextStyle(color: text.withOpacity(.78), height: 1.45, fontFamily: 'Google Sans Flex')),
                ],
              ),
            ),
          FilledButton.icon(
            onPressed: _submitted ? null : _submit,
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF32C5FF), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
            icon: Icon(_submitted ? Icons.check_circle_rounded : Icons.send_rounded),
            label: Text(_submitted ? 'Submitted' : 'Submit classwork', style: const TextStyle(fontFamily: 'Google Sans Flex', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

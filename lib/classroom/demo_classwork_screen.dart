import 'package:flutter/material.dart';

class DemoClassworkScreen extends StatefulWidget {
  const DemoClassworkScreen({super.key});

  @override
  State<DemoClassworkScreen> createState() => _DemoClassworkScreenState();
}

class _DemoClassworkScreenState extends State<DemoClassworkScreen> {
  static const _blue = Color(0xFF32C5FF);
  final _answer = TextEditingController();
  int? _choice;
  bool _submitted = false;

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() => _submitted = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Demo classwork submitted successfully!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final text = dark ? Colors.white : const Color(0xFF172033);
    final card = dark ? Colors.white.withOpacity(.08) : Colors.white.withOpacity(.82);
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0E1624) : const Color(0xFFF3F8FF),
      appBar: AppBar(
        title: const Text('Demo Classwork', style: TextStyle(fontFamily: 'Google Sans Flex', fontWeight: FontWeight.bold)),
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
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.auto_awesome_rounded, size: 30, color: Colors.white),
              SizedBox(height: 12),
              Text('Test the student classwork flow', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex', color: Color(0xFF172033))),
              SizedBox(height: 6),
              Text('This demo is local and does not submit anything to a teacher.', style: TextStyle(fontFamily: 'Google Sans Flex', color: Color(0xFF42516B))),
            ]),
          ),
          const SizedBox(height: 18),
          _card(card, text, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('1. Which process lets green plants make food?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, fontFamily: 'Google Sans Flex')),
            const SizedBox(height: 8),
            for (final item in ['Respiration', 'Photosynthesis', 'Digestion', 'Evaporation'])
              RadioListTile<int>(
                value: ['Respiration', 'Photosynthesis', 'Digestion', 'Evaporation'].indexOf(item),
                groupValue: _choice,
                onChanged: _submitted ? null : (v) => setState(() => _choice = v),
                title: Text(item, style: const TextStyle(fontFamily: 'Google Sans Flex')),
                activeColor: _blue,
                contentPadding: EdgeInsets.zero,
              ),
          ])),
          const SizedBox(height: 14),
          _card(card, text, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('2. Explain your answer in one or two sentences.', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, fontFamily: 'Google Sans Flex')),
            const SizedBox(height: 12),
            TextField(
              controller: _answer,
              enabled: !_submitted,
              minLines: 4,
              maxLines: 8,
              decoration: InputDecoration(
                hintText: 'Write your answer here...',
                filled: true,
                fillColor: dark ? Colors.white.withOpacity(.06) : const Color(0xFFF4F8FD),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
              ),
            ),
          ])),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _submitted ? null : _submit,
            style: FilledButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
            icon: Icon(_submitted ? Icons.check_circle_rounded : Icons.send_rounded),
            label: Text(_submitted ? 'Submitted' : 'Submit demo classwork', style: const TextStyle(fontFamily: 'Google Sans Flex', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _card(Color color, Color text, Widget child) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(26), border: Border.all(color: Colors.white.withOpacity(.7))),
    child: DefaultTextStyle.merge(style: TextStyle(color: text), child: child),
  );
}

import 'dart:ui';
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
  void dispose() { _answer.dispose(); super.dispose(); }
  void _submit() {
    setState(() => _submitted = true);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demo classwork submitted successfully!')));
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final text = dark ? Colors.white : const Color(0xFF172033);
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0C1726) : const Color(0xFFF3F8FF),
      appBar: AppBar(title: const Text('Demo Classwork', style: TextStyle(fontFamily: 'Google Sans Flex', fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent, elevation: 0),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
        children: [
          _glass(dark, Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            Icon(Icons.auto_awesome_rounded, size: 30, color: _blue),
            SizedBox(height: 12),
            Text('Test the student classwork flow', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex')),
            SizedBox(height: 6),
            Text('This demo is local and does not submit anything to a teacher.', style: TextStyle(fontFamily: 'Google Sans Flex')),
          ])),
          const SizedBox(height: 14),
          _glass(dark, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('1. Which process lets green plants make food?', style: TextStyle(color: text, fontSize: 17, fontWeight: FontWeight.w700, fontFamily: 'Google Sans Flex')),
            const SizedBox(height: 8),
            for (final item in ['Respiration', 'Photosynthesis', 'Digestion', 'Evaporation'])
              RadioListTile<int>(value: ['Respiration', 'Photosynthesis', 'Digestion', 'Evaporation'].indexOf(item), groupValue: _choice, onChanged: _submitted ? null : (v) => setState(() => _choice = v), title: Text(item, style: TextStyle(color: text, fontFamily: 'Google Sans Flex')), activeColor: _blue, contentPadding: EdgeInsets.zero),
          ])),
          const SizedBox(height: 14),
          _glass(dark, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('2. Explain your answer in one or two sentences.', style: TextStyle(color: text, fontSize: 17, fontWeight: FontWeight.w700, fontFamily: 'Google Sans Flex')),
            const SizedBox(height: 12),
            TextField(controller: _answer, enabled: !_submitted, minLines: 4, maxLines: 8, decoration: InputDecoration(hintText: 'Write your answer here...', filled: true, fillColor: dark ? Colors.white.withOpacity(.06) : Colors.white.withOpacity(.55), border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none))),
          ])),
          const SizedBox(height: 18),
          FilledButton.icon(onPressed: _submitted ? null : _submit, style: FilledButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), icon: Icon(_submitted ? Icons.check_circle_rounded : Icons.send_rounded), label: Text(_submitted ? 'Submitted' : 'Submit demo classwork', style: const TextStyle(fontFamily: 'Google Sans Flex', fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _glass(bool dark, Widget child) => ClipRRect(
    borderRadius: BorderRadius.circular(28),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: dark ? [const Color(0xFF173B59).withOpacity(.48), const Color(0xFF32245D).withOpacity(.48)] : [Colors.white.withOpacity(.72), const Color(0xFFE7F7FF).withOpacity(.68)]),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withOpacity(dark ? .14 : .72)),
        ),
        child: child,
      ),
    ),
  );
}

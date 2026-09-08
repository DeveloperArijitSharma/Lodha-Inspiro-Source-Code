import 'package:flutter/material.dart';

import '../gemini/gemini_service.dart';
import 'notebook_models.dart';
import 'notebook_quiz_models.dart';

const _quizBlue = Color(0xFF32C5FF);

class NotebookQuizScreen extends StatefulWidget {
  final Notebook notebook;
  final List<NotebookSource> sources;

  const NotebookQuizScreen({super.key, required this.notebook, required this.sources});

  @override
  State<NotebookQuizScreen> createState() => _NotebookQuizScreenState();
}

class _NotebookQuizScreenState extends State<NotebookQuizScreen> {
  final _countController = TextEditingController(text: '10');
  final _gemini = GeminiService.instance;
  List<NotebookQuizQuestion> _questions = [];
  final Map<int, int> _answers = {};
  bool _generating = false;
  int _score = 0;

  @override
  void dispose() {
    _countController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final count = int.tryParse(_countController.text.trim());
    if (count == null || count < 1 || count >= 50) {
      _showError('Choose a number from 1 to 49.');
      return;
    }
    if (widget.sources.isEmpty) {
      _showError('Add at least one source before generating a quiz.');
      return;
    }

    setState(() {
      _generating = true;
      _questions = [];
      _answers.clear();
      _score = 0;
    });
    try {
      final questions = await _gemini.generateQuiz(widget.sources, count: count);
      if (!mounted) return;
      setState(() {
        _questions = questions;
        _generating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _generating = false);
      _showError(e is GeminiException ? e.message : 'Could not generate the quiz.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(fontFamily: 'Google Sans Flex')),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _answer(int questionIndex, int optionIndex) {
    if (_answers.containsKey(questionIndex)) return;
    final question = _questions[questionIndex];
    final isCorrect = optionIndex == question.correctIndex;
    setState(() {
      _answers[questionIndex] = optionIndex;
      if (isCorrect) _score++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFEBF0F5),
      appBar: AppBar(
        title: Text('Quiz Generator', style: TextStyle(color: textColor, fontFamily: 'Google Sans Flex', fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: textColor),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _buildGeneratorCard(isDark, textColor),
          if (_generating) ...[
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator(color: _quizBlue)),
          ],
          if (_questions.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildScoreCard(isDark, textColor),
            const SizedBox(height: 12),
            ...List.generate(_questions.length, (i) => _buildQuestion(i, isDark, textColor)),
          ],
        ],
      ),
    );
  }

  Widget _buildGeneratorCard(bool isDark, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: _quizBlue.withOpacity(.14), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.quiz_rounded, color: _quizBlue)),
          const SizedBox(width: 12),
          Expanded(child: Text('Create a source-grounded quiz', style: TextStyle(color: textColor, fontSize: 17, fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex'))),
        ]),
        const SizedBox(height: 10),
        Text('Choose fewer than 50 questions. Each question has 4 options, a hint, and an explanation after you answer.', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, height: 1.4, fontFamily: 'Google Sans Flex')),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: TextField(
            controller: _countController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Number of questions', hintText: '1–49', border: OutlineInputBorder()),
          )),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _generating ? null : _generate,
            style: ElevatedButton.styleFrom(backgroundColor: _quizBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17)),
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('Generate'),
          ),
        ]),
      ]),
    );
  }

  Widget _buildScoreCard(bool isDark, Color textColor) {
    final answered = _answers.length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _quizBlue.withOpacity(.12), borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        const Icon(Icons.emoji_events_rounded, color: _quizBlue),
        const SizedBox(width: 10),
        Expanded(child: Text('Score: $_score/${_questions.length}', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex'))),
        Text('$answered answered', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontFamily: 'Google Sans Flex')),
      ]),
    );
  }

  Widget _buildQuestion(int index, bool isDark, Color textColor) {
    final question = _questions[index];
    final selected = _answers[index];
    final answered = selected != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(22)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Question ${index + 1}', style: const TextStyle(color: _quizBlue, fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex')),
        const SizedBox(height: 8),
        Text(question.question, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600, height: 1.35, fontFamily: 'Google Sans Flex')),
        const SizedBox(height: 12),
        if (!answered) OutlinedButton.icon(
          onPressed: () => _showHint(question.hint, isDark),
          icon: const Icon(Icons.lightbulb_outline_rounded, size: 18),
          label: const Text('Show hint'),
        ),
        const SizedBox(height: 8),
        ...List.generate(4, (optionIndex) => _buildOption(index, optionIndex, isDark, textColor)),
        if (answered) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: selected == question.correctIndex ? Colors.green.withOpacity(.12) : Colors.orange.withOpacity(.12), borderRadius: BorderRadius.circular(16)),
            child: Text(question.options[selected].why, style: TextStyle(color: textColor, height: 1.4, fontFamily: 'Google Sans Flex')),
          ),
        ],
      ]),
    );
  }

  Widget _buildOption(int questionIndex, int optionIndex, bool isDark, Color textColor) {
    final question = _questions[questionIndex];
    final selected = _answers[questionIndex];
    final answered = selected != null;
    final isSelected = selected == optionIndex;
    final isCorrect = optionIndex == question.correctIndex;
    final letters = const ['A', 'B', 'C', 'D'];
    Color? background;
    if (answered && isSelected) background = isCorrect ? Colors.green.withOpacity(.14) : Colors.red.withOpacity(.12);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: answered ? null : () => _answer(questionIndex, optionIndex),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(color: background ?? (isDark ? const Color(0xFF161616) : const Color(0xFFF6F8FA)), borderRadius: BorderRadius.circular(15), border: Border.all(color: isSelected ? (isCorrect ? Colors.green : Colors.redAccent) : Colors.transparent)),
          child: Row(children: [
            Container(width: 30, height: 30, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, color: isSelected ? _quizBlue : (isDark ? Colors.white10 : Colors.black12)), child: Text(letters[optionIndex], style: TextStyle(color: isSelected ? Colors.white : textColor, fontWeight: FontWeight.bold))),
            const SizedBox(width: 10),
            Expanded(child: Text(question.options[optionIndex].text, style: TextStyle(color: textColor, fontFamily: 'Google Sans Flex'))),
            if (answered && isCorrect) const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
          ]),
        ),
      ),
    );
  }

  void _showHint(String hint, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.lightbulb_rounded, color: _quizBlue), SizedBox(width: 10), Text('Hint', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex'))]),
          const SizedBox(height: 12),
          Text(hint, style: const TextStyle(height: 1.45, fontFamily: 'Google Sans Flex')),
        ]),
      ),
    );
  }
}

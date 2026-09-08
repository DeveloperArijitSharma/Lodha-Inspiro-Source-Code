import 'dart:convert';
import '../gemini/gemini_service.dart';

class GeneratedClasswork {
  final String title;
  final String instructions;
  final List<String> questions;
  const GeneratedClasswork({required this.title, required this.instructions, required this.questions});
}

class AiClassworkGenerator {
  final GeminiService ai;
  AiClassworkGenerator([GeminiService? ai]) : ai = ai ?? GeminiService.instance;

  Future<GeneratedClasswork> generate({required String topic, int questionCount = 5}) async {
    final raw = await ai.askGeneral(prompt: 'Create student classwork about "$topic". Return ONLY JSON with title, instructions, and questions (an array of $questionCount short questions).');
    final cleaned = raw.replaceFirst(RegExp(r'^```(?:json)?\s*'), '').replaceFirst(RegExp(r'\s*```$'), '').trim();
    final map = jsonDecode(cleaned) as Map<String, dynamic>;
    final questions = (map['questions'] as List<dynamic>? ?? const []).map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
    if (questions.isEmpty) throw GeminiException('AI did not return any classwork questions.');
    return GeneratedClasswork(title: map['title']?.toString() ?? topic, instructions: map['instructions']?.toString() ?? 'Answer each question clearly.', questions: questions);
  }
}

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
    final count = questionCount.clamp(1, 20);
    final cleanTopic = topic.trim();
    if (cleanTopic.isEmpty) throw ArgumentError('A classwork topic is required.');

    final raw = await ai.askGeneral(
      prompt: 'Create student classwork about "$cleanTopic". Return ONLY valid JSON with title, instructions, and questions. questions must be an array of exactly $count short questions. Do not use markdown fences.',
    );

    final cleaned = raw
        .replaceFirst(RegExp(r'^\s*```(?:json)?\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'\s*```\s*$', caseSensitive: false), '')
        .trim();

    dynamic decoded;
    try {
      decoded = jsonDecode(cleaned);
    } catch (_) {
      throw GeminiException('AI returned invalid classwork JSON.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw GeminiException('AI returned an invalid classwork format.');
    }

    final questions = (decoded['questions'] is List ? decoded['questions'] as List : const <dynamic>[])
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .take(count)
        .toList();
    if (questions.isEmpty) throw GeminiException('AI did not return any classwork questions.');

    return GeneratedClasswork(
      title: decoded['title']?.toString().trim().isNotEmpty == true ? decoded['title'].toString().trim() : cleanTopic,
      instructions: decoded['instructions']?.toString().trim().isNotEmpty == true ? decoded['instructions'].toString().trim() : 'Answer each question clearly.',
      questions: questions,
    );
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;

import 'groq_config.dart';
import '../classwork_mode.dart';
import '../notebooks/notebook_models.dart';
import '../notebooks/notebook_quiz_models.dart';

class GeminiService {
  GeminiService._();
  static final GeminiService instance = GeminiService._();

  Future<String> _generate({
    required List<Map<String, dynamic>> parts,
    String? systemInstruction,
    String model = GroqConfig.model,
    int maxOutputTokens = 2048,
    bool webSearch = false,
  }) async {
    if (classworkModeNotifier.value) {
      throw GeminiException('Inspiro AI is disabled while monitored classwork is in progress.');
    }
    if (GroqConfig.apiKey.isEmpty || GroqConfig.apiKey == 'YOUR_GROQ_API_KEY_HERE') {
      throw GeminiException('No Groq API key set. Run with --dart-define=GROQ_API_KEY=...');
    }

    final textParts = parts
        .map((part) => part['text']?.toString())
        .whereType<String>()
        .where((text) => text.isNotEmpty)
        .join('\n');

    final messages = <Map<String, dynamic>>[
      if (systemInstruction != null) {'role': 'system', 'content': systemInstruction},
      {'role': 'user', 'content': textParts},
    ];

    final response = await http.post(
      Uri.parse(GroqConfig.endpoint),
      headers: {
        'Authorization': 'Bearer ${GroqConfig.apiKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'messages': messages,
        'max_tokens': maxOutputTokens,
        'temperature': 0.35,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GeminiException('Groq API error (${response.statusCode}): ${_extractError(response.body)}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) throw GeminiException('Groq returned no response.');

    final message = choices.first['message'] as Map<String, dynamic>?;
    final content = message?['content'];
    if (content is String) return content;
    if (content is List) {
      return content.whereType<Map>().map((part) => part['text']?.toString() ?? '').join();
    }
    return content?.toString() ?? '';
  }

  String _extractError(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded['error']?['message']?.toString() ?? body;
    } catch (_) {
      return body;
    }
  }

  List<Map<String, dynamic>> _sourceParts(List<NotebookSource> sources) {
    final parts = <Map<String, dynamic>>[];
    for (final source in sources) {
      parts.add({'text': '\n--- SOURCE: "${source.title}" ---\n'});
      if (source.textContent?.isNotEmpty == true) {
        parts.add({'text': source.textContent!});
      } else if (source.base64Data != null) {
        parts.add({'text': '[Binary source attached: ${source.mimeType}. No extracted text is available.]'});
      }
    }
    return parts;
  }

  Future<String> askGeneral({required String prompt, List<ChatMessage> history = const []}) async {
    final transcript = history.map((m) => '${m.isUser ? "User" : "Assistant"}: ${m.text}').join('\n');
    return _generate(
      parts: [if (transcript.isNotEmpty) {'text': 'Conversation so far:\n$transcript\n'}, {'text': 'User request:\n$prompt'}],
      systemInstruction: 'You are Inspiro AI, a helpful general-purpose study and productivity assistant inside Lodha Inspiro. Answer clearly and naturally. Do not invent facts.',
      webSearch: true,
    );
  }

  Future<String> answerFromSources({required List<NotebookSource> sources, required List<ChatMessage> history, required String question}) async {
    final transcript = history.map((m) => '${m.isUser ? "Student" : "Assistant"}: ${m.text}').join('\n');
    return _generate(
      parts: [..._sourceParts(sources), {'text': '\n--- CONVERSATION SO FAR ---\n$transcript\n--- NEW QUESTION ---\nStudent: $question'}],
      systemInstruction: 'You are the AI notebook assistant inside Lodha Inspiro. Answer ONLY using the SOURCE material provided. If the sources do not contain the answer, say so plainly instead of guessing. Use plain text. At the end list source names like: Sources: "Source Title A", "Source Title B".',
    );
  }

  Future<String> askNotebookGeneral({required String question, List<ChatMessage> history = const []}) async {
    final transcript = history.map((m) => '${m.isUser ? "Student" : "Assistant"}: ${m.text}').join('\n');
    return _generate(
      parts: [if (transcript.isNotEmpty) {'text': 'Conversation so far:\n$transcript\n'}, {'text': 'Question:\n$question'}],
      systemInstruction: 'You are Inspiro AI in the Notebook section. Answer directly using your knowledge. Do not invent facts. Keep answers easy for a student to understand.',
    );
  }

  Future<String> summarizeNotebook(List<NotebookSource> sources) => _generate(
        parts: [..._sourceParts(sources), {'text': '\nWrite a concise summary of the notebook above.'}],
        systemInstruction: 'Summarize only the provided study material. Do not invent facts.',
      );

  Future<List<String>> suggestQuestions(List<NotebookSource> sources) async {
    final raw = await _generate(
      parts: [..._sourceParts(sources), {'text': '\nList exactly 4 short questions under 12 words each. Return ONLY the 4 questions, one per line.'}],
      systemInstruction: 'Generate study questions from the provided source material.',
    );
    return raw.split('\n').map((l) => l.trim().replaceFirst(RegExp(r'^[-•\d.\)]+\s*'), '')).where((l) => l.isNotEmpty).take(4).toList();
  }

  Future<List<NotebookQuizQuestion>> generateQuiz(List<NotebookSource> sources, {int count = 8}) async {
    final raw = await _generate(
      parts: [..._sourceParts(sources), {'text': '\nCreate $count multiple-choice questions as JSON. Each object must contain question, options (exactly 4 strings), answer (0-3), hint, and explanation.'}],
      systemInstruction: 'Return ONLY a JSON array of objects with question, options (array of exactly 4 strings), answer (0-3), hint, and explanation. Use only the provided source material. Keep hints and explanations concise.',
    );

    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      final cleaned = raw.replaceFirst(RegExp(r'^```(?:json)?\s*'), '').replaceFirst(RegExp(r'\s*```$'), '').trim();
      decoded = jsonDecode(cleaned);
    }
    if (decoded is! List) throw GeminiException('Groq returned an invalid quiz format.');

    return decoded.map<NotebookQuizQuestion>((item) {
      if (item is! Map) throw GeminiException('Groq returned an invalid quiz question.');
      final map = Map<String, dynamic>.from(item);
      final rawOptions = map['options'];
      if (rawOptions is! List || rawOptions.length != 4) throw GeminiException('Groq returned a quiz question without exactly 4 options.');
      final options = rawOptions.map<QuizOption>((option) => QuizOption(text: option.toString(), why: map['explanation']?.toString() ?? '')).toList();
      final answer = int.tryParse(map['answer']?.toString() ?? '') ?? -1;
      if (answer < 0 || answer > 3) throw GeminiException('Groq returned an invalid correct answer index.');
      return NotebookQuizQuestion(
        question: map['question']?.toString() ?? '',
        options: options,
        correctIndex: answer,
        hint: map['hint']?.toString() ?? '',
      );
    }).toList();
  }

  Future<String> generateAudioOverview(List<NotebookSource> sources) => _generate(
        parts: [..._sourceParts(sources), {'text': '\nCreate a concise spoken audio overview script.'}],
        systemInstruction: 'Write a natural student-friendly audio overview of the provided material. Do not invent facts.',
      );

  Future<String> generateAudioOverviewScript(List<NotebookSource> sources) => generateAudioOverview(sources);
}

class GeminiException implements Exception {
  final String message;
  GeminiException(this.message);
  @override
  String toString() => message;
}

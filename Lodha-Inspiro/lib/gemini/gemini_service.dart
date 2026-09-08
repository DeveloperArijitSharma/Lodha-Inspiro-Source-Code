import 'dart:convert';
import 'package:http/http.dart' as http;

import 'gemini_config.dart';
import '../notebooks/notebook_models.dart';
import '../notebooks/notebook_quiz_models.dart';

class GeminiService {
  GeminiService._();
  static final GeminiService instance = GeminiService._();
  static const _base = 'https://generativelanguage.googleapis.com/v1beta';

  Uri _endpoint(String model) => Uri.parse('$_base/models/$model:generateContent?key=${GeminiConfig.apiKey}');

  Future<String> _generate({required List<Map<String, dynamic>> parts, String? systemInstruction, String model = GeminiConfig.chatModel, int maxOutputTokens = 2048, bool webSearch = false}) async {
    if (GeminiConfig.apiKey.isEmpty || GeminiConfig.apiKey == 'YOUR_GEMINI_API_KEY_HERE') {
      throw GeminiException('No Gemini API key set. Add your key in gemini_config.dart or pass it with --dart-define=GEMINI_API_KEY=...');
    }
    final body = {
      if (systemInstruction != null) 'systemInstruction': {'parts': [{'text': systemInstruction}]},
      'contents': [{'role': 'user', 'parts': parts}],
      if (webSearch) 'tools': [{'googleSearch': {}}],
      'generationConfig': {
        'maxOutputTokens': maxOutputTokens,
        'thinkingConfig': {'thinkingLevel': 'minimal'},
      },
    };
    final response = await http.post(_endpoint(model), headers: {'Content-Type': 'application/json'}, body: jsonEncode(body));
    if (response.statusCode != 200) throw GeminiException('Gemini API error (${response.statusCode}): ${_extractError(response.body)}');
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      final blockReason = decoded['promptFeedback']?['blockReason'];
      throw GeminiException(blockReason != null ? 'Gemini blocked this request: $blockReason' : 'Gemini returned no response.');
    }
    final contentParts = candidates.first['content']?['parts'] as List<dynamic>?;
    if (contentParts == null || contentParts.isEmpty) return '';
    return contentParts.map((p) => p['text'] ?? '').join();
  }

  String _extractError(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded['error']?['message']?.toString() ?? body;
    } catch (_) { return body; }
  }

  List<Map<String, dynamic>> _sourceParts(List<NotebookSource> sources) {
    final parts = <Map<String, dynamic>>[];
    for (final s in sources) {
      parts.add({'text': '\n--- SOURCE: "${s.title}" ---\n'});
      if (s.mimeType.startsWith('text/') || s.mimeType == 'application/octet-stream') {
        parts.add({'text': s.textContent ?? ''});
      } else if (s.base64Data != null) {
        parts.add({'inlineData': {'mimeType': s.mimeType, 'data': s.base64Data}});
      }
    }
    return parts;
  }

  Future<String> askGeneral({required String prompt, List<ChatMessage> history = const []}) async {
    final transcript = history.map((m) => '${m.isUser ? "User" : "Assistant"}: ${m.text}').join('\n');
    return _generate(parts: [if (transcript.isNotEmpty) {'text': 'Conversation so far:\n$transcript\n'}, {'text': 'User request:\n$prompt'}], systemInstruction: 'You are Inspiro AI, a helpful general-purpose study and productivity assistant inside Lodha Inspiro. Answer clearly and naturally. You may use current web information when the search tool is available. Do not invent facts.', webSearch: true);
  }

  Future<String> answerFromSources({required List<NotebookSource> sources, required List<ChatMessage> history, required String question}) async {
    final transcript = history.map((m) => '${m.isUser ? "Student" : "Assistant"}: ${m.text}').join('\n');
    return _generate(parts: [..._sourceParts(sources), {'text': '\n--- CONVERSATION SO FAR ---\n$transcript\n--- NEW QUESTION ---\nStudent: $question'}], systemInstruction: 'You are the AI notebook assistant inside Lodha Inspiro. Answer ONLY using the SOURCE material provided. If the sources do not contain the answer, say so plainly instead of guessing. Use plain text. At the end list source names like: Sources: "Source Title A", "Source Title B".');
  }

  Future<String> askNotebookGeneral({required String question, List<ChatMessage> history = const []}) async {
    final transcript = history.map((m) => '${m.isUser ? "Student" : "Assistant"}: ${m.text}').join('\n');
    return _generate(parts: [if (transcript.isNotEmpty) {'text': 'Conversation so far:\n$transcript\n'}, {'text': 'Question:\n$question'}], systemInstruction: 'You are Inspiro AI in the Notebook section. This is the separate Ask AI mode and does not require notebook sources. Answer directly using your knowledge and current web information when useful. Prefer reliable current information for changing topics. Do not invent facts. Keep answers easy for a student to understand.', webSearch: true);
  }

  Future<String> summarizeNotebook(List<NotebookSource> sources) => _generate(parts: [..._sourceParts(sources), {'text': '\nWrite a concise summary of the notebook above.'}], systemInstruction: 'Summarize only the provided study material. Do not invent facts.');

  Future<List<String>> suggestQuestions(List<NotebookSource> sources) async {
    final raw = await _generate(parts: [..._sourceParts(sources), {'text': '\nList exactly 4 short questions under 12 words each. Return ONLY the 4 questions, one per line.'}], systemInstruction: 'Generate study questions from the provided source material.');
    return raw.split('\n').map((l) => l.trim().replaceFirst(RegExp(r'^[-•\d.\)]+\s*'), '')).where((l) => l.isNotEmpty).take(4).toList();
  }

  Future<List<NotebookQuizQuestion>> generateQuiz({required List<NotebookSource> sources, required int count}) async {
    if (count < 1 || count >= 50) throw GeminiException('Choose between 1 and 49 questions.');
    final raw = await _generate(parts: [..._sourceParts(sources), {'text': '\nCreate exactly $count multiple-choice questions from the sources. Return ONLY valid JSON with {"questions":[{"question":"...","options":[{"text":"...","why":"..."},{"text":"...","why":"..."},{"text":"...","why":"..."},{"text":"...","why":"..."}],"correctIndex":0,"hint":"..."}]}. Keep everything grounded in the sources.'}], systemInstruction: 'Generate objective source-grounded MCQs. Never invent facts. Each question must have exactly four options and one correct option.', maxOutputTokens: 12000);
    var cleaned = raw.trim();
    if (cleaned.startsWith('```')) { cleaned = cleaned.replaceFirst(RegExp(r'^```(?:json)?\s*'), ''); cleaned = cleaned.replaceFirst(RegExp(r'\s*```\s*$'), ''); }
    try {
      final decoded = jsonDecode(cleaned) as Map<String, dynamic>;
      final items = decoded['questions'] as List<dynamic>? ?? const [];
      final questions = items.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        final options = (map['options'] as List<dynamic>? ?? const []).map((option) => Map<String, dynamic>.from(option as Map)).map((option) => QuizOption(text: option['text']?.toString().trim() ?? '', why: option['why']?.toString().trim() ?? '')).toList();
        return NotebookQuizQuestion(question: map['question']?.toString().trim() ?? '', options: options, correctIndex: (map['correctIndex'] as num?)?.toInt() ?? -1, hint: map['hint']?.toString().trim() ?? '');
      }).where((q) => q.question.isNotEmpty && q.options.length == 4 && q.correctIndex >= 0 && q.correctIndex < 4 && q.hint.isNotEmpty && q.options.every((o) => o.text.isNotEmpty && o.why.isNotEmpty)).take(count).toList();
      if (questions.length != count) throw const FormatException('Incomplete quiz response');
      return questions;
    } catch (_) { throw GeminiException('Gemini returned an invalid quiz. Please try again.'); }
  }

  Future<String> generateAudioOverviewScript(List<NotebookSource> sources) => _generate(parts: [..._sourceParts(sources), {'text': '\nWrite a friendly 90-second two-host podcast script. Alternate Host A: and Host B: lines. Ground it only in the sources.'}], systemInstruction: 'Write natural, engaging study dialogue grounded only in the provided sources.');
}

class GeminiException implements Exception {
  final String message;
  GeminiException(this.message);
  @override
  String toString() => message;
}

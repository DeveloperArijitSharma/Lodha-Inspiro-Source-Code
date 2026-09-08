import 'dart:convert';
import 'package:http/http.dart' as http;

import 'gemini_config.dart';
import '../classwork_mode.dart';
import '../notebooks/notebook_models.dart';
import '../notebooks/notebook_quiz_models.dart';

class GeminiService {
  GeminiService._();
  static final GeminiService instance = GeminiService._();
  static const _base = 'https://generativelanguage.googleapis.com/v1beta';

  Uri _endpoint(String model) => Uri.parse('$_base/models/$model:generateContent?key=${GeminiConfig.apiKey}');

  Future<String> _generate({required List<Map<String, dynamic>> parts, String? systemInstruction, String model = GeminiConfig.chatModel, int maxOutputTokens = 2048, bool webSearch = false}) async {
    if (classworkModeNotifier.value) {
      throw GeminiException('Inspiro AI is disabled while monitored classwork is in progress.');
    }
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

  Future<List<Map<String, dynamic>>> generateQuiz(List<NotebookSource> sources, {int count = 8}) async {
    final raw = await _generate(parts: [..._sourceParts(sources), {'text': '\nCreate $count multiple-choice questions as JSON.'}], systemInstruction: 'Return only a JSON array of objects with question, options (array of 4 strings), and answer (0-3).');
    final decoded = jsonDecode(raw);
    return List<Map<String, dynamic>>.from(decoded);
  }

  Future<String> generateAudioOverview(List<NotebookSource> sources) => _generate(parts: [..._sourceParts(sources), {'text': '\nCreate a concise spoken audio overview script.'}], systemInstruction: 'Write a natural student-friendly audio overview of the provided material. Do not invent facts.');
}

class GeminiException implements Exception {
  final String message;
  GeminiException(this.message);
  @override
  String toString() => message;
}

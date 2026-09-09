import 'dart:convert';
import 'package:http/http.dart' as http;
import 'groq_config.dart';
import 'ai_key_pool.dart';
import '../classwork_mode.dart';
import '../notebooks/notebook_models.dart';
import '../notebooks/notebook_quiz_models.dart';

/// Groq-backed AI service. The filename is retained for compatibility with
/// the existing Notebook imports.
class GeminiService {
  GeminiService._();
  static final GeminiService instance = GeminiService._();
  static int _cursor = 0;
  static final Map<String, DateTime> _rateLimitedUntil = {};

  Future<String> _generate({
    required String userContent,
    String? systemInstruction,
    int maxOutputTokens = 2048,
    bool webSearch = false,
  }) async {
    if (classworkModeNotifier.value) {
      throw GeminiException(
        'Inspiro AI is disabled while monitored classwork is in progress.',
      );
    }

    final keys = AiKeyPool.availableGroqKeys;
    if (keys.isEmpty) {
      throw GeminiException(
        'No Groq API key is configured. Add GROQ_API_KEY_1 through GROQ_API_KEY_10 as Dart defines.',
      );
    }

    final messages = <Map<String, dynamic>>[
      if (systemInstruction != null && systemInstruction.trim().isNotEmpty)
        {'role': 'system', 'content': systemInstruction},
      {'role': 'user', 'content': userContent},
    ];

    final body = <String, dynamic>{
      'model': GroqConfig.model,
      'messages': messages,
      'temperature': 0.35,
      'max_completion_tokens': maxOutputTokens,
      'citation_options': 'disabled',
    };
    if (webSearch) {
      body['tools'] = [
        {'type': 'browser_search'},
      ];
    }

    for (var attempt = 0; attempt < keys.length; attempt++) {
      final i = (_cursor + attempt) % keys.length;
      final key = keys[i];
      final blockedUntil = _rateLimitedUntil[key];
      if (blockedUntil != null && blockedUntil.isAfter(DateTime.now())) {
        continue;
      }

      try {
        final response = await http.post(
          Uri.parse(GroqConfig.endpoint),
          headers: {
            'Authorization': 'Bearer $key',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          _rateLimitedUntil.remove(key);
          _cursor = (i + 1) % keys.length;
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final choices = data['choices'];
          if (choices is! List || choices.isEmpty) {
            throw GeminiException('Groq returned no response.');
          }
          final first = choices.first;
          if (first is! Map) throw GeminiException('Groq returned an invalid response.');
          final message = first['message'];
          if (message is! Map) throw GeminiException('Groq returned an empty response.');
          final text = message['content']?.toString().trim() ?? '';
          if (text.isEmpty) throw GeminiException('Groq returned no text.');
          return text;
        }

        final isQuotaOrTransient =
            response.statusCode == 429 ||
            response.statusCode == 403 ||
            response.statusCode >= 500;
        if (isQuotaOrTransient) {
          if (response.statusCode == 429 || response.statusCode == 403) {
            _rateLimitedUntil[key] =
                DateTime.now().add(const Duration(minutes: 2));
          }
          continue;
        }
        break;
      } catch (e) {
        if (e is GeminiException) rethrow;
        continue;
      }
    }

    final allCooling = keys.every((key) {
      final until = _rateLimitedUntil[key];
      return until != null && until.isAfter(DateTime.now());
    });
    if (allCooling) {
      throw GeminiException(
        'Groq is temporarily busy. Please try again in a moment.',
      );
    }
    throw GeminiException(
      'The AI service is temporarily unavailable. Please try again.',
    );
  }

  String _sourceText(List<NotebookSource> sources) {
    final buffer = StringBuffer();
    for (final source in sources) {
      buffer.writeln('\n--- SOURCE: "${source.title}" ---');
      final text = source.textContent?.trim();
      if (text != null && text.isNotEmpty) {
        buffer.writeln(text);
      } else {
        buffer.writeln('[No readable text is available for this source.]');
      }
    }
    return buffer.toString();
  }

  Future<String> askGeneral({
    required String prompt,
    List<ChatMessage> history = const [],
    bool webSearch = true,
  }) {
    final historyText = history
        .map((m) => '${m.isUser ? "User" : "Assistant"}: ${m.text}')
        .join('\n');
    return _generate(
      userContent:
          '${historyText.isEmpty ? '' : 'Conversation so far:\n$historyText\n\n'}User request:\n$prompt',
      systemInstruction:
          'You are Inspiro AI, a helpful general-purpose study and productivity assistant inside Lodha Inspiro. Answer clearly and naturally. Do not invent facts.',
      webSearch: webSearch,
    );
  }

  Future<String> answerFromSources({
    required List<NotebookSource> sources,
    required List<ChatMessage> history,
    required String question,
  }) {
    final historyText = history
        .map((m) => '${m.isUser ? "Student" : "Assistant"}: ${m.text}')
        .join('\n');
    return _generate(
      userContent:
          '${_sourceText(sources)}\n--- CONVERSATION SO FAR ---\n$historyText\n--- NEW QUESTION ---\nStudent: $question',
      systemInstruction:
          'You are the AI notebook assistant inside Lodha Inspiro. Answer ONLY using the SOURCE material provided. If the sources do not contain the answer, say so plainly instead of guessing. Use plain text. At the end list source names like: Sources: "Source Title A", "Source Title B".',
    );
  }

  Future<String> askNotebookGeneral({
    required String question,
    List<ChatMessage> history = const [],
  }) {
    final historyText = history
        .map((m) => '${m.isUser ? "Student" : "Assistant"}: ${m.text}')
        .join('\n');
    return _generate(
      userContent:
          '${historyText.isEmpty ? '' : 'Conversation so far:\n$historyText\n\n'}Question:\n$question',
      systemInstruction:
          'You are Inspiro AI in the Notebook section. Answer directly using your knowledge. Do not invent facts. Keep answers easy for a student to understand.',
    );
  }

  Future<String> summarizeNotebook(List<NotebookSource> sources) => _generate(
        userContent: '${_sourceText(sources)}\nWrite a concise summary of the notebook above.',
        systemInstruction:
            'Summarize only the provided study material. Do not invent facts.',
      );

  Future<List<String>> suggestQuestions(List<NotebookSource> sources) async {
    final result = await _generate(
      userContent:
          '${_sourceText(sources)}\nList exactly 4 short questions under 12 words each. Return ONLY the 4 questions, one per line.',
      systemInstruction:
          'Generate study questions from the provided source material.',
    );
    return result
        .split('\n')
        .map((line) => line.trim().replaceFirst(RegExp(r'^[-•\d.\)]+\s*'), ''))
        .where((line) => line.isNotEmpty)
        .take(4)
        .toList();
  }

  Future<List<NotebookQuizQuestion>> generateQuiz(
    List<NotebookSource> sources, {
    int count = 8,
  }) async {
    final result = await _generate(
      userContent:
          '${_sourceText(sources)}\nCreate $count multiple-choice questions as JSON. Each object must contain question, options (exactly 4 strings), answer (0-3), hint, and explanation.',
      systemInstruction:
          'Return ONLY a JSON array of objects with question, options (array of exactly 4 strings), answer (0-3), hint, and explanation. Use only the provided source material.',
    );
    dynamic decoded;
    try {
      decoded = jsonDecode(result);
    } catch (_) {
      decoded = jsonDecode(
        result
            .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
            .replaceFirst(RegExp(r'\s*```$'), '')
            .trim(),
      );
    }
    if (decoded is! List) {
      throw GeminiException('Groq returned an invalid quiz format.');
    }
    return decoded.map<NotebookQuizQuestion>((item) {
      if (item is! Map) {
        throw GeminiException('Groq returned an invalid quiz question.');
      }
      final map = Map<String, dynamic>.from(item);
      final options = map['options'];
      if (options is! List || options.length != 4) {
        throw GeminiException('Groq returned a quiz question without exactly 4 options.');
      }
      final answer = int.tryParse(map['answer']?.toString() ?? '') ?? -1;
      if (answer < 0 || answer > 3) {
        throw GeminiException('Groq returned an invalid correct answer index.');
      }
      return NotebookQuizQuestion(
        question: map['question']?.toString() ?? '',
        options: options
            .map<QuizOption>((value) => QuizOption(
                  text: value.toString(),
                  why: map['explanation']?.toString() ?? '',
                ))
            .toList(),
        correctIndex: answer,
        hint: map['hint']?.toString() ?? '',
      );
    }).toList();
  }

  Future<String> generateAudioOverview(List<NotebookSource> sources) => _generate(
        userContent:
            '${_sourceText(sources)}\nCreate a concise spoken audio overview script.',
        systemInstruction:
            'Write a natural student-friendly audio overview of the provided material. Do not invent facts.',
      );

  Future<String> generateAudioOverviewScript(List<NotebookSource> sources) =>
      generateAudioOverview(sources);
}

class GeminiException implements Exception {
  final String message;
  GeminiException(this.message);
  @override
  String toString() => message;
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'groq_config.dart';
import 'ai_key_pool.dart';
import '../classwork_mode.dart';
import '../notebooks/notebook_models.dart';
import '../notebooks/notebook_quiz_models.dart';

class GeminiService {
  GeminiService._();
  static final GeminiService instance = GeminiService._();
  static int _cursor = 0;
  static final Map<String, DateTime> _rateLimitedUntil = {};

  Future<String> _generate({
    required List<Map<String, dynamic>> parts,
    String? systemInstruction,
    String model = GroqConfig.model,
    int maxOutputTokens = 2048,
    bool webSearch = false,
  }) async {
    if (classworkModeNotifier.value) {
      throw GeminiException(
        'Inspiro AI is disabled while monitored classwork is in progress.',
      );
    }

    final keys = AiKeyPool.availableGeminiKeys;
    if (keys.isEmpty) {
      throw GeminiException(
        'No Gemini API key is configured. Add GEMINI_API_KEY_1 through GEMINI_API_KEY_10 as Dart defines.',
      );
    }

    final contents = <Map<String, dynamic>>[
      {
        'role': 'user',
        'parts': parts,
      },
    ];

    final body = <String, dynamic>{
      'contents': contents,
      'generationConfig': {
        'temperature': 0.35,
        'maxOutputTokens': maxOutputTokens,
      },
    };
    if (systemInstruction != null && systemInstruction.trim().isNotEmpty) {
      body['systemInstruction'] = {
        'parts': [
          {'text': systemInstruction},
        ],
      };
    }
    if (webSearch) {
      body['tools'] = [
        {'google_search': {}},
      ];
    }

    String? last;
    var attemptedKey = false;

    for (var attempt = 0; attempt < keys.length; attempt++) {
      final i = (_cursor + attempt) % keys.length;
      final key = keys[i];
      final blockedUntil = _rateLimitedUntil[key];
      if (blockedUntil != null && blockedUntil.isAfter(DateTime.now())) {
        continue;
      }
      attemptedKey = true;

      try {
        final endpoint =
            'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent';
        final r = await http.post(
          Uri.parse(endpoint),
          headers: {
            'x-goog-api-key': key,
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        );

        if (r.statusCode >= 200 && r.statusCode < 300) {
          _rateLimitedUntil.remove(key);
          _cursor = (i + 1) % keys.length;
          final d = jsonDecode(r.body) as Map<String, dynamic>;
          final candidates = d['candidates'];
          if (candidates is! List || candidates.isEmpty) {
            throw GeminiException('Gemini returned no response.');
          }
          final candidate = candidates.first;
          if (candidate is! Map) {
            throw GeminiException('Gemini returned an invalid response.');
          }
          final content = candidate['content'];
          if (content is! Map) {
            throw GeminiException('Gemini returned an empty response.');
          }
          final responseParts = content['parts'];
          if (responseParts is! List) {
            throw GeminiException('Gemini returned no text response.');
          }
          final text = responseParts
              .whereType<Map>()
              .map((p) => p['text']?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .join();
          if (text.isEmpty) throw GeminiException('Gemini returned no text.');
          return text;
        }

        final isQuotaOrTransient =
            r.statusCode == 429 || r.statusCode == 403 || r.statusCode >= 500;
        if (isQuotaOrTransient) {
          // Do not expose this key's quota/error to the student. Move on to
          // another configured key and keep the original request intact.
          if (r.statusCode == 429 || r.statusCode == 403) {
            _rateLimitedUntil[key] = DateTime.now().add(const Duration(minutes: 2));
          }
          last = 'Gemini temporarily unavailable.';
          continue;
        }

        last = 'Gemini request failed.';
        break;
      } catch (e) {
        // Parsing/transport failures on one key should not stop the key pool.
        last = e is GeminiException ? e.message : 'Gemini temporarily unavailable.';
        continue;
      }
    }

    if (!attemptedKey) {
      throw GeminiException(
        'Gemini is temporarily busy. Please try again in a moment.',
      );
    }
    throw GeminiException(
      'The AI service is temporarily unavailable. Please try again.',
    );
  }

  List<Map<String, dynamic>> _sourceParts(List<NotebookSource> sources) {
    final p = <Map<String, dynamic>>[];
    for (final s in sources) {
      p.add({
        'text': '\n--- SOURCE: "${s.title}" ---\n',
      });
      if (s.textContent?.isNotEmpty == true) {
        p.add({'text': s.textContent!});
      } else if (s.base64Data != null && s.base64Data!.isNotEmpty) {
        p.add({
          'inline_data': {
            'mime_type': s.mimeType,
            'data': s.base64Data,
          },
        });
      } else {
        p.add({
          'text': '[No readable content is available for this source.]',
        });
      }
    }
    return p;
  }

  Future<String> askGeneral({
    required String prompt,
    List<ChatMessage> history = const [],
    bool webSearch = true,
  }) {
    final t = history
        .map((m) => '${m.isUser ? "User" : "Assistant"}: ${m.text}')
        .join('\n');
    return _generate(
      parts: [
        if (t.isNotEmpty) {'text': 'Conversation so far:\n$t\n'},
        {'text': 'User request:\n$prompt'},
      ],
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
    final t = history
        .map((m) => '${m.isUser ? "Student" : "Assistant"}: ${m.text}')
        .join('\n');
    return _generate(
      parts: [
        ..._sourceParts(sources),
        {'text': '\n--- CONVERSATION SO FAR ---\n$t\n--- NEW QUESTION ---\nStudent: $question'},
      ],
      systemInstruction:
          'You are the AI notebook assistant inside Lodha Inspiro. Answer ONLY using the SOURCE material provided. If the sources do not contain the answer, say so plainly instead of guessing. Use plain text. At the end list source names like: Sources: "Source Title A", "Source Title B".',
    );
  }

  Future<String> askNotebookGeneral({
    required String question,
    List<ChatMessage> history = const [],
  }) {
    final t = history
        .map((m) => '${m.isUser ? "Student" : "Assistant"}: ${m.text}')
        .join('\n');
    return _generate(
      parts: [
        if (t.isNotEmpty) {'text': 'Conversation so far:\n$t\n'},
        {'text': 'Question:\n$question'},
      ],
      systemInstruction:
          'You are Inspiro AI in the Notebook section. Answer directly using your knowledge. Do not invent facts. Keep answers easy for a student to understand.',
    );
  }

  Future<String> summarizeNotebook(List<NotebookSource> sources) => _generate(
        parts: [
          ..._sourceParts(sources),
          {'text': '\nWrite a concise summary of the notebook above.'},
        ],
        systemInstruction:
            'Summarize only the provided study material. Do not invent facts.',
      );

  Future<List<String>> suggestQuestions(List<NotebookSource> sources) async {
    final r = await _generate(
      parts: [
        ..._sourceParts(sources),
        {
          'text': '\nList exactly 4 short questions under 12 words each. Return ONLY the 4 questions, one per line.',
        },
      ],
      systemInstruction:
          'Generate study questions from the provided source material.',
    );
    return r
        .split('\n')
        .map((l) => l.trim().replaceFirst(RegExp(r'^[-•\d.\)]+\s*'), ''))
        .where((l) => l.isNotEmpty)
        .take(4)
        .toList();
  }

  Future<List<NotebookQuizQuestion>> generateQuiz(
    List<NotebookSource> sources, {
    int count = 8,
  }) async {
    final r = await _generate(
      parts: [
        ..._sourceParts(sources),
        {
          'text': '\nCreate $count multiple-choice questions as JSON. Each object must contain question, options (exactly 4 strings), answer (0-3), hint, and explanation.',
        },
      ],
      systemInstruction:
          'Return ONLY a JSON array of objects with question, options (array of exactly 4 strings), answer (0-3), hint, and explanation. Use only the provided source material.',
    );
    dynamic d;
    try {
      d = jsonDecode(r);
    } catch (_) {
      d = jsonDecode(
        r
            .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
            .replaceFirst(RegExp(r'\s*```$'), '')
            .trim(),
      );
    }
    if (d is! List) throw GeminiException('Gemini returned an invalid quiz format.');
    return d.map<NotebookQuizQuestion>((x) {
      if (x is! Map) throw GeminiException('Gemini returned an invalid quiz question.');
      final m = Map<String, dynamic>.from(x);
      final o = m['options'];
      if (o is! List || o.length != 4) {
        throw GeminiException('Gemini returned a quiz question without exactly 4 options.');
      }
      final a = int.tryParse(m['answer']?.toString() ?? '') ?? -1;
      if (a < 0 || a > 3) throw GeminiException('Gemini returned an invalid correct answer index.');
      return NotebookQuizQuestion(
        question: m['question']?.toString() ?? '',
        options: o
            .map<QuizOption>(
              (v) => QuizOption(
                text: v.toString(),
                why: m['explanation']?.toString() ?? '',
              ),
            )
            .toList(),
        correctIndex: a,
        hint: m['hint']?.toString() ?? '',
      );
    }).toList();
  }

  Future<String> generateAudioOverview(List<NotebookSource> sources) => _generate(
        parts: [
          ..._sourceParts(sources),
          {'text': '\nCreate a concise spoken audio overview script.'},
        ],
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

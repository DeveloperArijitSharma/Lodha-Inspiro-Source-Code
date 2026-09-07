import 'dart:convert';
import 'package:http/http.dart' as http;

import 'gemini_config.dart';
import '../notebooks/notebook_models.dart';

/// Thin wrapper around the Gemini API (Generative Language REST endpoint).
///
/// Every notebook feature (grounded chat, summaries, audio-overview scripts)
/// goes through [_generate], which just posts a `contents` + optional
/// `systemInstruction` payload and pulls the text back out. Keeping one
/// choke point makes it trivial to swap models, add streaming, or move the
/// key behind a backend later without touching the UI code.
class GeminiService {
  GeminiService._();
  static final GeminiService instance = GeminiService._();

  static const _base = 'https://generativelanguage.googleapis.com/v1beta';

  Uri _endpoint(String model) =>
      Uri.parse('$_base/models/$model:generateContent?key=${GeminiConfig.apiKey}');

  Future<String> _generate({
    required List<Map<String, dynamic>> parts,
    String? systemInstruction,
    String model = GeminiConfig.chatModel,
    double temperature = 0.4,
  }) async {
    if (GeminiConfig.apiKey.isEmpty || GeminiConfig.apiKey == 'YOUR_GEMINI_API_KEY_HERE') {
      throw GeminiException(
          'No Gemini API key set. Open lib/gemini/gemini_config.dart and add your key '
          'from Google AI Studio (or pass it with --dart-define=GEMINI_API_KEY=...).');
    }

    final body = {
      if (systemInstruction != null)
        'systemInstruction': {
          'parts': [
            {'text': systemInstruction}
          ]
        },
      'contents': [
        {'role': 'user', 'parts': parts}
      ],
      'generationConfig': {
        'temperature': temperature,
        'maxOutputTokens': 2048,
      },
    };

    final response = await http.post(
      _endpoint(model),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw GeminiException(
          'Gemini API error (${response.statusCode}): ${_extractError(response.body)}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      final blockReason = decoded['promptFeedback']?['blockReason'];
      throw GeminiException(blockReason != null
          ? 'Gemini blocked this request: $blockReason'
          : 'Gemini returned no response.');
    }

    final contentParts = candidates.first['content']?['parts'] as List<dynamic>?;
    if (contentParts == null || contentParts.isEmpty) return '';
    return contentParts.map((p) => p['text'] ?? '').join();
  }

  String _extractError(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded['error']?['message']?.toString() ?? body;
    } catch (_) {
      return body;
    }
  }

  /// Turns every source in the notebook into Gemini "parts": a short label
  /// followed by either the raw text, or the file bytes as inline data
  /// (Gemini reads PDFs/images natively server-side, so we never need a
  /// client-side PDF parser — this is what keeps source upload identical
  /// across Android/iOS/macOS/Windows/web).
  List<Map<String, dynamic>> _sourceParts(List<NotebookSource> sources) {
    final parts = <Map<String, dynamic>>[];
    for (final s in sources) {
      parts.add({'text': '\n--- SOURCE: "${s.title}" ---\n'});
      if (s.mimeType.startsWith('text/') || s.mimeType == 'application/octet-stream') {
        parts.add({'text': s.textContent ?? ''});
      } else if (s.base64Data != null) {
        parts.add({
          'inlineData': {'mimeType': s.mimeType, 'data': s.base64Data}
        });
      }
    }
    return parts;
  }

  /// Grounded Q&A: answers strictly from the notebook's sources, in the
  /// style of NotebookLM, and asks the model to name which source(s) it
  /// used so the UI can show a citation chip.
  Future<String> answerFromSources({
    required List<NotebookSource> sources,
    required List<ChatMessage> history,
    required String question,
  }) async {
    final transcript = history
        .map((m) => '${m.isUser ? "Student" : "Assistant"}: ${m.text}')
        .join('\n');

    final parts = <Map<String, dynamic>>[
      ..._sourceParts(sources),
      {
        'text': '\n--- CONVERSATION SO FAR ---\n$transcript'
            '\n--- NEW QUESTION ---\nStudent: $question'
      },
    ];

    return _generate(
      parts: parts,
      systemInstruction:
          'You are the AI notebook assistant inside Lodha Inspiro, a study app. '
          'Answer ONLY using the SOURCE material provided above — never use outside '
          'knowledge. If the sources do not contain the answer, say so plainly instead '
          'of guessing. Keep answers concise and well-structured (use short paragraphs '
          'or bullet points). At the end of your answer, on a new line, list which '
          'source(s) you drew from like: Sources: "Source Title A", "Source Title B".',
    );
  }

  /// One-paragraph notebook summary, regenerated whenever sources change.
  Future<String> summarizeNotebook(List<NotebookSource> sources) {
    return _generate(
      parts: [
        ..._sourceParts(sources),
        {'text': '\nWrite a concise summary of the notebook above.'},
      ],
      systemInstruction:
          'You summarize study material for a student. Produce a tight 3-5 sentence '
          'overview of what these combined sources cover, followed by 3-6 bullet '
          'points of the key topics or takeaways. Do not invent facts not present '
          'in the sources.',
    );
  }

  /// Suggested starter questions, shown as chips under an empty notebook chat —
  /// mirrors NotebookLM's "suggested questions" affordance.
  Future<List<String>> suggestQuestions(List<NotebookSource> sources) async {
    final raw = await _generate(
      parts: [
        ..._sourceParts(sources),
        {
          'text':
              '\nList exactly 4 short questions (under 12 words each) a student '
                  'might ask about the sources above. Return ONLY the 4 questions, '
                  'one per line, no numbering, no extra commentary.'
        },
      ],
      systemInstruction: 'You generate study-prompt suggestions from source material.',
      temperature: 0.7,
    );
    return raw
        .split('\n')
        .map((l) => l.trim().replaceFirst(RegExp(r'^[-•\d.\)]+\s*'), ''))
        .where((l) => l.isNotEmpty)
        .take(4)
        .toList();
  }

  /// Generates a two-host, podcast-style dialogue script from the sources —
  /// the "Audio Overview" script. Playback is handled on-device by
  /// flutter_tts (see notebook_detail_screen.dart); this just writes the words.
  Future<String> generateAudioOverviewScript(List<NotebookSource> sources) {
    return _generate(
      model: GeminiConfig.chatModel,
      parts: [
        ..._sourceParts(sources),
        {
          'text':
              '\nWrite a friendly 90-second, two-host podcast script discussing the '
                  'sources above. Alternate lines between "Host A:" and "Host B:". '
                  'They should explain the material conversationally, like two people '
                  'genuinely excited about the topic — no stage directions, no sound '
                  'effect notes, just dialogue lines.'
        },
      ],
      systemInstruction:
          'You write natural, engaging two-person podcast scripts that explain study '
          'material clearly, grounded only in the provided sources.',
      temperature: 0.8,
    );
  }
}

class GeminiException implements Exception {
  final String message;
  GeminiException(this.message);
  @override
  String toString() => message;
}

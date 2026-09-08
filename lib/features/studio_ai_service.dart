import 'dart:convert';
import 'package:http/http.dart' as http;
import '../gemini/ai_key_pool.dart';
import '../gemini/groq_config.dart';
import '../gemini/gemini_service.dart';

class StudioAiService {
  static int _cursor = 0;

  Future<String> generate(String prompt) async {
    final keys = AiKeyPool.availableGeminiKeys;
    String? lastError;
    if (keys.isEmpty) {
      throw GeminiException(
        'Studio AI has no Gemini key. Configure GEMINI_API_KEY_1 through GEMINI_API_KEY_10.',
      );
    }

    for (var attempt = 0; attempt < keys.length; attempt++) {
      final i = (_cursor + attempt) % keys.length;
      try {
        final r = await http.post(
          Uri.parse(GroqConfig.endpoint),
          headers: {
            'x-goog-api-key': keys[i],
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {
                    'text':
                        'You create safe, clear, age-appropriate student classwork. Return only the format requested.\n\n$prompt',
                  },
                ],
              },
            ],
            'generationConfig': {
              'temperature': 0.35,
              'maxOutputTokens': 2500,
            },
          }),
        );
        if (r.statusCode >= 200 && r.statusCode < 300) {
          _cursor = (i + 1) % keys.length;
          final d = jsonDecode(r.body) as Map<String, dynamic>;
          final candidates = d['candidates'];
          if (candidates is! List || candidates.isEmpty) continue;
          final candidate = candidates.first;
          if (candidate is! Map) continue;
          final content = candidate['content'];
          if (content is! Map) continue;
          final parts = content['parts'];
          if (parts is! List) continue;
          final text = parts
              .whereType<Map>()
              .map((p) => p['text']?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .join();
          if (text.isNotEmpty) return text;
        } else if (r.statusCode == 401 ||
            r.statusCode == 403 ||
            r.statusCode == 429 ||
            r.statusCode >= 500) {
          lastError = 'Gemini API error (${r.statusCode}).';
        } else {
          lastError = 'Gemini API error (${r.statusCode}).';
          break;
        }
      } catch (e) {
        lastError = e.toString();
      }
    }

    throw GeminiException(
      lastError ?? 'All configured Gemini keys failed for Studio AI.',
    );
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../gemini/ai_key_pool.dart';
import '../gemini/groq_config.dart';
import '../gemini/gemini_service.dart';

class StudioAiService {
  static int _cursor = 0;
  static final Map<String, DateTime> _rateLimitedUntil = {};

  Future<String> generate(String prompt) async {
    final keys = AiKeyPool.availableGroqKeys;
    if (keys.isEmpty) {
      throw GeminiException(
        'Studio AI has no Groq key. Configure GROQ_API_KEY_1 through GROQ_API_KEY_10.',
      );
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
          body: jsonEncode({
            'model': GroqConfig.model,
            'messages': [
              {
                'role': 'system',
                'content':
                    'You create safe, clear, age-appropriate student classwork. Return only the format requested.',
              },
              {'role': 'user', 'content': prompt},
            ],
            'temperature': 0.35,
            'max_completion_tokens': 2500,
            'citation_options': 'disabled',
          }),
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          _rateLimitedUntil.remove(key);
          _cursor = (i + 1) % keys.length;
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final choices = data['choices'];
          if (choices is! List || choices.isEmpty) continue;
          final first = choices.first;
          if (first is! Map) continue;
          final message = first['message'];
          if (message is! Map) continue;
          final text = message['content']?.toString().trim() ?? '';
          if (text.isNotEmpty) return text;
          continue;
        }

        if (response.statusCode == 429 ||
            response.statusCode == 403 ||
            response.statusCode >= 500) {
          if (response.statusCode == 429 || response.statusCode == 403) {
            _rateLimitedUntil[key] =
                DateTime.now().add(const Duration(minutes: 2));
          }
          continue;
        }
        break;
      } catch (_) {
        continue;
      }
    }

    final allCooling = keys.every((key) {
      final until = _rateLimitedUntil[key];
      return until != null && until.isAfter(DateTime.now());
    });
    if (allCooling) {
      throw GeminiException('Studio AI is temporarily busy. Please try again.');
    }
    throw GeminiException(
      'Studio AI is temporarily unavailable. Please try again.',
    );
  }
}

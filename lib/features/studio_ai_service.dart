import 'dart:convert';
import 'package:http/http.dart' as http;
import '../gemini/ai_key_pool.dart';
import '../gemini/groq_config.dart';
import '../gemini/gemini_service.dart';

class StudioAiService {
  static int _cursor = 0;
  static final Map<String, DateTime> _rateLimitedUntil = <String, DateTime>{};

  List<String> _groqKeys() => AiKeyPool.groqKeys
      .map((String key) => key.trim())
      .where((String key) => key.isNotEmpty)
      .toList(growable: false);

  Future<String> generate(String prompt) async {
    final List<String> keys = _groqKeys();
    if (keys.isEmpty) {
      throw GeminiException(
        'Studio AI has no Groq key. Configure GROQ_API_KEY_1 through GROQ_API_KEY_10.',
      );
    }

    for (int attempt = 0; attempt < keys.length; attempt++) {
      final int i = (_cursor + attempt) % keys.length;
      final String key = keys[i];
      final DateTime? blockedUntil = _rateLimitedUntil[key];
      if (blockedUntil != null && blockedUntil.isAfter(DateTime.now())) {
        continue;
      }

      try {
        final http.Response response = await http.post(
          Uri.parse(GroqConfig.endpoint),
          headers: <String, String>{
            'Authorization': 'Bearer $key',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(<String, dynamic>{
            'model': GroqConfig.model,
            'messages': <Map<String, String>>[
              <String, String>{
                'role': 'system',
                'content':
                    'You create safe, clear, age-appropriate student classwork. Return only the format requested.',
              },
              <String, String>{'role': 'user', 'content': prompt},
            ],
            'temperature': 0.35,
            'max_completion_tokens': 2500,
            'citation_options': 'disabled',
          }),
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          _rateLimitedUntil.remove(key);
          _cursor = (i + 1).toInt() % keys.length;
          final dynamic decoded = jsonDecode(response.body);
          if (decoded is! Map<String, dynamic>) continue;
          final dynamic choices = decoded['choices'];
          if (choices is! List || choices.isEmpty) continue;
          final dynamic first = choices.first;
          if (first is! Map) continue;
          final dynamic message = first['message'];
          if (message is! Map) continue;
          final String text = message['content']?.toString().trim() ?? '';
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

    final DateTime now = DateTime.now();
    final bool allCooling = keys.every((String key) {
      final DateTime? until = _rateLimitedUntil[key];
      return until != null && until.isAfter(now);
    });
    if (allCooling) {
      throw GeminiException('Studio AI is temporarily busy. Please try again.');
    }
    throw GeminiException(
      'Studio AI is temporarily unavailable. Please try again.',
    );
  }
}

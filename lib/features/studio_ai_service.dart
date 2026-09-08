import 'dart:convert';
import 'package:http/http.dart' as http;
import '../gemini/ai_key_pool.dart';
import '../gemini/gemini_service.dart';

class StudioAiService {
  static const _groqEndpoint = 'https://api.groq.com/openai/v1/chat/completions';
  static const _openRouterEndpoint = 'https://openrouter.ai/api/v1/chat/completions';
  static const _openRouterModel = 'nvidia/nemotron-3.5-lightning:free';
  static int _cursor = 0;

  Future<String> generate(String prompt) async {
    final keys = AiKeyPool.availableGroqKeys.take(5).toList();
    String? lastError;
    if (keys.isNotEmpty) {
      for (var attempt = 0; attempt < keys.length; attempt++) {
        final i = (_cursor + attempt) % keys.length;
        try {
          final r = await _call(_groqEndpoint, keys[i], 'openai/gpt-oss-120b', prompt);
          if (r != null) {
            _cursor = (i + 1) % keys.length;
            return r;
          }
        } catch (e) { lastError = e.toString(); }
      }
    }
    if (AiKeyPool.openRouterKey.trim().isNotEmpty) {
      try {
        final r = await _call(_openRouterEndpoint, AiKeyPool.openRouterKey, _openRouterModel, prompt);
        if (r != null) return r;
      } catch (e) { lastError = e.toString(); }
    }
    throw GeminiException(lastError ?? 'Studio AI has no available provider key. Configure five Groq keys and an OpenRouter key.');
  }

  Future<String?> _call(String endpoint, String key, String model, String prompt) async {
    final r = await http.post(Uri.parse(endpoint), headers: {
      'Authorization': 'Bearer $key',
      'Content-Type': 'application/json',
      if (endpoint.contains('openrouter')) 'HTTP-Referer': 'https://github.com/DeveloperArijitSharma/Lodha-Inspiro-Source-Code',
      if (endpoint.contains('openrouter')) 'X-Title': 'Lodha Inspiro',
    }, body: jsonEncode({
      'model': model,
      'messages': [
        {'role': 'system', 'content': 'You create safe, clear, age-appropriate student classwork. Return only the format requested.'},
        {'role': 'user', 'content': prompt},
      ],
      'temperature': 0.35,
      'max_tokens': 2500,
    }));
    if (r.statusCode >= 200 && r.statusCode < 300) {
      final d = jsonDecode(r.body) as Map<String, dynamic>;
      final choices = d['choices'];
      if (choices is! List || choices.isEmpty) return null;
      final first = choices.first;
      if (first is! Map) return null;
      final message = first['message'];
      if (message is! Map) return null;
      final content = message['content'];
      return content?.toString();
    }
    if (r.statusCode == 401 || r.statusCode == 403 || r.statusCode == 429 || r.statusCode >= 500) return null;
    throw GeminiException('AI provider error (${r.statusCode}).');
  }
}

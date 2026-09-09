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
  static final Map<String, DateTime> _rateLimitedUntil = <String, DateTime>{};

  List<String> _groqKeys() => AiKeyPool.keys
      .map((String key) => key.trim())
      .where((String key) => key.isNotEmpty)
      .toList(growable: false);

  Future<String> _generate({
    required String userContent,
    String? systemInstruction,
    int maxOutputTokens = 2048,
    bool webSearch = false,
  }) async {
    if (classworkModeNotifier.value) {
      throw GeminiException('Inspiro AI is disabled while monitored classwork is in progress.');
    }
    final List<String> keys = _groqKeys();
    if (keys.isEmpty) {
      throw GeminiException('No Groq API key is configured. Add GROQ_API_KEY_1 through GROQ_API_KEY_10 as Dart defines.');
    }
    final List<Map<String, dynamic>> messages = <Map<String, dynamic>>[
      if (systemInstruction != null && systemInstruction.trim().isNotEmpty)
        <String, dynamic>{'role': 'system', 'content': systemInstruction},
      <String, dynamic>{'role': 'user', 'content': userContent},
    ];
    final Map<String, dynamic> body = <String, dynamic>{
      'model': GroqConfig.model,
      'messages': messages,
      'temperature': 0.35,
      'max_completion_tokens': maxOutputTokens,
      'citation_options': 'disabled',
    };
    if (webSearch) {
      body['tools'] = <Map<String, String>>[<String, String>{'type': 'browser_search'}];
    }

    for (int attempt = 0; attempt < keys.length; attempt++) {
      final int i = (_cursor + attempt) % keys.length;
      final String key = keys[i];
      final DateTime? blockedUntil = _rateLimitedUntil[key];
      if (blockedUntil != null && blockedUntil.isAfter(DateTime.now())) continue;
      try {
        final http.Response response = await http.post(
          Uri.parse(GroqConfig.endpoint),
          headers: <String, String>{'Authorization': 'Bearer $key', 'Content-Type': 'application/json'},
          body: jsonEncode(body),
        );
        if (response.statusCode >= 200 && response.statusCode < 300) {
          _rateLimitedUntil.remove(key);
          final int nextCursor = i + 1;
          _cursor = nextCursor >= keys.length ? 0 : nextCursor;
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
        if (response.statusCode == 429 || response.statusCode == 403) {
          _rateLimitedUntil[key] = DateTime.now().add(const Duration(minutes: 2));
        }
        // Any failed key is skipped and the next configured key is tried.
        continue;
      } catch (_) {
        // Network/key failure: silently move to the next configured key.
        continue;
      }
    }
    final DateTime now = DateTime.now();
    final bool allCooling = keys.every((String key) {
      final DateTime? until = _rateLimitedUntil[key];
      return until != null && until.isAfter(now);
    });
    if (allCooling) throw GeminiException('Groq is temporarily busy. Please try again in a moment.');
    throw GeminiException('The AI service is temporarily unavailable. Please try again.');
  }

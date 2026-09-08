import 'groq_config.dart';

/// Keeps multiple provider keys out of source control while allowing a build
/// to rotate through up to ten Groq keys. Keys are supplied with --dart-define.
class AiKeyPool {
  static const List<String> groqKeys = [
    String.fromEnvironment('GROQ_API_KEY_1'),
    String.fromEnvironment('GROQ_API_KEY_2'),
    String.fromEnvironment('GROQ_API_KEY_3'),
    String.fromEnvironment('GROQ_API_KEY_4'),
    String.fromEnvironment('GROQ_API_KEY_5'),
    String.fromEnvironment('GROQ_API_KEY_6'),
    String.fromEnvironment('GROQ_API_KEY_7'),
    String.fromEnvironment('GROQ_API_KEY_8'),
    String.fromEnvironment('GROQ_API_KEY_9'),
    String.fromEnvironment('GROQ_API_KEY_10'),
  ];

  static const String legacyKey = GroqConfig.apiKey;
  static const String openRouterKey = String.fromEnvironment('OPENROUTER_API_KEY');

  static List<String> get availableGroqKeys {
    final keys = groqKeys.where((key) => key.trim().isNotEmpty).toList();
    if (keys.isEmpty && legacyKey.trim().isNotEmpty && legacyKey != 'YOUR_GROQ_API_KEY_HERE') {
      keys.add(legacyKey);
    }
    return keys;
  }
}

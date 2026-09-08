/// Gemini API key pool for Inspiro AI.
/// Supply up to ten keys at build time with --dart-define.
/// Never commit real API keys to this public repository.
class AiKeyPool {
  static const List<String> geminiKeys = [
    String.fromEnvironment('GEMINI_API_KEY_1'),
    String.fromEnvironment('GEMINI_API_KEY_2'),
    String.fromEnvironment('GEMINI_API_KEY_3'),
    String.fromEnvironment('GEMINI_API_KEY_4'),
    String.fromEnvironment('GEMINI_API_KEY_5'),
    String.fromEnvironment('GEMINI_API_KEY_6'),
    String.fromEnvironment('GEMINI_API_KEY_7'),
    String.fromEnvironment('GEMINI_API_KEY_8'),
    String.fromEnvironment('GEMINI_API_KEY_9'),
    String.fromEnvironment('GEMINI_API_KEY_10'),
  ];

  static List<String> get availableGeminiKeys =>
      geminiKeys.where((key) => key.trim().isNotEmpty).toList();
}

/// Gemini API key pool for Inspiro AI.
/// Supply one key with GEMINI_API_KEY or up to ten keys with
/// GEMINI_API_KEY_1 through GEMINI_API_KEY_10 at build time.
/// Never commit real API keys to this public repository.
class AiKeyPool {
  static const String singleGeminiKey =
      String.fromEnvironment('GEMINI_API_KEY');

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

  static List<String> get availableGeminiKeys {
    final keys = <String>[];
    if (singleGeminiKey.trim().isNotEmpty) {
      keys.add(singleGeminiKey.trim());
    }
    keys.addAll(
      geminiKeys.where((key) => key.trim().isNotEmpty),
    );
    return keys.toSet().toList();
  }
}

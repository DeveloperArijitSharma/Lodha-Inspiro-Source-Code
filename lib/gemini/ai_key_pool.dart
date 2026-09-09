/// Groq API key pool for Inspiro AI.
/// Supply up to ten keys with GROQ_API_KEY_1 through GROQ_API_KEY_10 at build time.
/// Never commit real API keys to this public repository.
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

  static List<String> get availableGroqKeys => groqKeys
      .map((key) => key.trim())
      .where((key) => key.isNotEmpty)
      .toList();
}

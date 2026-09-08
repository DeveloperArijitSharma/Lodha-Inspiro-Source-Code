/// Groq configuration for Inspiro AI.
///
/// Primary legacy key:
/// flutter run --dart-define=GROQ_API_KEY=gsk_...
///
/// Multi-key builds can additionally provide GROQ_API_KEY_1 through
/// GROQ_API_KEY_10. Never commit real API keys to this public repository.
class GroqConfig {
  static const String apiKey = String.fromEnvironment(
    'GROQ_API_KEY',
    defaultValue: 'YOUR_GROQ_API_KEY_HERE',
  );

  static const String model = 'openai/gpt-oss-120b';
  static const String endpoint = 'https://api.groq.com/openai/v1/chat/completions';
  static const String appTitle = 'Lodha Inspiro';
}

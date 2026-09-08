/// Groq configuration for Inspiro AI.
///
/// Set the key with:
/// flutter run --dart-define=GROQ_API_KEY=gsk_...
///
/// The key is intentionally read at runtime so it is not committed to git.
class GroqConfig {
  static const String apiKey = String.fromEnvironment(
    'GROQ_API_KEY',
    defaultValue: 'YOUR_GROQ_API_KEY_HERE',
  );

  /// Fast student-focused model available on Groq's API.
  static const String model = 'openai/gpt-oss-120b';
  static const String endpoint = 'https://api.groq.com/openai/v1/chat/completions';
  static const String appTitle = 'Lodha Inspiro';
}

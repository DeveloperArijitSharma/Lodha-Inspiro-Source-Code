/// Gemini API configuration for Inspiro AI.
/// Real API keys are supplied through Dart defines and are never committed.
class GroqConfig {
  static const String model = 'gemini-3.5-flash-lite';
  static const String endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent';
  static const String appTitle = 'Lodha Inspiro';
}

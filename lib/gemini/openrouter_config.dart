/// OpenRouter configuration for Inspiro AI.
///
/// Set the key with:
/// flutter run --dart-define=OPENROUTER_API_KEY=sk-or-v1-...
///
/// The key is intentionally read at runtime so it is not committed to git.
class OpenRouterConfig {
  static const String apiKey = String.fromEnvironment(
    'OPENROUTER_API_KEY',
    defaultValue: 'YOUR_OPENROUTER_API_KEY_HERE',
  );

  /// Current fast free model selected for student chat workloads.
  static const String model = 'nvidia/nemotron-3.5-lightning:free';
  static const String endpoint = 'https://openrouter.ai/api/v1/chat/completions';
  static const String appTitle = 'Lodha Inspiro';
}

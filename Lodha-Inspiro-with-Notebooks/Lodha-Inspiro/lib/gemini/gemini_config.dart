/// Gemini API configuration.
///
/// 🔴 Set your key below, OR (recommended, especially before you commit this
/// to git / share the repo) run the app with:
///
///   flutter run --dart-define=GEMINI_API_KEY=your_key_here
///
/// Get a free key from Google AI Studio: https://aistudio.google.com/apikey
///
/// Longer term, for a production app, don't ship the Gemini key inside the
/// client binary at all — proxy requests through a small backend (Supabase
/// Edge Function works well since you're already on Supabase) so the key
/// never lives on user devices. The service layer in gemini_service.dart is
/// written so swapping the endpoint later is a one-file change.
class GeminiConfig {
  static const String apiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'YOUR_GEMINI_API_KEY_HERE',
  );

  /// Fast + low-latency model for chat, summaries, quizzes and audio scripts.
  static const String chatModel = 'gemini-3.5-flash-lite';
}

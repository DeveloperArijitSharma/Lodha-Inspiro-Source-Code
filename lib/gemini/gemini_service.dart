import 'dart:convert';
import 'package:http/http.dart' as http;
import 'groq_config.dart';
import '../classwork_mode.dart';
import '../notebooks/notebook_models.dart';
import '../notebooks/notebook_quiz_models.dart';

class GeminiService {
  GeminiService._();
  static final GeminiService instance = GeminiService._();
  static int _cursor = 0;
  static final Map<String, DateTime> _rateLimitedUntil = <String, DateTime>{};

  List<String> _groqKeys() => <String>[
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
  ].map((String key) => key.trim()).where((String key) => key.isNotEmpty).toList(growable: false);

  Future<String> _generate({
    required String userContent,
    String? systemInstruction,
    int maxOutputTokens = 1024,
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
      body['tools'] = <Map<String, String>>[
        <String, String>{'type': 'browser_search'},
      ];
    }

    for (int attempt = 0; attempt < keys.length; attempt++) {
      final int i = (_cursor + attempt) % keys.length;
      final String key = keys[i];
      final DateTime? blockedUntil = _rateLimitedUntil[key];
      if (blockedUntil != null && blockedUntil.isAfter(DateTime.now())) continue;
      try {
        final http.Response response = await http.post(
          Uri.parse(GroqConfig.endpoint),
          headers: <String, String>{
            'Authorization': 'Bearer $key',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        );
        if (response.statusCode >= 200 && response.statusCode < 300) {
          _rateLimitedUntil.remove(key);
          _cursor = (i + 1) % keys.length;
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
        continue;
      } catch (_) {
        continue;
      }
    }

    final DateTime now = DateTime.now();
    final bool allCooling = keys.every((String key) {
      final DateTime? until = _rateLimitedUntil[key];
      return until != null && until.isAfter(now);
    });
    if (allCooling) {
      throw GeminiException('Groq is temporarily busy. Please try again in a moment.');
    }
    throw GeminiException('The AI service is temporarily unavailable. Please try again.');
  }

  List<String> _sourceChunks(NotebookSource source) {
    final String text = source.textContent?.trim() ?? '';
    if (text.isEmpty) return <String>['[No readable text is available for this source.]'];
    const int chunkSize = 1800;
    const int overlap = 200;
    final List<String> chunks = <String>[];
    int start = 0;
    while (start < text.length) {
      int end = (start + chunkSize).clamp(0, text.length);
      if (end < text.length) {
        final int paragraphBreak = text.lastIndexOf('\n', end);
        if (paragraphBreak > start + 900) end = paragraphBreak;
      }
      final String chunk = text.substring(start, end).trim();
      if (chunk.isNotEmpty) chunks.add(chunk);
      if (end >= text.length) break;
      start = end - overlap;
    }
    return chunks;
  }

  Set<String> _keywords(String text) => RegExp(r'[A-Za-z0-9]{3,}')
      .allMatches(text.toLowerCase())
      .map((RegExpMatch match) => match.group(0)!)
      .toSet();

  String _compactHistory(List<ChatMessage> history, {int maxChars = 5000}) {
    if (history.isEmpty) return '';
    final List<String> recent = history
        .reversed
        .take(12)
        .toList()
        .reversed
        .map((ChatMessage m) => '${m.isUser ? 'Student' : 'Assistant'}: ${m.text.trim()}')
        .where((String text) => text.length > 12)
        .toList();
    String result = recent.join('\n');
    if (result.length > maxChars) {
      result = result.substring(result.length - maxChars);
    }
    return result;
  }

  String _boundedSourceText(
    List<NotebookSource> sources, {
    String? query,
    int maxChars = 12000,
  }) {
    final List<_SourceChunk> all = <_SourceChunk>[];
    for (final NotebookSource source in sources) {
      final List<String> chunks = _sourceChunks(source);
      for (int index = 0; index < chunks.length; index++) {
        all.add(_SourceChunk(source.title, index, chunks[index]));
      }
    }
    if (all.isEmpty) return '';

    final Set<String> queryWords = _keywords(query ?? '');
    for (final _SourceChunk chunk in all) {
      if (queryWords.isEmpty) {
        chunk.score = 0;
      } else {
        final Set<String> chunkWords = _keywords(chunk.text);
        chunk.score = queryWords.intersection(chunkWords).length.toDouble();
        if (_keywords(chunk.title).intersection(queryWords).isNotEmpty) {
          chunk.score += 2;
        }
      }
    }

    final int maxChunks = (maxChars / 1800).floor().clamp(1, 20);
    final List<_SourceChunk> selected = <_SourceChunk>[];
    final Set<String> selectedSources = <String>{};

    // Keep at least one useful chunk from each source when the budget permits.
    for (final _SourceChunk chunk in all) {
      if (selected.length >= maxChunks) break;
      if (!selectedSources.contains(chunk.title)) {
        selected.add(chunk);
        selectedSources.add(chunk.title);
      }
    }

    final List<_SourceChunk> ranked = List<_SourceChunk>.from(all)
      ..sort((_SourceChunk a, _SourceChunk b) => b.score.compareTo(a.score));
    for (final _SourceChunk chunk in ranked) {
      if (selected.length >= maxChunks) break;
      if (!selected.contains(chunk)) selected.add(chunk);
    }

    selected.sort((_SourceChunk a, _SourceChunk b) {
      final int sourceCompare = a.title.compareTo(b.title);
      if (sourceCompare != 0) return sourceCompare;
      return a.index.compareTo(b.index);
    });

    final StringBuffer buffer = StringBuffer();
    for (final _SourceChunk chunk in selected) {
      final String section = '\n--- SOURCE: "${chunk.title}" ---\n${chunk.text}\n';
      if (buffer.length + section.length > maxChars && buffer.isNotEmpty) break;
      buffer.write(section);
    }
    return buffer.toString().trim();
  }

  Future<String> askGeneral({
    required String prompt,
    List<ChatMessage> history = const <ChatMessage>[],
    bool webSearch = true,
  }) {
    final String h = _compactHistory(history);
    return _generate(
      userContent: '${h.isEmpty ? '' : 'Recent conversation:\n$h\n\n'}User request:\n$prompt',
      systemInstruction: 'You are Inspiro AI, a helpful general-purpose study and productivity assistant inside Lodha Inspiro. Answer clearly and naturally. Do not invent facts.',
      webSearch: webSearch,
    );
  }

  Future<String> answerFromSources({
    required List<NotebookSource> sources,
    required List<ChatMessage> history,
    required String question,
  }) {
    final String h = _compactHistory(history, maxChars: 3500);
    final String context = _boundedSourceText(sources, query: question, maxChars: 12000);
    return _generate(
      userContent: '$context\n--- CONVERSATION SO FAR ---\n${h.isEmpty ? '[No previous conversation]' : h}\n--- NEW QUESTION ---\nStudent: $question',
      systemInstruction: 'You are the AI notebook assistant inside Lodha Inspiro. Answer ONLY using the SOURCE material provided. If the sources do not contain the answer, say so plainly instead of guessing. Use plain text. At the end list source names like: Sources: "Source Title A", "Source Title B".',
      maxOutputTokens: 1200,
    );
  }

  Future<String> askNotebookGeneral({
    required String question,
    List<ChatMessage> history = const <ChatMessage>[],
  }) {
    final String h = _compactHistory(history, maxChars: 3500);
    return _generate(
      userContent: '${h.isEmpty ? '' : 'Recent conversation:\n$h\n\n'}Question:\n$question',
      systemInstruction: 'You are Inspiro AI in the Notebook section. Answer directly using your knowledge. Do not invent facts. Keep answers easy for a student to understand.',
    );
  }

  Future<String> summarizeNotebook(List<NotebookSource> sources) => _generate(
        userContent: '${_boundedSourceText(sources, maxChars: 14000)}\nWrite a concise summary of the notebook above.',
        systemInstruction: 'Summarize only the provided study material. Do not invent facts.',
        maxOutputTokens: 1000,
      );

  Future<List<String>> suggestQuestions(List<NotebookSource> sources) async {
    final String result = await _generate(
      userContent: '${_boundedSourceText(sources, maxChars: 10000)}\nList exactly 4 short questions under 12 words each. Return ONLY the 4 questions, one per line.',
      systemInstruction: 'Generate study questions from the provided source material.',
      maxOutputTokens: 350,
    );
    return result
        .split('\n')
        .map((String line) => line.trim().replaceFirst(RegExp(r'^[-•\d.\)]+\s*'), ''))
        .where((String line) => line.isNotEmpty)
        .take(4)
        .toList();
  }

  Future<List<NotebookQuizQuestion>> generateQuiz(
    List<NotebookSource> sources, {
    int count = 8,
  }) async {
    final String result = await _generate(
      userContent: '${_boundedSourceText(sources, maxChars: 14000)}\nCreate $count multiple-choice questions as JSON. Each object must contain question, options (exactly 4 strings), answer (0-3), hint, and explanation.',
      systemInstruction: 'Return ONLY a JSON array of objects with question, options (array of exactly 4 strings), answer (0-3), hint, and explanation. Use only the provided source material.',
      maxOutputTokens: 1600,
    );
    dynamic decoded;
    try {
      decoded = jsonDecode(result);
    } catch (_) {
      decoded = jsonDecode(
        result
            .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
            .replaceFirst(RegExp(r'\s*```$'), '')
            .trim(),
      );
    }
    if (decoded is! List) throw GeminiException('Groq returned an invalid quiz format.');
    return decoded.map<NotebookQuizQuestion>((dynamic item) {
      if (item is! Map) throw GeminiException('Groq returned an invalid quiz question.');
      final Map<String, dynamic> map = Map<String, dynamic>.from(item);
      final dynamic options = map['options'];
      if (options is! List || options.length != 4) {
        throw GeminiException('Groq returned a quiz question without exactly 4 options.');
      }
      final int answer = int.tryParse(map['answer']?.toString() ?? '') ?? -1;
      if (answer < 0 || answer > 3) {
        throw GeminiException('Groq returned an invalid correct answer index.');
      }
      return NotebookQuizQuestion(
        question: map['question']?.toString() ?? '',
        options: options
            .map<QuizOption>((dynamic value) => QuizOption(
                  text: value.toString(),
                  why: map['explanation']?.toString() ?? '',
                ))
            .toList(),
        correctIndex: answer,
        hint: map['hint']?.toString() ?? '',
      );
    }).toList();
  }

  Future<String> generateAudioOverview(List<NotebookSource> sources) => _generate(
        userContent: '${_boundedSourceText(sources, maxChars: 14000)}\nCreate a concise spoken audio overview script.',
        systemInstruction: 'Write a natural student-friendly audio overview of the provided material. Do not invent facts.',
        maxOutputTokens: 1200,
      );

  Future<String> generateAudioOverviewScript(List<NotebookSource> sources) => generateAudioOverview(sources);
}

class _SourceChunk {
  final String title;
  final int index;
  final String text;
  double score = 0;

  _SourceChunk(this.title, this.index, this.text);
}

class GeminiException implements Exception {
  final String message;
  GeminiException(this.message);

  @override
  String toString() => message;
}

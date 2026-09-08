import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:uuid/uuid.dart';

import '../gemini/gemini_service.dart';
import 'notebook_models.dart';
import 'notebook_quiz_screen.dart';
import 'notebook_repository.dart';
import 'note_export_service.dart';

const _accentBlue = Color(0xFF32C5FF);
final _uuid = Uuid();

class NotebookDetailScreen extends StatefulWidget {
  final Notebook notebook;
  const NotebookDetailScreen({super.key, required this.notebook});

  @override
  State<NotebookDetailScreen> createState() => _NotebookDetailScreenState();
}

class _NotebookDetailScreenState extends State<NotebookDetailScreen>
    with SingleTickerProviderStateMixin {
  final _repo = NotebookRepository();
  final _gemini = GeminiService.instance;
  late final TabController _tabController;

  List<NotebookSource> _sources = [];
  List<ChatMessage> _messages = [];
  bool _loadingSources = true;
  bool _sendingMessage = false;
  List<String> _suggestedQuestions = [];

  String? _summary;
  bool _generatingSummary = false;

  String? _audioScript;
  bool _generatingScript = false;
  bool _speaking = false;
  final FlutterTts _tts = FlutterTts();

  // Source-free AI is intentionally separate from the grounded notebook chat.
  List<ChatMessage> _generalMessages = [];
  bool _generalAskMode = false;

  double _audioProgress = 0;
  int _audioSpeakingLine = 0;
  List<int> _audioLineOffsets = [];
  int _audioTotalChars = 1;
  int _audioSeekLine = 0;

  List<NotebookNote> _notes = [];

  final _chatController = TextEditingController();
  final _chatScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _summary = widget.notebook.summary;
    _loadAll();
    _tts.setCompletionHandler(() {
      if (!mounted) return;
      setState(() {
        _speaking = false;
        _audioProgress = 1;
      });
    });
    _tts.setProgressHandler((String text, int start, int end, String word) {
      if (!mounted || !_speaking || _audioTotalChars <= 0) return;
      final base = _audioLineOffsets.isNotEmpty &&
              _audioSpeakingLine < _audioLineOffsets.length
          ? _audioLineOffsets[_audioSpeakingLine]
          : 0;
      final value = ((base + end) / _audioTotalChars).clamp(0.0, 1.0);
      setState(() => _audioProgress = value);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chatController.dispose();
    _chatScroll.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loadingSources = true);
    try {
      final sources = await _repo.fetchSources(widget.notebook.id);
      final messages = await _repo.fetchMessages(widget.notebook.id);
      final notes = await _repo.fetchNotes(widget.notebook.id);
      if (!mounted) return;
      setState(() {
        _sources = sources;
        _messages = messages;
        _notes = notes;
        _loadingSources = false;
      });
      if (messages.isEmpty && sources.isNotEmpty) _loadSuggestions();
      _scrollToBottom();
    } catch (_) {
      if (mounted) setState(() => _loadingSources = false);
      _toast('Could not load this notebook.', error: true);
    }
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message,
          style: const TextStyle(fontFamily: 'Google Sans Flex')),
      backgroundColor: error ? Colors.redAccent : _accentBlue,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _addTextSource() async {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Paste text source',
            style: TextStyle(
                fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex')),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                    hintText: 'Title (e.g. Lecture 3 notes)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bodyCtrl,
                maxLines: 8,
                decoration:
                    const InputDecoration(hintText: 'Paste the text here...'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _accentBlue),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (result != true || bodyCtrl.text.trim().isEmpty) {
      titleCtrl.dispose();
      bodyCtrl.dispose();
      return;
    }
    final source = NotebookSource(
      id: _uuid.v4(),
      notebookId: widget.notebook.id,
      title: titleCtrl.text.trim().isEmpty
          ? 'Pasted source'
          : titleCtrl.text.trim(),
      mimeType: 'text/plain',
      textContent: bodyCtrl.text.trim(),
      createdAt: DateTime.now(),
    );
    titleCtrl.dispose();
    bodyCtrl.dispose();
    await _persistSource(source);
  }

  Future<void> _addFileSource() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt', 'md'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      _toast('Could not read that file.', error: true);
      return;
    }
    final text = file.extension == 'txt' || file.extension == 'md';
    await _persistSource(NotebookSource(
      id: _uuid.v4(),
      notebookId: widget.notebook.id,
      title: file.name,
      mimeType: file.extension == 'pdf' ? 'application/pdf' : 'text/plain',
      textContent: text ? utf8.decode(bytes, allowMalformed: true) : null,
      base64Data: text ? null : base64Encode(bytes),
      createdAt: DateTime.now(),
    ));
  }

  Future<void> _persistSource(NotebookSource source) async {
    try {
      final saved = await _repo.addSource(source);
      if (!mounted) return;
      setState(() => _sources.add(saved));
      _toast('Source added.');
      _loadSuggestions();
    } catch (_) {
      _toast('Failed to add source.', error: true);
    }
  }

  Future<void> _deleteSource(NotebookSource source) async {
    try {
      await _repo.deleteSource(source.id);
      if (mounted) setState(() => _sources.removeWhere((s) => s.id == source.id));
    } catch (_) {
      _toast('Could not delete source.', error: true);
    }
  }

  Future<void> _loadSuggestions() async {
    if (_sources.isEmpty) return;
    try {
      final qs = await _gemini.suggestQuestions(_sources);
      if (mounted) setState(() => _suggestedQuestions = qs);
    } catch (_) {}
  }

  Future<void> _sendMessage([String? presetText]) async {
    if (_generalAskMode) return _sendGeneralMessage(presetText);
    final text = (presetText ?? _chatController.text).trim();
    if (text.isEmpty || _sendingMessage) return;
    if (_sources.isEmpty) {
      _toast('Add a source first so I have something to answer from.',
          error: true);
      return;
    }

    _chatController.clear();
    final userMsg = ChatMessage(
        id: _uuid.v4(), isUser: true, text: text, createdAt: DateTime.now());
    setState(() {
      _messages.add(userMsg);
      _sendingMessage = true;
      _suggestedQuestions = [];
    });
    _scrollToBottom();
    unawaited(_repo.addMessage(widget.notebook.id, userMsg));

    try {
      final answer = await _gemini.answerFromSources(
        sources: _sources,
        history: _messages.sublist(0, _messages.length - 1),
        question: text,
      );
      final aiMsg = ChatMessage(
          id: _uuid.v4(), isUser: false, text: answer, createdAt: DateTime.now());
      if (!mounted) return;
      setState(() {
        _messages.add(aiMsg);
        _sendingMessage = false;
      });
      unawaited(_repo.addMessage(widget.notebook.id, aiMsg));
      _scrollToBottom();
    } on GeminiException catch (e) {
      if (mounted) setState(() => _sendingMessage = false);
      _toast(e.message, error: true);
    } catch (_) {
      if (mounted) setState(() => _sendingMessage = false);
      _toast('Something went wrong reaching Gemini.', error: true);
    }
  }

  Future<void> _sendGeneralMessage([String? presetText]) async {
    final text = (presetText ?? _chatController.text).trim();
    if (text.isEmpty || _sendingMessage) return;
    _chatController.clear();
    final userMsg = ChatMessage(
      id: _uuid.v4(),
      isUser: true,
      text: text,
      createdAt: DateTime.now(),
    );
    setState(() {
      _generalMessages.add(userMsg);
      _sendingMessage = true;
    });
    _scrollToBottom();

    try {
      final answer = await _gemini.askNotebookGeneral(
        question: text,
        history: _generalMessages.sublist(0, _generalMessages.length - 1),
      );
      final aiMsg = ChatMessage(
        id: _uuid.v4(),
        isUser: false,
        text: answer,
        createdAt: DateTime.now(),
      );
      if (!mounted) return;
      setState(() {
        _generalMessages.add(aiMsg);
        _sendingMessage = false;
      });
      _scrollToBottom();
    } on GeminiException catch (e) {
      if (mounted) setState(() => _sendingMessage = false);
      _toast(e.message, error: true);
    } catch (_) {
      if (mounted) setState(() => _sendingMessage = false);
      _toast('Something went wrong reaching Gemini.', error: true);
    }
  }

  void _setGeneralAskMode(bool enabled) {
    if (_generalAskMode == enabled) return;
    setState(() {
      _generalAskMode = enabled;
      _suggestedQuestions = [];
      _chatController.clear();
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScroll.hasClients) {
        _chatScroll.animateTo(_chatScroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _generateSummary() async {
    if (_sources.isEmpty) {
      _toast('Add sources first.', error: true);
      return;
    }
    setState(() => _generatingSummary = true);
    try {
      final summary = await _gemini.summarizeNotebook(_sources);
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _generatingSummary = false;
      });
      await _repo.updateSummary(widget.notebook.id, summary);
    } catch (_) {
      if (mounted) setState(() => _generatingSummary = false);
      _toast('Could not generate a summary.', error: true);
    }
  }

  Future<void> _generateAudioOverview() async {
    if (_sources.isEmpty) {
      _toast('Add sources first.', error: true);
      return;
    }
    setState(() => _generatingScript = true);
    try {
      final script = await _gemini.generateAudioOverviewScript(_sources);
      if (!mounted) return;
      setState(() {
        _audioScript = script.trim();
        _generatingScript = false;
        _audioProgress = 0;
        _audioSeekLine = 0;
      });
      _prepareAudioTimeline();
    } catch (_) {
      if (mounted) setState(() => _generatingScript = false);
      _toast('Could not generate the audio overview.', error: true);
    }
  }

  List<String> _audioLines() => _audioScript == null
      ? const []
      : _audioScript!
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

  List<String> _audioSpokenLines() => _audioLines()
      .map((line) => line
          .replaceFirst(RegExp(r'^Host [AB]:\s*', caseSensitive: false), '')
          .trim())
      .where((line) => line.isNotEmpty)
      .toList();

  void _prepareAudioTimeline() {
    final spoken = _audioSpokenLines();
    var offset = 0;
    final offsets = <int>[];
    for (final line in spoken) {
      offsets.add(offset);
      offset += line.length + 1;
    }
    if (!mounted) return;
    setState(() {
      _audioLineOffsets = offsets;
      _audioTotalChars = offset.clamp(1, 1 << 30);
    });
  }

  Future<List<Map<String, String>>> _englishVoices() async {
    final voices = await _tts.getVoices;
    return (voices is List ? voices : const [])
        .whereType<Map>()
        .map((v) => Map<String, String>.from(v.map((key, value) =>
            MapEntry(key.toString(), value.toString()))))
        .where((v) => (v['locale'] ?? '').toLowerCase().startsWith('en'))
        .toList();
  }

  Future<void> _speakFromLine(int startLine) async {
    final lines = _audioLines();
    if (lines.isEmpty) return;
    final voices = await _englishVoices();
    final hostA = voices.isNotEmpty ? voices.first : null;
    final hostB = voices.length > 1 ? voices[1] : hostA;
    _audioSpeakingLine = startLine.clamp(0, lines.length - 1);

    if (mounted) {
      setState(() {
        _speaking = true;
        _audioProgress = _audioLineOffsets.isEmpty
            ? 0
            : (_audioLineOffsets[_audioSpeakingLine] / _audioTotalChars)
                .clamp(0.0, 1.0);
      });
    }

    for (var i = _audioSpeakingLine; i < lines.length; i++) {
      if (!_speaking) break;
      _audioSpeakingLine = i;
      final raw = lines[i];
      final isHostB = RegExp(r'^Host B:', caseSensitive: false).hasMatch(raw);
      final spoken = raw
          .replaceFirst(RegExp(r'^Host [AB]:\s*', caseSensitive: false), '')
          .trim();
      if (isHostB && hostB != null) {
        await _tts.setVoice(hostB);
      } else if (hostA != null) {
        await _tts.setVoice(hostA);
      }
      await _tts.speak(spoken);
      if (mounted && _speaking) {
        final end = _audioLineOffsets.isNotEmpty && i < _audioLineOffsets.length
            ? (_audioLineOffsets[i] + spoken.length + 1) /
                _audioTotalChars
            : (i + 1) / lines.length;
        setState(() => _audioProgress = end.clamp(0.0, 1.0));
      }
    }
    if (mounted && _speaking) {
      setState(() {
        _speaking = false;
        _audioProgress = 1;
      });
    }
  }

  Future<void> _toggleNarration() async {
    if (_audioScript == null) return;
    if (_speaking) {
      await _tts.stop();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    if (_audioLineOffsets.isEmpty) _prepareAudioTimeline();
    await _speakFromLine(_audioSeekLine);
  }

  Future<void> _seekAudio(double value) async {
    if (_audioScript == null) return;
    final lines = _audioLines();
    if (lines.isEmpty) return;
    final target = (value * _audioTotalChars).round();
    var line = 0;
    for (var i = 0; i < _audioLineOffsets.length; i++) {
      if (_audioLineOffsets[i] <= target) {
        line = i;
      } else {
        break;
      }
    }
    if (mounted) {
      setState(() {
        _audioProgress = value;
        _audioSeekLine = line;
      });
    }
    if (_speaking) {
      await _tts.stop();
      if (mounted) setState(() => _speaking = false);
      await _speakFromLine(line);
    }
  }

  String _audioTime(double p) {
    // The script is synthesized on-device, so its exact final duration is not
    // known until playback. This estimate is derived from the generated text
    // and stays synchronized to the TTS progress callback rather than a timer.
    const charsPerSecond = 13.0;
    final totalSeconds = (_audioTotalChars / charsPerSecond)
        .round()
        .clamp(1, 60 * 60);
    final seconds = (totalSeconds * p).round().clamp(0, totalSeconds);
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _saveMessageAsNote(ChatMessage message) async {
    HapticFeedback.mediumImpact();
    final firstLine = message.text.split('\n').first;
    final note = NotebookNote(
      id: _uuid.v4(),
      notebookId: widget.notebook.id,
      title: firstLine.length > 60 ? '${firstLine.substring(0, 60)}...' : firstLine,
      content: message.text,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    try {
      final saved = await _repo.addNote(note);
      if (!mounted) return;
      setState(() => _notes.insert(0, saved));
      _toast('Saved to notes.');
    } catch (_) {
      _toast('Could not save the note.', error: true);
    }
  }

  Future<void> _openNoteEditor({NotebookNote? existing}) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final contentCtrl = TextEditingController(text: existing?.content ?? '');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(existing == null ? 'New note' : 'Edit note',
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex')),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(hintText: 'Title')),
              const SizedBox(height: 12),
              TextField(
                  controller: contentCtrl,
                  maxLines: 10,
                  decoration:
                      const InputDecoration(hintText: 'Write your note...')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _accentBlue),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (saved != true) {
      titleCtrl.dispose();
      contentCtrl.dispose();
      return;
    }
    final title = titleCtrl.text.trim().isEmpty
        ? 'Untitled note'
        : titleCtrl.text.trim();
    final content = contentCtrl.text.trim();
    titleCtrl.dispose();
    contentCtrl.dispose();

    try {
      if (existing == null) {
        final note = NotebookNote(
          id: _uuid.v4(),
          notebookId: widget.notebook.id,
          title: title,
          content: content,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final createdNote = await _repo.addNote(note);
        if (mounted) setState(() => _notes.insert(0, createdNote));
      } else {
        final updated =
            await _repo.updateNote(existing.id, title: title, content: content);
        if (mounted) {
          setState(() {
            _notes.removeWhere((n) => n.id == existing.id);
            _notes.insert(0, updated);
          });
        }
      }
    } catch (_) {
      _toast('Could not save the note.', error: true);
    }
  }

  Future<void> _deleteNote(NotebookNote note) async {
    try {
      await _repo.deleteNote(note.id);
      if (mounted) setState(() => _notes.removeWhere((n) => n.id == note.id));
    } catch (_) {
      _toast('Could not delete the note.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFEBF0F5),
      appBar: AppBar(
        title: Text(widget.notebook.title,
            style: TextStyle(
                color: textColor,
                fontFamily: 'Google Sans Flex',
                fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: textColor),
        bottom: TabBar(
          controller: _tabController,
          labelColor: _accentBlue,
          unselectedLabelColor: isDark ? Colors.white54 : Colors.black45,
          indicatorColor: _accentBlue,
          labelStyle: const TextStyle(
              fontFamily: 'Google Sans Flex', fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Sources'),
            Tab(text: 'Chat'),
            Tab(text: 'Studio'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSourcesTab(isDark, textColor),
          _buildChatTab(isDark, textColor),
          _buildStudioTab(isDark, textColor),
        ],
      ),
    );
  }

  Widget _buildSourcesTab(bool isDark, Color textColor) {
    if (_loadingSources) {
      return const Center(child: CircularProgressIndicator(color: _accentBlue));
    }
    return Stack(
      children: [
        _sources.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'No sources yet.\nAdd notes, a PDF, or pasted text to ground this notebook.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black45,
                        fontFamily: 'Google Sans Flex'),
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                itemCount: _sources.length,
                itemBuilder: (context, i) {
                  final s = _sources[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          s.mimeType == 'application/pdf'
                              ? Icons.picture_as_pdf_rounded
                              : Icons.notes_rounded,
                          color: _accentBlue,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(s.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Google Sans Flex')),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.redAccent, size: 20),
                          onPressed: () => _deleteSource(s),
                        ),
                      ],
                    ),
                  );
                },
              ),
        Positioned(
          right: 20,
          bottom: 24,
          child: Row(
            children: [
              FloatingActionButton(
                heroTag: 'add_text',
                backgroundColor: Colors.white,
                foregroundColor: _accentBlue,
                onPressed: _addTextSource,
                child: const Icon(Icons.text_snippet_outlined),
              ),
              const SizedBox(width: 12),
              FloatingActionButton.extended(
                heroTag: 'add_file',
                backgroundColor: _accentBlue,
                foregroundColor: Colors.white,
                onPressed: _addFileSource,
                icon: const Icon(Icons.upload_file_rounded),
                label: const Text('Add source',
                    style: TextStyle(fontFamily: 'Google Sans Flex')),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChatTab(bool isDark, Color textColor) {
    final activeMessages = _generalAskMode ? _generalMessages : _messages;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(.06)
                  : Colors.white.withOpacity(.75),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: isDark ? Colors.white12 : Colors.black12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _setGeneralAskMode(false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: !_generalAskMode
                            ? _accentBlue.withOpacity(.16)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text('Notebook Sources',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontFamily: 'Google Sans Flex',
                              fontWeight: FontWeight.w600,
                              color: !_generalAskMode
                                  ? _accentBlue
                                  : (isDark
                                      ? Colors.white60
                                      : Colors.black54))),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _setGeneralAskMode(true),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: _generalAskMode
                            ? _accentBlue.withOpacity(.16)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.public_rounded,
                              size: 16,
                              color: _generalAskMode
                                  ? _accentBlue
                                  : (isDark
                                      ? Colors.white60
                                      : Colors.black54)),
                          const SizedBox(width: 5),
                          Text('Ask AI + Web',
                              style: TextStyle(
                                  fontFamily: 'Google Sans Flex',
                                  fontWeight: FontWeight.w600,
                                  color: _generalAskMode
                                      ? _accentBlue
                                      : (isDark
                                          ? Colors.white60
                                          : Colors.black54))),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: activeMessages.isEmpty
              ? _buildChatEmptyState(isDark, textColor)
              : ListView.builder(
                  controller: _chatScroll,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  itemCount: activeMessages.length + (_sendingMessage ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i >= activeMessages.length) return _buildTypingBubble(isDark);
                    return _buildMessageBubble(activeMessages[i], isDark, textColor);
                  },
                ),
        ),
        _buildChatInput(isDark, textColor),
      ],
    );
  }

  Widget _buildChatEmptyState(bool isDark, Color textColor) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),
        Icon(Icons.chat_bubble_outline_rounded,
            size: 48, color: _accentBlue.withOpacity(0.6)),
        const SizedBox(height: 16),
        Text(
          _generalAskMode
              ? 'Ask Gemini anything. This mode is separate from your notebook sources and can browse the web.'
              : (_sources.isEmpty
                  ? 'Add a source first, then ask anything about it.'
                  : 'Ask anything grounded in your sources.'),
          textAlign: TextAlign.center,
          style: TextStyle(
              color: isDark ? Colors.white60 : Colors.black54,
              fontFamily: 'Google Sans Flex'),
        ),
        if (!_generalAskMode && _suggestedQuestions.isNotEmpty) ...[
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: _suggestedQuestions
                .map((q) => ActionChip(
                      label: Text(q,
                          style:
                              const TextStyle(fontFamily: 'Google Sans Flex')),
                      backgroundColor: _accentBlue.withOpacity(0.12),
                      onPressed: () => _sendMessage(q),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isDark, Color textColor) {
    final isUser = msg.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78),
            decoration: BoxDecoration(
              color: isUser
                  ? _accentBlue
                  : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isUser ? 20 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 20),
              ),
            ),
            child: Text(
              msg.text,
              style: TextStyle(
                color: isUser ? Colors.white : textColor,
                fontFamily: 'Google Sans Flex',
                fontSize: 14.5,
                height: 1.4,
              ),
            ),
          ),
          if (!isUser)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: GestureDetector(
                onTap: () => _saveMessageAsNote(msg),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bookmark_add_outlined,
                        size: 14,
                        color: isDark ? Colors.white38 : Colors.black38),
                    const SizedBox(width: 4),
                    Text('Save as note',
                        style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : Colors.black38,
                            fontFamily: 'Google Sans Flex')),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypingBubble(bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const SizedBox(
          width: 20,
          height: 12,
          child: Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: _accentBlue),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatInput(bool isDark, Color textColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withOpacity(0.4)
                  : Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                  color: isDark ? Colors.white12 : Colors.white70),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    style: TextStyle(
                        color: textColor, fontFamily: 'Google Sans Flex'),
                    decoration: InputDecoration(
                      hintText: _generalAskMode
                          ? 'Ask anything, with web access...'
                          : 'Ask about your sources...',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: _accentBlue),
                  onPressed: _sendingMessage ? null : () => _sendMessage(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudioTab(bool isDark, Color textColor) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildStudioCard(
          isDark: isDark,
          textColor: textColor,
          icon: Icons.summarize_rounded,
          title: 'Notebook summary',
          child: _generatingSummary
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                      child: CircularProgressIndicator(color: _accentBlue)),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _summary?.isNotEmpty == true
                          ? _summary!
                          : 'Generate a summary of everything in this notebook.',
                      style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontFamily: 'Google Sans Flex',
                          height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _generateSummary,
                      child: Text(
                          _summary == null ? 'Generate summary' : 'Regenerate'),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        _buildStudioCard(
          isDark: isDark,
          textColor: textColor,
          icon: Icons.quiz_rounded,
          title: 'Quiz Generator',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Generate source-grounded MCQs with exactly 4 options, a hint before answering, and an explanation after you choose.',
                  style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontFamily: 'Google Sans Flex',
                      height: 1.45)),
              const SizedBox(height: 8),
              Text('Question limit: 1–49. 50 is not allowed.',
                  style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black45,
                      fontSize: 12,
                      fontFamily: 'Google Sans Flex')),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _accentBlue, foregroundColor: Colors.white),
                onPressed: _sources.isEmpty
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => NotebookQuizScreen(
                                  notebook: widget.notebook,
                                  sources: _sources)),
                        ),
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Open Quiz Generator'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildStudioCard(
          isDark: isDark,
          textColor: textColor,
          icon: Icons.podcasts_rounded,
          title: 'Audio Overview',
          child: _generatingScript
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                      child: CircularProgressIndicator(color: _accentBlue)),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_audioScript == null)
                      Text(
                        'Generate a two-host discussion of your sources, then listen to it narrated on-device.',
                        style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontFamily: 'Google Sans Flex',
                            height: 1.4),
                      ),
                    if (_audioScript != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF111318)
                              : const Color(0xFFF4F7FA),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    gradient: const LinearGradient(colors: [
                                      Color(0xFF32C5FF),
                                      Color(0xFF7C5CFF)
                                    ]),
                                  ),
                                  child: const Icon(Icons.graphic_eq_rounded,
                                      color: Colors.white),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                    child: Text('Two-host study discussion',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Google Sans Flex'))),
                                IconButton(
                                  onPressed: _toggleNarration,
                                  icon: Icon(
                                      _speaking
                                          ? Icons.stop_circle_rounded
                                          : Icons.play_circle_fill_rounded,
                                      size: 42,
                                      color: _accentBlue),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Slider(
                              value: _audioProgress.clamp(0.0, 1.0),
                              onChanged: _seekAudio,
                              activeColor: _accentBlue,
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_audioTime(_audioProgress),
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                                Text(_audioTime(1),
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Text('Live transcript',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Google Sans Flex')),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 190,
                              child: ListView.builder(
                                itemCount: _audioLines().length,
                                itemBuilder: (_, i) {
                                  final line = _audioLines()[i];
                                  final active =
                                      _speaking && i == _audioSpeakingLine;
                                  return Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 6),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 120),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: active
                                            ? _accentBlue.withOpacity(.12)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        line.replaceFirst(
                                            RegExp(r'^Host [AB]:\s*',
                                                caseSensitive: false),
                                            ''),
                                        style: TextStyle(
                                            fontFamily: 'Google Sans Flex',
                                            height: 1.35,
                                            fontWeight: active
                                                ? FontWeight.w600
                                                : FontWeight.normal),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _generateAudioOverview,
                      child: Text(
                          _audioScript == null ? 'Generate script' : 'Regenerate'),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        _buildStudioCard(
          isDark: isDark,
          textColor: textColor,
          icon: Icons.sticky_note_2_outlined,
          title: 'Notes',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_notes.isEmpty)
                Text('No notes yet. Write one, or save an answer from Chat.',
                    style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black45,
                        fontFamily: 'Google Sans Flex')),
              ..._notes.map((note) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF161616)
                          : const Color(0xFFF4F6F8),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: InkWell(
                      onTap: () => _openNoteEditor(existing: note),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(note.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: textColor,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Google Sans Flex')),
                                const SizedBox(height: 4),
                                Text(note.content,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.black54,
                                        fontSize: 12.5,
                                        fontFamily: 'Google Sans Flex')),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.file_download_outlined,
                                color: _accentBlue),
                            onSelected: (format) async {
                              try {
                                await NoteExportService.export(
                                    note: note, format: format);
                              } catch (_) {
                                _toast('Could not export the note.', error: true);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                  value: 'pdf', child: Text('PDF (.pdf)')),
                              PopupMenuItem(
                                  value: 'docx', child: Text('Word (.docx)')),
                              PopupMenuItem(
                                  value: 'png', child: Text('Image (.png)')),
                              PopupMenuItem(
                                  value: 'pptx', child: Text('PowerPoint (.pptx)')),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded,
                                size: 18, color: Colors.redAccent),
                            onPressed: () => _deleteNote(note),
                          ),
                        ],
                      ),
                    ),
                  )),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: () => _openNoteEditor(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New note'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStudioCard({
    required bool isDark,
    required Color textColor,
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _accentBlue),
              const SizedBox(width: 10),
              Text(title,
                  style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Google Sans Flex')),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

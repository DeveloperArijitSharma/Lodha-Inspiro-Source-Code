import 'dart:convert';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:uuid/uuid.dart';

import '../gemini/gemini_service.dart';
import 'notebook_models.dart';
import 'notebook_repository.dart';

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

  List<NotebookNote> _notes = [];

  final _chatController = TextEditingController();
  final _chatScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _summary = widget.notebook.summary;
    _loadAll();
    _tts.setCompletionHandler(() => setState(() => _speaking = false));
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
      setState(() {
        _sources = sources;
        _messages = messages;
        _notes = notes;
        _loadingSources = false;
      });
      if (messages.isEmpty && sources.isNotEmpty) _loadSuggestions();
    } catch (e) {
      setState(() => _loadingSources = false);
      _toast('Could not load this notebook.', error: true);
    }
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(fontFamily: 'Google Sans Flex')),
      backgroundColor: error ? Colors.redAccent : _accentBlue,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ---------------------------------------------------------------- SOURCES

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
            style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex')),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(hintText: 'Title (e.g. Lecture 3 notes)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bodyCtrl,
                maxLines: 8,
                decoration: const InputDecoration(hintText: 'Paste the text here...'),
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

    if (result != true || bodyCtrl.text.trim().isEmpty) return;
    final source = NotebookSource(
      id: _uuid.v4(),
      notebookId: widget.notebook.id,
      title: titleCtrl.text.trim().isEmpty ? 'Pasted text' : titleCtrl.text.trim(),
      mimeType: 'text/plain',
      textContent: bodyCtrl.text.trim(),
      createdAt: DateTime.now(),
    );
    await _persistSource(source);
  }

  Future<void> _addFileSource() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true, // critical for web + consistent cross-platform behaviour
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt', 'md'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) {
      _toast('Could not read that file on this platform.', error: true);
      return;
    }

    final isText = file.extension == 'txt' || file.extension == 'md';
    final source = NotebookSource(
      id: _uuid.v4(),
      notebookId: widget.notebook.id,
      title: file.name,
      mimeType: file.extension == 'pdf' ? 'application/pdf' : 'text/plain',
      textContent: isText ? utf8.decode(file.bytes!, allowMalformed: true) : null,
      base64Data: isText ? null : base64Encode(file.bytes!),
      createdAt: DateTime.now(),
    );
    await _persistSource(source);
  }

  Future<void> _persistSource(NotebookSource source) async {
    HapticFeedback.mediumImpact();
    try {
      final saved = await _repo.addSource(source);
      setState(() => _sources.add(saved));
      _toast('Source added.');
      _loadSuggestions();
    } catch (e) {
      _toast('Failed to add source.', error: true);
    }
  }

  Future<void> _deleteSource(NotebookSource source) async {
    await _repo.deleteSource(source.id);
    setState(() => _sources.removeWhere((s) => s.id == source.id));
  }

  Future<void> _loadSuggestions() async {
    if (_sources.isEmpty) return;
    try {
      final qs = await _gemini.suggestQuestions(_sources);
      if (mounted) setState(() => _suggestedQuestions = qs);
    } catch (_) {
      // Suggestions are a nice-to-have; fail silently.
    }
  }

  // ------------------------------------------------------------------- CHAT

  Future<void> _sendMessage([String? presetText]) async {
    final text = (presetText ?? _chatController.text).trim();
    if (text.isEmpty || _sendingMessage) return;
    if (_sources.isEmpty) {
      _toast('Add a source first so I have something to answer from.', error: true);
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
      setState(() {
        _messages.add(aiMsg);
        _sendingMessage = false;
      });
      unawaited(_repo.addMessage(widget.notebook.id, aiMsg));
      _scrollToBottom();
    } on GeminiException catch (e) {
      setState(() => _sendingMessage = false);
      _toast(e.message, error: true);
    } catch (e) {
      setState(() => _sendingMessage = false);
      _toast('Something went wrong reaching Gemini.', error: true);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScroll.hasClients) {
        _chatScroll.animateTo(_chatScroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  // ---------------------------------------------------------------- STUDIO

  Future<void> _generateSummary() async {
    if (_sources.isEmpty) {
      _toast('Add sources first.', error: true);
      return;
    }
    setState(() => _generatingSummary = true);
    try {
      final summary = await _gemini.summarizeNotebook(_sources);
      setState(() {
        _summary = summary;
        _generatingSummary = false;
      });
      await _repo.updateSummary(widget.notebook.id, summary);
    } catch (e) {
      setState(() => _generatingSummary = false);
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
      setState(() {
        _audioScript = script;
        _generatingScript = false;
      });
    } catch (e) {
      setState(() => _generatingScript = false);
      _toast('Could not generate the audio overview.', error: true);
    }
  }

  Future<void> _toggleNarration() async {
    if (_audioScript == null) return;
    if (_speaking) {
      await _tts.stop();
      setState(() => _speaking = false);
      return;
    }
    // Strip "Host A:"/"Host B:" labels for smoother single-voice narration.
    final spoken = _audioScript!.replaceAll(RegExp(r'Host [AB]:\s*'), '');
    setState(() => _speaking = true);
    await _tts.speak(spoken);
  }

  // -------------------------------------------------------------------- NOTES

  Future<void> _saveMessageAsNote(ChatMessage message) async {
    HapticFeedback.mediumImpact();
    final note = NotebookNote(
      id: _uuid.v4(),
      notebookId: widget.notebook.id,
      title: message.text.split('\n').first.length > 60
          ? '${message.text.split('\n').first.substring(0, 60)}...'
          : message.text.split('\n').first,
      content: message.text,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    try {
      final saved = await _repo.addNote(note);
      setState(() => _notes.insert(0, saved));
      _toast('Saved to notes.');
    } catch (e) {
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
            style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex')),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(hintText: 'Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentCtrl,
                maxLines: 10,
                decoration: const InputDecoration(hintText: 'Write your note...'),
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
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (saved != true) return;
    final title = titleCtrl.text.trim().isEmpty ? 'Untitled note' : titleCtrl.text.trim();
    final content = contentCtrl.text.trim();

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
        setState(() => _notes.insert(0, createdNote));
      } else {
        final updated = await _repo.updateNote(existing.id, title: title, content: content);
        setState(() {
          _notes.removeWhere((n) => n.id == existing.id);
          _notes.insert(0, updated);
        });
      }
    } catch (e) {
      _toast('Could not save the note.', error: true);
    }
  }

  Future<void> _deleteNote(NotebookNote note) async {
    await _repo.deleteNote(note.id);
    setState(() => _notes.removeWhere((n) => n.id == note.id));
  }

  // ------------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFEBF0F5),
      appBar: AppBar(
        title: Text(widget.notebook.title,
            style: TextStyle(
                color: textColor, fontFamily: 'Google Sans Flex', fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: textColor),
        bottom: TabBar(
          controller: _tabController,
          labelColor: _accentBlue,
          unselectedLabelColor: isDark ? Colors.white54 : Colors.black45,
          indicatorColor: _accentBlue,
          labelStyle: const TextStyle(fontFamily: 'Google Sans Flex', fontWeight: FontWeight.bold),
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
                          icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 20),
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
                label: const Text('Add source', style: TextStyle(fontFamily: 'Google Sans Flex')),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChatTab(bool isDark, Color textColor) {
    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? _buildChatEmptyState(isDark, textColor)
              : ListView.builder(
                  controller: _chatScroll,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  itemCount: _messages.length + (_sendingMessage ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i >= _messages.length) {
                      return _buildTypingBubble(isDark);
                    }
                    return _buildMessageBubble(_messages[i], isDark, textColor);
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
        Icon(Icons.chat_bubble_outline_rounded, size: 48, color: _accentBlue.withOpacity(0.6)),
        const SizedBox(height: 16),
        Text(
          _sources.isEmpty
              ? 'Add a source first, then ask anything about it.'
              : 'Ask anything grounded in your sources.',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: isDark ? Colors.white60 : Colors.black54, fontFamily: 'Google Sans Flex'),
        ),
        if (_suggestedQuestions.isNotEmpty) ...[
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: _suggestedQuestions
                .map((q) => ActionChip(
                      label: Text(q, style: const TextStyle(fontFamily: 'Google Sans Flex')),
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
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
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
                        size: 14, color: isDark ? Colors.white38 : Colors.black38),
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
              child: CircularProgressIndicator(strokeWidth: 2, color: _accentBlue),
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
              color: isDark ? Colors.black.withOpacity(0.4) : Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: isDark ? Colors.white12 : Colors.white70),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    style: TextStyle(color: textColor, fontFamily: 'Google Sans Flex'),
                    decoration: const InputDecoration(
                      hintText: 'Ask about your sources...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                  child: Center(child: CircularProgressIndicator(color: _accentBlue)),
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
                      child: Text(_summary == null ? 'Generate summary' : 'Regenerate'),
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
                  child: Center(child: CircularProgressIndicator(color: _accentBlue)),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _audioScript == null
                          ? 'Generate a two-host discussion of your sources, then listen to it narrated on-device.'
                          : _audioScript!,
                      maxLines: _audioScript == null ? null : 6,
                      overflow: TextOverflow.fade,
                      style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontFamily: 'Google Sans Flex',
                          height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: _generateAudioOverview,
                          child: Text(_audioScript == null ? 'Generate script' : 'Regenerate'),
                        ),
                        if (_audioScript != null) ...[
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: _accentBlue),
                            onPressed: _toggleNarration,
                            icon: Icon(_speaking ? Icons.stop_rounded : Icons.play_arrow_rounded,
                                color: Colors.white),
                            label: Text(_speaking ? 'Stop' : 'Play',
                                style: const TextStyle(color: Colors.white)),
                          ),
                        ],
                      ],
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
                      color: isDark ? const Color(0xFF161616) : const Color(0xFFF4F6F8),
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
                                        color: isDark ? Colors.white54 : Colors.black54,
                                        fontSize: 12.5,
                                        fontFamily: 'Google Sans Flex')),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18, color: Colors.redAccent),
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
                      color: textColor, fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex')),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// Small helper so we can fire-and-forget Supabase writes without awaiting
// them inline (keeps the chat UI snappy while still persisting history).
void unawaited(Future<void> future) {}

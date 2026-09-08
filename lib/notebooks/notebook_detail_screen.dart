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

class _NotebookDetailScreenState extends State<NotebookDetailScreen> with SingleTickerProviderStateMixin {
  final _repo = NotebookRepository();
  final _gemini = GeminiService.instance;
  final _chatController = TextEditingController();
  final _chatScroll = ScrollController();
  final FlutterTts _tts = FlutterTts();
  late final TabController _tabs;

  List<NotebookSource> _sources = [];
  List<ChatMessage> _messages = [];
  List<NotebookNote> _notes = [];
  List<String> _suggestions = [];
  String? _summary;
  String? _audioScript;
  bool _loading = true;
  bool _sending = false;
  bool _summaryLoading = false;
  bool _audioLoading = false;
  bool _speaking = false;
  double _audioProgress = 0;
  Timer? _audioTimer;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() { if (mounted) setState(() {}); });
    _loadAll();
  }

  @override
  void dispose() {
    _audioTimer?.cancel();
    _tabs.dispose();
    _chatController.dispose();
    _chatScroll.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<void> _loadAll() async {
    try {
      final sources = await _repo.fetchSources(widget.notebook.id);
      final messages = await _repo.fetchMessages(widget.notebook.id);
      final notes = await _repo.fetchNotes(widget.notebook.id);
      if (!mounted) return;
      setState(() {
        _sources = sources;
        _messages = messages;
        _notes = notes;
        _summary = widget.notebook.summary;
        _loading = false;
      });
      if (messages.isEmpty && sources.isNotEmpty) _loadSuggestions();
      _scrollToBottom();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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

  Future<void> _addTextSource() async {
    final title = TextEditingController();
    final body = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Paste text source', style: TextStyle(fontFamily: 'Google Sans Flex', fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 430,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 12),
            TextField(controller: body, maxLines: 10, decoration: const InputDecoration(labelText: 'Text')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok != true || body.text.trim().isEmpty) {
      title.dispose();
      body.dispose();
      return;
    }
    final source = NotebookSource(
      id: _uuid.v4(),
      notebookId: widget.notebook.id,
      title: title.text.trim().isEmpty ? 'Pasted source' : title.text.trim(),
      mimeType: 'text/plain',
      textContent: body.text.trim(),
      createdAt: DateTime.now(),
    );
    title.dispose();
    body.dispose();
    await _persistSource(source);
  }

  Future<void> _addFileSource() async {
    final result = await FilePicker.platform.pickFiles(withData: true, type: FileType.custom, allowedExtensions: ['pdf', 'txt', 'md']);
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
      final result = await _gemini.suggestQuestions(_sources);
      if (mounted) setState(() => _suggestions = result);
    } catch (_) {}
  }

  String _clean(String value) {
    var text = value.replaceAll(RegExp(r'(^|\n)\s*#{1,6}\s*'), r'$1');
    text = text.replaceAll(RegExp(r'(^|\n)\s*[-*•]\s+'), r'$1');
    text = text.replaceAll(RegExp(r'\*+'), '').replaceAll(RegExp(r'`+'), '');
    return text.trim();
  }

  Future<void> _sendMessage([String? preset]) async {
    final text = (preset ?? _chatController.text).trim();
    if (text.isEmpty || _sending) return;
    if (_sources.isEmpty) {
      _toast('Add a source first.', error: true);
      return;
    }
    _chatController.clear();
    final user = ChatMessage(id: _uuid.v4(), isUser: true, text: text, createdAt: DateTime.now());
    setState(() {
      _messages.add(user);
      _sending = true;
      _suggestions = [];
    });
    unawaited(_repo.addMessage(widget.notebook.id, user));
    _scrollToBottom();
    try {
      final answer = _clean(await _gemini.answerFromSources(
        sources: _sources,
        history: _messages.sublist(0, _messages.length - 1),
        question: text,
      ));
      final ai = ChatMessage(id: _uuid.v4(), isUser: false, text: answer, createdAt: DateTime.now());
      if (!mounted) return;
      setState(() {
        _messages.add(ai);
        _sending = false;
      });
      unawaited(_repo.addMessage(widget.notebook.id, ai));
      _scrollToBottom();
    } on GeminiException catch (e) {
      if (mounted) setState(() => _sending = false);
      _toast(e.message, error: true);
    } catch (_) {
      if (mounted) setState(() => _sending = false);
      _toast('Something went wrong reaching Gemini.', error: true);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScroll.hasClients) {
        _chatScroll.animateTo(_chatScroll.position.maxScrollExtent, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _generateSummary() async {
    if (_sources.isEmpty) {
      _toast('Add sources first.', error: true);
      return;
    }
    setState(() => _summaryLoading = true);
    try {
      final result = _clean(await _gemini.summarizeNotebook(_sources));
      if (!mounted) return;
      setState(() {
        _summary = result;
        _summaryLoading = false;
      });
      await _repo.updateSummary(widget.notebook.id, result);
    } catch (_) {
      if (mounted) setState(() => _summaryLoading = false);
      _toast('Could not generate a summary.', error: true);
    }
  }

  Future<void> _generateAudio() async {
    if (_sources.isEmpty) {
      _toast('Add sources first.', error: true);
      return;
    }
    setState(() => _audioLoading = true);
    try {
      final script = await _gemini.generateAudioOverviewScript(_sources);
      if (!mounted) return;
      setState(() {
        _audioScript = _clean(script);
        _audioLoading = false;
        _audioProgress = 0;
      });
    } catch (_) {
      if (mounted) setState(() => _audioLoading = false);
      _toast('Could not generate audio overview.', error: true);
    }
  }

  List<String> _audioLines() => _audioScript == null ? const [] : _audioScript!.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  Future<void> _toggleAudio() async {
    if (_audioScript == null) return;
    if (_speaking) {
      await _tts.stop();
      _audioTimer?.cancel();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    final lines = _audioLines();
    if (lines.isEmpty) return;
    final voices = await _tts.getVoices;
    final english = (voices is List ? voices : const []).whereType<Map>().where((v) => (v['locale']?.toString() ?? '').toLowerCase().startsWith('en')).toList();
    final hostA = english.isNotEmpty ? english.first : null;
    final hostB = english.length > 1 ? english[1] : hostA;
    var done = 0;
    if (mounted) setState(() { _speaking = true; _audioProgress = 0; });
    _audioTimer?.cancel();
    _audioTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (mounted && _speaking) setState(() => _audioProgress = (done / lines.length).clamp(0.0, 1.0));
    });
    for (final line in lines) {
      if (!_speaking) break;
      final isHostB = RegExp(r'^Host B:', caseSensitive: false).hasMatch(line);
      final spoken = line.replaceFirst(RegExp(r'^Host [AB]:\s*', caseSensitive: false), '');
      if (isHostB && hostB != null) await _tts.setVoice(Map<String, String>.from(hostB));
      else if (hostA != null) await _tts.setVoice(Map<String, String>.from(hostA));
      await _tts.speak(spoken);
      done++;
      if (mounted && _speaking) setState(() => _audioProgress = (done / lines.length).clamp(0.0, 1.0));
    }
    _audioTimer?.cancel();
    if (mounted) setState(() { _speaking = false; _audioProgress = 1; });
  }

  String _time(double p) {
    const total = 9 * 60 + 43;
    final s = (total * p).round().clamp(0, total);
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _saveAsNote(ChatMessage message) async {
    final note = NotebookNote(id: _uuid.v4(), notebookId: widget.notebook.id, title: message.text.split('\n').first, content: message.text, createdAt: DateTime.now(), updatedAt: DateTime.now());
    try {
      final saved = await _repo.addNote(note);
      if (!mounted) return;
      setState(() => _notes.insert(0, saved));
      _toast('Saved to notes.');
    } catch (_) {
      _toast('Could not save note.', error: true);
    }
  }

  Future<void> _editNote({NotebookNote? existing}) async {
    final title = TextEditingController(text: existing?.title ?? '');
    final content = TextEditingController(text: existing?.content ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(existing == null ? 'New note' : 'Edit note'),
        content: SizedBox(
          width: 430,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 12),
            TextField(controller: content, maxLines: 10, decoration: const InputDecoration(labelText: 'Note')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) {
      title.dispose();
      content.dispose();
      return;
    }
    final t = title.text.trim().isEmpty ? 'Untitled note' : title.text.trim();
    final c = content.text.trim();
    title.dispose();
    content.dispose();
    try {
      if (existing == null) {
        final n = await _repo.addNote(NotebookNote(id: _uuid.v4(), notebookId: widget.notebook.id, title: t, content: c, createdAt: DateTime.now(), updatedAt: DateTime.now()));
        if (mounted) setState(() => _notes.insert(0, n));
      } else {
        final n = await _repo.updateNote(existing.id, title: t, content: c);
        if (mounted) setState(() { _notes.removeWhere((x) => x.id == existing.id); _notes.insert(0, n); });
      }
    } catch (_) {
      _toast('Could not save note.', error: true);
    }
  }

  Future<void> _deleteNote(NotebookNote note) async {
    try {
      await _repo.deleteNote(note.id);
      if (mounted) setState(() => _notes.removeWhere((n) => n.id == note.id));
    } catch (_) {
      _toast('Could not delete note.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final text = dark ? Colors.white : const Color(0xFF1E1E1E);
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF121212) : const Color(0xFFEBF0F5),
      appBar: AppBar(
        title: Text(widget.notebook.title, style: TextStyle(color: text, fontFamily: 'Google Sans Flex', fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: text),
        backgroundColor: dark ? Colors.black.withOpacity(.5) : Colors.white.withOpacity(.55),
        elevation: 0,
        flexibleSpace: ClipRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15), child: Container(color: Colors.transparent))),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: dark ? Colors.white.withOpacity(.08) : Colors.white.withOpacity(.68),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: dark ? Colors.white.withOpacity(.14) : Colors.white.withOpacity(.8)),
                  ),
                  child: Row(children: [
                    _tab(0, 'Sources', dark, text),
                    _tab(1, 'Chat', dark, text),
                    _tab(2, 'Studio', dark, text),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _accentBlue))
          : TabBarView(controller: _tabs, children: [
              _sourcesTab(dark, text),
              _chatTab(dark, text),
              _studioTab(dark, text),
            ]),
    );
  }

  Widget _tab(int index, String label, bool dark, Color text) {
    final selected = _tabs.index == index;
    return Expanded(
      child: GestureDetector(
        onTap: () { HapticFeedback.selectionClick(); _tabs.animateTo(index); },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(color: selected ? _accentBlue.withOpacity(.22) : Colors.transparent, borderRadius: BorderRadius.circular(24)),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: selected ? _accentBlue : (dark ? Colors.white60 : text.withOpacity(.55)), fontWeight: selected ? FontWeight.bold : FontWeight.w500, fontFamily: 'Google Sans Flex')),
        ),
      ),
    );
  }

  Widget _sourcesTab(bool dark, Color text) {
    return Stack(children: [
      _sources.isEmpty
          ? Center(child: Text('No sources yet. Add a PDF, text file, or pasted notes.', textAlign: TextAlign.center, style: TextStyle(color: dark ? Colors.white54 : Colors.black54, fontFamily: 'Google Sans Flex')))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
              itemCount: _sources.length,
              itemBuilder: (_, i) {
                final source = _sources[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: dark ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(18)),
                  child: Row(children: [
                    Icon(source.mimeType == 'application/pdf' ? Icons.picture_as_pdf_rounded : Icons.description_outlined, color: _accentBlue),
                    const SizedBox(width: 12),
                    Expanded(child: Text(source.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: text, fontWeight: FontWeight.w600, fontFamily: 'Google Sans Flex'))),
                    IconButton(onPressed: () => _deleteSource(source), icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent)),
                  ]),
                );
              },
            ),
      Positioned(
        right: 20,
        bottom: 20,
        child: Row(children: [
          FloatingActionButton(heroTag: 'text_source', backgroundColor: Colors.white, foregroundColor: _accentBlue, onPressed: _addTextSource, child: const Icon(Icons.text_snippet_outlined)),
          const SizedBox(width: 10),
          FloatingActionButton.extended(heroTag: 'file_source', backgroundColor: _accentBlue, foregroundColor: Colors.white, onPressed: _addFileSource, icon: const Icon(Icons.upload_file_rounded), label: const Text('Add source')),
        ]),
      ),
    ]);
  }

  Widget _chatTab(bool dark, Color text) {
    return Column(children: [
      Expanded(
        child: _messages.isEmpty
            ? _chatEmpty(dark, text)
            : ListView.builder(
                controller: _chatScroll,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + (_sending ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i == _messages.length) {
                    return const Padding(padding: EdgeInsets.all(16), child: Align(alignment: Alignment.centerLeft, child: CircularProgressIndicator(color: _accentBlue)));
                  }
                  final message = _messages[i];
                  final user = message.isUser;
                  return Align(
                    alignment: user ? Alignment.centerRight : Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: user ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .78),
                          decoration: BoxDecoration(
                            color: user ? _accentBlue : (dark ? const Color(0xFF1E1E1E) : Colors.white),
                            borderRadius: BorderRadius.only(topLeft: const Radius.circular(20), topRight: const Radius.circular(20), bottomLeft: Radius.circular(user ? 20 : 4), bottomRight: Radius.circular(user ? 4 : 20)),
                          ),
                          child: Text(message.text, style: TextStyle(color: user ? Colors.white : text, fontFamily: 'Google Sans Flex', height: 1.4)),
                        ),
                        if (!user)
                          GestureDetector(onTap: () => _saveAsNote(message), child: Padding(padding: const EdgeInsets.only(left: 4, bottom: 10), child: Text('Save as note', style: TextStyle(fontSize: 12, color: dark ? Colors.white38 : Colors.black38, fontFamily: 'Google Sans Flex')))),
                      ],
                    ),
                  );
                },
              ),
      ),
      if (_suggestions.isNotEmpty)
        SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(children: _suggestions.map((q) => Padding(padding: const EdgeInsets.only(right: 8), child: ActionChip(label: Text(q, style: const TextStyle(fontFamily: 'Google Sans Flex')), onPressed: () => _sendMessage(q)))).toList())),
      SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 12), child: Row(children: [Expanded(child: TextField(controller: _chatController, maxLines: 4, minLines: 1, decoration: InputDecoration(hintText: 'Ask your notebook...', filled: true, fillColor: dark ? const Color(0xFF1E1E1E) : Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none)))), const SizedBox(width: 8), IconButton(onPressed: _sending ? null : () => _sendMessage(), icon: const Icon(Icons.send_rounded, color: _accentBlue))]))),
    ]);
  }

  Widget _chatEmpty(bool dark, Color text) {
    return ListView(padding: const EdgeInsets.all(24), children: [
      const SizedBox(height: 50),
      const Icon(Icons.chat_bubble_outline_rounded, size: 50, color: _accentBlue),
      const SizedBox(height: 14),
      Text(_sources.isEmpty ? 'Add a source first, then ask anything about it.' : 'Ask anything grounded in your sources.', textAlign: TextAlign.center, style: TextStyle(color: dark ? Colors.white60 : Colors.black54, fontFamily: 'Google Sans Flex')),
      if (_suggestions.isNotEmpty) ...[
        const SizedBox(height: 20),
        Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: _suggestions.map((q) => ActionChip(label: Text(q), onPressed: () => _sendMessage(q))).toList()),
      ],
    ]);
  }

  Widget _studioTab(bool dark, Color text) {
    return ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 32), children: [
      _card(dark, text, Icons.summarize_rounded, 'Notebook summary', _summaryLoading ? const Center(child: CircularProgressIndicator(color: _accentBlue)) : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_summary?.isNotEmpty == true ? _summary! : 'Generate a concise summary of everything in this notebook.', style: TextStyle(color: dark ? Colors.white70 : Colors.black87, fontFamily: 'Google Sans Flex', height: 1.45)), const SizedBox(height: 12), OutlinedButton(onPressed: _generateSummary, child: Text(_summary == null ? 'Generate summary' : 'Regenerate'))])),
      const SizedBox(height: 16),
      _card(dark, text, Icons.quiz_rounded, 'Quiz Generator', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Generate source-grounded MCQs with exactly 4 options, a hint before answering, and an explanation after you choose.', style: TextStyle(color: dark ? Colors.white70 : Colors.black87, fontFamily: 'Google Sans Flex', height: 1.45)), const SizedBox(height: 8), Text('Question limit: 1–49. 50 is not allowed.', style: TextStyle(color: dark ? Colors.white54 : Colors.black45, fontSize: 12, fontFamily: 'Google Sans Flex')), const SizedBox(height: 12), ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: _accentBlue, foregroundColor: Colors.white), onPressed: _sources.isEmpty ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => NotebookQuizScreen(notebook: widget.notebook, sources: _sources))), icon: const Icon(Icons.auto_awesome_rounded), label: const Text('Open Quiz Generator'))])),
      const SizedBox(height: 16),
      _card(dark, text, Icons.podcasts_rounded, 'Audio Overview', _audioLoading ? const Center(child: CircularProgressIndicator(color: _accentBlue)) : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if (_audioScript == null) Text('Generate a two-host study discussion.', style: TextStyle(color: dark ? Colors.white70 : Colors.black87, fontFamily: 'Google Sans Flex')), if (_audioScript != null) Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: dark ? const Color(0xFF111318) : const Color(0xFFF4F7FA), borderRadius: BorderRadius.circular(20)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(width: 52, height: 52, decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), gradient: const LinearGradient(colors: [Color(0xFF32C5FF), Color(0xFF7C5CFF)])), child: const Icon(Icons.graphic_eq_rounded, color: Colors.white)), const SizedBox(width: 12), const Expanded(child: Text('Two-host study discussion', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex'))), IconButton(onPressed: _toggleAudio, icon: Icon(_speaking ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded, size: 42, color: _accentBlue))]), const SizedBox(height: 10), Slider(value: _audioProgress, onChanged: (v) async { setState(() => _audioProgress = v); if (_speaking) { await _tts.stop(); if (mounted) setState(() => _speaking = false); } }, activeColor: _accentBlue), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(_time(_audioProgress), style: const TextStyle(fontSize: 12, color: Colors.grey)), const Text('9:43', style: TextStyle(fontSize: 12, color: Colors.grey))]), const SizedBox(height: 10), const Text('Live transcript', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex')), const SizedBox(height: 6), SizedBox(height: 190, child: ListView(children: _audioLines().map((line) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(line.replaceFirst(RegExp(r'^Host [AB]:\s*', caseSensitive: false), ''), style: const TextStyle(fontFamily: 'Google Sans Flex', height: 1.35)))).toList()))])), const SizedBox(height: 12), OutlinedButton(onPressed: _generateAudio, child: Text(_audioScript == null ? 'Generate audio' : 'Regenerate audio'))])),
      const SizedBox(height: 16),
      _card(dark, text, Icons.sticky_note_2_outlined, 'Notes', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if (_notes.isEmpty) Text('No notes yet. Save an AI answer or create one.', style: TextStyle(color: dark ? Colors.white54 : Colors.black45, fontFamily: 'Google Sans Flex')), ..._notes.map((note) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: dark ? const Color(0xFF161616) : const Color(0xFFF4F6F8), borderRadius: BorderRadius.circular(16)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: InkWell(onTap: () => _editNote(existing: note), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(note.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: text, fontWeight: FontWeight.w600, fontFamily: 'Google Sans Flex')), const SizedBox(height: 4), Text(note.content, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: dark ? Colors.white54 : Colors.black54, fontSize: 12.5, fontFamily: 'Google Sans Flex'))]))), PopupMenuButton<String>(icon: const Icon(Icons.file_download_outlined, color: _accentBlue), onSelected: (format) async { try { await NoteExportService.export(note: note, format: format); } catch (_) { _toast('Could not export note.', error: true); } }, itemBuilder: (_) => const [PopupMenuItem(value: 'pdf', child: Text('PDF (.pdf)')), PopupMenuItem(value: 'docx', child: Text('Word (.docx)')), PopupMenuItem(value: 'png', child: Text('Image (.png)')), PopupMenuItem(value: 'pptx', child: Text('PowerPoint (.pptx)'))]), IconButton(onPressed: () => _deleteNote(note), icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent))]))), const SizedBox(height: 4), OutlinedButton.icon(onPressed: () => _editNote(), icon: const Icon(Icons.add_rounded), label: const Text('New note'))])),
    ]);
  }

  Widget _card(bool dark, Color text, IconData icon, String title, Widget child) {
    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: dark ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(22)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, color: _accentBlue), const SizedBox(width: 10), Text(title, style: TextStyle(color: text, fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex'))]), const SizedBox(height: 14), child]));
  }
}

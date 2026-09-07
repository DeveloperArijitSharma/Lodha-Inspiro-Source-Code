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
  bool _audioPaused = false;
  double _audioProgress = 0.0;
  Timer? _audioTimer;
  final FlutterTts _tts = FlutterTts();

  List<NotebookNote> _notes = [];
  final _chatController = TextEditingController();
  final _chatScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadNotebook();
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _speaking = false);
    });
  }

  @override
  void dispose() {
    _audioTimer?.cancel();
    _tabController.dispose();
    _chatController.dispose();
    _chatScroll.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<void> _loadNotebook() async {
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
        _loadingSources = false;
      });
      if (sources.isNotEmpty) _loadSuggestions();
      _scrollToBottom();
    } catch (_) {
      if (mounted) setState(() => _loadingSources = false);
      _toast('Could not load this notebook.', error: true);
    }
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(fontFamily: 'Google Sans Flex')),
      backgroundColor: error ? Colors.redAccent : _accentBlue,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _addFileSource() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
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
    } catch (_) {
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
    } catch (_) {}
  }

  String _cleanAiText(String value) {
    var cleaned = value.replaceAll(RegExp(r'(^|\n)\s*#{1,6}\s*'), r'$1');
    cleaned = cleaned.replaceAll(RegExp(r'(^|\n)\s*[-*•]\s+'), r'$1');
    cleaned = cleaned.replaceAll(RegExp(r'\*+'), '');
    cleaned = cleaned.replaceAll(RegExp(r'`+'), '');
    return cleaned.trim();
  }

  Future<void> _sendMessage([String? presetText]) async {
    final text = (presetText ?? _chatController.text).trim();
    if (text.isEmpty || _sendingMessage) return;
    if (_sources.isEmpty) {
      _toast('Add a source first so I have something to answer from.', error: true);
      return;
    }
    _chatController.clear();
    final userMsg = ChatMessage(id: _uuid.v4(), isUser: true, text: text, createdAt: DateTime.now());
    setState(() {
      _messages.add(userMsg);
      _sendingMessage = true;
      _suggestedQuestions = [];
    });
    _scrollToBottom();
    unawaited(_repo.addMessage(widget.notebook.id, userMsg));
    try {
      final answer = _cleanAiText(await _gemini.answerFromSources(
        sources: _sources,
        history: _messages.sublist(0, _messages.length - 1),
        question: text,
      ));
      final aiMsg = ChatMessage(id: _uuid.v4(), isUser: false, text: answer, createdAt: DateTime.now());
      setState(() {
        _messages.add(aiMsg);
        _sendingMessage = false;
      });
      unawaited(_repo.addMessage(widget.notebook.id, aiMsg));
      _scrollToBottom();
    } on GeminiException catch (e) {
      setState(() => _sendingMessage = false);
      _toast(e.message, error: true);
    } catch (_) {
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

  Future<void> _generateSummary() async {
    if (_sources.isEmpty) {
      _toast('Add sources first.', error: true);
      return;
    }
    setState(() => _generatingSummary = true);
    try {
      final summary = _cleanAiText(await _gemini.summarizeNotebook(_sources));
      setState(() {
        _summary = summary;
        _generatingSummary = false;
      });
      await _repo.updateSummary(widget.notebook.id, summary);
    } catch (_) {
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
        _audioScript = _cleanAiText(script);
        _generatingScript = false;
        _audioProgress = 0;
      });
    } catch (_) {
      setState(() => _generatingScript = false);
      _toast('Could not generate the audio overview.', error: true);
    }
  }

  List<String> _audioLines() {
    if (_audioScript == null) return const [];
    return _audioScript!.split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty).toList();
  }

  Future<void> _toggleNarration() async {
    if (_audioScript == null) return;
    if (_speaking) {
      await _tts.stop();
      _audioTimer?.cancel();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    final lines = _audioLines();
    if (lines.isEmpty) return;
    _audioTimer?.cancel();
    setState(() {
      _speaking = true;
      _audioPaused = false;
      _audioProgress = 0;
    });
    final voices = await _tts.getVoices;
    final englishVoices = (voices is List ? voices : const [])
        .whereType<Map>()
        .where((v) => (v['locale']?.toString() ?? '').toLowerCase().startsWith('en'))
        .toList();
    final host1 = englishVoices.isNotEmpty ? englishVoices.first : null;
    final host2 = englishVoices.length > 1 ? englishVoices[1] : host1;
    var completedLines = 0;
    _audioTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted || !_speaking) return;
      setState(() => _audioProgress = (completedLines / lines.length).clamp(0.0, 1.0));
    });
    for (final line in lines) {
      if (!_speaking) break;
      final isHostB = RegExp(r'^Host B:', caseSensitive: false).hasMatch(line);
      final spoken = line.replaceFirst(RegExp(r'^Host [AB]:\s*', caseSensitive: false), '');
      if (isHostB && host2 != null) {
        await _tts.setVoice(Map<String, String>.from(host2));
      } else if (host1 != null) {
        await _tts.setVoice(Map<String, String>.from(host1));
      }
      await _tts.speak(spoken);
      completedLines++;
      if (mounted && _speaking) setState(() => _audioProgress = (completedLines / lines.length).clamp(0.0, 1.0));
    }
    _audioTimer?.cancel();
    if (mounted) setState(() { _speaking = false; _audioProgress = 1.0; });
  }

  String _formatAudioTime(double progress) {
    const totalSeconds = 9 * 60 + 43;
    final seconds = (totalSeconds * progress).round().clamp(0, totalSeconds);
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  Widget _buildAudioPlayer(bool isDark, Color textColor) {
    final lines = _audioLines();
    final activeIndex = lines.isEmpty ? 0 : (_audioProgress * lines.length).floor().clamp(0, lines.length - 1);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: isDark ? const Color(0xFF111318) : const Color(0xFFF4F7FA),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(colors: [Color(0xFF32C5FF), Color(0xFF7C5CFF)]),
            ),
            child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Audio Overview', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex')),
            SizedBox(height: 3),
            Text('Two-host study discussion', style: TextStyle(fontSize: 13, color: Colors.grey, fontFamily: 'Google Sans Flex')),
          ])),
          IconButton(
            onPressed: _toggleNarration,
            icon: Icon(_speaking ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded, size: 44, color: _accentBlue),
          ),
        ]),
        const SizedBox(height: 18),
        Slider(
          value: _audioProgress,
          onChanged: (value) async {
            setState(() => _audioProgress = value);
            if (_speaking) {
              await _tts.stop();
              setState(() => _speaking = false);
            }
          },
          activeColor: _accentBlue,
        ),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(_formatAudioTime(_audioProgress), style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const Text('9:43', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
        const SizedBox(height: 14),
        Text('Live transcript', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex')),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 250),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: lines.length,
            itemBuilder: (context, index) {
              final line = lines[index].replaceFirst(RegExp(r'^Host [AB]:\s*', caseSensitive: false), '');
              final isActive = index == activeIndex;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Text(line, style: TextStyle(
                  color: isActive ? textColor : (isDark ? Colors.white38 : Colors.black38),
                  fontSize: isActive ? 16 : 14,
                  height: 1.35,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                  fontFamily: 'Google Sans Flex',
                )),
              );
            },
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.notebook.title, style: const TextStyle(fontFamily: 'Google Sans Flex', fontWeight: FontWeight.bold)),
        bottom: TabBar(controller: _tabController, tabs: const [Tab(text: 'Sources'), Tab(text: 'Chat'), Tab(text: 'Studio')]),
      ),
      body: _loadingSources
          ? const Center(child: CircularProgressIndicator(color: _accentBlue))
          : TabBarView(controller: _tabController, children: [
              _buildSourcesTab(isDark, textColor),
              _buildChatTab(isDark, textColor),
              _buildStudioTab(isDark, textColor),
            ]),
    );
  }

  Widget _buildSourcesTab(bool isDark, Color textColor) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ElevatedButton.icon(
            onPressed: _addFileSource,
            icon: const Icon(Icons.add),
            label: const Text('Add source', style: TextStyle(fontFamily: 'Google Sans Flex')),
          ),
          const SizedBox(height: 16),
          if (_sources.isEmpty)
            const Text('No sources yet.', style: TextStyle(fontFamily: 'Google Sans Flex')),
          ..._sources.map((s) => Card(
                child: ListTile(
                  leading: const Icon(Icons.description_outlined, color: _accentBlue),
                  title: Text(s.title, style: const TextStyle(fontFamily: 'Google Sans Flex', fontWeight: FontWeight.w600)),
                  trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _deleteSource(s)),
                ),
              )),
        ],
      );

  Widget _buildChatTab(bool isDark, Color textColor) => Column(children: [
        Expanded(
          child: ListView.builder(
            controller: _chatScroll,
            padding: const EdgeInsets.all(20),
            itemCount: _messages.length + (_sendingMessage ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _messages.length) return const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: _accentBlue));
              final message = _messages[index];
              return Align(
                alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 620),
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: message.isUser ? _accentBlue : (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF1F3F5)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(message.text, style: TextStyle(color: message.isUser ? Colors.white : textColor, fontFamily: 'Google Sans Flex', height: 1.4)),
                ),
              );
            },
          ),
        ),
        if (_suggestedQuestions.isNotEmpty)
          SizedBox(height: 48, child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _suggestedQuestions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => ActionChip(label: Text(_suggestedQuestions[i]), onPressed: () => _sendMessage(_suggestedQuestions[i])),
          )),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: TextField(
            controller: _chatController,
            onSubmitted: (_) => _sendMessage(),
            decoration: InputDecoration(
              hintText: 'Ask about your sources...',
              suffixIcon: IconButton(onPressed: _sendingMessage ? null : () => _sendMessage(), icon: const Icon(Icons.send_rounded, color: _accentBlue)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
            ),
          ),
        ),
      ]);

  Widget _buildStudioCard({required bool isDark, required Color textColor, required IconData icon, required String title, required Widget child}) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(icon, color: _accentBlue), const SizedBox(width: 10), Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex'))]),
            const SizedBox(height: 14),
            child,
          ]),
        ),
      );

  Widget _buildStudioTab(bool isDark, Color textColor) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildStudioCard(
            isDark: isDark,
            textColor: textColor,
            icon: Icons.summarize_rounded,
            title: 'Notebook summary',
            child: _generatingSummary
                ? const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Center(child: CircularProgressIndicator(color: _accentBlue)))
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_summary?.isNotEmpty == true ? _summary! : 'Generate a summary of everything in this notebook.', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontFamily: 'Google Sans Flex', height: 1.4)),
                    const SizedBox(height: 12),
                    OutlinedButton(onPressed: _generateSummary, child: Text(_summary == null ? 'Generate summary' : 'Regenerate')),
                  ]),
          ),
          const SizedBox(height: 16),
          _buildStudioCard(
            isDark: isDark,
            textColor: textColor,
            icon: Icons.podcasts_rounded,
            title: 'Audio Overview',
            child: _generatingScript
                ? const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Center(child: CircularProgressIndicator(color: _accentBlue)))
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (_audioScript == null)
                      Text('Generate a two-host discussion of your sources, then listen in the full player.', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontFamily: 'Google Sans Flex', height: 1.4))
                    else
                      _buildAudioPlayer(isDark, textColor),
                    const SizedBox(height: 12),
                    OutlinedButton(onPressed: _generateAudioOverview, child: Text(_audioScript == null ? 'Generate audio' : 'Regenerate audio')),
                  ]),
          ),
          const SizedBox(height: 16),
          _buildStudioCard(
            isDark: isDark,
            textColor: textColor,
            icon: Icons.sticky_note_2_outlined,
            title: 'Notes',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (_notes.isEmpty) Text('No notes yet.', style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontFamily: 'Google Sans Flex')),
              ..._notes.map((note) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(note.title, style: const TextStyle(fontFamily: 'Google Sans Flex', fontWeight: FontWeight.w600)))),
            ]),
          ),
        ],
      );
}

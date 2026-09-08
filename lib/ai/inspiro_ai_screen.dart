import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../gemini/gemini_service.dart';
import '../notebooks/notebook_models.dart';

/// General Inspiro AI chat. Notebook chat remains strictly source-grounded;
/// this screen is the separate general-purpose student assistant.
class InspiroAiScreen extends StatefulWidget {
  const InspiroAiScreen({super.key});

  @override
  State<InspiroAiScreen> createState() => _InspiroAiScreenState();
}

class _InspiroAiScreenState extends State<InspiroAiScreen> {
  final _gemini = GeminiService.instance;
  final _uuid = const Uuid();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty || _sending) return;

    _controller.clear();
    final user = ChatMessage(
      id: _uuid.v4(),
      isUser: true,
      text: text,
      createdAt: DateTime.now(),
    );
    setState(() {
      _messages.add(user);
      _sending = true;
    });
    _scrollToBottom();

    try {
      final answer = await _gemini.askGeneral(
        prompt: text,
        history: _messages.sublist(0, _messages.length - 1),
      );
      setState(() {
        _messages.add(ChatMessage(
          id: _uuid.v4(),
          isUser: false,
          text: answer,
          createdAt: DateTime.now(),
        ));
        _sending = false;
      });
    } on GeminiException catch (e) {
      _showError(e.message);
      setState(() => _sending = false);
    } catch (_) {
      _showError('Something went wrong reaching Inspiro AI.');
      setState(() => _sending = false);
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Inspiro AI',
          style: TextStyle(fontFamily: 'Google Sans Flex', fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildWelcome(textColor)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    itemCount: _messages.length + (_sending ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_sending && index == _messages.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      final message = _messages[index];
                      return Align(
                        alignment: message.isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 560),
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: message.isUser
                                ? const Color(0xFF32C5FF)
                                : (isDark ? const Color(0xFF242424) : Colors.white),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            message.text,
                            style: TextStyle(
                              color: message.isUser ? Colors.white : textColor,
                              fontFamily: 'Google Sans Flex',
                              height: 1.35,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Ask Inspiro AI anything...',
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcome(Color textColor) {
    const suggestions = [
      'Explain photosynthesis simply',
      'Help me make a study plan',
      'Quiz me on a topic',
      'Give me ideas for a project',
    ];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome_rounded, size: 52, color: Color(0xFF32C5FF)),
              const SizedBox(height: 16),
              Text(
                'What are we learning today?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Google Sans Flex',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ask for explanations, study help, brainstorming or a quick quiz.',
                textAlign: TextAlign.center,
                style: TextStyle(color: textColor.withOpacity(.65), fontFamily: 'Google Sans Flex'),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: suggestions
                    .map((text) => ActionChip(
                          label: Text(text),
                          onPressed: () => _send(text),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

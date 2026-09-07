import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'notebook_detail_screen.dart';
import 'notebook_models.dart';
import 'notebook_repository.dart';

const _accentBlue = Color(0xFF32C5FF);
const _accentPurple = Color(0xFFD3B4FF);

class NotebooksListScreen extends StatefulWidget {
  const NotebooksListScreen({super.key});

  @override
  State<NotebooksListScreen> createState() => _NotebooksListScreenState();
}

class _NotebooksListScreenState extends State<NotebooksListScreen> {
  final _repo = NotebookRepository();
  List<Notebook> _notebooks = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final notebooks = await _repo.fetchNotebooks();
      setState(() {
        _notebooks = notebooks;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load notebooks. Pull down to retry.';
        _loading = false;
      });
    }
  }

  Future<void> _createNotebook() async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('New notebook',
            style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex')),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(fontFamily: 'Google Sans Flex'),
          decoration: const InputDecoration(hintText: 'e.g. Chapter 4 — Photosynthesis'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _accentBlue),
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (title == null || title.trim().isEmpty) return;
    HapticFeedback.mediumImpact();
    try {
      final notebook = await _repo.createNotebook(title.trim());
      setState(() => _notebooks.insert(0, notebook));
      if (mounted) _openNotebook(notebook);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create notebook.')),
        );
      }
    }
  }

  void _openNotebook(Notebook notebook) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NotebookDetailScreen(notebook: notebook)),
    ).then((_) => _load());
  }

  Future<void> _deleteNotebook(Notebook notebook) async {
    HapticFeedback.heavyImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete notebook?',
            style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex')),
        content: Text('This removes "${notebook.title}" and all its sources and chat history.',
            style: const TextStyle(fontFamily: 'Google Sans Flex')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repo.deleteNotebook(notebook.id);
    setState(() => _notebooks.removeWhere((n) => n.id == notebook.id));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);

    return RefreshIndicator(
      color: _accentBlue,
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: _accentBlue))
          : _error != null
              ? ListView(children: [
                  const SizedBox(height: 120),
                  Center(
                      child: Text(_error!,
                          style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)))
                ])
              : _notebooks.isEmpty
                  ? _buildEmptyState(isDark, textColor)
                  : _buildList(isDark, textColor),
    );
  }

  Widget _buildEmptyState(bool isDark, Color textColor) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 100, 24, 40),
      children: [
        Icon(Icons.auto_awesome_rounded, size: 56, color: _accentBlue.withOpacity(0.7)),
        const SizedBox(height: 20),
        Text('No notebooks yet',
            style: TextStyle(
                color: textColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'Google Sans Flex')),
        const SizedBox(height: 8),
        Text(
          'Create a notebook, add your class notes, textbook chapters or PDFs, '
          'and ask Gemini questions grounded in exactly that material.',
          style: TextStyle(
              color: isDark ? Colors.white60 : Colors.black54,
              fontSize: 14,
              fontFamily: 'Google Sans Flex'),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _createNotebook,
          style: ElevatedButton.styleFrom(
            backgroundColor: _accentBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Create your first notebook',
              style: TextStyle(fontFamily: 'Google Sans Flex', fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildList(bool isDark, Color textColor) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      itemCount: _notebooks.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Notebooks',
                    style: TextStyle(
                        color: textColor,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Google Sans Flex')),
                IconButton(
                  onPressed: _createNotebook,
                  icon: const Icon(Icons.add_circle_rounded, color: _accentBlue, size: 32),
                ),
              ],
            ),
          );
        }
        final notebook = _notebooks[index - 1];
        return Dismissible(
          key: ValueKey(notebook.id),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) async {
            await _deleteNotebook(notebook);
            return false; // we manage removal via setState ourselves
          },
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            child: const Icon(Icons.delete_rounded, color: Colors.redAccent),
          ),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => _openNotebook(notebook),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _accentPurple.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.menu_book_rounded, color: Color(0xFF6B4FA0)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(notebook.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    fontFamily: 'Google Sans Flex')),
                            const SizedBox(height: 4),
                            Text(
                              notebook.summary?.isNotEmpty == true
                                  ? notebook.summary!
                                  : 'No sources yet — tap to add some',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: isDark ? Colors.white60 : Colors.black54,
                                  fontSize: 13,
                                  fontFamily: 'Google Sans Flex'),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded,
                          color: _accentBlue, size: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

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
  bool _creating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final notebooks = await _repo.fetchNotebooks();
      if (!mounted) return;
      setState(() {
        _notebooks = notebooks;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is StateError
            ? e.message
            : 'Could not load notebooks. Pull down to retry.';
      });
    }
  }

  Future<void> _createNotebook() async {
    if (_creating) return;
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(dialogContext).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'New notebook',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Google Sans Flex',
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(fontFamily: 'Google Sans Flex'),
          decoration: const InputDecoration(
            labelText: 'Notebook name',
            hintText: 'e.g. Photosynthesis',
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _accentBlue),
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();

    final cleanTitle = title?.trim() ?? '';
    if (cleanTitle.isEmpty || !mounted) return;

    HapticFeedback.mediumImpact();
    setState(() => _creating = true);
    try {
      final notebook = await _repo.createNotebook(cleanTitle);
      if (!mounted) return;
      setState(() {
        _notebooks.insert(0, notebook);
        _creating = false;
      });
      _openNotebook(notebook);
    } catch (e) {
      if (!mounted) return;
      setState(() => _creating = false);
      final message = e is StateError
          ? e.message
          : 'Failed to create notebook. Check that you are signed in and try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontFamily: 'Google Sans Flex'),
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openNotebook(Notebook notebook) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotebookDetailScreen(notebook: notebook),
      ),
    ).then((_) => _load());
  }

  Future<void> _deleteNotebook(Notebook notebook) async {
    HapticFeedback.heavyImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(dialogContext).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Delete notebook?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Google Sans Flex',
          ),
        ),
        content: Text(
          'This removes "${notebook.title}" and its sources, chats and notes.',
          style: const TextStyle(fontFamily: 'Google Sans Flex'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _repo.deleteNotebook(notebook.id);
      if (!mounted) return;
      setState(() => _notebooks.removeWhere((n) => n.id == notebook.id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete notebook.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 110, 24, 40),
                  children: [
                    Icon(Icons.cloud_off_rounded, size: 56, color: _accentBlue),
                    const SizedBox(height: 18),
                    Text(
                      'Notebook service unavailable',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Google Sans Flex',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontFamily: 'Google Sans Flex',
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                )
              : _notebooks.isEmpty
                  ? _buildEmptyState(isDark, textColor)
                  : _buildList(isDark, textColor),
    );
  }

  Widget _buildEmptyState(bool isDark, Color textColor) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 100, 24, 40),
      children: [
        const Icon(Icons.auto_awesome_rounded, size: 56, color: _accentBlue),
        const SizedBox(height: 20),
        Text(
          'No notebooks yet',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: textColor,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: 'Google Sans Flex',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Create a notebook, add class notes, textbook chapters or PDFs, and ask Gemini questions grounded in that material.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isDark ? Colors.white60 : Colors.black54,
            fontSize: 14,
            fontFamily: 'Google Sans Flex',
            height: 1.45,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _creating ? null : _createNotebook,
          style: FilledButton.styleFrom(
            backgroundColor: _accentBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          icon: _creating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_rounded),
          label: Text(_creating ? 'Creating...' : 'Create your first notebook'),
        ),
      ],
    );
  }

  Widget _buildList(bool isDark, Color textColor) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      itemCount: _notebooks.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Notebooks',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Google Sans Flex',
                  ),
                ),
                IconButton(
                  onPressed: _creating ? null : _createNotebook,
                  icon: const Icon(
                    Icons.add_circle_rounded,
                    color: _accentBlue,
                    size: 32,
                  ),
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
            return false;
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
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                      ),
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
                        child: const Icon(
                          Icons.menu_book_rounded,
                          color: Color(0xFF6B4FA0),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notebook.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                fontFamily: 'Google Sans Flex',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              notebook.summary?.isNotEmpty == true
                                  ? notebook.summary!
                                  : 'No sources yet. Tap to add some.',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDark ? Colors.white60 : Colors.black54,
                                fontSize: 13,
                                fontFamily: 'Google Sans Flex',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: _accentBlue,
                        size: 16,
                      ),
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

import 'package:flutter/material.dart';

class MessageActionsSheet extends StatelessWidget {
  final bool canEdit;
  final VoidCallback onReply;
  final VoidCallback onReact;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const MessageActionsSheet({
    super.key,
    required this.canEdit,
    required this.onReply,
    required this.onReact,
    this.onEdit,
    this.onDelete,
  });

  static Future<void> show({
    required BuildContext context,
    required bool canEdit,
    required VoidCallback onReply,
    required VoidCallback onReact,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => MessageActionsSheet(
        canEdit: canEdit,
        onReply: onReply,
        onReact: onReact,
        onEdit: onEdit,
        onDelete: onDelete,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 18),
            _action(
              context,
              icon: Icons.reply_rounded,
              label: 'Reply',
              color: textColor,
              onTap: onReply,
            ),
            _action(
              context,
              icon: Icons.emoji_emotions_outlined,
              label: 'React',
              color: textColor,
              onTap: onReact,
            ),
            if (canEdit && onEdit != null)
              _action(
                context,
                icon: Icons.edit_rounded,
                label: 'Edit',
                color: textColor,
                onTap: onEdit!,
              ),
            if (canEdit && onDelete != null)
              _action(
                context,
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
                color: Colors.redAccent,
                onTap: onDelete!,
              ),
          ],
        ),
      ),
    );
  }

  Widget _action(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontFamily: 'Google Sans Flex',
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }
}

class MessageReactionPicker extends StatelessWidget {
  final ValueChanged<String> onSelected;

  const MessageReactionPicker({super.key, required this.onSelected});

  static Future<void> show({
    required BuildContext context,
    required ValueChanged<String> onSelected,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => MessageReactionPicker(onSelected: onSelected),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const reactions = ['👍', '❤️', '😂', '😮', '😢', '👏', '🔥', '🎉'];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: reactions
              .map(
                (reaction) => InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    Navigator.pop(context);
                    onSelected(reaction);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(reaction, style: const TextStyle(fontSize: 26)),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

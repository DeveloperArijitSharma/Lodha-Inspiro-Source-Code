import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'messaging/message_actions_sheet.dart';
import 'messaging/message_models.dart';
import 'messaging/message_repository.dart';
import 'notification_service.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String chatName;
  final String chatType;

  const ChatScreen({super.key, required this.chatId, required this.chatName, required this.chatType});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final supabase = Supabase.instance.client;
  final MessageRepository _repository = MessageRepository();
  final TextEditingController _messageController = TextEditingController();
  final Color _accentBlue = const Color(0xFF32C5FF);

  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic>? _replyingTo;
  bool _isLoading = true;
  bool _isUploading = false;
  RealtimeChannel? _messageChannel;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _subscribeToMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    if (_messageChannel != null) supabase.removeChannel(_messageChannel!);
    super.dispose();
  }

  Future<void> _fetchMessages() async {
    try {
      final response = await supabase.from('messages').select().eq('chat_id', widget.chatId).order('created_at', ascending: true);
      if (!mounted) return;
      setState(() {
        _messages = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _subscribeToMessages() {
    _messageChannel = supabase.channel('public:messages:${widget.chatId}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'chat_id', value: widget.chatId),
        callback: (payload) async {
          final record = Map<String, dynamic>.from(payload.newRecord.isNotEmpty ? payload.newRecord : payload.oldRecord);
          if (record['id'] == null || !mounted) return;

          if (payload.eventType == PostgresChangeEvent.delete) {
            setState(() => _messages.removeWhere((m) => m['id']?.toString() == record['id']?.toString()));
            return;
          }

          final index = _messages.indexWhere((m) => m['id']?.toString() == record['id']?.toString());
          setState(() {
            if (index >= 0) {
              _messages[index] = record;
            } else {
              _messages.add(record);
              _messages.sort((a, b) => (a['created_at']?.toString() ?? '').compareTo(b['created_at']?.toString() ?? ''));
            }
          });

          final currentUserId = supabase.auth.currentUser?.id;
          if (payload.eventType == PostgresChangeEvent.insert && record['sender_id']?.toString() != currentUserId) {
            final text = record['text']?.toString().trim();
            await NotificationService.showChatNotification(title: widget.chatName, body: text?.isNotEmpty == true ? text! : 'Sent an attachment');
          }
        },
      )
      .subscribe();
  }

  Future<void> _sendMessage({String? attachmentUrl}) async {
    final text = _messageController.text.trim();
    if (text.isEmpty && attachmentUrl == null) return;
    final replyId = _replyingTo?['id']?.toString();
    _messageController.clear();
    setState(() => _replyingTo = null);

    try {
      await _repository.sendMessage(chatId: widget.chatId, text: text.isEmpty ? null : text, attachmentUrl: attachmentUrl, replyToMessageId: replyId);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send message'), backgroundColor: Colors.redAccent));
    }
  }

  Future<void> _pickAndUploadAttachment() async {
    HapticFeedback.selectionClick();
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image == null) return;
      setState(() => _isUploading = true);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      final bytes = await image.readAsBytes();
      await supabase.storage.from('chat_attachments').uploadBinary(fileName, bytes, fileOptions: const FileOptions(upsert: true));
      final imageUrl = supabase.storage.from('chat_attachments').getPublicUrl(fileName);
      if (mounted) setState(() => _isUploading = false);
      await _sendMessage(attachmentUrl: imageUrl);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to upload image attachment.'), backgroundColor: Colors.redAccent));
    }
  }

  Future<void> _openActions(Map<String, dynamic> msg) async {
    final currentUserId = supabase.auth.currentUser?.id;
    final isMe = msg['sender_id']?.toString() == currentUserId;
    await MessageActionsSheet.show(
      context: context,
      canEdit: isMe,
      onReply: () => setState(() => _replyingTo = msg),
      onReact: () => MessageReactionPicker.show(context: context, onSelected: (emoji) => _react(msg['id'].toString(), emoji)),
      onEdit: isMe ? () => _editMessage(msg) : null,
      onDelete: isMe ? () => _deleteMessage(msg['id'].toString()) : null,
    );
  }

  Future<void> _react(String id, String emoji) async {
    try {
      await _repository.setReaction(messageId: id, emoji: emoji);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update reaction')));
    }
  }

  Future<void> _editMessage(Map<String, dynamic> msg) async {
    final controller = TextEditingController(text: msg['text']?.toString() ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(controller: controller, autofocus: true, maxLines: 5, decoration: const InputDecoration(hintText: 'Message')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty) return;
    try {
      await _repository.editMessage(messageId: msg['id'].toString(), text: value);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not edit message')));
    }
  }

  Future<void> _deleteMessage(String id) async {
    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('The message will be hidden from the conversation.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), style: FilledButton.styleFrom(backgroundColor: Colors.redAccent), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repository.deleteMessage(id);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not delete message')));
    }
  }

  Map<String, dynamic>? _messageById(String? id) {
    if (id == null) return null;
    for (final message in _messages) {
      if (message['id']?.toString() == id) return message;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFEBF0F5);
    final currentUserId = supabase.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black.withOpacity(0.5) : Colors.white.withOpacity(0.5),
        elevation: 0,
        flexibleSpace: ClipRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15), child: Container(color: Colors.transparent))),
        iconTheme: IconThemeData(color: textColor),
        title: Row(children: [
          CircleAvatar(backgroundColor: _accentBlue.withOpacity(0.2), radius: 18, child: Icon(widget.chatType == 'group' ? Icons.group : Icons.person, color: _accentBlue, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Text(widget.chatName, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Google Sans Flex'), overflow: TextOverflow.ellipsis)),
        ]),
      ),
      body: Column(children: [
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF32C5FF)))
              : _messages.isEmpty
                  ? Center(child: Text('No messages yet. Start the conversation!', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontFamily: 'Google Sans Flex')))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final isMe = msg['sender_id']?.toString() == currentUserId;
                        return GestureDetector(onLongPress: () => _openActions(msg), child: _buildMessageBubble(msg, isMe, isDark));
                      },
                    ),
        ),
        if (_replyingTo != null) _buildReplyBanner(isDark),
        if (_isUploading)
          Container(padding: const EdgeInsets.all(8), color: _accentBlue.withOpacity(0.2), child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF32C5FF))), SizedBox(width: 12), Text('Uploading image attachment...')])),
        ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: EdgeInsets.only(left: 8, right: 16, top: 12, bottom: MediaQuery.of(context).padding.bottom + 12),
              decoration: BoxDecoration(color: isDark ? Colors.black.withOpacity(0.6) : Colors.white.withOpacity(0.7), border: Border(top: BorderSide(color: isDark ? Colors.white12 : Colors.black12))),
              child: Row(children: [
                IconButton(icon: const Icon(Icons.add_circle_outline_rounded), color: isDark ? Colors.white70 : Colors.black54, iconSize: 28, onPressed: _isUploading ? null : _pickAndUploadAttachment),
                Expanded(child: Container(decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(24)), child: TextField(controller: _messageController, style: TextStyle(color: textColor, fontFamily: 'Google Sans Flex'), decoration: InputDecoration(hintText: 'Type a message...', hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontFamily: 'Google Sans Flex'), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)), onSubmitted: (_) => _sendMessage())),
                const SizedBox(width: 12),
                GestureDetector(onTap: () => _sendMessage(), child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _accentBlue, shape: BoxShape.circle), child: const Icon(Icons.send_rounded, color: Colors.white, size: 20))),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildReplyBanner(bool isDark) {
    final reply = _replyingTo!;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05), border: Border(top: BorderSide(color: isDark ? Colors.white12 : Colors.black12))),
      child: Row(children: [
        Container(width: 3, height: 38, decoration: BoxDecoration(color: _accentBlue, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Replying to message', style: TextStyle(color: _accentBlue, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex')), Text(reply['text']?.toString().isNotEmpty == true ? reply['text'].toString() : 'Attachment', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontFamily: 'Google Sans Flex'))])),
        IconButton(onPressed: () => setState(() => _replyingTo = null), icon: Icon(Icons.close_rounded, color: isDark ? Colors.white54 : Colors.black45)),
      ]),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe, bool isDark) {
    final deleted = msg['deleted_at'] != null;
    final reply = _messageById(msg['reply_to_message_id']?.toString());
    final rawReactions = msg['reactions'];
    final reactions = rawReactions is Map ? Map<String, dynamic>.from(rawReactions) : <String, dynamic>{};

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: isMe ? _accentBlue : (isDark ? const Color(0xFF2C2C2E) : Colors.white), borderRadius: BorderRadius.only(topLeft: const Radius.circular(20), topRight: const Radius.circular(20), bottomLeft: Radius.circular(isMe ? 20 : 5), bottomRight: Radius.circular(isMe ? 5 : 20)), boxShadow: [if (!isDark && !isMe) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (reply != null && !deleted) Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: isMe ? Colors.white.withOpacity(0.15) : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)), borderRadius: BorderRadius.circular(10)), child: Text(reply['text']?.toString().isNotEmpty == true ? reply['text'].toString() : 'Attachment', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: isMe ? Colors.white70 : (isDark ? Colors.white60 : Colors.black54), fontSize: 12, fontFamily: 'Google Sans Flex'))),
          if (deleted)
            Text('Message deleted', style: TextStyle(color: isMe ? Colors.white70 : (isDark ? Colors.white38 : Colors.black45), fontStyle: FontStyle.italic, fontFamily: 'Google Sans Flex'))
          else ...[
            if (msg['attachment_url']?.toString().isNotEmpty == true) ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(msg['attachment_url'].toString(), height: 180, width: double.infinity, fit: BoxFit.cover)),
            if (msg['attachment_url']?.toString().isNotEmpty == true && msg['text']?.toString().isNotEmpty == true) const SizedBox(height: 8),
            if (msg['text']?.toString().isNotEmpty == true) Text(msg['text'].toString(), style: TextStyle(color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87), fontSize: 15, fontFamily: 'Google Sans Flex')),
            if (msg['edited_at'] != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('edited', style: TextStyle(color: isMe ? Colors.white60 : (isDark ? Colors.white38 : Colors.black45), fontSize: 10, fontFamily: 'Google Sans Flex'))),
          ],
          if (reactions.isNotEmpty && !deleted) Padding(padding: const EdgeInsets.only(top: 8), child: Wrap(spacing: 4, children: reactions.entries.map((entry) { final users = entry.value is List ? entry.value as List : const []; return Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: isMe ? Colors.white.withOpacity(0.18) : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)), borderRadius: BorderRadius.circular(12)), child: Text('${entry.key} ${users.length}', style: TextStyle(fontSize: 12, color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87)))); }).toList())),
        ]),
      ),
    );
  }
}

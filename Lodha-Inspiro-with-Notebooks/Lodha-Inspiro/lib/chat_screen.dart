import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'call_screen.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String chatName;
  final String chatType;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.chatName,
    required this.chatType,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final supabase = Supabase.instance.client;
  final TextEditingController _messageController = TextEditingController();
  final Color _accentBlue = const Color(0xFF32C5FF);

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _subscribeToMessages();
  }

  Future<void> _fetchMessages() async {
    try {
      final response = await supabase
          .from('messages')
          .select()
          .eq('chat_id', widget.chatId)
          .order('created_at', ascending: true);

      setState(() {
        _messages = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _subscribeToMessages() {
    supabase
        .channel('public:messages:${widget.chatId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: widget.chatId,
          ),
          callback: (payload) {
            _fetchMessages();
          },
        )
        .subscribe();
  }

  Future<void> _sendMessage({String? attachmentUrl}) async {
    final text = _messageController.text.trim();
    if (text.isEmpty && attachmentUrl == null) return;

    _messageController.clear();

    try {
      await supabase.from('messages').insert({
        'chat_id': widget.chatId,
        'sender_id': supabase.auth.currentUser?.id,
        'text': text.isEmpty ? null : text,
        'attachment_url': attachmentUrl,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Failed to send message'),
            backgroundColor: Colors.redAccent),
      );
    }
  }

  // 🚀 REAL ATTACHMENT FUNCTION (`+` button opens gallery & uploads to Supabase Storage)
  Future<void> _pickAndUploadAttachment() async {
    HapticFeedback.selectionClick();
    final ImagePicker picker = ImagePicker();

    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() => _isUploading = true);

      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      final bytes = await image.readAsBytes();

      // Upload to Supabase Storage bucket 'chat_attachments'
      await supabase.storage.from('chat_attachments').uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      // Get public URL
      final imageUrl =
          supabase.storage.from('chat_attachments').getPublicUrl(fileName);

      setState(() => _isUploading = false);

      // Send message with the image attachment URL
      await _sendMessage(attachmentUrl: imageUrl);
    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Failed to upload image. Ensure bucket "chat_attachments" exists.'),
            backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _deleteMessage(String id) async {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete Message?',
            style: TextStyle(
                fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex')),
        content: const Text('This message will be permanently deleted.',
            style: TextStyle(fontFamily: 'Google Sans Flex')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await supabase.from('messages').delete().eq('id', id);
              _fetchMessages();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _startCall(String callType) {
    HapticFeedback.selectionClick();
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => CallScreen(
                callID: widget.chatName, isVideoCall: callType == 'video')));
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
        backgroundColor: isDark
            ? Colors.black.withOpacity(0.5)
            : Colors.white.withOpacity(0.5),
        elevation: 0,
        flexibleSpace: ClipRect(
            child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(color: Colors.transparent))),
        iconTheme: IconThemeData(color: textColor),
        title: Row(
          children: [
            CircleAvatar(
                backgroundColor: _accentBlue.withOpacity(0.2),
                radius: 18,
                child: Icon(
                    widget.chatType == 'group' ? Icons.group : Icons.person,
                    color: _accentBlue,
                    size: 20)),
            const SizedBox(width: 12),
            Expanded(
                child: Text(widget.chatName,
                    style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        fontFamily: 'Google Sans Flex'),
                    overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: [
          if (widget.chatType == 'classmate') ...[
            IconButton(
                icon: const Icon(Icons.call_rounded),
                color: _accentBlue,
                onPressed: () => _startCall('voice')),
            IconButton(
                icon: const Icon(Icons.videocam_rounded),
                color: _accentBlue,
                onPressed: () => _startCall('video')),
            const SizedBox(width: 8),
          ]
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF32C5FF)))
                : _messages.isEmpty
                    ? Center(
                        child: Text('No messages yet. Start the conversation!',
                            style: TextStyle(
                                color: isDark ? Colors.white54 : Colors.black54,
                                fontFamily: 'Google Sans Flex')))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe = msg['sender_id'] == currentUserId;
                          return GestureDetector(
                            onLongPress: () {
                              if (isMe) _deleteMessage(msg['id']);
                            },
                            child: _buildMessageBubble(msg['text'],
                                msg['attachment_url'], isMe, isDark),
                          );
                        },
                      ),
          ),
          if (_isUploading)
            Container(
              padding: const EdgeInsets.all(8),
              color: _accentBlue.withOpacity(0.2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF32C5FF))),
                  const SizedBox(width: 12),
                  Text('Uploading image attachment...',
                      style: TextStyle(
                          color: textColor,
                          fontFamily: 'Google Sans Flex',
                          fontSize: 13)),
                ],
              ),
            ),
          ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: EdgeInsets.only(
                    left: 8,
                    right: 16,
                    top: 12,
                    bottom: MediaQuery.of(context).padding.bottom + 12),
                decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withOpacity(0.6)
                        : Colors.white.withOpacity(0.7),
                    border: Border(
                        top: BorderSide(
                            color: isDark ? Colors.white12 : Colors.black12))),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      color: isDark ? Colors.white70 : Colors.black54,
                      iconSize: 28,
                      onPressed: _isUploading
                          ? null
                          : _pickAndUploadAttachment, // 🚀 Real image picker trigger
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.1)
                                : Colors.black.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(24)),
                        child: TextField(
                          controller: _messageController,
                          style: TextStyle(
                              color: textColor, fontFamily: 'Google Sans Flex'),
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: TextStyle(
                                color: isDark ? Colors.white54 : Colors.black54,
                                fontFamily: 'Google Sans Flex'),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => _sendMessage(),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: _accentBlue, shape: BoxShape.circle),
                        child: const Icon(Icons.send_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
      String? text, String? attachmentUrl, bool isMe, bool isDark) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe
              ? _accentBlue
              : (isDark ? const Color(0xFF2C2C2E) : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMe ? 20 : 5),
            bottomRight: Radius.circular(isMe ? 5 : 20),
          ),
          boxShadow: [
            if (!isDark && !isMe)
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (attachmentUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  attachmentUrl,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 180,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(
                          color: Color(0xFF32C5FF)),
                    );
                  },
                ),
              ),
              if (text != null && text.isNotEmpty) const SizedBox(height: 8),
            ],
            if (text != null && text.isNotEmpty)
              Text(
                text,
                style: TextStyle(
                  color: isMe
                      ? Colors.white
                      : (isDark ? Colors.white : Colors.black87),
                  fontSize: 15,
                  fontFamily: 'Google Sans Flex',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

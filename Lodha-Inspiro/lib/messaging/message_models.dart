class InspiroMessage {
  final String id;
  final String chatId;
  final String senderId;
  final String? text;
  final String? attachmentUrl;
  final String? replyToMessageId;
  final Map<String, dynamic> reactions;
  final DateTime createdAt;
  final DateTime? editedAt;
  final DateTime? deletedAt;

  const InspiroMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.text,
    this.attachmentUrl,
    this.replyToMessageId,
    this.reactions = const {},
    required this.createdAt,
    this.editedAt,
    this.deletedAt,
  });

  factory InspiroMessage.fromMap(Map<String, dynamic> map) {
    final rawReactions = map['reactions'];
    return InspiroMessage(
      id: map['id'] as String,
      chatId: map['chat_id'] as String,
      senderId: map['sender_id'] as String,
      text: map['text'] as String?,
      attachmentUrl: map['attachment_url'] as String?,
      replyToMessageId: map['reply_to_message_id'] as String?,
      reactions: rawReactions is Map
          ? Map<String, dynamic>.from(rawReactions)
          : const {},
      createdAt: DateTime.parse(map['created_at'] as String),
      editedAt: map['edited_at'] == null
          ? null
          : DateTime.parse(map['edited_at'] as String),
      deletedAt: map['deleted_at'] == null
          ? null
          : DateTime.parse(map['deleted_at'] as String),
    );
  }

  bool get isDeleted => deletedAt != null;
  bool get isEdited => editedAt != null;
}

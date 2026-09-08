import 'package:supabase_flutter/supabase_flutter.dart';

import 'message_models.dart';

class MessageRepository {
  final SupabaseClient _client;

  MessageRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<InspiroMessage> sendMessage({
    required String chatId,
    String? text,
    String? attachmentUrl,
    String? replyToMessageId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('You must be signed in to send a message.');
    }

    final row = await _client
        .from('messages')
        .insert({
          'chat_id': chatId,
          'sender_id': userId,
          'text': text,
          'attachment_url': attachmentUrl,
          'reply_to_message_id': replyToMessageId,
        })
        .select()
        .single();

    return InspiroMessage.fromMap(Map<String, dynamic>.from(row));
  }

  Future<InspiroMessage> editMessage({
    required String messageId,
    required String text,
  }) async {
    final row = await _client
        .from('messages')
        .update({
          'text': text,
          'edited_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', messageId)
        .select()
        .single();

    return InspiroMessage.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> deleteMessage(String messageId) async {
    await _client
        .from('messages')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', messageId);
  }

  Future<InspiroMessage> setReaction({
    required String messageId,
    required String emoji,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('You must be signed in to react to a message.');
    }

    final row = await _client
        .from('messages')
        .select('reactions')
        .eq('id', messageId)
        .single();

    final raw = row['reactions'];
    final reactions = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    final users = reactions[emoji] is List
        ? List<String>.from(reactions[emoji] as List)
        : <String>[];

    if (users.contains(userId)) {
      users.remove(userId);
    } else {
      users.add(userId);
    }

    if (users.isEmpty) {
      reactions.remove(emoji);
    } else {
      reactions[emoji] = users;
    }

    final updated = await _client
        .from('messages')
        .update({'reactions': reactions})
        .eq('id', messageId)
        .select()
        .single();

    return InspiroMessage.fromMap(Map<String, dynamic>.from(updated));
  }
}

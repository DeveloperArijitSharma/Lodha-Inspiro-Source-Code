import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatAttachmentService {
  final SupabaseClient client;
  ChatAttachmentService([SupabaseClient? client]) : client = client ?? Supabase.instance.client;

  Future<String> uploadImage({required String fileName, required List<int> bytes}) async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) throw StateError('You must be signed in to upload an attachment.');
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    await client.storage.from('chat_attachments').uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: false));
    return path;
  }

  Future<List<int>> download(String path) async {
    return client.storage.from('chat_attachments').download(path);
  }
}

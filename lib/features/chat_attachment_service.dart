import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatAttachmentService {
  final SupabaseClient client;
  ChatAttachmentService([SupabaseClient? client]) : client = client ?? Supabase.instance.client;

  Future<String> uploadImage({
    required String fileName,
    required List<int> bytes,
    String? contentType,
  }) async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('You must be signed in to upload an attachment.');
    }
    if (bytes.isEmpty) throw ArgumentError('Attachment is empty.');

    final safeName = fileName.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final normalizedName = safeName.isEmpty ? 'attachment' : safeName;
    final path = '$uid/${DateTime.now().microsecondsSinceEpoch}_$normalizedName';

    await client.storage.from('chat_attachments').uploadBinary(
      path,
      Uint8List.fromList(bytes),
      fileOptions: FileOptions(upsert: false, contentType: contentType),
    );
    return path;
  }

  Future<List<int>> download(String path) async {
    if (path.trim().isEmpty) throw ArgumentError('Attachment path is empty.');
    return client.storage.from('chat_attachments').download(path);
  }
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:uuid/uuid.dart';

class FileManagerService {
  FileManagerService._();
  static final FileManagerService instance = FileManagerService._();

  static const String bucket = 'file-manager';
  static const Set<String> supportedExtensions = {
    'pdf',
    'txt',
    'md',
    'docx',
    'xlsx',
    'pptx',
    'jpg',
    'jpeg',
    'png',
    'webp',
  };

  static const Set<String> aiSupportedExtensions = {'pdf', 'txt', 'md'};

  final SupabaseClient _supabase = Supabase.instance.client;
  final Uuid _uuid = const Uuid();

  String _extension(String name) => name.contains('.')
      ? name.split('.').last.toLowerCase()
      : '';

  String _mime(String extension) {
    switch (extension) {
      case 'pdf': return 'application/pdf';
      case 'txt': return 'text/plain';
      case 'md': return 'text/markdown';
      case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xlsx': return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'pptx': return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      case 'webp': return 'image/webp';
      default: return 'application/octet-stream';
    }
  }

  String classify(String name, {String? sourceKind}) {
    final lower = name.toLowerCase();
    if (sourceKind == 'notebook' || lower.contains('notebook') || lower.contains('study note')) {
      return 'notebook_notes';
    }
    if (sourceKind == 'ai' || lower.contains('ai') || lower.contains('prompt') || lower.contains('assistant')) {
      return 'ai_work';
    }
    if (lower.contains('school') || lower.contains('homework') || lower.contains('assignment') ||
        lower.contains('classwork') || lower.contains('exam') || lower.contains('worksheet') ||
        lower.contains('project') || lower.contains('circular') || lower.contains('notice')) {
      return 'school_work';
    }
    final extension = _extension(name);
    if ({'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) return 'images';
    if ({'pdf', 'txt', 'md', 'docx', 'xlsx', 'pptx'}.contains(extension)) return 'documents';
    return 'personal';
  }

  Future<String> _extractText(String extension, Uint8List bytes) async {
    if (bytes.isEmpty || !aiSupportedExtensions.contains(extension)) return '';
    if (extension == 'txt' || extension == 'md') return utf8.decode(bytes, allowMalformed: true).trim();
    final document = PdfDocument(inputBytes: bytes);
    try {
      return PdfTextExtractor(document).extractText().trim();
    } finally {
      document.dispose();
    }
  }

  Future<List<Map<String, dynamic>>> listFiles() async {
    final response = await _supabase
        .from('file_manager_files')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.custom,
      allowedExtensions: supportedExtensions.toList(),
    );
    if (result == null) return;

    final user = _supabase.auth.currentUser;
    if (user == null) throw StateError('Please sign in again.');

    for (final picked in result.files) {
      final bytes = picked.bytes;
      if (bytes == null || bytes.isEmpty) continue;
      await uploadBytes(user.id, picked.name, bytes);
    }
  }

  Future<void> uploadBytes(String userId, String name, Uint8List bytes, {
    String? sourceKind,
    String visibility = 'personal',
  }) async {
    final extension = _extension(name);
    if (!supportedExtensions.contains(extension)) {
      throw ArgumentError('This file type is not supported.');
    }
    final id = _uuid.v4();
    final safeName = name.replaceAll(RegExp(r'[^A-Za-z0-9._ -]'), '_');
    final storagePath = visibility == 'school'
        ? 'school/${id}_$safeName'
        : '$userId/${id}_$safeName';
    final contentText = await _extractText(extension, bytes);
    final category = classify(name, sourceKind: sourceKind);

    await _supabase.storage.from(bucket).uploadBinary(
      storagePath,
      bytes,
      fileOptions: FileOptions(contentType: _mime(extension), upsert: false),
    );

    try {
      await _supabase.from('file_manager_files').insert({
        'owner_id': userId,
        'name': name,
        'storage_path': storagePath,
        'extension': extension,
        'mime_type': _mime(extension),
        'size_bytes': bytes.length,
        'category': category,
        'visibility': visibility,
        'ai_supported': aiSupportedExtensions.contains(extension),
        'content_text': contentText.isEmpty ? null : contentText,
        'metadata': {'source_kind': sourceKind},
      });
    } catch (_) {
      await _supabase.storage.from(bucket).remove([storagePath]);
      rethrow;
    }
  }

  Future<void> rename(Map<String, dynamic> file, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    final extension = _extension(trimmed);
    if (extension != file['extension']) {
      throw ArgumentError('Keep the original file extension.');
    }
    final oldPath = file['storage_path'] as String;
    final parts = oldPath.split('/');
    final folder = parts.first;
    final idPart = parts.length > 1 ? parts.last.split('_').first : _uuid.v4();
    final safeName = trimmed.replaceAll(RegExp(r'[^A-Za-z0-9._ -]'), '_');
    final newPath = '$folder/${idPart}_$safeName';
    if (newPath == oldPath) return;

    await _supabase.storage.from(bucket).move(oldPath, newPath);
    try {
      await _supabase.from('file_manager_files').update({
        'name': trimmed,
        'storage_path': newPath,
      }).eq('id', file['id']);
    } catch (_) {
      await _supabase.storage.from(bucket).move(newPath, oldPath);
      rethrow;
    }
  }

  Future<void> delete(Map<String, dynamic> file) async {
    await _supabase.storage.from(bucket).remove([file['storage_path'] as String]);
    await _supabase.from('file_manager_files').delete().eq('id', file['id']);
  }

  Future<Uint8List> download(Map<String, dynamic> file) async {
    return _supabase.storage.from(bucket).download(file['storage_path'] as String);
  }

  Future<void> updateTextFile(Map<String, dynamic> file, String text) async {
    final extension = file['extension'] as String;
    if (!{'txt', 'md'}.contains(extension)) {
      throw ArgumentError('Only TXT and Markdown files are editable inside the app.');
    }
    final bytes = Uint8List.fromList(utf8.encode(text));
    await _supabase.storage.from(bucket).uploadBinary(
      file['storage_path'] as String,
      bytes,
      fileOptions: FileOptions(contentType: _mime(extension), upsert: true),
    );
    await _supabase.from('file_manager_files').update({
      'content_text': text,
      'size_bytes': bytes.length,
    }).eq('id', file['id']);
  }

  Future<void> analyzeAndOrganize() async {
    final files = await listFiles();
    for (final file in files) {
      final metadata = Map<String, dynamic>.from(file['metadata'] ?? {});
      final sourceKind = metadata['source_kind']?.toString();
      final category = classify(file['name'] as String, sourceKind: sourceKind);
      final extension = _extension(file['name'] as String);
      await _supabase.from('file_manager_files').update({
        'category': category,
        'ai_supported': aiSupportedExtensions.contains(extension),
      }).eq('id', file['id']);
    }
  }
}

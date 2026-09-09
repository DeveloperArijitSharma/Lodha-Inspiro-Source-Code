import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class FileManagerService {
  FileManagerService._();
  static final FileManagerService instance = FileManagerService._();

  static const String bucket = 'file-manager';
  static const Set<String> aiSupportedExtensions = {'txt', 'md'};

  final SupabaseClient _supabase = Supabase.instance.client;
  final Uuid _uuid = const Uuid();

  String? get currentUserId => _supabase.auth.currentUser?.id;

  String _extension(String name) {
    final dot = name.lastIndexOf('.');
    return dot > 0 && dot < name.length - 1 ? name.substring(dot + 1).toLowerCase() : '';
  }

  String _mime(String extension) {
    switch (extension) {
      case 'pdf': return 'application/pdf';
      case 'txt': return 'text/plain';
      case 'md': return 'text/markdown';
      case 'doc': return 'application/msword';
      case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls': return 'application/vnd.ms-excel';
      case 'xlsx': return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt': return 'application/vnd.ms-powerpoint';
      case 'pptx': return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'csv': return 'text/csv';
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      case 'gif': return 'image/gif';
      case 'webp': return 'image/webp';
      case 'mp3': return 'audio/mpeg';
      case 'wav': return 'audio/wav';
      case 'mp4': return 'video/mp4';
      case 'mov': return 'video/quicktime';
      default: return 'application/octet-stream';
    }
  }

  String classify(String name, {String? sourceKind}) {
    final lower = name.toLowerCase();
    if (sourceKind == 'notebook' || lower.contains('notebook') || lower.contains('study note')) return 'notebook_notes';
    if (sourceKind == 'ai' || lower.contains('prompt') || lower.contains('assistant') || lower.contains('ai_work')) return 'ai_work';
    if (lower.contains('school') || lower.contains('homework') || lower.contains('assignment') || lower.contains('classwork') || lower.contains('exam') || lower.contains('worksheet') || lower.contains('project') || lower.contains('circular') || lower.contains('notice')) return 'school_work';
    final extension = _extension(name);
    if ({'jpg', 'jpeg', 'png', 'gif', 'webp'}.contains(extension)) return 'images';
    if ({'pdf', 'txt', 'md', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'csv'}.contains(extension)) return 'documents';
    return 'personal';
  }

  Future<List<Map<String, dynamic>>> listFiles({String? folderId}) async {
    final query = _supabase.from('file_manager_files').select();
    final response = folderId == null
        ? await query.isFilter('folder_id', null).order('created_at', ascending: false)
        : await query.eq('folder_id', folderId).order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> listAllFiles() async {
    final response = await _supabase.from('file_manager_files').select().order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> listFolders({String? parentId}) async {
    final query = _supabase.from('file_manager_folders').select();
    final response = parentId == null
        ? await query.isFilter('parent_id', null).order('name')
        : await query.eq('parent_id', parentId).order('name');
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> createFolder(String name, {String? parentId}) async {
    final user = currentUserId;
    final clean = name.trim();
    if (user == null) throw StateError('Please sign in again.');
    if (clean.isEmpty) throw ArgumentError('Folder name cannot be empty.');
    await _supabase.from('file_manager_folders').insert({'owner_id': user, 'name': clean, 'parent_id': parentId});
  }

  Future<void> renameFolder(Map<String, dynamic> folder, String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    await _supabase.from('file_manager_folders').update({'name': clean}).eq('id', folder['id']);
  }

  Future<void> deleteFolder(Map<String, dynamic> folder) async {
    final id = folder['id'].toString();
    final children = await listFolders(parentId: id);
    for (final child in children) {
      await deleteFolder(child);
    }
    final files = await listFiles(folderId: id);
    for (final file in files) {
      await delete(file);
    }
    await _supabase.from('file_manager_folders').delete().eq('id', id);
  }

  Future<void> importFromDevice({String? folderId}) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.any,
    );
    if (result == null) return;
    final user = currentUserId;
    if (user == null) throw StateError('Please sign in again.');
    for (final picked in result.files) {
      final bytes = picked.bytes;
      if (bytes != null && bytes.isNotEmpty) {
        await uploadBytes(user, picked.name, bytes, folderId: folderId, sourceProvider: 'Files / Drive / OneDrive / other');
      }
    }
  }

  Future<void> importImagesFromGallery({String? folderId}) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.image,
    );
    if (result == null) return;
    final user = currentUserId;
    if (user == null) throw StateError('Please sign in again.');
    for (final picked in result.files) {
      final bytes = picked.bytes;
      if (bytes != null && bytes.isNotEmpty) {
        await uploadBytes(user, picked.name, bytes, folderId: folderId, sourceProvider: 'Gallery');
      }
    }
  }

  Future<void> uploadBytes(
    String userId,
    String name,
    Uint8List bytes, {
    String? sourceKind,
    String visibility = 'personal',
    String? folderId,
    String? sourceProvider,
    String? locationLabel,
    String? categoryOverride,
  }) async {
    if (bytes.isEmpty) throw ArgumentError('The selected file is empty.');
    final extension = _extension(name);
    final id = _uuid.v4();
    final safeName = name.replaceAll(RegExp(r'[^A-Za-z0-9._ -]'), '_');
    final storageRoot = visibility == 'school' ? 'school' : userId;
    final folderPart = folderId == null ? 'root' : 'folders/$folderId';
    final storagePath = '$storageRoot/$folderPart/${id}_$safeName';
    final category = categoryOverride ?? classify(name, sourceKind: sourceKind);

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
        'content_text': null,
        'metadata': {'source_kind': sourceKind, 'import_source': sourceProvider},
        'folder_id': folderId,
        'source_provider': sourceProvider,
        'imported_at': DateTime.now().toIso8601String(),
        'location_label': locationLabel ?? 'On this device',
      });
    } catch (_) {
      await _supabase.storage.from(bucket).remove([storagePath]);
      rethrow;
    }
  }

  Future<void> saveNotebookNote({required String notebookTitle, required String noteTitle, required String text}) async {
    final user = currentUserId;
    if (user == null) throw StateError('Please sign in again.');
    final bytes = Uint8List.fromList(utf8.encode(text));
    await uploadBytes(
      user,
      '${noteTitle.trim().isEmpty ? 'Notebook Note' : noteTitle.trim()}.txt',
      bytes,
      sourceKind: 'notebook',
      sourceProvider: 'Inspiro Notebook / Studio',
      locationLabel: 'Inspiro Notebook • $notebookTitle',
      categoryOverride: 'notebook_notes',
    );
  }

  Future<void> moveFile(Map<String, dynamic> file, {String? folderId}) async {
    final user = currentUserId;
    if (user == null) throw StateError('Please sign in again.');
    final oldPath = file['storage_path'].toString();
    final extension = file['extension'].toString();
    final safeName = file['name'].toString().replaceAll(RegExp(r'[^A-Za-z0-9._ -]'), '_');
    final idPart = oldPath.split('/').last.split('_').first;
    final root = file['visibility'] == 'school' ? 'school' : user;
    final folderPart = folderId == null ? 'root' : 'folders/$folderId';
    final newPath = '$root/$folderPart/${idPart}_$safeName';
    if (newPath == oldPath) return;
    await _supabase.storage.from(bucket).move(oldPath, newPath);
    try {
      await _supabase.from('file_manager_files').update({'folder_id': folderId, 'storage_path': newPath, 'updated_at': DateTime.now().toIso8601String()}).eq('id', file['id']);
    } catch (_) {
      await _supabase.storage.from(bucket).move(newPath, oldPath);
      rethrow;
    }
  }

  Future<void> rename(Map<String, dynamic> file, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    final extension = _extension(trimmed);
    if (extension != file['extension']) throw ArgumentError('Keep the original file extension.');
    final oldPath = file['storage_path'] as String;
    final segments = oldPath.split('/');
    final idPart = segments.last.split('_').first;
    final safeName = trimmed.replaceAll(RegExp(r'[^A-Za-z0-9._ -]'), '_');
    final newPath = '${segments.sublist(0, segments.length - 1).join('/')}/$idPart\_$safeName';
    if (newPath == oldPath) return;
    await _supabase.storage.from(bucket).move(oldPath, newPath);
    try {
      await _supabase.from('file_manager_files').update({'name': trimmed, 'storage_path': newPath, 'updated_at': DateTime.now().toIso8601String()}).eq('id', file['id']);
    } catch (_) {
      await _supabase.storage.from(bucket).move(newPath, oldPath);
      rethrow;
    }
  }

  Future<void> delete(Map<String, dynamic> file) async {
    await _supabase.storage.from(bucket).remove([file['storage_path'] as String]);
    await _supabase.from('file_manager_files').delete().eq('id', file['id']);
  }

  Future<Uint8List> download(Map<String, dynamic> file) => _supabase.storage.from(bucket).download(file['storage_path'] as String);

  Future<void> updateTextFile(Map<String, dynamic> file, String text) async {
    final extension = file['extension'] as String;
    if (!{'txt', 'md'}.contains(extension)) throw ArgumentError('Only TXT and Markdown files are editable inside the app.');
    final bytes = Uint8List.fromList(utf8.encode(text));
    await _supabase.storage.from(bucket).uploadBinary(file['storage_path'] as String, bytes, fileOptions: FileOptions(contentType: _mime(extension), upsert: true));
    await _supabase.from('file_manager_files').update({'content_text': text, 'size_bytes': bytes.length, 'updated_at': DateTime.now().toIso8601String()}).eq('id', file['id']);
  }

  Future<void> analyzeAndOrganize() async {
    final files = await listAllFiles();
    for (final file in files) {
      final metadata = Map<String, dynamic>.from(file['metadata'] ?? {});
      final sourceKind = metadata['source_kind']?.toString();
      final category = classify(file['name'] as String, sourceKind: sourceKind);
      await _supabase.from('file_manager_files').update({'category': category}).eq('id', file['id']);
    }
  }
}

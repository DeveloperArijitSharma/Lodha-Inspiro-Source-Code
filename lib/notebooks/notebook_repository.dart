import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../file_manager/file_manager_service.dart';
import 'notebook_models.dart';
import 'pdf_text_extractor.dart';

/// All Supabase reads/writes for the Notebooks feature.
class NotebookRepository {
  final _client = Supabase.instance.client;
  final _pdfExtractor = const PdfTextExtractorService();

  String _requireUserId() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) throw StateError('Please sign in before using Notebooks.');
    return userId;
  }

  Future<List<Notebook>> fetchNotebooks() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return [];
    final rows = await _client.from('notebooks').select().eq('owner_id', userId).order('created_at', ascending: false);
    return (rows as List).map((row) => Notebook.fromMap(Map<String, dynamic>.from(row as Map))).toList();
  }

  Future<Notebook> createNotebook(String title) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) throw ArgumentError('Notebook title cannot be empty.');
    final userId = _requireUserId();
    final row = await _client.from('notebooks').insert({'title': cleanTitle, 'owner_id': userId}).select().single();
    return Notebook.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> deleteNotebook(String id) async {
    _requireUserId();
    await _client.from('notebooks').delete().eq('id', id);
  }

  Future<void> updateSummary(String notebookId, String summary) async {
    _requireUserId();
    await _client.from('notebooks').update({'summary': summary.trim()}).eq('id', notebookId);
  }

  Future<List<NotebookSource>> fetchSources(String notebookId) async {
    _requireUserId();
    final rows = await _client.from('notebook_sources').select().eq('notebook_id', notebookId).order('created_at', ascending: true);
    return (rows as List).map((row) => NotebookSource.fromMap(Map<String, dynamic>.from(row as Map))).toList();
  }

  Future<NotebookSource> addSource(NotebookSource source) async {
    _requireUserId();
    if (source.mimeType == 'application/pdf' && source.base64Data != null && source.base64Data!.isNotEmpty) {
      final bytes = Uint8List.fromList(base64Decode(source.base64Data!));
      final extracted = await _pdfExtractor.extract(bytes);
      if (extracted.trim().isEmpty) throw StateError('This PDF does not contain selectable text. Scanned/image-only PDFs need OCR before they can be used as text sources.');
      source = NotebookSource(id: source.id, notebookId: source.notebookId, title: source.title, mimeType: source.mimeType, textContent: extracted, createdAt: source.createdAt);
    }
    final row = await _client.from('notebook_sources').insert(source.toInsertMap(source.notebookId)).select().single();
    return NotebookSource.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> deleteSource(String id) async {
    _requireUserId();
    await _client.from('notebook_sources').delete().eq('id', id);
  }

  Future<List<ChatMessage>> fetchMessages(String notebookId) async {
    _requireUserId();
    final rows = await _client.from('notebook_messages').select().eq('notebook_id', notebookId).order('created_at', ascending: true);
    return (rows as List).map((row) => ChatMessage.fromMap(Map<String, dynamic>.from(row as Map))).toList();
  }

  Future<ChatMessage> addMessage(String notebookId, ChatMessage message) async {
    _requireUserId();
    final row = await _client.from('notebook_messages').insert(message.toInsertMap(notebookId)).select().single();
    return ChatMessage.fromMap(Map<String, dynamic>.from(row));
  }

  Future<List<NotebookNote>> fetchNotes(String notebookId) async {
    _requireUserId();
    final rows = await _client.from('notebook_notes').select().eq('notebook_id', notebookId).order('updated_at', ascending: false);
    return (rows as List).map((row) => NotebookNote.fromMap(Map<String, dynamic>.from(row as Map))).toList();
  }

  Future<NotebookNote> addNote(NotebookNote note) async {
    _requireUserId();
    final row = await _client.from('notebook_notes').insert(note.toInsertMap(note.notebookId)).select().single();
    final saved = NotebookNote.fromMap(Map<String, dynamic>.from(row));
    try {
      final notebook = await _client.from('notebooks').select('title').eq('id', note.notebookId).single();
      await FileManagerService.instance.saveNotebookNote(notebookTitle: notebook['title'].toString(), noteTitle: saved.title, text: saved.content);
    } catch (_) {
      // The Notebook remains saved even if the File Manager mirror is temporarily unavailable.
    }
    return saved;
  }

  Future<NotebookNote> updateNote(String id, {required String title, required String content}) async {
    _requireUserId();
    final row = await _client.from('notebook_notes').update({'title': title.trim().isEmpty ? 'Untitled note' : title.trim(), 'content': content, 'updated_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id).select().single();
    return NotebookNote.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> deleteNote(String id) async {
    _requireUserId();
    await _client.from('notebook_notes').delete().eq('id', id);
  }
}

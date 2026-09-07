import 'package:supabase_flutter/supabase_flutter.dart';
import 'notebook_models.dart';

/// All Supabase reads/writes for the Notebooks feature, in one place.
/// See supabase_notebooks_schema.sql for the tables this expects.
class NotebookRepository {
  final _client = Supabase.instance.client;

  Future<List<Notebook>> fetchNotebooks() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];
    final rows = await _client
        .from('notebooks')
        .select()
        .eq('owner_id', userId)
        .order('created_at', ascending: false);
    return (rows as List).map((r) => Notebook.fromMap(r)).toList();
  }

  Future<Notebook> createNotebook(String title) async {
    final userId = _client.auth.currentUser?.id;
    final row = await _client
        .from('notebooks')
        .insert({'title': title, 'owner_id': userId})
        .select()
        .single();
    return Notebook.fromMap(row);
  }

  Future<void> deleteNotebook(String id) async {
    await _client.from('notebooks').delete().eq('id', id);
  }

  Future<void> updateSummary(String notebookId, String summary) async {
    await _client.from('notebooks').update({'summary': summary}).eq('id', notebookId);
  }

  Future<List<NotebookSource>> fetchSources(String notebookId) async {
    final rows = await _client
        .from('notebook_sources')
        .select()
        .eq('notebook_id', notebookId)
        .order('created_at', ascending: true);
    return (rows as List).map((r) => NotebookSource.fromMap(r)).toList();
  }

  Future<NotebookSource> addSource(NotebookSource source) async {
    final row = await _client
        .from('notebook_sources')
        .insert(source.toInsertMap(source.notebookId))
        .select()
        .single();
    return NotebookSource.fromMap(row);
  }

  Future<void> deleteSource(String id) async {
    await _client.from('notebook_sources').delete().eq('id', id);
  }

  Future<List<ChatMessage>> fetchMessages(String notebookId) async {
    final rows = await _client
        .from('notebook_messages')
        .select()
        .eq('notebook_id', notebookId)
        .order('created_at', ascending: true);
    return (rows as List).map((r) => ChatMessage.fromMap(r)).toList();
  }

  Future<ChatMessage> addMessage(String notebookId, ChatMessage message) async {
    final row = await _client
        .from('notebook_messages')
        .insert(message.toInsertMap(notebookId))
        .select()
        .single();
    return ChatMessage.fromMap(row);
  }

  Future<List<NotebookNote>> fetchNotes(String notebookId) async {
    final rows = await _client
        .from('notebook_notes')
        .select()
        .eq('notebook_id', notebookId)
        .order('updated_at', ascending: false);
    return (rows as List).map((r) => NotebookNote.fromMap(r)).toList();
  }

  Future<NotebookNote> addNote(NotebookNote note) async {
    final row = await _client
        .from('notebook_notes')
        .insert(note.toInsertMap(note.notebookId))
        .select()
        .single();
    return NotebookNote.fromMap(row);
  }

  Future<NotebookNote> updateNote(String id, {required String title, required String content}) async {
    final row = await _client
        .from('notebook_notes')
        .update({'title': title, 'content': content, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', id)
        .select()
        .single();
    return NotebookNote.fromMap(row);
  }

  Future<void> deleteNote(String id) async {
    await _client.from('notebook_notes').delete().eq('id', id);
  }
}

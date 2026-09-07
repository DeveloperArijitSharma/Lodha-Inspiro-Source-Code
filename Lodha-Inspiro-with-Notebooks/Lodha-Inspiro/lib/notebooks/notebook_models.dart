class Notebook {
  final String id;
  final String title;
  final String? summary;
  final DateTime createdAt;

  Notebook({
    required this.id,
    required this.title,
    this.summary,
    required this.createdAt,
  });

  factory Notebook.fromMap(Map<String, dynamic> map) => Notebook(
        id: map['id'] as String,
        title: map['title'] as String? ?? 'Untitled notebook',
        summary: map['summary'] as String?,
        createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );

  Map<String, dynamic> toInsertMap() => {
        'title': title,
        if (summary != null) 'summary': summary,
      };
}

/// A single source document attached to a notebook.
///
/// [textContent] is used for plain text/markdown/pasted sources.
/// [base64Data] + [mimeType] is used for anything binary (PDF, images) —
/// Gemini reads these natively, so we never parse PDFs on-device, which is
/// what keeps this working identically on Android/iOS/macOS/Windows/web.
class NotebookSource {
  final String id;
  final String notebookId;
  final String title;
  final String mimeType;
  final String? textContent;
  final String? base64Data;
  final DateTime createdAt;

  NotebookSource({
    required this.id,
    required this.notebookId,
    required this.title,
    required this.mimeType,
    this.textContent,
    this.base64Data,
    required this.createdAt,
  });

  factory NotebookSource.fromMap(Map<String, dynamic> map) => NotebookSource(
        id: map['id'] as String,
        notebookId: map['notebook_id'] as String,
        title: map['title'] as String? ?? 'Untitled source',
        mimeType: map['mime_type'] as String? ?? 'text/plain',
        textContent: map['text_content'] as String?,
        base64Data: map['base64_data'] as String?,
        createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );

  Map<String, dynamic> toInsertMap(String notebookId) => {
        'notebook_id': notebookId,
        'title': title,
        'mime_type': mimeType,
        if (textContent != null) 'text_content': textContent,
        if (base64Data != null) 'base64_data': base64Data,
      };
}

class ChatMessage {
  final String id;
  final bool isUser;
  final String text;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.isUser,
    required this.text,
    required this.createdAt,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
        id: map['id'] as String,
        isUser: map['is_user'] as bool? ?? true,
        text: map['text'] as String? ?? '',
        createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );

  Map<String, dynamic> toInsertMap(String notebookId) => {
        'notebook_id': notebookId,
        'is_user': isUser,
        'text': text,
      };
}

/// A saved, editable note — either typed by the student directly, or saved
/// from an AI chat answer they wanted to keep (mirrors NotebookLM's notes).
class NotebookNote {
  final String id;
  final String notebookId;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  NotebookNote({
    required this.id,
    required this.notebookId,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NotebookNote.fromMap(Map<String, dynamic> map) => NotebookNote(
        id: map['id'] as String,
        notebookId: map['notebook_id'] as String,
        title: map['title'] as String? ?? 'Untitled note',
        content: map['content'] as String? ?? '',
        createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '') ??
            DateTime.now(),
      );

  Map<String, dynamic> toInsertMap(String notebookId) => {
        'notebook_id': notebookId,
        'title': title,
        'content': content,
      };
}

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
/// PDFs are converted to hidden text before this model is saved. Groq receives
/// that stored text for grounded Notebook answers. Plain text/markdown sources
/// continue to use [textContent]. [base64Data] is retained only for backwards
/// compatibility with older source rows.
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

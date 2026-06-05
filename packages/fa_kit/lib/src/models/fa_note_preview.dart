import '../pages/fa_notes_page.dart';

/// A note preview (header) in the notes list.
class FANotePreview {
  final int id;
  final String author;
  final String displayAuthor;
  final String title;
  final DateTime datetime;
  final String naturalDatetime;
  final bool unread;
  final Uri noteUrl;

  FANotePreview({
    required this.id,
    required this.author,
    required this.displayAuthor,
    required this.title,
    required this.datetime,
    required this.naturalDatetime,
    required this.unread,
    required this.noteUrl,
  });

  /// Create from a parsed note header.
  factory FANotePreview.fromHeader(FANoteHeader header) {
    return FANotePreview(
      id: header.id,
      author: header.author,
      displayAuthor: header.displayAuthor,
      title: header.title,
      datetime: header.datetime,
      naturalDatetime: header.naturalDatetime,
      unread: header.unread,
      noteUrl: header.noteUrl,
    );
  }

  /// Create a copy marked as read.
  FANotePreview asRead() {
    return FANotePreview(
      id: id,
      author: author,
      displayAuthor: displayAuthor,
      title: title,
      datetime: datetime,
      naturalDatetime: naturalDatetime,
      unread: false,
      noteUrl: noteUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is FANotePreview && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

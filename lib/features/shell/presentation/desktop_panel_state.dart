import '../../notes/domain/note_item.dart';

/// Opens the desktop panel editor instead of a full-screen route.
class NoteEditorRequest {
  const NoteEditorRequest({
    this.item,
    this.initialType = NoteType.note,
    this.contextDay,
  });

  final NoteItem? item;
  final NoteType initialType;

  /// Home day selector when the editor was opened (audit completions).
  final DateTime? contextDay;

  bool get isCreate => item == null;
}

enum DesktopPanelView {
  summary,
  settings,
  editor,
}

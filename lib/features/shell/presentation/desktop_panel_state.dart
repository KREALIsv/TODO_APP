import '../../notes/domain/note_item.dart';

/// Opens the desktop panel editor instead of a full-screen route.
class NoteEditorRequest {
  const NoteEditorRequest({
    this.item,
    this.initialType = NoteType.note,
  });

  final NoteItem? item;
  final NoteType initialType;

  bool get isCreate => item == null;
}

enum DesktopPanelView {
  summary,
  settings,
  editor,
}

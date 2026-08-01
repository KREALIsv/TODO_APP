import '../../notes/domain/notes_filter.dart';

/// Result from [ProfileScreen] when the user picks a filter or a diary day.
class ProfileNavigationResult {
  const ProfileNavigationResult({this.filter, this.day});

  final NotesFilter? filter;
  final DateTime? day;
}

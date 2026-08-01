import '../../notes/data/day_entries_repository.dart';
import '../../notes/data/notes_repository.dart';
import 'sync_conflict.dart';

class AccountSwitchPrompt {
  const AccountSwitchPrompt({
    required this.fromEmail,
    required this.toEmail,
  });

  final String fromEmail;
  final String toEmail;
}

/// Whether this device still holds notes or day-log data from another account.
bool deviceHasAccountSpecificContent({
  required NotesRepository notes,
  required DayEntriesRepository dayEntries,
}) {
  final hasNotes = notes.exportAllMaps().any((map) => !isSyncConflictNoteMap(map));
  if (hasNotes) return true;
  return dayEntries.getAll().isNotEmpty;
}

/// Returns a prompt when [currentEmail] differs from the last bound sync account
/// and local content would be unsafe to upload blindly.
AccountSwitchPrompt? detectAccountSwitchPrompt({
  required String? boundAccountEmail,
  required String? currentEmail,
  required bool hasLocalContent,
}) {
  if (currentEmail == null || currentEmail.trim().isEmpty) return null;
  if (boundAccountEmail == null || boundAccountEmail.trim().isEmpty) return null;
  if (boundAccountEmail.trim().toLowerCase() == currentEmail.trim().toLowerCase()) {
    return null;
  }
  if (!hasLocalContent) return null;
  return AccountSwitchPrompt(
    fromEmail: boundAccountEmail,
    toEmail: currentEmail,
  );
}

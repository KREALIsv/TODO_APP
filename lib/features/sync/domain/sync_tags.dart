/// Stable tag entity id used in sync mutations (`tag_${lowercase name}`).
String tagSyncEntityId(String name) => 'tag_${name.trim().toLowerCase()}';

/// Resolves a tag display name for DELETE mutations during pull.
///
/// DELETE payloads omit the tag name, so we first check the pre-pull snapshot
/// and then fall back to the local catalog (covers fresh devices replaying
/// CREATE followed by DELETE from the mutation log).
String? resolveTagNameForDelete({
  required String entityId,
  Map<String, Map<String, dynamic>>? beforePullTags,
  required Iterable<String> catalogNames,
}) {
  final fromSnapshot = beforePullTags?[entityId]?['name'];
  if (fromSnapshot is String && fromSnapshot.trim().isNotEmpty) {
    return fromSnapshot;
  }

  const prefix = 'tag_';
  if (!entityId.startsWith(prefix)) return null;
  final key = entityId.substring(prefix.length);
  for (final name in catalogNames) {
    if (name.trim().toLowerCase() == key) return name;
  }
  return null;
}

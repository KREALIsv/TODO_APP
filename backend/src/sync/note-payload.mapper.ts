/** Stable tag entity id used by the Flutter client (`tag_${lowercase name}`). */
export function tagSyncEntityId(name: string): string {
  return `tag_${name.trim().toLowerCase()}`;
}

/** Maps client [NoteItem] payload fields onto the normalized `notes` row. */
export function noteContentFromPayload(payload: Record<string, unknown>): string {
  const legacy = payload.content;
  if (typeof legacy === 'string' && legacy.trim().length > 0) {
    return legacy;
  }

  const title = typeof payload.title === 'string' ? payload.title : '';
  const body = typeof payload.body === 'string' ? payload.body : '';
  const trimmedTitle = title.trim();
  const trimmedBody = body.trim();

  if (trimmedTitle && trimmedBody) {
    return `${trimmedTitle}\n\n${trimmedBody}`;
  }
  return trimmedTitle || trimmedBody || '';
}

export function tagIdsFromPayload(payload: Record<string, unknown>): string[] {
  if (Array.isArray(payload.tagIds)) {
    return payload.tagIds.map(String);
  }
  if (Array.isArray(payload.tags)) {
    return payload.tags
      .filter((tag): tag is string => typeof tag === 'string' && tag.trim().length > 0)
      .map(tagSyncEntityId);
  }
  return [];
}

export function reminderOffsetFromPayload(
  payload: Record<string, unknown>,
): string | null {
  if (payload.reminderOffset !== undefined) {
    const value = payload.reminderOffset;
    return value == null ? null : String(value);
  }
  if (payload.reminderMinutesBefore !== undefined) {
    const minutes = payload.reminderMinutesBefore;
    if (minutes == null) return null;
    return String(minutes);
  }
  return null;
}

export interface NormalizedNotePayload {
  content: string;
  archivedAt: Date | null;
  dueAt: Date | null;
  reminderOffset: string | null;
  tagIds: string[];
}

export function normalizeNotePayload(
  payload: Record<string, unknown>,
): NormalizedNotePayload {
  return {
    content: noteContentFromPayload(payload),
    archivedAt: payload.archivedAt
      ? new Date(payload.archivedAt as string)
      : null,
    dueAt: payload.dueAt ? new Date(payload.dueAt as string) : null,
    reminderOffset: reminderOffsetFromPayload(payload),
    tagIds: tagIdsFromPayload(payload),
  };
}

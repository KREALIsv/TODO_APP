import {
  noteContentFromPayload,
  normalizeNotePayload,
  reminderOffsetFromPayload,
  tagIdsFromPayload,
  tagSyncEntityId,
} from './note-payload.mapper';

describe('note-payload.mapper', () => {
  it('builds stable tag ids from display names', () => {
    expect(tagSyncEntityId('Work')).toBe('tag_work');
    expect(tagSyncEntityId('  Gym  ')).toBe('tag_gym');
  });

  it('maps client title/body to content', () => {
    expect(
      noteContentFromPayload({ title: 'Hello', body: 'World' }),
    ).toBe('Hello\n\nWorld');
    expect(noteContentFromPayload({ title: 'Only title', body: '' })).toBe(
      'Only title',
    );
    expect(noteContentFromPayload({ title: '', body: 'Only body' })).toBe(
      'Only body',
    );
  });

  it('prefers legacy content when present', () => {
    expect(
      noteContentFromPayload({
        content: 'Legacy',
        title: 'Ignored',
        body: 'Ignored',
      }),
    ).toBe('Legacy');
  });

  it('maps tag names to tag ids', () => {
    expect(
      tagIdsFromPayload({ tags: ['Work', 'Personal'] }),
    ).toEqual(['tag_work', 'tag_personal']);
    expect(tagIdsFromPayload({ tagIds: ['tag_custom'] })).toEqual([
      'tag_custom',
    ]);
  });

  it('maps reminderMinutesBefore to reminderOffset string', () => {
    expect(reminderOffsetFromPayload({ reminderMinutesBefore: 60 })).toBe('60');
    expect(reminderOffsetFromPayload({ reminderMinutesBefore: null })).toBeNull();
    expect(reminderOffsetFromPayload({ reminderOffset: '30' })).toBe('30');
  });

  it('normalizes a full client note payload', () => {
    const normalized = normalizeNotePayload({
      title: 'Deploy',
      body: 'Ship it',
      tags: ['Work'],
      dueAt: '2026-07-31T10:00:00.000Z',
      archivedAt: null,
      reminderMinutesBefore: 30,
    });

    expect(normalized.content).toBe('Deploy\n\nShip it');
    expect(normalized.tagIds).toEqual(['tag_work']);
    expect(normalized.reminderOffset).toBe('30');
    expect(normalized.dueAt).toEqual(new Date('2026-07-31T10:00:00.000Z'));
  });
});

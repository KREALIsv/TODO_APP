export interface SyncResponseItem {
  entityType: 'note' | 'tag' | 'dayEntry';
  entityId: string;
  operation: 'CREATE' | 'UPDATE' | 'DELETE';
  payload: Record<string, unknown> | null;
  serverRevision: string;
  serverUpdatedAt: string;
}

export class SyncPullResponseDto {
  data!: SyncResponseItem[];
  nextCursor!: string | null;
}

import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../common/services';
import { SyncMutationDto, SyncPullResponseDto, SyncResponseItem } from './dto';

const PAGE_SIZE = 100;

@Injectable()
export class SyncService {
  constructor(private readonly prisma: PrismaService) {}

  async push(
    userId: string,
    mutations: SyncMutationDto[],
  ): Promise<{ accepted: number; revision: string }> {
    return this.prisma.$transaction(async (tx) => {
      let maxRevision = await this.getCurrentRevision(tx as unknown as PrismaService, userId);

      const accepted = [] as typeof mutations;

      for (const mutation of mutations) {
        const existing = await tx.syncMutation.findUnique({
          where: {
            userId_clientMutationId: {
              userId,
              clientMutationId: mutation.clientMutationId,
            },
          },
        });

        if (existing) continue;

        maxRevision += BigInt(1);

        await tx.syncMutation.create({
          data: {
            userId,
            clientMutationId: mutation.clientMutationId,
            entityType: mutation.entityType,
            entityId: mutation.entityId,
            operation: mutation.operation,
            payload: (mutation.payload ?? {}) as Prisma.InputJsonValue,
            serverRevision: maxRevision,
          },
        });

        await this.applyMutation(tx as unknown as PrismaService, userId, mutation);
        accepted.push(mutation);
      }

      return { accepted: accepted.length, revision: maxRevision.toString() };
    });
  }

  async pull(
    userId: string,
    cursor?: string,
    entityType?: string,
  ): Promise<SyncPullResponseDto> {
    const afterRevision = cursor ? BigInt(cursor) : BigInt(0);

    const where: {
      userId: string;
      serverRevision: { gt: bigint };
      entityType?: string;
    } = {
      userId,
      serverRevision: { gt: afterRevision },
    };

    if (entityType) {
      where.entityType = entityType;
    }

    const rows = await this.prisma.syncMutation.findMany({
      where,
      orderBy: { serverRevision: 'asc' },
      take: PAGE_SIZE + 1,
    });

    const hasMore = rows.length > PAGE_SIZE;
    const items = (hasMore ? rows.slice(0, PAGE_SIZE) : rows).map(
      (row): SyncResponseItem => ({
        entityType: row.entityType as SyncResponseItem['entityType'],
        entityId: row.entityId,
        operation: row.operation as SyncResponseItem['operation'],
        payload: (row.payload as Record<string, unknown>) ?? null,
        serverRevision: row.serverRevision.toString(),
        serverUpdatedAt: row.serverUpdatedAt.toISOString(),
      }),
    );

    const nextCursor = items.length === 0
      ? null
      : items[items.length - 1].serverRevision;

    return { data: items, nextCursor };
  }

  async status(userId: string): Promise<{ revision: string; count: number }> {
    const last = await this.prisma.syncMutation.findFirst({
      where: { userId },
      orderBy: { serverRevision: 'desc' },
      select: { serverRevision: true },
    });

    const count = await this.prisma.syncMutation.count({
      where: { userId },
    });

    return {
      revision: last?.serverRevision.toString() ?? '0',
      count,
    };
  }

  private async getCurrentRevision(
    prisma: PrismaService,
    userId: string,
  ): Promise<bigint> {
    const last = await prisma.syncMutation.findFirst({
      where: { userId },
      orderBy: { serverRevision: 'desc' },
      select: { serverRevision: true },
    });
    return last?.serverRevision ?? BigInt(0);
  }

  private async applyMutation(
    prisma: PrismaService,
    userId: string,
    mutation: SyncMutationDto,
  ): Promise<void> {
    const payload = mutation.payload ?? {};
    const now = new Date();

    switch (mutation.entityType) {
      case 'note':
        if (mutation.operation === 'DELETE') {
          await prisma.note.updateMany({
            where: { userId, id: mutation.entityId },
            data: { deletedAt: now },
          });
        } else {
          await prisma.note.upsert({
            where: { userId_id: { userId, id: mutation.entityId } },
            create: {
              id: mutation.entityId,
              userId,
              content: (payload.content as string) ?? '',
              archivedAt: payload.archivedAt
                ? new Date(payload.archivedAt as string)
                : null,
              dueAt: payload.dueAt
                ? new Date(payload.dueAt as string)
                : null,
              reminderOffset: (payload.reminderOffset as string) ?? null,
              tagIds: ((payload.tagIds as string[]) ?? []).map(String),
              serverUpdatedAt: now,
              serverRevision: await this.nextRevisionFor(prisma, userId),
            },
            update: {
              content: (payload.content as string) ?? undefined,
              archivedAt: payload.archivedAt !== undefined
                ? payload.archivedAt
                  ? new Date(payload.archivedAt as string)
                  : null
                : undefined,
              dueAt: payload.dueAt !== undefined
                ? payload.dueAt
                  ? new Date(payload.dueAt as string)
                  : null
                : undefined,
              reminderOffset: payload.reminderOffset !== undefined
                ? (payload.reminderOffset as string) ?? null
                : undefined,
              tagIds: payload.tagIds !== undefined
                ? ((payload.tagIds as string[]) ?? []).map(String)
                : undefined,
              serverUpdatedAt: now,
              serverRevision: await this.nextRevisionFor(prisma, userId),
            },
          });
        }
        break;

      case 'tag':
        if (mutation.operation === 'DELETE') {
          await prisma.tag.updateMany({
            where: { userId, id: mutation.entityId },
            data: { deletedAt: now },
          });
        } else {
          await prisma.tag.upsert({
            where: { userId_id: { userId, id: mutation.entityId } },
            create: {
              id: mutation.entityId,
              userId,
              name: (payload.name as string) ?? '',
              colorId: (payload.colorId as string) ?? null,
              opacity: payload.opacity !== undefined
                ? Number(payload.opacity)
                : null,
              serverUpdatedAt: now,
              serverRevision: await this.nextRevisionFor(prisma, userId),
            },
            update: {
              name: payload.name !== undefined ? (payload.name as string) : undefined,
              colorId: payload.colorId !== undefined
                ? (payload.colorId as string) ?? null
                : undefined,
              opacity: payload.opacity !== undefined
                ? Number(payload.opacity)
                : undefined,
              serverUpdatedAt: now,
              serverRevision: await this.nextRevisionFor(prisma, userId),
            },
          });
        }
        break;

      case 'dayEntry':
        if (mutation.operation === 'DELETE') {
          await prisma.dayEntry.updateMany({
            where: { userId, id: mutation.entityId },
            data: { deletedAt: now },
          });
        } else {
          await prisma.dayEntry.upsert({
            where: { userId_id: { userId, id: mutation.entityId } },
            create: {
              id: mutation.entityId,
              userId,
              noteId: (payload.noteId as string) ?? '',
              day: payload.day ? new Date(payload.day as string) : new Date(),
              outcome: (payload.outcome as string) ?? null,
              serverUpdatedAt: now,
              serverRevision: await this.nextRevisionFor(prisma, userId),
            },
            update: {
              noteId: payload.noteId !== undefined ? (payload.noteId as string) : undefined,
              day: payload.day !== undefined
                ? new Date(payload.day as string)
                : undefined,
              outcome: payload.outcome !== undefined
                ? (payload.outcome as string) ?? null
                : undefined,
              serverUpdatedAt: now,
              serverRevision: await this.nextRevisionFor(prisma, userId),
            },
          });
        }
        break;
    }
  }

  private async nextRevisionFor(
    prisma: PrismaService,
    userId: string,
  ): Promise<bigint> {
    const last = await prisma.syncMutation.findFirst({
      where: { userId },
      orderBy: { serverRevision: 'desc' },
      select: { serverRevision: true },
    });
    return (last?.serverRevision ?? BigInt(0)) + BigInt(1);
  }
}

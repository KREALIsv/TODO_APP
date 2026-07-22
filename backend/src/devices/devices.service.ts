import { Injectable } from '@nestjs/common';
import { PrismaService } from '../common/services';

@Injectable()
export class DevicesService {
  constructor(private readonly prisma: PrismaService) {}

  async registerOrUpdate(
    userId: string,
    appUserId: string,
    metadata: {
      platform?: string;
      osVersion?: string;
      appVersion?: string;
    } = {},
  ) {
    const existing = await this.prisma.device.findUnique({
      where: { appUserId },
    });

    if (existing && existing.userId !== userId) {
      // Reassign device to current user if it was previously anonymous.
      await this.prisma.device.update({
        where: { id: existing.id },
        data: { userId },
      });
    }

    return this.prisma.device.upsert({
      where: { appUserId },
      create: {
        userId,
        appUserId,
        platform: metadata.platform ?? null,
        osVersion: metadata.osVersion ?? null,
        appVersion: metadata.appVersion ?? null,
      },
      update: {
        platform: metadata.platform ?? existing?.platform ?? null,
        osVersion: metadata.osVersion ?? existing?.osVersion ?? null,
        appVersion: metadata.appVersion ?? existing?.appVersion ?? null,
        lastSyncedAt: new Date(),
      },
    });
  }

  async getByUser(userId: string) {
    return this.prisma.device.findMany({
      where: { userId },
      orderBy: { lastSyncedAt: 'desc' },
    });
  }
}

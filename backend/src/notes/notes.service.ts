import { Injectable } from '@nestjs/common';
import { PrismaService } from '../common/services';

@Injectable()
export class NotesService {
  constructor(private readonly prisma: PrismaService) {}

  async findByUser(userId: string) {
    return this.prisma.note.findMany({
      where: { userId, deletedAt: null },
      orderBy: { serverUpdatedAt: 'desc' },
    });
  }
}

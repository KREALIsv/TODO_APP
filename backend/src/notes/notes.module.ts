import { Module } from '@nestjs/common';
import { PrismaService } from '../common/services';
import { NotesService } from './notes.service';

@Module({
  providers: [NotesService, PrismaService],
  exports: [NotesService],
})
export class NotesModule {}

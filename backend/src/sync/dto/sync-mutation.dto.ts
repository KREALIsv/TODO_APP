import { IsString, IsOptional, IsIn, IsObject } from 'class-validator';

export class SyncMutationDto {
  @IsString()
  clientMutationId!: string;

  @IsString()
  @IsIn(['note', 'tag', 'dayEntry'])
  entityType!: 'note' | 'tag' | 'dayEntry';

  @IsString()
  entityId!: string;

  @IsString()
  @IsIn(['CREATE', 'UPDATE', 'DELETE'])
  operation!: 'CREATE' | 'UPDATE' | 'DELETE';

  @IsObject()
  @IsOptional()
  payload?: Record<string, unknown>;
}

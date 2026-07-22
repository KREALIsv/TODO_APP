import { ArrayMinSize, IsArray, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';
import { SyncMutationDto } from './sync-mutation.dto';

export class SyncPushDto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => SyncMutationDto)
  @ArrayMinSize(1)
  mutations!: SyncMutationDto[];
}

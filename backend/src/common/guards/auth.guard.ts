import {
  CanActivate,
  ExecutionContext,
  GoneException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Request } from 'express';
import * as jwt from 'jsonwebtoken';
import { PrismaService } from '../services';

export interface JwtPayload {
  userId: string;
  sessionUuid: string;
  iat: number;
  exp: number;
}

@Injectable()
export class AuthGuard implements CanActivate {
  constructor(
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<Request>();
    const token = this.extractBearerToken(request);

    let payload: JwtPayload;
    try {
      payload = jwt.verify(
        token,
        this.config.getOrThrow<string>('SECRET_AUTH_TOKEN_KEY'),
      ) as JwtPayload;
    } catch {
      throw new UnauthorizedException('Invalid token');
    }

    if (Date.now() / 1000 >= payload.exp) {
      throw new GoneException('Token expired');
    }

    const session = await this.prisma.session.findUnique({
      where: { sessionUuid: payload.sessionUuid },
    });

    if (!session || session.expiresAt <= new Date()) {
      throw new UnauthorizedException('Session invalid or expired');
    }

    request['user'] = {
      userId: payload.userId,
      sessionUuid: payload.sessionUuid,
    };

    return true;
  }

  private extractBearerToken(request: Request): string {
    const header = request.headers.authorization;
    if (!header) {
      throw new UnauthorizedException('Authorization header missing');
    }

    const [scheme, token] = header.split(' ');
    if (scheme?.toLowerCase() !== 'bearer' || !token) {
      throw new UnauthorizedException('Invalid authorization format');
    }

    return token;
  }
}

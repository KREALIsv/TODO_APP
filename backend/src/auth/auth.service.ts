import {
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcrypt';
import * as jwt from 'jsonwebtoken';
import * as crypto from 'crypto';
import { PrismaService } from '../common/services';
import { LoginDto, RegisterDto } from './dto';
import { AuthResponseDto } from './dto/auth-response.dto';

export interface TokenPayload {
  userId: string;
  sessionUuid: string;
}

@Injectable()
export class AuthService {
  constructor(
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
  ) {}

  async register(dto: RegisterDto): Promise<AuthResponseDto> {
    const existing = await this.prisma.user.findUnique({
      where: { email: dto.email.toLowerCase() },
    });

    if (existing) {
      throw new ConflictException('Email already registered');
    }

    const passwordHash = await bcrypt.hash(dto.password, 12);

    const user = await this.prisma.user.create({
      data: {
        email: dto.email.toLowerCase(),
        passwordHash,
      },
    });

    return this.createSession(user.id);
  }

  async login(dto: LoginDto): Promise<AuthResponseDto> {
    const user = await this.prisma.user.findUnique({
      where: { email: dto.email.toLowerCase() },
    });

    if (!user || !user.passwordHash) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const valid = await bcrypt.compare(dto.password, user.passwordHash);
    if (!valid) {
      throw new UnauthorizedException('Invalid credentials');
    }

    return this.createSession(user.id);
  }

  async refresh(refreshToken: string): Promise<AuthResponseDto> {
    const session = await this.prisma.session.findUnique({
      where: { refreshToken },
    });

    if (!session || session.expiresAt <= new Date()) {
      throw new UnauthorizedException('Invalid or expired refresh token');
    }

    await this.prisma.session.delete({ where: { id: session.id } });

    return this.createSession(session.userId);
  }

  async logout(userId: string, sessionUuid: string): Promise<void> {
    await this.prisma.session.deleteMany({
      where: { userId, sessionUuid },
    });
  }

  async logoutAll(userId: string): Promise<void> {
    await this.prisma.session.deleteMany({
      where: { userId },
    });
  }

  private async createSession(userId: string): Promise<AuthResponseDto> {
    const secret = this.config.getOrThrow<string>('SECRET_AUTH_TOKEN_KEY');
    const accessExpiration = this.config.getOrThrow<string>('ACCESS_TOKEN_EXPIRATION');
    const refreshExpiration = this.config.getOrThrow<string>('REFRESH_TOKEN_EXPIRATION');

    const sessionUuid = crypto.randomUUID();
    const now = Math.floor(Date.now() / 1000);
    const accessExpiresIn = this.parseDuration(accessExpiration);
    const refreshExpiresIn = this.parseDuration(refreshExpiration);

    const accessToken = jwt.sign({ userId, sessionUuid }, secret, {
      expiresIn: accessExpiresIn,
    });

    const refreshToken = jwt.sign({ userId, sessionUuid }, secret, {
      expiresIn: refreshExpiresIn,
    });

    await this.prisma.session.create({
      data: {
        userId,
        refreshToken,
        sessionUuid,
        expiresAt: new Date(Date.now() + refreshExpiresIn * 1000),
      },
    });

    return {
      accessToken,
      refreshToken,
      expiresIn: accessExpiresIn,
    };
  }

  private parseDuration(exp: string): number {
    const match = exp.match(/^(\d+)([smhdwMy])$/);
    if (!match) return 900;
    const value = parseInt(match[1], 10);
    const unit = match[2];
    const multipliers: Record<string, number> = {
      s: 1,
      m: 60,
      h: 3600,
      d: 86400,
      w: 604800,
      M: 2592000,
      y: 31536000,
    };
    return value * (multipliers[unit] ?? 1);
  }
}

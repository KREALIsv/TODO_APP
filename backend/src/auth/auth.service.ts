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
import { MailService } from '../mail';
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
    private readonly mail: MailService,
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

    void this.sendWelcomeEmail(user.id, user.email);

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

  async requestPasswordReset(email: string): Promise<void> {
    const normalized = email.trim().toLowerCase();
    const user = await this.prisma.user.findUnique({
      where: { email: normalized },
    });

    if (!user || !user.passwordHash) {
      return;
    }

    if (!this.mail.isConfigured()) {
      return;
    }

    const rawToken = crypto.randomBytes(32).toString('hex');
    const tokenHash = crypto.createHash('sha256').update(rawToken).digest('hex');
    const expiresAt = new Date(Date.now() + 60 * 60 * 1000);

    await this.prisma.passwordResetToken.updateMany({
      where: { userId: user.id, usedAt: null },
      data: { usedAt: new Date() },
    });

    await this.prisma.passwordResetToken.create({
      data: {
        userId: user.id,
        tokenHash,
        expiresAt,
      },
    });

    const appUrl = this.config.get<string>(
      'WODO_APP_URL',
      'https://app.wodo.app',
    );
    const resetUrl = `${appUrl.replace(/\/$/, '')}/?wodo_reset=${rawToken}`;

    await this.mail.send({
      to: user.email,
      flow: 'password_reset',
      userId: user.id,
      subject: 'Restablece tu contraseña de WODO',
      html: this.mail.buildPasswordResetHtml(resetUrl),
    });
  }

  async resetPassword(token: string, password: string): Promise<void> {
    const tokenHash = crypto.createHash('sha256').update(token).digest('hex');
    const record = await this.prisma.passwordResetToken.findUnique({
      where: { tokenHash },
      include: { user: true },
    });

    if (
      !record ||
      record.usedAt ||
      record.expiresAt <= new Date() ||
      !record.user.passwordHash
    ) {
      throw new UnauthorizedException('Invalid or expired reset token');
    }

    const passwordHash = await bcrypt.hash(password, 12);

    await this.prisma.$transaction([
      this.prisma.user.update({
        where: { id: record.userId },
        data: { passwordHash },
      }),
      this.prisma.passwordResetToken.update({
        where: { id: record.id },
        data: { usedAt: new Date() },
      }),
      this.prisma.session.deleteMany({ where: { userId: record.userId } }),
    ]);
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

  private async sendWelcomeEmail(userId: string, email: string): Promise<void> {
    if (!this.mail.isConfigured()) return;

    try {
      const appUrl = this.config.get<string>(
        'WODO_APP_URL',
        'https://app.wodo.app',
      );
      await this.mail.send({
        to: email,
        flow: 'welcome',
        userId,
        subject: 'Bienvenida/o a WODO',
        html: this.mail.buildWelcomeHtml(appUrl.replace(/\/$/, '')),
      });
    } catch (error) {
      // Registration should succeed even if welcome mail fails.
      console.error('Welcome email failed:', error);
    }
  }

  private async createSession(userId: string): Promise<AuthResponseDto> {
    const secret = this.config.getOrThrow<string>('SECRET_AUTH_TOKEN_KEY');
    const accessExpiration = this.config.getOrThrow<string>('ACCESS_TOKEN_EXPIRATION');
    const refreshExpiration = this.config.getOrThrow<string>('REFRESH_TOKEN_EXPIRATION');

    const sessionUuid = crypto.randomUUID();
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

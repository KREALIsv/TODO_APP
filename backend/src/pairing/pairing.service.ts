import {
  BadRequestException,
  GoneException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PairingStatus } from '@prisma/client';
import * as crypto from 'crypto';
import { AuthService } from '../auth/auth.service';
import { PrismaService } from '../common/services';
import { DevicesService } from '../devices/devices.service';
import { ApprovePairingDto, StartPairingDto } from './dto';

const PAIRING_TTL_MS = 3 * 60 * 1000;
const DISPLAY_CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

export interface PairingStartResult {
  pairingId: string;
  displayCode: string;
  pollToken: string;
  expiresAt: string;
  qrPayload: {
    v: number;
    pairingId: string;
    code: string;
    apiBase: string;
    expiresAt: string;
    ephemeralPub?: string;
  };
}

export interface PairingPendingResult {
  pairingId: string;
  displayCode: string;
  ephemeralPub: string | null;
  expiresAt: string;
  encryptionRequired: boolean;
}

export interface PairingPollResult {
  status: 'pending' | 'approved' | 'expired';
  accessToken?: string;
  refreshToken?: string;
  expiresIn?: number;
  email?: string;
  wrappedDek?: string | null;
  approverEphemeralPub?: string | null;
  encryptionEnabled?: boolean;
}

@Injectable()
export class PairingService {
  constructor(
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
    private readonly auth: AuthService,
    private readonly devices: DevicesService,
  ) {}

  async start(dto: StartPairingDto): Promise<PairingStartResult> {
    const pollToken = crypto.randomBytes(32).toString('hex');
    const pollTokenHash = this.hashToken(pollToken);
    const displayCode = await this.allocateDisplayCode();
    const expiresAt = new Date(Date.now() + PAIRING_TTL_MS);
    const apiBase = this.resolveApiBase();
    const ephemeralPub = dto.ephemeralPub?.trim() || null;

    const session = await this.prisma.pairingSession.create({
      data: {
        displayCode,
        pollTokenHash,
        clientPlatform: dto.clientPlatform ?? null,
        newAppUserId: dto.appUserId?.trim() || null,
        ephemeralPub,
        expiresAt,
      },
    });

    const expiresAtIso = expiresAt.toISOString();
    return {
      pairingId: session.id,
      displayCode,
      pollToken,
      expiresAt: expiresAtIso,
      qrPayload: {
        v: 1,
        pairingId: session.id,
        code: displayCode,
        apiBase,
        expiresAt: expiresAtIso,
        ...(ephemeralPub ? { ephemeralPub } : {}),
      },
    };
  }

  async getPendingByCode(code: string): Promise<PairingPendingResult> {
    const normalized = code.trim().toUpperCase();
    const session = await this.prisma.pairingSession.findFirst({
      where: {
        displayCode: normalized,
        status: PairingStatus.pending,
      },
      orderBy: { createdAt: 'desc' },
    });

    if (!session) {
      throw new NotFoundException('No encontramos esa solicitud de vinculación.');
    }
    if (session.expiresAt <= new Date()) {
      await this.markExpired(session.id);
      throw new GoneException('El código de vinculación expiró. Genera uno nuevo.');
    }

    return {
      pairingId: session.id,
      displayCode: session.displayCode,
      ephemeralPub: session.ephemeralPub,
      expiresAt: session.expiresAt.toISOString(),
      encryptionRequired: false,
    };
  }

  async approve(
    approverUserId: string,
    dto: ApprovePairingDto,
  ): Promise<{ accepted: true }> {
    const pairingId = dto.pairingId?.trim();
    const code = dto.code?.trim().toUpperCase();
    if (!pairingId && !code) {
      throw new BadRequestException('Indica el código o el ID de vinculación.');
    }

    const session = pairingId
      ? await this.prisma.pairingSession.findUnique({ where: { id: pairingId } })
      : await this.prisma.pairingSession.findFirst({
          where: {
            displayCode: code!,
            status: PairingStatus.pending,
          },
          orderBy: { createdAt: 'desc' },
        });

    if (!session) {
      throw new NotFoundException('No encontramos esa solicitud de vinculación.');
    }

    if (session.expiresAt <= new Date()) {
      await this.markExpired(session.id);
      throw new GoneException('El código de vinculación expiró. Genera uno nuevo.');
    }

    if (session.status !== PairingStatus.pending) {
      throw new BadRequestException(
        'Esta vinculación ya fue usada o ya no está pendiente.',
      );
    }

    const user = await this.prisma.user.findUnique({
      where: { id: approverUserId },
    });
    if (!user) {
      throw new UnauthorizedException('Usuario no válido.');
    }

    if (user.encryptionEnabled) {
      if (!dto.wrappedDek?.trim() || !dto.approverEphemeralPub?.trim()) {
        throw new BadRequestException(
          'Esta cuenta tiene datos protegidos: se requiere la clave envuelta (DEK) para vincular.',
        );
      }
    }

    const platform =
      session.clientPlatform === 'web' || session.clientPlatform === 'mobile'
        ? session.clientPlatform
        : undefined;
    const tokens = await this.auth.issueSession(approverUserId, platform);

    await this.prisma.pairingSession.update({
      where: { id: session.id },
      data: {
        status: PairingStatus.approved,
        approverUserId,
        approvedAt: new Date(),
        grantAccessToken: tokens.accessToken,
        grantRefreshToken: tokens.refreshToken,
        grantExpiresIn: tokens.expiresIn,
        grantEmail: user.email,
        grantWrappedDek: dto.wrappedDek?.trim() || null,
        grantApproverPub: dto.approverEphemeralPub?.trim() || null,
      },
    });

    if (session.newAppUserId) {
      await this.devices.markTrusted(approverUserId, session.newAppUserId);
    }

    return { accepted: true };
  }

  async poll(pollToken: string): Promise<PairingPollResult> {
    const token = pollToken?.trim();
    if (!token) {
      throw new UnauthorizedException('Token de vinculación requerido.');
    }

    const session = await this.prisma.pairingSession.findUnique({
      where: { pollTokenHash: this.hashToken(token) },
    });

    if (!session) {
      throw new NotFoundException('Vinculación no encontrada.');
    }

    if (
      session.status === PairingStatus.consumed ||
      session.status === PairingStatus.expired
    ) {
      throw new GoneException('Esta vinculación ya no está disponible.');
    }

    if (session.expiresAt <= new Date() && session.status === PairingStatus.pending) {
      await this.markExpired(session.id);
      return { status: 'expired' };
    }

    if (session.status === PairingStatus.pending) {
      return { status: 'pending' };
    }

    if (session.status !== PairingStatus.approved) {
      return { status: 'expired' };
    }

    if (
      !session.grantAccessToken ||
      !session.grantRefreshToken ||
      session.grantExpiresIn == null
    ) {
      throw new GoneException('La sesión de vinculación ya no está disponible.');
    }

    let encryptionEnabled = false;
    if (session.approverUserId) {
      const user = await this.prisma.user.findUnique({
        where: { id: session.approverUserId },
        select: { encryptionEnabled: true },
      });
      encryptionEnabled = user?.encryptionEnabled ?? false;
    }

    const result: PairingPollResult = {
      status: 'approved',
      accessToken: session.grantAccessToken,
      refreshToken: session.grantRefreshToken,
      expiresIn: session.grantExpiresIn,
      email: session.grantEmail ?? undefined,
      wrappedDek: session.grantWrappedDek,
      approverEphemeralPub: session.grantApproverPub,
      encryptionEnabled,
    };

    await this.prisma.pairingSession.update({
      where: { id: session.id },
      data: {
        status: PairingStatus.consumed,
        consumedAt: new Date(),
        grantAccessToken: null,
        grantRefreshToken: null,
        grantExpiresIn: null,
        grantEmail: null,
        grantWrappedDek: null,
        grantApproverPub: null,
      },
    });

    return result;
  }

  private async markExpired(id: string): Promise<void> {
    await this.prisma.pairingSession.update({
      where: { id },
      data: { status: PairingStatus.expired },
    });
  }

  private hashToken(token: string): string {
    return crypto.createHash('sha256').update(token).digest('hex');
  }

  private async allocateDisplayCode(): Promise<string> {
    for (let attempt = 0; attempt < 12; attempt++) {
      const code = this.randomDisplayCode();
      const existing = await this.prisma.pairingSession.findFirst({
        where: {
          displayCode: code,
          status: PairingStatus.pending,
          expiresAt: { gt: new Date() },
        },
      });
      if (!existing) return code;
    }
    return this.randomDisplayCode(10);
  }

  private randomDisplayCode(length = 8): string {
    let out = '';
    const bytes = crypto.randomBytes(length);
    for (let i = 0; i < length; i++) {
      out += DISPLAY_CODE_ALPHABET[bytes[i]! % DISPLAY_CODE_ALPHABET.length];
    }
    return out;
  }

  private resolveApiBase(): string {
    const configured = this.config.get<string>('APP_PUBLIC_URL');
    if (configured?.trim()) {
      const base = configured.replace(/\/$/, '');
      return base.endsWith('/api/v1') ? base : `${base}/api/v1`;
    }
    return 'https://api.wodo.app/api/v1';
  }
}

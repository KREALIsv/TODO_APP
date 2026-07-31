import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_surface.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/domain/auth_errors.dart';
import '../../auth/presentation/widgets/auth_page_shell.dart';
import '../../encryption/data/crypto_service.dart';
import '../../encryption/data/vault_service.dart';
import '../../sync/data/device_identity.dart';
import '../../sync/data/device_registry.dart';
import '../../sync/data/sync_service.dart';
import '../data/pairing_service.dart';

/// New device (typically web): show QR + code and wait for phone approval.
class QrLoginScreen extends StatefulWidget {
  const QrLoginScreen({super.key});

  @override
  State<QrLoginScreen> createState() => _QrLoginScreenState();
}

class _QrLoginScreenState extends State<QrLoginScreen> {
  PairingStart? _pairing;
  PairingKeySession? _keySession;
  var _loading = true;
  Object? _error;
  Timer? _expiryTicker;
  var _pollGeneration = 0;

  @override
  void initState() {
    super.initState();
    _begin();
  }

  @override
  void dispose() {
    _pollGeneration++;
    _expiryTicker?.cancel();
    super.dispose();
  }

  Future<void> _begin() async {
    final generation = ++_pollGeneration;
    setState(() {
      _loading = true;
      _error = null;
      _pairing = null;
    });
    _expiryTicker?.cancel();

    try {
      final keySession = await PairingKeySession.create();
      final pub = await keySession.publicKeyBase64;
      final started = await PairingService.instance.start(
        appUserId: DeviceIdentity.instance.appUserId,
        ephemeralPub: pub,
      );
      if (!mounted || generation != _pollGeneration) return;

      _keySession = keySession;
      setState(() {
        _pairing = started;
        _loading = false;
      });
      _expiryTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {});
        if (DateTime.now().isAfter(started.expiresAt)) {
          _expiryTicker?.cancel();
        }
      });

      while (mounted && generation == _pollGeneration) {
        if (DateTime.now().isAfter(started.expiresAt)) {
          throw StateError(
            'El código de vinculación expiró. Genera uno nuevo.',
          );
        }

        final result = await PairingService.instance.poll(started.pollToken);
        if (!mounted || generation != _pollGeneration) return;

        if (result.isPending) {
          await Future<void>.delayed(const Duration(seconds: 2));
          continue;
        }
        if (result.isExpired) {
          throw StateError(
            'El código de vinculación expiró. Genera uno nuevo.',
          );
        }
        if (!result.isApproved ||
            result.accessToken == null ||
            result.refreshToken == null ||
            result.expiresIn == null) {
          throw StateError('No se pudo completar la vinculación.');
        }

        await AuthService.instance.applySessionTokens(
          accessToken: result.accessToken!,
          refreshToken: result.refreshToken!,
          expiresInSeconds: result.expiresIn!,
          email: result.email,
        );

        if (result.encryptionEnabled) {
          final wrapped = result.wrappedDek;
          final approverPub = result.approverEphemeralPub;
          final session = _keySession;
          if (wrapped == null ||
              approverPub == null ||
              session == null) {
            throw StateError(
              'La cuenta tiene datos protegidos, pero no llegó la clave. '
              'Vuelve a intentar o usa el código de recuperación.',
            );
          }
          final dek = await CryptoService.instance.unwrapDekFromPairing(
            wrappedDek: wrapped,
            approverEphemeralPubBase64: approverPub,
            newDeviceKeyPair: session.keyPair,
          );
          await VaultService.instance.storeDekFromPairing(dek);
        }

        await DeviceRegistry.instance.register();
        await DeviceIdentity.instance.setSyncEnabled(true);
        await VaultService.instance.refreshSecurity();
        await SyncService.instance.syncNow();
        if (!mounted || generation != _pollGeneration) return;
        Navigator.of(context).pop(true);
        return;
      }
    } catch (error) {
      if (!mounted || generation != _pollGeneration) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  String get _remainingLabel {
    final pairing = _pairing;
    if (pairing == null) return '';
    final seconds =
        pairing.expiresAt.difference(DateTime.now()).inSeconds.clamp(0, 9999);
    final m = seconds ~/ 60;
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _copyCode() async {
    final code = _pairing?.displayCode;
    if (code == null) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Código copiado'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final pairing = _pairing;
    final expired =
        pairing != null && DateTime.now().isAfter(pairing.expiresAt);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Entrar con tu teléfono'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: AuthPageShell(
        title: 'Entrar con tu teléfono',
        subtitle:
            'En un dispositivo donde ya tengas sesión (p. ej. tu teléfono), '
            'abre Ajustes → Vincular dispositivo e introduce este código.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_loading && pairing == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null && pairing == null) ...[
              Text(
                AuthErrors.message(_error!, registering: false),
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppSurface.secondary(context),
                ),
              ),
              const SizedBox(height: 16),
              AuthPrimaryButton(
                label: 'Reintentar',
                onPressed: _begin,
              ),
            ] else if (pairing != null) ...[
              Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppSurface.border(context),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: QrImageView(
                      data: pairing.qrData,
                      version: QrVersions.auto,
                      size: 220,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Código',
                textAlign: TextAlign.center,
                style: textTheme.labelLarge?.copyWith(
                  color: AppSurface.secondary(context),
                ),
              ),
              const SizedBox(height: 6),
              SelectableText(
                pairing.displayCode,
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall?.copyWith(
                  letterSpacing: 3,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: _copyCode,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copiar código'),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                expired ? 'Código expirado' : 'Caduca en $_remainingLabel',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  color: expired
                      ? Theme.of(context).colorScheme.error
                      : AppSurface.secondary(context),
                ),
              ),
              const SizedBox(height: 20),
              if (_error != null) ...[
                Text(
                  AuthErrors.message(_error!, registering: false),
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (expired || _error != null)
                AuthPrimaryButton(
                  label: 'Generar código nuevo',
                  onPressed: _begin,
                )
              else ...[
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(height: 12),
                Text(
                  'Esperando confirmación en tu teléfono…',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppSurface.secondary(context),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Usar correo y contraseña'),
            ),
          ],
        ),
      ),
    );
  }
}

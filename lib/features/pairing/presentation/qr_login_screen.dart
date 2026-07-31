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
  const QrLoginScreen({super.key, @visibleForTesting this.previewPairing});

  /// Renders the QR state without calling the pairing API (tests/previews only).
  @visibleForTesting
  final PairingStart? previewPairing;

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
    final preview = widget.previewPairing;
    if (preview != null) {
      _pairing = preview;
      _loading = false;
      _expiryTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {});
      });
      return;
    }
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
          if (wrapped == null || approverPub == null || session == null) {
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
    final seconds = pairing.expiresAt
        .difference(DateTime.now())
        .inSeconds
        .clamp(0, 9999);
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
        leading: const BackButton(),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: AuthPageShell(
        title: 'Vincular este dispositivo',
        subtitle:
            'Usa un equipo donde ya tengas sesión para aprobar el acceso.',
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
              AuthPrimaryButton(label: 'Reintentar', onPressed: _begin),
            ] else if (pairing != null) ...[
              const _PairingSteps(),
              const SizedBox(height: 20),
              Center(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppSurface.border(context)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      QrImageView(
                        data: pairing.qrData,
                        version: QrVersions.auto,
                        size: 200,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'O introduce este código',
                        style: textTheme.labelMedium?.copyWith(
                          color: AppSurface.secondary(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        pairing.displayCode,
                        textAlign: TextAlign.center,
                        style: textTheme.headlineSmall?.copyWith(
                          letterSpacing: 4,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace',
                          color: AppSurface.title(context),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextButton.icon(
                        onPressed: _copyCode,
                        icon: const Icon(Icons.copy_rounded, size: 17),
                        label: const Text('Copiar'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
              else
                _WaitingStatus(remainingLabel: _remainingLabel),
            ],
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Volver al inicio de sesión'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PairingSteps extends StatelessWidget {
  const _PairingSteps();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _PairingStep(
          number: '1',
          text: 'Abre WODO en el dispositivo donde ya tienes sesión.',
        ),
        SizedBox(height: 10),
        _PairingStep(
          number: '2',
          text: 'Ve a Ajustes → Vincular dispositivo y escanea el QR.',
        ),
      ],
    );
  }
}

class _PairingStep extends StatelessWidget {
  const _PairingStep({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: textTheme.labelMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              text,
              style: textTheme.bodyMedium?.copyWith(height: 1.35),
            ),
          ),
        ),
      ],
    );
  }
}

class _WaitingStatus extends StatelessWidget {
  const _WaitingStatus({required this.remainingLabel});

  final String remainingLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Esperando aprobación…',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'El código vence en $remainingLabel',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppSurface.secondary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

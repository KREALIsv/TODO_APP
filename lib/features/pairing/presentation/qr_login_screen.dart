import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
        compactHeader: true,
        maxContentWidth: 440,
        title: 'Vincular este dispositivo',
        subtitle: 'Aprueba el acceso desde un dispositivo donde ya tengas sesión.',
        footer: AuthTextLink(
          label: 'Volver al inicio de sesión',
          onPressed: () => Navigator.of(context).pop(false),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_loading && pairing == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
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
              const AuthPairingHint(),
              const SizedBox(height: 16),
              AuthPairingQrPanel(
                qrData: pairing.qrData,
                displayCode: pairing.displayCode,
                onCopy: _copyCode,
              ),
              const SizedBox(height: 14),
              if (_error != null) ...[
                Text(
                  AuthErrors.message(_error!, registering: false),
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (expired || _error != null)
                AuthPrimaryButton(
                  label: 'Generar código nuevo',
                  onPressed: _begin,
                )
              else
                AuthWaitingBanner(remainingLabel: _remainingLabel),
            ],
          ],
        ),
      ),
    );
  }
}

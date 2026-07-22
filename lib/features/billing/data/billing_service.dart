import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../domain/product_mapping.dart';
import 'app_identity_repository.dart';
import 'revenue_cat_config.dart';

enum BillingConnectionState { unconfigured, loading, ready, failed }

class BillingPackage {
  const BillingPackage({
    required this.id,
    required this.productId,
    required this.title,
    required this.price,
  });

  final String id;
  final String productId;
  final String title;
  final String price;
}

class BillingService extends ChangeNotifier {
  BillingService._();

  static final instance = BillingService._();

  BillingConnectionState _state = BillingConnectionState.unconfigured;
  List<Package> _packages = const [];
  bool _hasPlus = false;
  String? _errorMessage;
  bool _sdkConfigured = false;

  BillingConnectionState get state => _state;
  bool get hasPlus => _hasPlus;
  String? get errorMessage => _errorMessage;
  String get appUserId => AppIdentityRepository.instance.appUserId;
  bool get isConfigured => RevenueCatConfig.isConfigured;
  String get platformLabel => RevenueCatConfig.platformLabel;

  List<BillingPackage> get packages => _packages
      .map(
        (package) => BillingPackage(
          id: package.identifier,
          productId: package.storeProduct.identifier,
          title: package.storeProduct.title,
          price: package.storeProduct.priceString,
        ),
      )
      .toList(growable: false);

  Future<void> initialize() async {
    if (!RevenueCatConfig.isConfigured) {
      _state = BillingConnectionState.unconfigured;
      notifyListeners();
      return;
    }

    _state = BillingConnectionState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      if (!_sdkConfigured) {
        final config = PurchasesConfiguration(RevenueCatConfig.apiKey)
          ..appUserID = AppIdentityRepository.instance.appUserId
          ..preferredUILocaleOverride = 'es'
          ..automaticDeviceIdentifierCollectionEnabled = false
          ..diagnosticsEnabled = false;
        await Purchases.setLogLevel(
          kDebugMode ? LogLevel.debug : LogLevel.warn,
        );
        await Purchases.configure(config);
        _sdkConfigured = true;
      }
      await refresh();
    } catch (error) {
      _setFailure(error);
    }
  }

  Future<void> refresh() async {
    if (!_sdkConfigured) {
      await initialize();
      return;
    }

    _state = BillingConnectionState.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      final results = await Future.wait<dynamic>([
        Purchases.getOfferings(),
        Purchases.getCustomerInfo(),
      ]);
      final offerings = results[0] as Offerings;
      final customerInfo = results[1] as CustomerInfo;
      _packages = offerings.current?.availablePackages ?? const [];
      _applyCustomerInfo(customerInfo);
      _state = BillingConnectionState.ready;
      notifyListeners();
    } catch (error) {
      _setFailure(error);
    }
  }

  Future<bool> purchase(String packageId) async {
    final package = _packages
        .where((item) => item.identifier == packageId)
        .firstOrNull;
    if (package == null) {
      _setFailure(
        StateError('El producto seleccionado ya no está disponible.'),
      );
      return false;
    }

    _state = BillingConnectionState.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      _applyCustomerInfo(result.customerInfo);
      _state = BillingConnectionState.ready;
      notifyListeners();
      return true;
    } on PlatformException catch (error) {
      if (PurchasesErrorHelper.getErrorCode(error) ==
          PurchasesErrorCode.purchaseCancelledError) {
        _state = BillingConnectionState.ready;
        notifyListeners();
        return false;
      }
      _setFailure(error);
      return false;
    } catch (error) {
      _setFailure(error);
      return false;
    }
  }

  Future<void> restore() async {
    if (!_sdkConfigured) return initialize();
    _state = BillingConnectionState.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      final customerInfo = await Purchases.restorePurchases();
      _applyCustomerInfo(customerInfo);
      _state = BillingConnectionState.ready;
      notifyListeners();
    } catch (error) {
      _setFailure(error);
    }
  }

  void _applyCustomerInfo(CustomerInfo customerInfo) {
    _hasPlus = customerInfo.entitlements.active.containsKey(
      ProductMapping.entitlementId,
    );
  }

  void _setFailure(Object error) {
    _state = BillingConnectionState.failed;
    _errorMessage = error is PlatformException
        ? (error.message ?? 'Error de conexión con RevenueCat.')
        : error.toString().replaceFirst('Exception: ', '');
    notifyListeners();
  }
}

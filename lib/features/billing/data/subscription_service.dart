import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../auth/data/auth_service.dart';
import '../../sync/data/wodo_api_config.dart';

enum SubscriptionTier { free, plus }

enum BillingActionResult { unavailable, opened, restored }

class SubscriptionService extends ChangeNotifier {
  SubscriptionService._();

  static final instance = SubscriptionService._();

  SubscriptionTier _tier = SubscriptionTier.free;
  bool _loading = false;
  String? _manageUrl;

  SubscriptionTier get tier => _tier;
  bool get hasPlus => _tier == SubscriptionTier.plus;
  bool get isLoading => _loading;
  String? get manageUrl => _manageUrl;
  String get planLabel => hasPlus ? 'Plus' : 'Gratis';

  Future<void> refresh() async {
    if (!AuthService.instance.isAuthenticated || !WodoApiConfig.isConfigured) {
      _tier = SubscriptionTier.free;
      _manageUrl = null;
      notifyListeners();
      return;
    }

    _loading = true;
    notifyListeners();
    try {
      final token = await AuthService.instance.accessToken();
      final response = await http.get(
        WodoApiConfig.uri('billing/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = decoded['data'] as Map<String, dynamic>?;
        _tier = data?['tier'] == 'plus'
            ? SubscriptionTier.plus
            : SubscriptionTier.free;
        _manageUrl = data?['manageUrl'] as String?;
      }
    } catch (_) {
      // Billing never blocks local use. The last known entitlement is retained.
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<BillingActionResult> beginCheckout(String planId) async {
    return _postAction('billing/checkout', {'planId': planId});
  }

  Future<BillingActionResult> restore() async {
    return _postAction('billing/restore', const {});
  }

  Future<BillingActionResult> _postAction(
    String path,
    Map<String, dynamic> body,
  ) async {
    if (!AuthService.instance.isAuthenticated || !WodoApiConfig.isConfigured) {
      return BillingActionResult.unavailable;
    }
    try {
      final token = await AuthService.instance.accessToken();
      final response = await http.post(
        WodoApiConfig.uri(path),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return BillingActionResult.unavailable;
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = decoded['data'] as Map<String, dynamic>?;
      return data?['status'] == 'restored'
          ? BillingActionResult.restored
          : data?['checkoutUrl'] != null
          ? BillingActionResult.opened
          : BillingActionResult.unavailable;
    } catch (_) {
      return BillingActionResult.unavailable;
    }
  }
}

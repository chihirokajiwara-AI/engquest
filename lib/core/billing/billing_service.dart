// lib/core/billing/billing_service.dart
// A-KEN Quest — Billing Service (Stripe Integration)
//
// Manages subscription state for the commercial flavor.
// Uses Stripe Checkout (server-side) + customer portal for management.
//
// Architecture:
//   App → BillingService → Backend proxy → Stripe API
//   The backend proxy (Firebase Functions or VPS endpoint) holds the Stripe
//   secret key; the app only sends the Firebase UID.
//
// Subscription states:
//   - free: no subscription (Grade 5 only in aken flavor)
//   - trial: 7-day free trial (all grades unlocked)
//   - active: paid ¥999/month (all grades unlocked)
//   - expired: subscription lapsed (reverts to free)

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../firebase/auth_service.dart';
import '../config/flavor_config.dart';

enum SubscriptionStatus {
  free,
  trial,
  active,
  expired,
}

class SubscriptionInfo {
  final SubscriptionStatus status;
  final DateTime? trialEnd;
  final DateTime? currentPeriodEnd;
  final String? stripeCustomerId;

  const SubscriptionInfo({
    required this.status,
    this.trialEnd,
    this.currentPeriodEnd,
    this.stripeCustomerId,
  });

  bool get hasAccess =>
      status == SubscriptionStatus.trial ||
      status == SubscriptionStatus.active;

  /// For edilab flavor, always has access (free).
  static const SubscriptionInfo edilabFree = SubscriptionInfo(
    status: SubscriptionStatus.active,
  );
}

class BillingService {
  BillingService({String? backendUrl})
      : _backendUrl = backendUrl ?? _kDefaultBackendUrl;

  // TODO: Replace with actual backend URL after deployment
  static const _kDefaultBackendUrl = 'https://api.akenquest.jp';

  final String _backendUrl;
  final _auth = AuthService();

  SubscriptionInfo _cached = const SubscriptionInfo(
    status: SubscriptionStatus.free,
  );

  /// Current subscription state (cached).
  SubscriptionInfo get subscription => _cached;

  /// Whether the user has premium access.
  /// For edilab flavor: always true.
  /// For aken flavor: true if trial or active subscription.
  bool get hasPremiumAccess {
    if (FlavorConfig.instance.isEdilabFlavor) return true;
    return _cached.hasAccess;
  }

  /// Check if a specific Eiken grade is accessible.
  bool isGradeAccessible(String eikenGrade) {
    final flavor = FlavorConfig.instance;
    if (flavor.isGradeFree(eikenGrade)) return true;
    return hasPremiumAccess;
  }

  /// Build authorization headers with Firebase ID token.
  Future<Map<String, String>> _authHeaders() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    final token = await _auth.getIdToken();
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Fetch latest subscription status from backend.
  Future<SubscriptionInfo> refreshStatus() async {
    if (FlavorConfig.instance.isEdilabFlavor) {
      _cached = SubscriptionInfo.edilabFree;
      return _cached;
    }

    try {
      final uid = await _auth.getOrCreateUid();
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('$_backendUrl/billing/status?uid=$uid'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _cached = _parseStatus(data);
      }
    } catch (e) {
      debugPrint('BillingService.refreshStatus error: $e');
      // Keep cached value on network failure
    }

    return _cached;
  }

  /// Create a Stripe Checkout session for new subscription.
  /// Returns the checkout URL to open in a browser/webview.
  Future<String?> createCheckoutSession() async {
    try {
      final uid = await _auth.getOrCreateUid();
      final headers = await _authHeaders();
      final response = await http.post(
        Uri.parse('$_backendUrl/billing/checkout'),
        headers: headers,
        body: jsonEncode({
          'uid': uid,
          'trial_days': 7,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['checkout_url'] as String?;
      }
    } catch (e) {
      debugPrint('BillingService.createCheckoutSession error: $e');
    }
    return null;
  }

  /// Get Stripe Customer Portal URL for subscription management.
  Future<String?> getCustomerPortalUrl() async {
    try {
      final uid = await _auth.getOrCreateUid();
      final headers = await _authHeaders();
      final response = await http.post(
        Uri.parse('$_backendUrl/billing/portal'),
        headers: headers,
        body: jsonEncode({'uid': uid}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['portal_url'] as String?;
      }
    } catch (e) {
      debugPrint('BillingService.getCustomerPortalUrl error: $e');
    }
    return null;
  }

  SubscriptionInfo _parseStatus(Map<String, dynamic> data) {
    final statusStr = data['status'] as String? ?? 'free';
    final status = SubscriptionStatus.values.firstWhere(
      (s) => s.name == statusStr,
      orElse: () => SubscriptionStatus.free,
    );

    return SubscriptionInfo(
      status: status,
      trialEnd: data['trial_end'] != null
          ? DateTime.tryParse(data['trial_end'] as String)
          : null,
      currentPeriodEnd: data['current_period_end'] != null
          ? DateTime.tryParse(data['current_period_end'] as String)
          : null,
      stripeCustomerId: data['stripe_customer_id'] as String?,
    );
  }
}

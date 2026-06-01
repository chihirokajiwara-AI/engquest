// lib/core/billing/billing_config.dart
// A-KEN Quest — RevenueCat billing configuration.
//
// Holds per-platform API keys and entitlement/offering identifiers.
// The API keys here are placeholders — replace them with real values
// from the RevenueCat dashboard before release.

import 'package:flutter/foundation.dart'
    show kIsWeb, TargetPlatform, defaultTargetPlatform;

class BillingConfig {
  BillingConfig._();

  // ── RevenueCat API keys ──────────────────────────────────────────────────
  // TODO: Replace these with real RevenueCat public API keys from dashboard.
  // iOS and Android keys are "public app-specific" keys (safe to embed).
  // Web key is a "Web Billing API key" configured in RevenueCat dashboard.

  static const _apiKeyIos = 'rc_placeholder_aken_ios';
  static const _apiKeyAndroid = 'rc_placeholder_aken_android';
  static const _apiKeyWeb = 'rc_placeholder_aken_web';

  /// Returns the RevenueCat API key for the current platform.
  static String get apiKey {
    if (kIsWeb) return _apiKeyWeb;
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return _apiKeyIos;
      case TargetPlatform.android:
        return _apiKeyAndroid;
      default:
        // Fallback to web key for unsupported platforms.
        return _apiKeyWeb;
    }
  }

  // ── Entitlement & Offering identifiers ───────────────────────────────────
  // These must match what is configured in the RevenueCat dashboard.

  /// The entitlement identifier that grants access to all premium grades.
  static const entitlementId = 'aken_premium';

  /// The offering identifier for the default monthly subscription.
  static const offeringId = 'default';

  /// The package identifier within the offering (monthly plan).
  static const packageId = r'$rc_monthly';
}

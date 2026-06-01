// lib/core/billing/billing_service.dart
// A-KEN Quest — Billing Service (RevenueCat Integration)
//
// Manages subscription state for the commercial flavor using RevenueCat,
// which wraps iOS StoreKit 2, Google Play Billing, and Web (Stripe) into
// a single SDK with unified entitlements.
//
// Architecture:
//   App → BillingService → RevenueCat SDK → App Store / Play Store / Stripe
//   The RevenueCat dashboard holds product mappings; the app only needs the
//   public API key (safe to embed — it is not a secret).
//
// Subscription states:
//   - free: no subscription (Grade 5 only in aken flavor)
//   - trial: 7-day free trial (all grades unlocked)
//   - active: paid ¥999/month (all grades unlocked)
//   - expired: subscription lapsed (reverts to free)

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config/flavor_config.dart';
import '../firebase/auth_service.dart';
import 'billing_config.dart';

// ── Subscription data types ─────────────────────────────────────────────────

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

  const SubscriptionInfo({
    required this.status,
    this.trialEnd,
    this.currentPeriodEnd,
  });

  bool get hasAccess =>
      status == SubscriptionStatus.trial || status == SubscriptionStatus.active;

  /// For edilab flavor, always has access (free).
  static const SubscriptionInfo edilabFree = SubscriptionInfo(
    status: SubscriptionStatus.active,
  );
}

// ── BillingService ──────────────────────────────────────────────────────────

class BillingService {
  BillingService();

  final _auth = AuthService();

  SubscriptionInfo _cached = const SubscriptionInfo(
    status: SubscriptionStatus.free,
  );

  bool _initialized = false;

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

  // ── Initialization ──────────────────────────────────────────────────────

  /// Initialize the RevenueCat SDK. Call once at app startup.
  /// No-op for edilab flavor (billing not needed).
  Future<void> initialize() async {
    if (_initialized) return;
    if (FlavorConfig.instance.isEdilabFlavor) {
      _cached = SubscriptionInfo.edilabFree;
      _initialized = true;
      return;
    }

    try {
      await Purchases.setLogLevel(
        kDebugMode ? LogLevel.debug : LogLevel.error,
      );

      final configuration = PurchasesConfiguration(BillingConfig.apiKey);

      // Set the Firebase UID as the RevenueCat app user ID so that
      // entitlements are tied to the same identity across platforms.
      final uid = await _auth.getOrCreateUid();
      configuration.appUserID = uid;

      await Purchases.configure(configuration);
      _initialized = true;

      // Fetch initial entitlement status.
      await refreshStatus();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('BillingService.initialize error: $e');
      }
    }
  }

  // ── Status ──────────────────────────────────────────────────────────────

  /// Fetch latest subscription status from RevenueCat.
  Future<SubscriptionInfo> refreshStatus() async {
    if (FlavorConfig.instance.isEdilabFlavor) {
      _cached = SubscriptionInfo.edilabFree;
      return _cached;
    }

    try {
      final customerInfo = await Purchases.getCustomerInfo();
      _cached = _mapCustomerInfo(customerInfo);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('BillingService.refreshStatus error: $e');
      }
      // Keep cached value on failure.
    }
    return _cached;
  }

  // ── Purchase ────────────────────────────────────────────────────────────

  /// Initiate a purchase flow for the monthly subscription package.
  ///
  /// Returns `true` if the purchase succeeded (or was already active),
  /// `false` on cancellation or error.
  Future<bool> purchaseMonthly() async {
    try {
      final offerings = await Purchases.getOfferings();
      final offering =
          offerings.getOffering(BillingConfig.offeringId) ?? offerings.current;

      if (offering == null) {
        if (kDebugMode) {
          debugPrint('BillingService.purchaseMonthly: no offering found');
        }
        return false;
      }

      // Find the monthly package.
      final package =
          offering.monthly ?? offering.availablePackages.firstOrNull;

      if (package == null) {
        if (kDebugMode) {
          debugPrint('BillingService.purchaseMonthly: no package found');
        }
        return false;
      }

      final customerInfo = await Purchases.purchasePackage(package);
      _cached = _mapCustomerInfo(customerInfo);
      return _cached.hasAccess;
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) {
        // User cancelled — not an error.
        return false;
      }
      if (kDebugMode) {
        debugPrint('BillingService.purchaseMonthly error: $e');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('BillingService.purchaseMonthly error: $e');
      }
      return false;
    }
  }

  // ── Restore ─────────────────────────────────────────────────────────────

  /// Restore previous purchases (e.g. after reinstall or new device).
  Future<bool> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      _cached = _mapCustomerInfo(customerInfo);
      return _cached.hasAccess;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('BillingService.restorePurchases error: $e');
      }
      return false;
    }
  }

  // ── Subscription management ─────────────────────────────────────────────

  /// Open the platform's subscription management page.
  /// On iOS: App Store subscription settings.
  /// On Android: Play Store subscription settings.
  /// On Web: RevenueCat-hosted Stripe portal.
  Future<void> showManageSubscriptions() async {
    try {
      await Purchases.showManageSubscriptions();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('BillingService.showManageSubscriptions error: $e');
      }
    }
  }

  // ── Internal mapping ───────────────────────────────────────────────────

  /// Map RevenueCat [CustomerInfo] to our [SubscriptionInfo].
  SubscriptionInfo _mapCustomerInfo(CustomerInfo info) {
    final entitlement = info.entitlements.all[BillingConfig.entitlementId];

    if (entitlement == null || !entitlement.isActive) {
      // Check if they HAD an entitlement that expired.
      if (entitlement != null && !entitlement.isActive) {
        return SubscriptionInfo(
          status: SubscriptionStatus.expired,
          currentPeriodEnd: entitlement.expirationDate != null
              ? DateTime.tryParse(entitlement.expirationDate!)
              : null,
        );
      }
      return const SubscriptionInfo(status: SubscriptionStatus.free);
    }

    // Entitlement is active — determine if trial or paid.
    final periodType = entitlement.periodType;
    final isTrial = periodType == PeriodType.trial;

    return SubscriptionInfo(
      status: isTrial ? SubscriptionStatus.trial : SubscriptionStatus.active,
      trialEnd: isTrial && entitlement.expirationDate != null
          ? DateTime.tryParse(entitlement.expirationDate!)
          : null,
      currentPeriodEnd: entitlement.expirationDate != null
          ? DateTime.tryParse(entitlement.expirationDate!)
          : null,
    );
  }
}

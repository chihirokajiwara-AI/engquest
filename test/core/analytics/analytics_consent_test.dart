// test/core/analytics/analytics_consent_test.dart
// #120 (COPPA privacy-by-default): a children's app must send NO analytics until
// a parent consents. Locks that AnalyticsService wires the NoOp sink (nothing
// leaves the device) unless Firebase is available AND consent is granted.

import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/core/analytics/analytics_service.dart';

void main() {
  setUp(AnalyticsService.resetForTesting);

  test('default (no consent arg) → NoOp sink, even if Firebase is available', () {
    AnalyticsService.initialize(firebaseAvailable: true);
    expect(AnalyticsService.instance.sink, isA<NoOpAnalytics>(),
        reason: 'consent defaults to false → no real analytics sink');
  });

  test('Firebase available but consent DENIED → still NoOp (nothing sent)', () {
    AnalyticsService.initialize(
        firebaseAvailable: true, analyticsConsentGranted: false);
    expect(AnalyticsService.instance.sink, isA<NoOpAnalytics>());
  });

  test('no Firebase → NoOp regardless of consent', () {
    AnalyticsService.initialize(
        firebaseAvailable: false, analyticsConsentGranted: true);
    expect(AnalyticsService.instance.sink, isA<NoOpAnalytics>());
  });
}

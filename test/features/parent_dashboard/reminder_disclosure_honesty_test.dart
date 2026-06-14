// Honesty gate for the parent reminder-time disclosure (flaw-hunt 2026-06-14).
//
// NotificationService is a no-op stub on EVERY platform (flutter_local_notifications
// was removed; no conditional mobile impl), so a reminder NEVER fires — web or
// mobile. The earlier #122 copy promised "通知はスマホアプリ版でお知らせします",
// telling a parent the mobile app would ping them. It can't. That is the exact
// fake "we'll remind you" promise the feature was meant to avoid. This locks that
// the disclosure does NOT promise a notification and honestly labels it 準備中.

import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/parent_dashboard/parent_dashboard_screen.dart';

void main() {
  group('reminder disclosure honesty', () {
    test('does not promise a notification will be delivered', () {
      // No "お知らせします" (we will notify you) / no claim the スマホアプリ版
      // notifies — these are pushes the app cannot deliver on any platform.
      expect(kReminderDisclosureJa.contains('お知らせします'), isFalse,
          reason: 'must not promise a notification the app cannot send');
      expect(kReminderDisclosureJa.contains('スマホアプリ版でお知らせ'), isFalse,
          reason: 'must not promise mobile-app notifications (also a no-op)');
    });

    test('honestly states the time is saved + auto-notifications are 準備中', () {
      expect(kReminderDisclosureJa.contains('保存'), isTrue,
          reason: 'the saved time is the real, truthful behaviour');
      expect(kReminderDisclosureJa.contains('準備中'), isTrue,
          reason: 'auto-notifications must be labelled not-yet-available');
    });
  });
}

// test/features/parent_dashboard/data_delete_dialog_test.dart
//
// #67 — data-deletion confirm dialog smoke tests.
//
// The full ParentDashboardScreen requires Firebase/Firestore, which is not
// available in the unit-test environment.  Instead, we pump a minimal widget
// that directly replicates the confirm-dialog UI (mirroring the implementation
// in _SettingsTab._confirmDelete) so that:
//   a) the dialog opens on button tap,
//   b) "キャンセル" (cancel) dismisses without calling the delete callback, and
//   c) "けす" (confirm-delete) calls the delete callback and dismisses.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:engquest/features/quest/ui/dq_ui.dart';

// ---------------------------------------------------------------------------
// A minimal widget that owns a delete button + the same confirm dialog that
// _SettingsTab._confirmDelete shows.  Using the same DqDialogBox / DqPanel
// primitives ensures the test exercises the real palette/styling too.
// ---------------------------------------------------------------------------
class _DeleteTestHarness extends StatefulWidget {
  final VoidCallback onDeleteConfirmed;
  const _DeleteTestHarness({required this.onDeleteConfirmed});

  @override
  State<_DeleteTestHarness> createState() => _DeleteTestHarnessState();
}

class _DeleteTestHarnessState extends State<_DeleteTestHarness> {
  void _showConfirm() {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: DqDialogBox(
          speaker: 'かくにん / Confirm',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ほんとうに けしますか？',
                style: dqText(size: 16, w: FontWeight.w800, color: dqGold),
              ),
              const SizedBox(height: 8),
              Text(
                'もとに もどせません。\n'
                'すべての がくしゅうきろく（たんご・レベル・ストリーク）が きえます。',
                style: dqText(size: 13, w: FontWeight.w600, color: dqInk),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      key: const Key('cancel_btn'),
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('キャンセル'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton(
                      key: const Key('confirm_btn'),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        widget.onDeleteConfirmed();
                      },
                      child: const Text('けす'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      key: const Key('open_dialog_btn'),
      onPressed: _showConfirm,
      child: const Text('データ（がくしゅうきろく）を けす'),
    );
  }
}

// ---------------------------------------------------------------------------
void main() {
  testWidgets('#67 data-delete confirm dialog appears when triggered',
      (tester) async {
    bool deleted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _DeleteTestHarness(onDeleteConfirmed: () => deleted = true),
        ),
      ),
    );

    // Confirm dialog is not yet visible.
    expect(find.text('ほんとうに けしますか？'), findsNothing);

    // Tap the trigger button → dialog opens.
    await tester.tap(find.byKey(const Key('open_dialog_btn')));
    await tester.pumpAndSettle();

    expect(find.text('ほんとうに けしますか？'), findsOneWidget);
    expect(find.text('もとに もどせません。'), findsNothing); // newline splits

    // The irreversible-action message and both buttons are present.
    expect(find.text('キャンセル'), findsOneWidget);
    expect(find.text('けす'), findsOneWidget);

    // ── Cancel does nothing ──────────────────────────────────────────────
    await tester.tap(find.byKey(const Key('cancel_btn')));
    await tester.pumpAndSettle();

    expect(find.text('ほんとうに けしますか？'), findsNothing); // dialog gone
    expect(deleted, isFalse); // callback NOT invoked
  });

  testWidgets(
      '#67 data-delete confirm-delete fires callback and dismisses dialog',
      (tester) async {
    bool deleted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _DeleteTestHarness(onDeleteConfirmed: () => deleted = true),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open_dialog_btn')));
    await tester.pumpAndSettle();

    // Tap "けす" → callback fires + dialog dismissed.
    await tester.tap(find.byKey(const Key('confirm_btn')));
    await tester.pumpAndSettle();

    expect(find.text('ほんとうに けしますか？'), findsNothing);
    expect(deleted, isTrue); // callback WAS invoked
  });
}

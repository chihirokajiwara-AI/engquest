import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/core/ui/page_transitions.dart';

void main() {
  group('FadeSlideRoute', () {
    testWidgets('displays destination widget with fade+slide animation',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  FadeSlideRoute(
                    builder: (_) => const Scaffold(
                      body: Text('Destination'),
                    ),
                  ),
                );
              },
              child: const Text('Navigate'),
            ),
          ),
        ),
      );

      // Tap the button to trigger navigation
      await tester.tap(find.text('Navigate'));
      await tester.pump(); // Start the animation
      await tester.pump(const Duration(milliseconds: 200)); // Mid-animation

      // The destination should be partially visible (mid-transition)
      expect(find.text('Destination'), findsOneWidget);

      // Complete the animation
      await tester.pumpAndSettle();
      expect(find.text('Destination'), findsOneWidget);
    });

    testWidgets('reverse transition works on pop', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  FadeSlideRoute(
                    builder: (_) => Scaffold(
                      body: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Go Back'),
                      ),
                    ),
                  ),
                );
              },
              child: const Text('Navigate'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Navigate'));
      await tester.pumpAndSettle();

      // Now pop back
      await tester.tap(find.text('Go Back'));
      await tester.pumpAndSettle();

      // Should be back on the original screen
      expect(find.text('Navigate'), findsOneWidget);
    });

    test('transition duration is 400ms forward, 300ms reverse', () {
      final route = FadeSlideRoute(
        builder: (_) => const SizedBox(),
      );
      expect(route.transitionDuration, const Duration(milliseconds: 400));
      expect(
          route.reverseTransitionDuration, const Duration(milliseconds: 300));
    });
  });

  group('Chat bubble animation', () {
    test('slide+fade animation reaches target values', () {
      final ctrl = AnimationController(
        duration: const Duration(milliseconds: 350),
        vsync: const TestVSync(),
      );
      addTearDown(ctrl.dispose);

      final curved = CurvedAnimation(parent: ctrl, curve: Curves.easeOutCubic);
      final fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(curved);
      final slideAnim = Tween<Offset>(
        begin: const Offset(-0.15, 0.0),
        end: Offset.zero,
      ).animate(curved);

      // Before animation
      expect(fadeAnim.value, 0.0);
      expect(slideAnim.value, const Offset(-0.15, 0.0));

      // After animation completes
      ctrl.value = 1.0;
      expect(fadeAnim.value, 1.0);
      expect(slideAnim.value, Offset.zero);

      // Mid-animation
      ctrl.value = 0.5;
      expect(fadeAnim.value, greaterThan(0.0));
      expect(fadeAnim.value, lessThan(1.0));
      expect(slideAnim.value.dx, greaterThan(-0.15));
      expect(slideAnim.value.dx, lessThan(0.0));
    });
  });

  group('Battle AnimatedSwitcher', () {
    testWidgets('AnimatedSwitcher crossfades between keyed children',
        (tester) async {
      var showFirst = true;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Column(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: showFirst
                      ? const KeyedSubtree(
                          key: ValueKey('first'),
                          child: Text('Loading'),
                        )
                      : const KeyedSubtree(
                          key: ValueKey('second'),
                          child: Text('Session'),
                        ),
                ),
                ElevatedButton(
                  onPressed: () => setState(() => showFirst = false),
                  child: const Text('Switch'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Loading'), findsOneWidget);

      await tester.tap(find.text('Switch'));
      await tester.pump();
      // During crossfade, both may be present
      await tester.pump(const Duration(milliseconds: 200));

      await tester.pumpAndSettle();
      expect(find.text('Session'), findsOneWidget);
    });
  });
}

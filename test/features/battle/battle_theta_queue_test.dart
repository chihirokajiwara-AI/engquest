// ZPD ordering gate (8-pillar cycle-2, pillar ①): thetaSortQueue is what finally
// makes the captured-but-dead onboarding placement θ DO something — it steers the
// NEW cards a child meets toward their measured ability, without ever touching
// FSRS state. These tests lock the contract: no-op without placement data,
// reviewed-before-new, and the θ→difficulty scale mapping (so a high-ability child
// actually reaches the hardest cards, which a raw |difficulty−θ| compare would not).

import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/battle/battle_screen.dart';
import 'package:engquest/core/fsrs/fsrs_card.dart';

void main() {
  // New card (never reviewed): state newCard, reps 0.
  FSRSCard nu(String id, double d) => FSRSCard(vocabId: id, difficulty: d);
  // Already-seen card: review state with reps.
  FSRSCard rev(String id, double d) =>
      FSRSCard(vocabId: id, state: CardState.review, difficulty: d, reps: 2);

  group('thetaSortQueue', () {
    test('theta == 0 is a no-op (placement-less decks untouched)', () {
      final deck = [nu('a', 2), nu('b', 8), nu('c', 5)];
      final q = [0, 1, 2];
      thetaSortQueue(q, deck, 0.0);
      expect(q, [0, 1, 2]);
    });

    test('reviewed-due cards always precede new cards', () {
      final deck = [nu('a', 5), rev('b', 5), nu('c', 5), rev('d', 5)];
      final q = [0, 1, 2, 3];
      thetaSortQueue(q, deck, 3.0);
      expect(q.indexOf(1) < q.indexOf(0), isTrue);
      expect(q.indexOf(1) < q.indexOf(2), isTrue);
      expect(q.indexOf(3) < q.indexOf(2), isTrue);
    });

    test('high theta steers the HARDEST new cards first (θ→difficulty mapped)', () {
      // θ=6 maps to target difficulty 10; |d−10| ascending → 9, 5, 1.
      final deck = [nu('easy', 1), nu('mid', 5), nu('hard', 9)];
      final q = [0, 1, 2];
      thetaSortQueue(q, deck, 6.0);
      expect(q, [2, 1, 0]);
    });

    test('low theta steers the EASIEST new cards first', () {
      // θ=0.6 → target 1.9; |d−1.9| ascending → 1, 5, 9.
      final deck = [nu('easy', 1), nu('mid', 5), nu('hard', 9)];
      final q = [0, 1, 2];
      thetaSortQueue(q, deck, 0.6);
      expect(q, [0, 1, 2]);
    });

    test('empty queue is safe', () {
      final deck = <FSRSCard>[];
      final q = <int>[];
      thetaSortQueue(q, deck, 3.0);
      expect(q, isEmpty);
    });
  });
}

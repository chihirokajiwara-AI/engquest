// lib/core/content/vocab_age_filter.dart
// ENG Quest — P1.6: Age-appropriate vocabulary filtering (pure, testable)
//
// Single source of truth for the Onboarding → Battle age-filter contract.
//
// The wiring chain is:
//   OnboardingFlow (child age)
//     → OnboardingStorage.save / _AppEntryPoint._childAge
//       → WorldMapScreen(childAge:)
//         → BattleScreen(childAge:)
//           → filterVocabByAge(seed, childAge)   ← this file
//
// Keeping the threshold + young-learner ID set here (instead of as private
// constants inside battle_screen.dart) lets us unit-test the age→deck mapping
// directly, and guarantees the same logic is applied everywhere age filtering
// is needed (web build, future placement screens, etc.).

import '../../data/models/vocab_item.dart';

/// Children below this age receive the restricted young-learner deck.
///
/// Rationale: under-8 learners at the L1-L2 boundary benefit from concrete,
/// picturable nouns (animals, food, colors, family) and the simplest verbs.
/// Abstract adjectives and school/object vocabulary are deferred until age 8+.
const int kYoungLearnerAgeThreshold = 8;

/// Word IDs suitable for young learners (age < [kYoungLearnerAgeThreshold]).
/// Focus: concrete nouns (animals, colors, food, family) + simple verbs.
const Set<String> kYoungLearnerVocabIds = {
  'eiken5_001', // cat
  'eiken5_002', // dog
  'eiken5_003', // apple
  'eiken5_006', // red
  'eiken5_007', // big
  'eiken5_009', // eat
  'eiken5_010', // water
  'eiken5_012', // happy
  'eiken5_013', // play
  'eiken5_015', // blue
  'eiken5_016', // mother
  'eiken5_017', // father
  'eiken5_019', // small
  'eiken5_020', // bird
  'eiken5_021', // fish
  'eiken5_022', // tree
  'eiken5_023', // green
  'eiken5_024', // sing
  'eiken5_027', // white
  'eiken5_029', // milk
};

/// Returns [source] filtered by [age]:
///   age <  [kYoungLearnerAgeThreshold] → young-learner subset
///   age >= [kYoungLearnerAgeThreshold] → full deck (copy)
///
/// Always returns a fresh list (never the input instance), so callers can
/// safely shuffle/mutate the result.
List<VocabItem> filterVocabByAge(List<VocabItem> source, int age) {
  if (age < kYoungLearnerAgeThreshold) {
    return source
        .where((v) => kYoungLearnerVocabIds.contains(v.id))
        .toList();
  }
  return List<VocabItem>.from(source);
}

/// True when [age] should receive the restricted young-learner deck.
bool isYoungLearner(int age) => age < kYoungLearnerAgeThreshold;

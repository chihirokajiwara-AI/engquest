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
// Keeping the threshold + young-learner category set here (instead of as
// private constants inside battle_screen.dart) lets us unit-test the
// age→deck mapping directly, and guarantees the same logic is applied
// everywhere age filtering is needed (web build, future placement screens, etc.).

import '../models/vocab_item.dart';

/// Children below this age receive the restricted young-learner deck.
///
/// Rationale: under-8 learners at the L1-L2 boundary benefit from concrete,
/// picturable nouns (animals, food, colors, family) and the simplest verbs.
/// Abstract adjectives and school/object vocabulary are deferred until age 8+.
const int kYoungLearnerAgeThreshold = 8;

/// Categories suitable for young learners (age < [kYoungLearnerAgeThreshold]).
/// Focus: concrete, picturable vocabulary that maps naturally to early child literacy.
/// With the 600-word dataset these categories provide ~95 words — enough
/// for a full session without overwhelming very young learners.
const Set<String> kYoungLearnerCategories = {
  'Animals',
  'Food & Drink',
  'Family & People',
  'Colors & Shapes',
};

/// Returns [source] filtered by [age]:
///   age <  [kYoungLearnerAgeThreshold] → young-learner category subset
///   age >= [kYoungLearnerAgeThreshold] → full deck (copy)
///
/// Always returns a fresh list (never the input instance), so callers can
/// safely shuffle/mutate the result.
List<VocabItem> filterVocabByAge(List<VocabItem> source, int age) {
  if (age < kYoungLearnerAgeThreshold) {
    return source
        .where((v) => kYoungLearnerCategories.contains(v.category))
        .toList();
  }
  return List<VocabItem>.from(source);
}

/// True when [age] should receive the restricted young-learner deck.
bool isYoungLearner(int age) => age < kYoungLearnerAgeThreshold;

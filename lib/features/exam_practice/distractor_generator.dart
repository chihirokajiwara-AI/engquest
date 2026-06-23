// lib/features/exam_practice/distractor_generator.dart
// A-KEN Quest — anti-leak distractor generator for Eiken 大問1 (vocab cloze).
//
// WHY (#76): the `distractors` stored in the vocab JSON are alphabetical-adjacency
// artifacts (e.g. "decoration" → ["quantitative easing", "questionnaire",
// "radiation"]). Measured across the six banks, ~89–93% of items have the answer
// as the UNIQUE first letter among the four choices — the trivial odd-one-out —
// and 23–36% inject multi-word phrases against a single-word answer. A child can
// pick the answer without reading the English, so the practice is gameable and
// teaches nothing. (A naive "regenerate from a same-POS pool" was tried earlier
// and content-QA-blocked at ~40% clean precisely because it did NOT control the
// first letter and re-introduced phrase / synonym contamination.)
//
// This regenerates the three distractors at load time from the live grade bank
// under hard constraints that remove the orthographic tells BY CONSTRUCTION:
//   • SAME first letter as the answer   → eliminates the odd-one-out leak
//   • SAME primary part-of-speech       → grammatically plausible in the blank
//   • single token (no space / hyphen)  → no multi-word phrase tell
//   • != answer, jpTranslation not overlapping (no synonym → no 2nd valid answer)
//   • the word does not appear anywhere in the cloze sentence
//   • ranked to PREFER a different `category` than the answer, which lowers the
//     odds a distractor also fits the sentence (topical mismatch)
//
// The first-letter / phrase / synonym tells are killed deterministically; the
// remaining risk (a same-POS word that happens to also fit the sentence) is what
// the content-QA gate measures. Full semantic validation is #32 (needs the LLM
// backend, #7) — this is the orthographic-leak fix that ships without it.

import 'dart:math';

import '../../core/models/vocab_item.dart';

/// Ultra-generic, high-frequency words that make poor distractors because their
/// meaning is broad enough to "also fit" a loosely-constrained cloze (the residual
/// ambiguity class content-QA flagged for #76 — e.g. "standard" fitting "in ___
/// order", "today"/"there" fitting "ate lunch ___"). Excluding them removes the
/// most common false-second-answer without an LLM. Lower-cased; matched verbatim.
const Set<String> _genericConfusables = {
  // time / place / manner adverbs (mutually substitutable in many sentences)
  'today', 'tomorrow', 'yesterday', 'now', 'then', 'here', 'there', 'soon',
  'later', 'again', 'always', 'never', 'often', 'sometimes', 'really', 'very',
  'too', 'also', 'just', 'only', 'even', 'still', 'well', 'together',
  // ultra-generic adjectives / determiners
  'standard', 'normal', 'general', 'basic', 'common', 'main', 'usual',
  'regular',
  'good', 'bad', 'nice', 'fine', 'great', 'big', 'small', 'new', 'old', 'same',
  'other', 'many', 'much', 'more', 'most', 'some', 'any', 'such', 'own',
};

/// Build three anti-leak distractors for [answer]'s cloze, drawn from [bank]
/// (the other words of the same grade). [sentence] is the cloze source sentence.
///
/// Returns null when fewer than three clean candidates exist — the caller then
/// skips the item rather than ship a leaky one.
List<String>? buildAntiLeakDistractors(
  VocabItem answer,
  String sentence,
  List<VocabItem> bank,
  Random rng,
) {
  final ans = answer.word.trim();
  if (ans.isEmpty || answer.pos.isEmpty) return null;
  // POS-match (below) is the grammatical-plausibility guard. If the answer's own
  // POS is `unknown` (a non-standard pos string in the data → fromString default),
  // it would match ANY other unknown-tagged word regardless of real part of
  // speech — skip rather than emit a grammatically-mismatched distractor set.
  if (answer.pos.first == PartOfSpeech.unknown) return null;
  final initial = ans[0].toLowerCase();
  final pos = answer.pos.first;
  final ansLower = ans.toLowerCase();
  final ansJp = answer.jpTranslation.trim();
  final lowerSentence = sentence.toLowerCase();

  bool isClean(VocabItem c) {
    final w = c.word.trim();
    if (w.isEmpty) return false;
    final wl = w.toLowerCase();
    if (wl == ansLower) return false;
    // ultra-generic words "also fit" loose sentences → drop them as distractors
    // (but never as the answer itself, which keeps such words practiceable).
    if (_genericConfusables.contains(wl)) return false;
    // single plain token only — reject phrases, hyphenated compounds, and the
    // underscore-joined multiword keys the vocab data uses ("physical_education").
    if (w.contains(' ') || w.contains('-') || w.contains('_')) return false;
    // SAME first letter → the answer is no longer the orthographic odd-one-out
    if (w[0].toLowerCase() != initial) return false;
    // grammatically plausible in the blank
    if (!c.pos.contains(pos)) return false;
    // not a synonym (would create a second valid answer)
    final jp = c.jpTranslation.trim();
    if (jp.isNotEmpty &&
        ansJp.isNotEmpty &&
        (jp == ansJp || jp.contains(ansJp) || ansJp.contains(jp))) {
      return false;
    }
    // never show a word already visible in the sentence — WORD-BOUNDARY match,
    // not raw substring. contains() both over-rejects ("at" inside "attitude"
    // silently drains valid short-word distractors → the item gets skipped) and
    // under-rejects (a distractor "study" isn't caught when the sentence shows
    // "studying"). Mirrors wholeWordMatch() used elsewhere for the same reason.
    if (RegExp('\\b${RegExp.escape(wl)}\\b').hasMatch(lowerSentence)) {
      return false;
    }
    return true;
  }

  // De-duplicate by lowercased word so two casings can't both be picked.
  final seen = <String>{};
  final candidates = <VocabItem>[];
  for (final c in bank) {
    if (!isClean(c)) continue;
    if (seen.add(c.word.toLowerCase())) candidates.add(c);
  }
  if (candidates.length < 3) return null;

  // Prefer a different category (topical mismatch lowers sentence-fit ambiguity),
  // then fall back to same-category peers to reach three.
  final diffCat = <VocabItem>[];
  final sameCat = <VocabItem>[];
  for (final c in candidates) {
    (c.category == answer.category ? sameCat : diffCat).add(c);
  }
  diffCat.shuffle(rng);
  sameCat.shuffle(rng);
  final ordered = [...diffCat, ...sameCat];
  // .trim() the output: all filtering was done on the trimmed form, so a bank
  // word with stray whitespace must not surface as a padded distractor string.
  return ordered.take(3).map((c) => c.word.trim()).toList();
}

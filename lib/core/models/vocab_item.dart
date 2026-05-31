// lib/core/models/vocab_item.dart
// ENG Quest — A1 Vocabulary Item model (C02: CEFR-Tagged Content DB)
// Matches vocab_a1_300.json schema

import 'package:equatable/equatable.dart';

/// CEFR levels supported in ENG Quest content DB
enum CefrLevel { a1, a2, b1, b2, c1, c2 }

extension CefrLevelExtension on CefrLevel {
  String get label {
    switch (this) {
      case CefrLevel.a1: return 'A1';
      case CefrLevel.a2: return 'A2';
      case CefrLevel.b1: return 'B1';
      case CefrLevel.b2: return 'B2';
      case CefrLevel.c1: return 'C1';
      case CefrLevel.c2: return 'C2';
    }
  }

  static CefrLevel fromString(String s) {
    switch (s.toUpperCase()) {
      case 'A1': return CefrLevel.a1;
      case 'A2': return CefrLevel.a2;
      case 'B1': return CefrLevel.b1;
      case 'B2': return CefrLevel.b2;
      case 'C1': return CefrLevel.c1;
      case 'C2': return CefrLevel.c2;
      default: return CefrLevel.a1;
    }
  }
}

/// Part of speech
enum PartOfSpeech {
  noun, verb, adjective, adverb, number, phrase, interjection,
  preposition, conjunction, pronoun, properNoun, unknown
}

extension PartOfSpeechExtension on PartOfSpeech {
  static PartOfSpeech fromString(String s) {
    switch (s.toLowerCase().replaceAll(' ', '_')) {
      case 'noun': return PartOfSpeech.noun;
      case 'verb': return PartOfSpeech.verb;
      case 'adjective': return PartOfSpeech.adjective;
      case 'adverb': return PartOfSpeech.adverb;
      case 'number': return PartOfSpeech.number;
      case 'phrase': return PartOfSpeech.phrase;
      case 'interjection': return PartOfSpeech.interjection;
      case 'preposition': return PartOfSpeech.preposition;
      case 'conjunction': return PartOfSpeech.conjunction;
      case 'pronoun': return PartOfSpeech.pronoun;
      case 'proper_noun': return PartOfSpeech.properNoun;
      default: return PartOfSpeech.unknown;
    }
  }
}

/// FSRS card learning state
enum FsrsState { newCard, learning, review, relearning }

extension FsrsStateExtension on FsrsState {
  String get value {
    switch (this) {
      case FsrsState.newCard: return 'new';
      case FsrsState.learning: return 'learning';
      case FsrsState.review: return 'review';
      case FsrsState.relearning: return 'relearning';
    }
  }

  static FsrsState fromString(String s) {
    switch (s) {
      case 'learning': return FsrsState.learning;
      case 'review': return FsrsState.review;
      case 'relearning': return FsrsState.relearning;
      default: return FsrsState.newCard;
    }
  }
}

/// Core vocabulary item — immutable data class
/// Matches JSON schema in src/data/content_db/vocab_a1_300.json
class VocabItem extends Equatable {
  final String id;               // e.g., "eiken5_001"
  final String word;             // e.g., "apple"
  final String reading;          // Katakana reading, e.g., "アップル"
  final String jpTranslation;    // Japanese meaning, e.g., "りんご"
  final CefrLevel cefrLevel;     // A1 for MVP
  final String eikenLevel;       // "5" for 英検5級
  final String category;         // e.g., "Food"
  final List<PartOfSpeech> pos;  // parts of speech
  final List<String> exampleSentences;
  final String audioUrl;         // Firebase Storage path
  final String imageUrl;         // Firebase Storage path
  final FsrsState fsrsState;     // current learning state
  final List<String> tags;       // ["eiken5", "A1", "food"]
  /// 3 wrong Japanese translations used as distractors in 4-choice quiz mode.
  /// If empty, the battle screen falls back to generating distractors from the deck.
  final List<String> distractors;

  const VocabItem({
    required this.id,
    required this.word,
    required this.reading,
    required this.jpTranslation,
    required this.cefrLevel,
    required this.eikenLevel,
    required this.pos,
    required this.exampleSentences,
    this.category = '',
    this.audioUrl = '',
    this.imageUrl = '',
    this.fsrsState = FsrsState.newCard,
    this.tags = const [],
    this.distractors = const [],
  });

  factory VocabItem.fromJson(Map<String, dynamic> json) {
    return VocabItem(
      id: json['id'] as String,
      word: json['word'] as String,
      reading: json['reading'] as String,
      jpTranslation: json['jpTranslation'] as String,
      cefrLevel: CefrLevelExtension.fromString(json['cefrLevel'] as String),
      eikenLevel: json['eikenLevel'] as String,
      category: json['category'] as String? ?? '',
      pos: (json['pos'] as List<dynamic>)
          .map((p) => PartOfSpeechExtension.fromString(p as String))
          .toList(),
      exampleSentences: (json['exampleSentences'] as List<dynamic>)
          .map((s) => s as String)
          .toList(),
      audioUrl: json['audioUrl'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      fsrsState: FsrsStateExtension.fromString(
        json['fsrsState'] as String? ?? 'new',
      ),
      tags: (json['tags'] as List<dynamic>? ?? [])
          .map((t) => t as String)
          .toList(),
      distractors: (json['distractors'] as List<dynamic>? ?? [])
          .map((d) => d as String)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'word': word,
    'reading': reading,
    'jpTranslation': jpTranslation,
    'cefrLevel': cefrLevel.label,
    'eikenLevel': eikenLevel,
    'category': category,
    'pos': pos.map((p) => p.name).toList(),
    'exampleSentences': exampleSentences,
    'audioUrl': audioUrl,
    'imageUrl': imageUrl,
    'fsrsState': fsrsState.value,
    'tags': tags,
    'distractors': distractors,
  };

  VocabItem copyWith({
    FsrsState? fsrsState,
    List<String>? exampleSentences,
    List<String>? distractors,
  }) {
    return VocabItem(
      id: id,
      word: word,
      reading: reading,
      jpTranslation: jpTranslation,
      cefrLevel: cefrLevel,
      eikenLevel: eikenLevel,
      category: category,
      pos: pos,
      exampleSentences: exampleSentences ?? this.exampleSentences,
      audioUrl: audioUrl,
      imageUrl: imageUrl,
      fsrsState: fsrsState ?? this.fsrsState,
      tags: tags,
      distractors: distractors ?? this.distractors,
    );
  }

  @override
  List<Object?> get props => [id, word, cefrLevel, eikenLevel, fsrsState];

  @override
  String toString() => 'VocabItem($id: "$word" [$cefrLevel] ${fsrsState.value})';
}

// lib/data/content/vocab_a1.dart
// ENG Quest — A1 (英検5級) vocabulary: 30 seed words
//
// CEFR A1 covers basic concrete vocabulary: animals, colors, food, family,
// simple verbs, and everyday objects.

import '../models/vocab_item.dart';

/// 30 A1-level vocabulary items (英検5級) — the original seed deck.
const List<VocabItem> kSeedVocabA1 = [
  VocabItem(id: 'eiken5_001', word: 'cat',    reading: 'キャット',   jpTranslation: 'ねこ',       cefrLevel: 'A1', eikenLevel: '5', pos: ['noun'],      exampleSentences: ['I have a cat.']),
  VocabItem(id: 'eiken5_002', word: 'dog',    reading: 'ドッグ',     jpTranslation: 'いぬ',       cefrLevel: 'A1', eikenLevel: '5', pos: ['noun'],      exampleSentences: ['My dog is big.']),
  VocabItem(id: 'eiken5_003', word: 'apple',  reading: 'アップル',   jpTranslation: 'りんご',     cefrLevel: 'A1', eikenLevel: '5', pos: ['noun'],      exampleSentences: ['I eat an apple.']),
  VocabItem(id: 'eiken5_004', word: 'book',   reading: 'ブック',     jpTranslation: 'ほん',       cefrLevel: 'A1', eikenLevel: '5', pos: ['noun'],      exampleSentences: ['I read a book.']),
  VocabItem(id: 'eiken5_005', word: 'school', reading: 'スクール',   jpTranslation: 'がっこう',   cefrLevel: 'A1', eikenLevel: '5', pos: ['noun'],      exampleSentences: ['I go to school.']),
  VocabItem(id: 'eiken5_006', word: 'red',    reading: 'レッド',     jpTranslation: 'あか',       cefrLevel: 'A1', eikenLevel: '5', pos: ['adjective'], exampleSentences: ['The apple is red.']),
  VocabItem(id: 'eiken5_007', word: 'big',    reading: 'ビッグ',     jpTranslation: 'おおきい',   cefrLevel: 'A1', eikenLevel: '5', pos: ['adjective'], exampleSentences: ['That is a big dog.']),
  VocabItem(id: 'eiken5_008', word: 'run',    reading: 'ラン',       jpTranslation: 'はしる',     cefrLevel: 'A1', eikenLevel: '5', pos: ['verb'],      exampleSentences: ['I run every day.']),
  VocabItem(id: 'eiken5_009', word: 'eat',    reading: 'イート',     jpTranslation: 'たべる',     cefrLevel: 'A1', eikenLevel: '5', pos: ['verb'],      exampleSentences: ['We eat breakfast.']),
  VocabItem(id: 'eiken5_010', word: 'water',  reading: 'ウォーター', jpTranslation: 'みず',       cefrLevel: 'A1', eikenLevel: '5', pos: ['noun'],      exampleSentences: ['Drink some water.']),
  VocabItem(id: 'eiken5_011', word: 'friend', reading: 'フレンド',   jpTranslation: 'ともだち',   cefrLevel: 'A1', eikenLevel: '5', pos: ['noun'],      exampleSentences: ['She is my friend.']),
  VocabItem(id: 'eiken5_012', word: 'happy',  reading: 'ハッピー',   jpTranslation: 'うれしい',   cefrLevel: 'A1', eikenLevel: '5', pos: ['adjective'], exampleSentences: ['I am very happy.']),
  VocabItem(id: 'eiken5_013', word: 'play',   reading: 'プレイ',     jpTranslation: 'あそぶ',     cefrLevel: 'A1', eikenLevel: '5', pos: ['verb'],      exampleSentences: ['We play soccer.']),
  VocabItem(id: 'eiken5_014', word: 'house',  reading: 'ハウス',     jpTranslation: 'いえ',       cefrLevel: 'A1', eikenLevel: '5', pos: ['noun'],      exampleSentences: ['This is my house.']),
  VocabItem(id: 'eiken5_015', word: 'blue',   reading: 'ブルー',     jpTranslation: 'あお',       cefrLevel: 'A1', eikenLevel: '5', pos: ['adjective'], exampleSentences: ['The sky is blue.']),
  VocabItem(id: 'eiken5_016', word: 'mother', reading: 'マザー',     jpTranslation: 'おかあさん', cefrLevel: 'A1', eikenLevel: '5', pos: ['noun'],      exampleSentences: ['My mother is kind.']),
  VocabItem(id: 'eiken5_017', word: 'father', reading: 'ファーザー', jpTranslation: 'おとうさん', cefrLevel: 'A1', eikenLevel: '5', pos: ['noun'],      exampleSentences: ['My father works hard.']),
  VocabItem(id: 'eiken5_018', word: 'like',   reading: 'ライク',     jpTranslation: 'すき',       cefrLevel: 'A1', eikenLevel: '5', pos: ['verb'],      exampleSentences: ['I like music.']),
  VocabItem(id: 'eiken5_019', word: 'small',  reading: 'スモール',   jpTranslation: 'ちいさい',   cefrLevel: 'A1', eikenLevel: '5', pos: ['adjective'], exampleSentences: ['It is a small cat.']),
  VocabItem(id: 'eiken5_020', word: 'bird',   reading: 'バード',     jpTranslation: 'とり',       cefrLevel: 'A1', eikenLevel: '5', pos: ['noun'],      exampleSentences: ['A bird is singing.']),
  VocabItem(id: 'eiken5_021', word: 'fish',   reading: 'フィッシュ', jpTranslation: 'さかな',     cefrLevel: 'A1', eikenLevel: '5', pos: ['noun'],      exampleSentences: ['I see a fish.']),
  VocabItem(id: 'eiken5_022', word: 'tree',   reading: 'ツリー',     jpTranslation: 'き',         cefrLevel: 'A1', eikenLevel: '5', pos: ['noun'],      exampleSentences: ['The tree is tall.']),
  VocabItem(id: 'eiken5_023', word: 'green',  reading: 'グリーン',   jpTranslation: 'みどり',     cefrLevel: 'A1', eikenLevel: '5', pos: ['adjective'], exampleSentences: ['The grass is green.']),
  VocabItem(id: 'eiken5_024', word: 'sing',   reading: 'シング',     jpTranslation: 'うたう',     cefrLevel: 'A1', eikenLevel: '5', pos: ['verb'],      exampleSentences: ['They sing a song.']),
  VocabItem(id: 'eiken5_025', word: 'pen',    reading: 'ペン',       jpTranslation: 'ペン',       cefrLevel: 'A1', eikenLevel: '5', pos: ['noun'],      exampleSentences: ['I have a pen.']),
  VocabItem(id: 'eiken5_026', word: 'desk',   reading: 'デスク',     jpTranslation: 'つくえ',     cefrLevel: 'A1', eikenLevel: '5', pos: ['noun'],      exampleSentences: ['Put it on the desk.']),
  VocabItem(id: 'eiken5_027', word: 'white',  reading: 'ホワイト',   jpTranslation: 'しろ',       cefrLevel: 'A1', eikenLevel: '5', pos: ['adjective'], exampleSentences: ['Snow is white.']),
  VocabItem(id: 'eiken5_028', word: 'walk',   reading: 'ウォーク',   jpTranslation: 'あるく',     cefrLevel: 'A1', eikenLevel: '5', pos: ['verb'],      exampleSentences: ['I walk to school.']),
  VocabItem(id: 'eiken5_029', word: 'milk',   reading: 'ミルク',     jpTranslation: 'ぎゅうにゅう', cefrLevel: 'A1', eikenLevel: '5', pos: ['noun'],    exampleSentences: ['I drink milk.']),
  VocabItem(id: 'eiken5_030', word: 'park',   reading: 'パーク',     jpTranslation: 'こうえん',   cefrLevel: 'A1', eikenLevel: '5', pos: ['noun'],      exampleSentences: ['Let\'s go to the park.']),
];

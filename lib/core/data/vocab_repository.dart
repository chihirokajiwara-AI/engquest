// lib/core/data/vocab_repository.dart
// ENG Quest — Vocabulary Repository (C02: CEFR-Tagged Content DB)
// Loads 600-word eiken5 database from bundled JSON asset; syncs with Firestore for user progress

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/vocab_item.dart';

/// Metadata about the vocabulary database
class VocabDatabaseMeta {
  final String version;
  final String created;
  final String description;
  final int totalWords;
  final String cefrLevel;
  final String eikenLevel;
  final Map<String, int> categories;

  const VocabDatabaseMeta({
    required this.version,
    required this.created,
    required this.description,
    required this.totalWords,
    required this.cefrLevel,
    required this.eikenLevel,
    required this.categories,
  });

  factory VocabDatabaseMeta.fromJson(Map<String, dynamic> json) {
    return VocabDatabaseMeta(
      version: json['version'] as String,
      created: json['created'] as String,
      description: json['description'] as String,
      totalWords: json['totalWords'] as int,
      cefrLevel: json['cefrLevel'] as String,
      eikenLevel: json['eikenLevel'] as String,
      categories: Map<String, int>.from(json['categories'] as Map),
    );
  }
}

/// Query filter for vocab lookups
class VocabFilter {
  final CefrLevel? cefrLevel;
  final String? category;
  final PartOfSpeech? pos;
  final FsrsState? fsrsState;
  final String? searchTerm;

  const VocabFilter({
    this.cefrLevel,
    this.category,
    this.pos,
    this.fsrsState,
    this.searchTerm,
  });
}

/// Vocabulary repository — single source of truth for content DB
/// 
/// Usage:
///   final repo = VocabRepository();
///   await repo.initialize();
///   final words = repo.getByCategory('Animals');
///   final dueCards = repo.filterBy(VocabFilter(fsrsState: FsrsState.review));
class VocabRepository {
  static const String _assetPath = 'assets/data/eiken5_vocab.json';

  List<VocabItem> _words = [];
  VocabDatabaseMeta? _meta;
  bool _initialized = false;

  bool get isInitialized => _initialized;
  VocabDatabaseMeta? get meta => _meta;
  int get totalWords => _words.length;

  /// Load the vocabulary database from bundled asset
  Future<void> initialize() async {
    if (_initialized) return;

    final jsonString = await rootBundle.loadString(_assetPath);
    final json = jsonDecode(jsonString) as Map<String, dynamic>;

    _meta = VocabDatabaseMeta.fromJson(json);
    _words = (json['words'] as List<dynamic>)
        .map((w) => VocabItem.fromJson(w as Map<String, dynamic>))
        .toList();

    _initialized = true;
  }

  /// Get all words
  List<VocabItem> getAll() {
    _assertInitialized();
    return List.unmodifiable(_words);
  }

  /// Get by ID
  VocabItem? getById(String id) {
    _assertInitialized();
    try {
      return _words.firstWhere((w) => w.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Get all words in a category
  List<VocabItem> getByCategory(String category) {
    _assertInitialized();
    return _words.where((w) => w.category == category).toList();
  }

  /// Get all available categories
  List<String> getCategories() {
    _assertInitialized();
    final seen = <String>{};
    return _words
        .map((w) => w.category)
        .where((c) => seen.add(c))
        .toList();
  }

  /// Filter by multiple criteria
  List<VocabItem> filterBy(VocabFilter filter) {
    _assertInitialized();
    return _words.where((w) {
      if (filter.cefrLevel != null && w.cefrLevel != filter.cefrLevel) {
        return false;
      }
      if (filter.category != null && w.category != filter.category) {
        return false;
      }
      if (filter.pos != null && !w.pos.contains(filter.pos)) {
        return false;
      }
      if (filter.fsrsState != null && w.fsrsState != filter.fsrsState) {
        return false;
      }
      if (filter.searchTerm != null) {
        final term = filter.searchTerm!.toLowerCase();
        if (!w.word.toLowerCase().contains(term) &&
            !w.jpTranslation.toLowerCase().contains(term) &&
            !w.reading.toLowerCase().contains(term)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  /// Get all new (never-studied) cards
  List<VocabItem> getNewCards() {
    return filterBy(const VocabFilter(fsrsState: FsrsState.newCard));
  }

  /// Get N random new cards for a study session
  List<VocabItem> getNewCardsForSession({int count = 10}) {
    _assertInitialized();
    final newCards = getNewCards()..shuffle();
    return newCards.take(count).toList();
  }

  /// Get words by tag
  List<VocabItem> getByTag(String tag) {
    _assertInitialized();
    return _words.where((w) => w.tags.contains(tag)).toList();
  }

  /// Update a word's FSRS state (in-memory; persist to Firestore separately)
  void updateFsrsState(String id, FsrsState newState) {
    _assertInitialized();
    final idx = _words.indexWhere((w) => w.id == id);
    if (idx >= 0) {
      _words[idx] = _words[idx].copyWith(fsrsState: newState);
    }
  }

  /// Summary stats for parent dashboard
  Map<String, dynamic> getSummaryStats() {
    _assertInitialized();
    final stateCount = <String, int>{};
    for (final state in FsrsState.values) {
      stateCount[state.value] = _words.where((w) => w.fsrsState == state).length;
    }

    final reviewed = _words.where((w) => w.fsrsState != FsrsState.newCard).length;
    final mastered = _words.where((w) => w.fsrsState == FsrsState.review).length;

    return {
      'total': totalWords,
      'reviewed': reviewed,
      'mastered': mastered,
      'masteryPercent': totalWords > 0 ? (mastered / totalWords * 100).round() : 0,
      'byState': stateCount,
      'byCategory': {
        for (final cat in getCategories())
          cat: getByCategory(cat).where((w) => w.fsrsState == FsrsState.review).length,
      },
    };
  }

  void _assertInitialized() {
    if (!_initialized) {
      throw StateError(
        'VocabRepository not initialized. Call initialize() first.',
      );
    }
  }
}

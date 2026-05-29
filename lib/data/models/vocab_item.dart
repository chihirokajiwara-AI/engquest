// lib/data/models/vocab_item.dart

class VocabItem {
  final String id;
  final String word;
  final String reading;
  final String jpTranslation;
  final String cefrLevel;
  final String eikenLevel;
  final List<String> pos;
  final List<String> exampleSentences;

  const VocabItem({
    required this.id,
    required this.word,
    required this.reading,
    required this.jpTranslation,
    required this.cefrLevel,
    required this.eikenLevel,
    required this.pos,
    required this.exampleSentences,
  });
}

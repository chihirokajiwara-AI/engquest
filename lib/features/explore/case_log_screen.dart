// lib/features/explore/case_log_screen.dart
// 事件簿 (Case File) — post-clear replayability (NARRATIVE-PRODUCER-RUBRIC N12).
//
// A child who has cleared cases had nowhere to RE-experience the mystery they
// assembled. This screen is that post-clear surface: per chapter it shows the
// cleared status + the サイレント lore the child unlocked, and a header that
// shows the 7-bookmark sentence ASSEMBLING as cases are cleared (each cleared
// chapter reveals its word; uncleared show ？). COPPA-clean: the child's OWN
// progress only, no social. Reached from Settings (the secondary-screen hub) so
// the frozen 英検-foreground home composition (#66) is untouched.
//
// NO dart:io / Firebase / network — reads SceneSolvedStore (SharedPreferences).

import 'package:flutter/material.dart';

import '../exam_practice/eiken_exam_config.dart' show gradeLabelJa;
import '../quest/ui/dq_ui.dart';
import 'hotspot.dart';
import 'scene_solved_store.dart';

/// The 案件簿 in canonical play order (edge→centre = 5級→準1級).
const List<String> kCaseLogGradeOrder = [
  '5',
  '4',
  '3',
  'pre2',
  'pre2plus',
  '2',
  'pre1',
];

/// The torn-storybook bookmark each cleared chapter restores. Read in order they
/// assemble アイラ's sentence (STORY-BIBLE); the 準1 finale returns her NAME.
const Map<String, String> kBookmarkByGrade = {
  '5': 'Once, I',
  '4': 'told a story,',
  '3': 'and the whole',
  'pre2': 'grey world',
  'pre2plus': 'turned to',
  '2': 'colour.',
  'pre1': '— アイラ',
};

/// The assembling sentence: each CLEARED grade reveals its bookmark; uncleared
/// show ？. Pure + public so the reveal logic is unit-tested.
String assembledBookmarkLine(Set<String> clearedGrades) {
  return kCaseLogGradeOrder
      .map((g) => clearedGrades.contains(g) ? (kBookmarkByGrade[g] ?? '') : '？')
      .join(' ');
}

/// A chapter is cleared when every NPC ナゾ in its scene is solved.
bool isChapterCleared(SceneDef scene, Set<int> solvedIdx) {
  for (var i = 0; i < scene.hotspots.length; i++) {
    if (scene.hotspots[i].kind == HotspotKind.npc && !solvedIdx.contains(i)) {
      return false;
    }
  }
  return true;
}

class CaseLogScreen extends StatefulWidget {
  const CaseLogScreen({super.key});

  @override
  State<CaseLogScreen> createState() => _CaseLogScreenState();
}

class _CaseLogScreenState extends State<CaseLogScreen> {
  late final Future<Map<String, Set<int>>> _solved;

  @override
  void initState() {
    super.initState();
    _solved = _loadAll();
  }

  Future<Map<String, Set<int>>> _loadAll() async {
    final out = <String, Set<int>>{};
    for (final g in kCaseLogGradeOrder) {
      out[g] = await SceneSolvedStore.solvedIndices(g);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return DqScene(
      child: SafeArea(
        child: FutureBuilder<Map<String, Set<int>>>(
          future: _solved,
          builder: (context, snap) {
            final solved = snap.data ?? const {};
            final cleared = <String>{
              for (final g in kCaseLogGradeOrder)
                if (kScenesByGrade[g] != null &&
                    isChapterCleared(kScenesByGrade[g]!, solved[g] ?? const {}))
                  g,
            };
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Semantics(
                        button: true,
                        label: 'もどる',
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: dqGold),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      Text('事件簿（じけんぼ）',
                          style: dqText(
                              size: 20, w: FontWeight.w900, color: dqGold)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      _bookmarkHeader(cleared),
                      const SizedBox(height: 14),
                      for (final g in kCaseLogGradeOrder)
                        if (kScenesByGrade[g] != null)
                          _chapterTile(
                            g,
                            kScenesByGrade[g]!,
                            solved[g] ?? const {},
                            cleared.contains(g),
                          ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _bookmarkHeader(Set<String> cleared) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dqBox,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: dqGold, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🔖 ことばの しおり',
              style: dqText(size: 13, w: FontWeight.w800, color: dqGold)),
          const SizedBox(height: 8),
          Text(
            assembledBookmarkLine(cleared),
            style: dqText(size: 15, w: FontWeight.w700, color: dqInk)
                .copyWith(height: 1.6),
          ),
          const SizedBox(height: 6),
          Text(
            cleared.isEmpty
                // Warm first-visit state — a bleak all-？ board would discourage;
                // frame the empty 事件簿 as an invitation to the first case.
                ? 'まだ、どの 事件（じけん）も かいけつ していない。\n'
                    'さいしょの 事件（じけん）から、やぶれた おはなしを あつめにいこう！'
                : '事件（じけん）を かいけつ するたび、やぶれた おはなしの 1ページが もどる。',
            style: dqText(size: 11, color: dqInk.withAlpha(180))
                .copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _chapterTile(
      String grade, SceneDef scene, Set<int> solvedIdx, bool cleared) {
    final npcCount =
        scene.hotspots.where((h) => h.kind == HotspotKind.npc).length;
    final solvedCount = scene.hotspots
        .asMap()
        .entries
        .where(
            (e) => e.value.kind == HotspotKind.npc && solvedIdx.contains(e.key))
        .length;
    // The lore the child has actually unlocked (solved NPCs only) — honest: an
    // unsolved ナゾ's fragment stays hidden.
    final unlocked = <String>[
      for (final e in scene.hotspots.asMap().entries)
        if (e.value.kind == HotspotKind.npc &&
            solvedIdx.contains(e.key) &&
            e.value.mysteryFragmentJa != null)
          e.value.mysteryFragmentJa!,
    ];
    final status = cleared
        ? '✓ かいけつ'
        : solvedCount > 0
            ? '$solvedCount / $npcCount'
            : 'みかいふう';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dqBox.withAlpha(cleared ? 235 : 150),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: cleared ? dqGold.withAlpha(150) : dqInk.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${gradeLabelJa(grade)}　${scene.titleJa}',
                  style: dqText(size: 14, w: FontWeight.w800, color: dqInk),
                ),
              ),
              Text(status,
                  style: dqText(
                      size: 12,
                      w: FontWeight.w700,
                      color: cleared ? dqGold : dqInk.withAlpha(160))),
            ],
          ),
          for (final frag in unlocked) ...[
            const SizedBox(height: 8),
            Text(frag,
                style: dqText(size: 12, color: dqInk.withAlpha(220))
                    .copyWith(height: 1.5)),
          ],
          // A SOLVED case can be re-read in full: show the 解決 finale (the
          // chapter's resolution lore) so the 事件簿 is a complete re-experience,
          // not just the per-solve drips (N12 replayability — pure display).
          if (cleared && scene.cleared != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: dqGold.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: dqGold.withAlpha(70)),
              ),
              child: Text(
                '🎉 ${scene.cleared!}',
                style: dqText(size: 11, color: dqInk.withAlpha(220))
                    .copyWith(height: 1.55),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

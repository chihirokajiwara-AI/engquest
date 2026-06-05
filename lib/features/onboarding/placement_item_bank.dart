// lib/features/onboarding/placement_item_bank.dart
//
// Verbatim port of the 35-item placement bank from
// docs/design/PLACEMENT-DIAGNOSTIC-PLAN.json § result.banks
//
// 7 grades × 5 items = 35 total (5 per θ rung 0..6).
// Every item has 4 SAME-LANGUAGE, same-type choices — no mixed-language options.
// (Guard against the 7,923-distractor bug class.)
//
// Helpers:
//   itemsForGrade(int g)          → all items for rung g
//   unusedItemForGrade(int g, Set<int> used) → pick first unused, or recycle

import 'placement_engine.dart';

// ---------------------------------------------------------------------------
// The bank (const — zero runtime allocation)
// ---------------------------------------------------------------------------

const List<PlacementItem> kPlacementBank = [
  // ── Rung 0 — 5級 (A1−) ────────────────────────────────────────────────────

  PlacementItem(
    grade: 0,
    skill: 'vocab',
    stemEn: 'Look! A big ___ is in the sky. '
        'It is yellow and bright in the day.',
    stemJa: '空に大きな◯◯がある。昼に黄色くてあかるいよ。',
    choices: ['sun', 'moon', 'star', 'cloud'],
    correctIndex: 0,
  ),
  PlacementItem(
    grade: 0,
    skill: 'grammar',
    stemEn: 'My brother and I ___ very happy today.',
    stemJa: 'ぼくと兄は今日とても◯◯です。',
    choices: ['are', 'am', 'is', 'be'],
    correctIndex: 0,
  ),
  PlacementItem(
    grade: 0,
    skill: 'vocab',
    stemEn: 'I open my book and ___ a story every night before I sleep.',
    stemJa: 'ねる前に毎ばん本をひらいてお話を◯◯する。',
    choices: ['read', 'eat', 'run', 'sing'],
    correctIndex: 0,
  ),
  PlacementItem(
    grade: 0,
    skill: 'grammar',
    stemEn: '"___ you swim?" "Yes, I can. I like the pool."',
    stemJa: '「あなたは泳げ◯◯か？」「うん、できるよ。プールがすきなんだ。」',
    choices: ['Can', 'Are', 'Do', 'Is'],
    correctIndex: 0,
  ),
  PlacementItem(
    grade: 0,
    skill: 'readingGist',
    stemEn: 'Girl: "Hi! How are you today?"  Boy: "___"',
    stemJa: '女の子「やあ！今日はげんき？」 男の子「◯◯」',
    choices: [
      "I'm fine, thank you.",
      "I'm twelve years old.",
      "It's a red bag.",
      'See you tomorrow!',
    ],
    correctIndex: 0,
  ),

  // ── Rung 1 — 4級 (A1) ─────────────────────────────────────────────────────

  PlacementItem(
    grade: 1,
    skill: 'grammar',
    stemEn: 'Yesterday I ___ to the park with my brother.',
    stemJa: 'きのう、わたしは おとうとと こうえんへ いきました。',
    choices: ['go', 'goes', 'went', 'going'],
    correctIndex: 2,
  ),
  PlacementItem(
    grade: 1,
    skill: 'grammar',
    stemEn: 'This book is ___ than that one.',
    stemJa: 'この ほんは あの ほんより おもしろい。',
    choices: [
      'interesting',
      'interestinger',
      'more interesting',
      'most interesting',
    ],
    correctIndex: 2,
  ),
  PlacementItem(
    grade: 1,
    skill: 'vocab',
    stemEn: 'It is raining, so please take your ___.',
    stemJa: 'あめが ふっているので、___ を もっていってね。',
    choices: ['umbrella', 'spoon', 'pencil', 'ticket'],
    correctIndex: 0,
  ),
  PlacementItem(
    grade: 1,
    skill: 'grammar',
    stemEn: 'A: Why were you absent yesterday?  B: ___ I was sick.',
    stemJa: 'A: きのう どうして やすんだの？  B: ___ びょうきだったんだ。',
    choices: ['Because', 'But', 'So', 'Or'],
    correctIndex: 0,
  ),
  PlacementItem(
    grade: 1,
    skill: 'readingGist',
    stemEn: 'Tom: Are you free this Saturday? '
        'Mary: Sorry, I can\'t. I\'m going to visit my grandmother. '
        'Tom: That\'s OK. How about Sunday? '
        'Mary: Sunday is fine!  '
        'Question: When will Tom and Mary meet?',
    stemJa: 'トム: 土曜日はひま？ '
        'メアリー: ごめん、むり。おばあちゃんの家に行くの。 '
        'トム: だいじょうぶ。日曜日はどう？ '
        'メアリー: 日曜日ならいいよ！  '
        'しつもん: トムとメアリーは いつ 会いますか？',
    choices: [
      'On Saturday',
      'On Sunday',
      "On her grandmother's birthday",
      'They will not meet',
    ],
    correctIndex: 1,
  ),

  // ── Rung 2 — 3級 (A1+) ────────────────────────────────────────────────────

  PlacementItem(
    grade: 2,
    skill: 'grammar',
    stemEn: 'I have never ___ sushi before.',
    stemJa: 'わたしは今までに一度もすしを食べたことがない。',
    choices: ['eaten', 'eat', 'ate', 'eating'],
    correctIndex: 0,
  ),
  PlacementItem(
    grade: 2,
    skill: 'grammar',
    stemEn: 'This temple ___ built about 400 years ago.',
    stemJa: 'このお寺は約400年前に建てられた。',
    choices: ['was', 'is', 'has', 'does'],
    correctIndex: 0,
  ),
  PlacementItem(
    grade: 2,
    skill: 'grammar',
    stemEn: 'The man ___ lives next door is a kind doctor.',
    stemJa: 'となりに住んでいる男の人は親切な医者です。',
    choices: ['who', 'which', 'what', 'whose'],
    correctIndex: 0,
  ),
  PlacementItem(
    grade: 2,
    skill: 'vocab',
    stemEn: 'It is raining hard outside. Don\'t forget to take your ___.',
    stemJa: '外は雨がはげしい。___を持っていくのを忘れないで。',
    choices: ['umbrella', 'dictionary', 'blanket', 'calendar'],
    correctIndex: 0,
  ),
  PlacementItem(
    grade: 2,
    skill: 'readingGist',
    stemEn: 'Tom: I want to join the basketball club, but practice is every '
        'morning at 6:30.\n'
        'Lisa: That\'s really early! Can you wake up that early every day?\n'
        'Tom: I\'m not sure. Maybe I\'ll try the art club instead.\n\n'
        'What is Tom\'s problem?',
    stemJa: 'トムの問題は何ですか。（会話を読んで主旨をつかむ）',
    choices: [
      "The basketball club's practice is too early in the morning.",
      'Tom does not like playing basketball at all.',
      'The art club is already full of members.',
      'Lisa wants Tom to join the art club with her.',
    ],
    correctIndex: 0,
  ),

  // ── Rung 3 — 準2級 (A2) ───────────────────────────────────────────────────

  PlacementItem(
    grade: 3,
    skill: 'grammar',
    stemEn: 'A: You look tired. B: Yes, I ___ on this report since this morning.',
    stemJa: 'A: つかれてるね。 B: うん、けさからずっとこのレポートに___んだ。',
    choices: [
      'have been working',
      'am working',
      'worked',
      'will work',
    ],
    correctIndex: 0,
  ),
  PlacementItem(
    grade: 3,
    skill: 'grammar',
    stemEn: '___ it was raining hard, we decided to go hiking anyway.',
    stemJa: '雨がはげしくふっていた___、わたしたちはそれでもハイキングに行くことにした。',
    choices: ['Although', 'Because', 'So', 'If'],
    correctIndex: 0,
  ),
  PlacementItem(
    grade: 3,
    skill: 'vocab',
    stemEn: 'Our flight was ___ because of the storm, so we waited three more hours.',
    stemJa: 'あらしのせいで、わたしたちのフライトは___され、あと3時間まった。',
    choices: ['delayed', 'arrived', 'boarded', 'canceled'],
    correctIndex: 0,
  ),
  PlacementItem(
    grade: 3,
    skill: 'readingGist',
    stemEn: 'Tom: I want to join the school band, but I can\'t read music. '
        'Lisa: Don\'t worry — the teacher gives free lessons after school on Fridays. '
        'You should go this week. '
        'Tom: ___',
    stemJa: 'Tom: バンドに入りたいけど、ぼくは楽ふが読めないんだ。 '
        'Lisa: 心配しないで。先生が金曜の放課後に無料レッスンをしてくれるよ。今週行ってみたら。 '
        'Tom: ___',
    choices: [
      "Good idea. I'll go this Friday.",
      "Sorry, I can't play any sports.",
      'Yes, I already know how to read music.',
      'No, the band practices on Mondays.',
    ],
    correctIndex: 0,
  ),
  PlacementItem(
    grade: 3,
    skill: 'readingGist',
    stemEn: 'Notice: The city library will close early at 5 p.m. this Saturday '
        'for cleaning. Books due that day can be returned on Monday with no '
        'late fee. The reading room reopens at the usual time on Sunday. '
        '— When can members return Saturday\'s books without a fee?',
    stemJa: 'おしらせ: 市立図書館は清掃のため今週の土曜は午後5時に早くしまります。'
        'その日にかえす本は、延滞料金なしで月曜にかえせます。'
        '閲覧室は日曜は通常どおりに開きます。'
        '— 土曜にかえす本は、料金なしでいつかえせますか。',
    choices: [
      'On Monday',
      'On Saturday before 5 p.m.',
      'On Sunday',
      'Anytime with a small fee',
    ],
    correctIndex: 0,
  ),

  // ── Rung 4 — 準2級プラス (A2+) ────────────────────────────────────────────

  PlacementItem(
    grade: 4,
    skill: 'grammar',
    stemEn: 'It ___ since early this morning, so the outdoor festival was '
        'finally called off.',
    stemJa: '今朝早くからずっと雨が降っているので、屋外のフェスティバルはついに中止になった。'
        '（called off = 中止）',
    choices: [
      'has been raining',
      'is raining',
      'rained',
      'was raining',
    ],
    correctIndex: 0,
  ),
  PlacementItem(
    grade: 4,
    skill: 'grammar',
    stemEn: 'If the city ___ more bicycle lanes next year, '
        'fewer people will drive to work.',
    stemJa: 'もし市が来年もっと自転車レーンを作れば、車で通勤する人は減るだろう。'
        '（lanes = レーン／車線）',
    choices: ['builds', 'will build', 'built', 'is building'],
    correctIndex: 0,
  ),
  PlacementItem(
    grade: 4,
    skill: 'grammar',
    stemEn: 'The volunteers worked hard all weekend ___ the heavy rain and the cold wind.',
    stemJa: 'ボランティアたちは、激しい雨と冷たい風にもかかわらず、'
        '週末ずっと一生けんめい働いた。（volunteers = ボランティア）',
    choices: ['despite', 'although', 'because of', 'instead of'],
    correctIndex: 0,
  ),
  PlacementItem(
    grade: 4,
    skill: 'readingGist',
    stemEn: 'NOTICE — Greenfield Library: Starting next month, the library will '
        'close two hours earlier on weekdays to save energy. Weekend hours will '
        'not change, and the study rooms can still be reserved online. '
        '___ What is the main point of this notice?',
    stemJa: 'お知らせ（図書館）：来月から、省エネのため平日は2時間早く閉館します。'
        '週末の時間は変わりません。自習室は引き続きオンラインで予約できます。'
        '——このお知らせの要点は？',
    choices: [
      'The library will reduce its weekday opening hours.',
      'The library will close permanently next month.',
      'The study rooms can no longer be reserved.',
      'Weekend hours will be made longer.',
    ],
    correctIndex: 0,
  ),
  PlacementItem(
    grade: 4,
    skill: 'readingGist',
    stemEn: 'A: I\'m thinking of joining the school\'s recycling club, but the '
        'meetings are after school on Fridays and I have piano then. '
        'B: ___ '
        'A: Good idea! I\'ll email the club leader tonight and ask. '
        'What is B most likely saying?',
    stemJa: 'A：学校のリサイクル部に入ろうと思うんだけど、集まりが金曜の放課後で、'
        'その時間はピアノがあるんだ。 '
        'B：____ '
        'A：いい考えだね！今夜部長にメールして聞いてみる。'
        '——Bが言ったと考えられるのは？',
    choices: [
      "Why don't you ask if you can come on a different day?",
      'Then you should quit playing the piano right away.',
      "I didn't know the recycling club already closed.",
      'You should not join any clubs while you are busy.',
    ],
    correctIndex: 0,
  ),

  // ── Rung 5 — 2級 (B1) ─────────────────────────────────────────────────────

  PlacementItem(
    grade: 5,
    skill: 'vocab',
    stemEn: 'The government finally decided to ___ the old law because many '
        'people thought it was unfair.',
    stemJa: '政府は、その古い法律を ___ することについに決めた。'
        '多くの人が不公平だと考えていたからだ。',
    choices: ['abolish', 'announce', 'admire', 'arrange'],
    correctIndex: 0,
  ),
  PlacementItem(
    grade: 5,
    skill: 'grammar',
    stemEn: 'If I ___ more free time, I would travel all around the world.',
    stemJa: 'もし、もっと自由な時間が ___ なら、世界中を旅行するのに。',
    choices: ['had', 'have', 'had had', 'will have'],
    correctIndex: 0,
  ),
  PlacementItem(
    grade: 5,
    skill: 'vocab',
    stemEn: 'It took her several weeks to ___ a decision about which '
        'university to attend.',
    stemJa: 'どの大学に通うかについて ___ のに、彼女は数週間かかった。',
    choices: ['make', 'take', 'do', 'get'],
    correctIndex: 0,
  ),
  PlacementItem(
    grade: 5,
    skill: 'grammar',
    stemEn: '___ finished all his homework, Ken went outside to play '
        'with his friends.',
    stemJa: '宿題を全部 ___、ケンは友だちと遊びに外へ出た。',
    choices: ['Having', 'Have', 'Had', 'Having had'],
    correctIndex: 0,
  ),
  PlacementItem(
    grade: 5,
    skill: 'readingGist',
    stemEn: "A: I'm really thinking about studying abroad next year, but the "
        "tuition is so expensive that I'm not sure I can afford it. B: ___",
    stemJa: 'A: 来年、留学を本気で考えているんだけど、学費がとても高くて、払えるか自信がないんだ。 '
        'B: ___（会話が自然につながる返事は？）',
    choices: [
      'Have you looked into scholarships? '
          'Some of them can cover most of the tuition.',
      'Yes, I went abroad with my family last summer and had a great time.',
      'You should buy a cheaper textbook for your English class then.',
      "I don't really like studying, so I usually just play games after school.",
    ],
    correctIndex: 0,
  ),

  // ── Rung 6 — 準1級 (B2) ───────────────────────────────────────────────────

  PlacementItem(
    grade: 6,
    skill: 'vocab',
    stemEn: 'Without regular maintenance, the old bridge will gradually ___ '
        'until it is no longer safe to cross.',
    stemJa: 'ていきてきな てんけんが ないと、その ふるい はしは だんだん ___ し、'
        'わたれなく なってしまう。',
    choices: ['deteriorate', 'accumulate', 'negotiate', 'illuminate'],
    correctIndex: 0,
  ),
  PlacementItem(
    grade: 6,
    skill: 'vocab',
    stemEn: 'She was ___ to lend him the money at first, but she finally '
        'agreed after he promised to pay it all back.',
    stemJa: 'かのじょは はじめ お金（かね）を かすのを ___ だったが、'
        'かれが ぜんぶ かえすと やくそく したので、ついに しょうちした。',
    choices: ['reluctant', 'eager', 'grateful', 'curious'],
    correctIndex: 0,
  ),
  PlacementItem(
    grade: 6,
    skill: 'grammar',
    stemEn: 'Not only ___ the entrance exam, but he also won a full '
        'scholarship to the university.',
    stemJa: 'かれは にゅうがく しけんに ___ だけでなく、'
        'だいがくの ぜんがく しょうがくきんも かくとくした。',
    choices: [
      'did he pass',
      'he passed',
      'he did pass',
      'passed he',
    ],
    correctIndex: 0,
  ),
  PlacementItem(
    grade: 6,
    skill: 'grammar',
    stemEn: 'If she had caught the earlier train this morning, '
        'she ___ in the office with us right now.',
    stemJa: 'もし けさ はやい でんしゃに のっていたら、かのじょは いま ___ '
        'わたしたちと オフィスに いるはずだ。',
    choices: [
      'would be',
      'would have been',
      'will be',
      'had been',
    ],
    correctIndex: 0,
  ),
  PlacementItem(
    grade: 6,
    skill: 'readingGist',
    stemEn: 'Read the passage, then answer.\n\n'
        '"Many cities have introduced bike-sharing programs, hoping to ease '
        'traffic and cut pollution. Yet researchers note that most users were '
        'already cyclists or walkers; few have actually given up their cars. '
        'The schemes may be popular, but their environmental payoff has so far '
        'been modest."\n\n'
        "What is the writer's main point?",
    stemJa: 'ぶんしょうを よんで、こたえよう。（じてんしゃシェアの こうかについての ぶんしょう）\n\n'
        'この ひっしゃが いちばん いいたい ことは？',
    choices: [
      'Bike-sharing programs have done less for the environment than hoped.',
      'Bike-sharing programs have successfully removed many cars from the roads.',
      'Cities should stop funding bike-sharing because nobody uses it.',
      'Cyclists and walkers dislike using bike-sharing programs.',
    ],
    correctIndex: 0,
  ),
];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Returns all items for the given rung [g] (0..6).
List<PlacementItem> itemsForGrade(int g) =>
    kPlacementBank.where((item) => item.grade == g).toList();

/// Returns an item for grade [g] that is not in [used] (identified by bank
/// index).  Falls back to the first item at [g] if all are exhausted (e.g.
/// if a session is longer than the bank depth — avoids a null crash at the
/// cost of item reuse).
PlacementItem unusedItemForGrade(int g, Set<int> used) {
  PlacementItem? fallback;
  for (var i = 0; i < kPlacementBank.length; i++) {
    final item = kPlacementBank[i];
    if (item.grade != g) continue;
    fallback ??= item; // keep first match as fallback
    if (!used.contains(i)) {
      return item; // first unused at this grade
    }
  }
  // All items at this grade are used — return the fallback (recycle).
  return fallback ??
      kPlacementBank.firstWhere(
        (item) => item.grade == g,
        orElse: () => kPlacementBank.first,
      );
}

/// Returns the bank index of [item].  Used to register it in [usedItemIds].
int bankIndexOf(PlacementItem item) => kPlacementBank.indexOf(item);

# A-KEN Quest — 語彙例文精査 + 音声再生成 指示書

**From:** charsiu-ai-claude (司令塔)
**To:** hermes-engquest (@hermes_engquest_bot)
**Date:** 2026-06-02 12:35 JST
**Priority:** IMMEDIATE — この作業完了後に音声再生成が控えている

---

## 背景と経緯

### 本日の作業結果
1. **13エージェント**を4フェーズで展開し、A-KEN Questを大規模改善
2. 語彙を大幅拡充: 2級 800→2000語、準1級 3000→3475語
3. **Kokoro TTS v0.9.4**（Mac Mini ローカル、¥0）で全9,575語の音声を生成
4. TtsServiceにバンドルアセット読込パス追加（CRITICAL修正済み）
5. BattleScreenにスピーカーアイコン+自動再生を接続（CRITICAL修正済み）

### 発見された問題
CEO が生成された音声を確認した結果:
- **例文の品質が不均一** — 特に3級・準1級で不自然な例文が多数
- 例: "The apartment was very useful."（3級）
- 例: "It is important to authenticate in this context."（準1級）
- **英語定義フィールドが存在しない** — 上位級の音声に定義を含めたいが、JSONに `definition` フィールドがない

### CEO決定事項（音声フォーマット）
**上位級（準2級・2級・準1級）— 7セグメント:**
1. {word}（ゆっくり speed=0.7）
2. [0.5秒の無音]
3. {word}（普通 speed=1.0）
4. [0.5秒の無音]
5. "{word} means {英語定義}."（普通 speed=1.0）
6. [0.5秒の無音]
7. "{wordを使った分かりやすく短い例文}"（普通 speed=1.0）

**下位級（5級・4級・3級）— 5セグメント:**
1. {word}（ゆっくり speed=0.7）
2. [0.5秒の無音]
3. {word}（普通 speed=1.0）
4. [0.5秒の無音]
5. "{wordを使った分かりやすく短い例文}"（普通 speed=1.0）

---

## タスク1: 語彙JSON例文精査・修正

### 対象ファイル
```
assets/data/eiken5_vocab.json    — 600語 (例文2個/語, 品質: まあまあ)
assets/data/eiken4_vocab.json    — 700語 (例文2個/語, 品質: まあまあ)
assets/data/eiken3_vocab.json    — 1,300語 (例文1個/語, 品質: 低い)
assets/data/eiken_pre2_vocab.json — 1,500語 (例文2個/語, 品質: 中)
assets/data/eiken2_vocab.json    — 2,000語 (例文1-2個/語, 品質: 中)
assets/data/eiken_pre1_vocab.json — 3,475語 (例文1-2個/語, 品質: 低い)
```

### JSONスキーマ（変更禁止のフィールド）
```json
{
  "id": "eiken5_001",          // 変更禁止
  "word": "cat",               // 変更禁止
  "reading": "キャット",        // 変更禁止
  "jpTranslation": "ねこ",     // 精査対象
  "cefrLevel": "A1",           // 変更禁止
  "eikenLevel": "5",           // 変更禁止
  "category": "Animals",       // 変更禁止
  "pos": ["noun"],             // 変更禁止
  "exampleSentences": [        // ★精査・修正対象★
    "I have a cat.",
    "The cat is sleeping."
  ],
  "distractors": ["いぬ","さかな","とり"],  // 変更禁止
  "audioUrl": "",              // 変更禁止（音声再生成後に更新）
  "imageUrl": "",              // 変更禁止
  "fsrsState": "new",         // 変更禁止
  "tags": []                   // 変更禁止
}
```

### 追加フィールド（上位級のみ）
**準2級・2級・準1級**に以下のフィールドを追加:
```json
{
  "englishDefinition": "the supreme authority of a state to govern itself"
}
```
- 簡潔で正確な英語定義（1文、大文字なし、ピリオドなし）
- 辞書的な定義ではなく、学習者が理解しやすい平易な英語で
- 音声で "sovereignty means the supreme authority of a state to govern itself." と読み上げるために使用

### 例文の品質基準

#### 全級共通
- **その単語を必ず含む**こと
- **自然な英語**であること（テンプレ感のある文は不可）
- **短い**こと（10-15語以内が理想、最大20語）
- **文法的に正確**であること
- **各語に例文2個**必須（1個しかない語は2個に増やす）

#### 級別の難易度調整
| 級 | CEFR | 例文の特徴 | 良い例 | 悪い例 |
|----|------|-----------|--------|--------|
| 5級 | A1 | 最もシンプル、主語+動詞+目的語、日常場面 | "I have a cat." | "The cat exhibits feline behavior." |
| 4級 | A2 | 少し長い、時制のバリエーション | "She wakes up early on school days." | "The waking process involves..." |
| 3級 | A2-B1 | 複文OK、学校・旅行・趣味の場面 | "We went to the beach during summer vacation." | "The vacation was very useful." |
| 準2級 | B1 | 抽象概念OK、社会的話題 | "This discovery is significant for science." | "An objective view is important." |
| 2級 | B1-B2 | 学術的・ビジネス場面、接続詞使用 | "The convenience of online shopping changed how we buy things." | "Convenience is convenient." |
| 準1級 | B2-C1 | 専門的・学術的、複雑な構文OK | "The government decided to authenticate all digital identities." | "It is important to authenticate in this context." |

#### 絶対禁止パターン
- "X was very useful." — 何にでも使えるテンプレ
- "X is important." — 具体性ゼロ
- "It is important to X in this context." — テンプレ
- "She packed her X before the trip." — 意味不明な組み合わせ
- 単語の意味と例文が矛盾するもの

### 実行手順

1. **各JSONファイルを読み込む**
2. **全語の `exampleSentences` を精査**:
   - テンプレ・不自然な例文を検出
   - 級レベルに合った自然な例文に書き換え
   - 1個しかない場合は2個に増やす
3. **上位級に `englishDefinition` フィールドを追加**（準2級・2級・準1級）
4. **jpTranslation の精査**（明らかな誤訳がないか）
5. **保存時にJSON構造を壊さない**（`totalWords`, `version` 等のヘッダーも保持）
6. **検証**:
   ```bash
   flutter analyze --fatal-infos --fatal-warnings  # 0件
   flutter test                                      # 全テスト通過
   ```
7. **コミット**: 級ごとに分けてコミット
   ```
   fix(content): polish eiken5 example sentences (600 words)
   fix(content): polish eiken4 example sentences (700 words)
   ...
   ```

### 並列実行の推奨
- 6級分あるので、複数エージェントで並列実行可能
- ただし **同じファイルを同時に編集しない**こと
- worktree分離推奨

---

## タスク2: 音声再生成（タスク1完了後）

### 前提
タスク1で例文精査 + englishDefinition追加が完了していること。

### 音声生成スクリプト
`scripts/generate_kokoro_audio.py` を改修する必要あり。

現在のスクリプト:
```python
text = f"{word}. {word}."  # 単純な2回繰り返し
```

改修後（上位級）:
```python
# 3セグメント分離生成 + 0.5秒silenceで結合
seg1 = pipeline(word, speed=0.7)       # ゆっくり
seg2 = pipeline(word, speed=1.0)       # 普通
seg3 = pipeline(f"{word} means {definition}.", speed=1.0)  # 定義
seg4 = pipeline(example_sentence, speed=1.0)  # 例文
combined = concat([seg1, silence, seg2, silence, seg3, silence, seg4])
```

改修後（下位級）:
```python
seg1 = pipeline(word, speed=0.7)       # ゆっくり
seg2 = pipeline(word, speed=1.0)       # 普通
seg3 = pipeline(example_sentence, speed=1.0)  # 例文
combined = concat([seg1, silence, seg2, silence, seg3])
```

### Kokoro TTS環境
```
Python venv: ~/.venvs/kokoro/
Kokoro version: 0.9.4
Voice: af_heart (American English female)
Sample rate: 24000 Hz
Output: MP3 (ffmpeg libmp3lame)
```

### テスト済みパラメータ（CEOサンプル承認済み）
- speed=0.7 → ゆっくり発音（CEOOKOKOK済み）
- speed=1.0 → 普通速度
- silence = numpy.zeros(12000) → 0.5秒 at 24kHz
- 出力: WAV → ffmpeg → MP3

### 出力先
```
assets/audio/eiken5/      → 600ファイル
assets/audio/eiken4/      → 700ファイル
assets/audio/eiken3/      → 1,300ファイル
assets/audio/eiken_pre2/  → 1,500ファイル
assets/audio/eiken2/      → 2,000ファイル
assets/audio/eiken_pre1/  → 3,475ファイル
```

ファイル名: `{vocab_id}_{sanitized_word}.mp3`
例: `eiken_pre1_3001_sovereignty.mp3`

### 既存音声の扱い
- **全削除して再生成**（既存の音声は旧フォーマット "word. word." のため）
- 再生成前に `rm assets/audio/{grade}/*.mp3` で旧ファイル削除
- `.gitkeep` は残すこと

### 並列実行
- 最大6プロセス並列（各級1プロセス）で実行可能
- Mac Mini RAM 24GB → 6並列でも問題なし（各プロセス ~1GB）
- 所要時間: 約60-90分（全9,575語）

### 注意事項
- `flutter test` 実行時にKokoroプロセスが同時に動いていると、WAV→MP3変換の一瞬でFlutterが存在しないWAVを参照してクラッシュする可能性あり（本日発生済み・再実行で解消）
- pubspec.yaml に全音声ディレクトリが宣言済み（変更不要）

---

## タスク3: TtsService の連携確認

### 既に完了済み（変更不要）
- `lib/core/audio/tts_service.dart`:
  - `_loadBundledAsset()` — バンドルMP3を `rootBundle.load()` で読込
  - `_gradeFromVocabId()` — vocabIdからgrade directoryを特定
  - `_sanitizeWord()` — ファイル名マッチング（generate_kokoro_audio.pyと同一ロジック）
  - 優先順位: メモリキャッシュ → バンドルアセット → Google TTS API → unavailable

- `lib/features/battle/battle_screen.dart`:
  - WordAudioPlayerService統合済み
  - カード表面にスピーカーアイコン（タップで再生）
  - カードめくり時に自動再生（WordAudioAutoPlay.trigger）
  - セッション開始時に先読み20語（prefetchSession）

---

## 品質基準（全作業共通）
```bash
flutter analyze --fatal-infos --fatal-warnings  # 0件必須
flutter test                                      # 全451テスト通過必須
```

CEFRラベル: A1/A2/B1/B2/C1/C2（大文字、標準値のみ）

---

## ファイルマップ
```
assets/data/
  eiken5_vocab.json      — 5級語彙 (600語)
  eiken4_vocab.json      — 4級語彙 (700語)
  eiken3_vocab.json      — 3級語彙 (1,300語)
  eiken_pre2_vocab.json  — 準2級語彙 (1,500語)
  eiken2_vocab.json      — 2級語彙 (2,000語)
  eiken_pre1_vocab.json  — 準1級語彙 (3,475語)

assets/audio/
  eiken5/                — 5級音声 (現在600 MP3, 旧フォーマット)
  eiken4/                — 4級音声 (現在700 MP3, 旧フォーマット)
  eiken3/                — 3級音声 (現在1,300 MP3, 旧フォーマット)
  eiken_pre2/            — 準2級音声 (現在1,500 MP3, 旧フォーマット)
  eiken2/                — 2級音声 (現在2,000 MP3, 旧フォーマット)
  eiken_pre1/            — 準1級音声 (現在3,475 MP3, 旧フォーマット)

scripts/
  generate_kokoro_audio.py — 音声生成スクリプト (要改修)

lib/core/audio/
  tts_service.dart              — TTS取得サービス (修正済み)
  word_audio_player_service.dart — 音声再生サービス (修正済み)

lib/features/battle/
  battle_screen.dart            — フラッシュカードUI (音声接続済み)

docs/
  HANDOFF-2026-06-02.md         — 全体引き継ぎドキュメント
  CONTENT_QUALITY_AUDIT.md      — E2コンテンツ品質監査レポート
```

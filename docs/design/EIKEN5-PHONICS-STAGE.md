# 英検5級 舞台 — 『言葉を失った村』(The Village of Lost Words)

CEO vision (2026-06-04): the 英検5級 **舞台 (stage)** teaches from ZERO. Villagers lost language down to single sounds ("a","b") = phonics; the hero helps each villager regain words; the story IS the from-zero learning. Audio-central. Built ONLY from phonics + 英検5級's short words. Replaces the current grammar-quiz town_eiken5 (which tests without teaching — wrong for a true beginner).

## Story frame
- 『言葉を失った村』= once **〈ソネア / Sonea, Kingdom of the First Voice〉**, where language was born; 魔王サイレント struck the source first, so silence floods outward. Villagers are survivors (not babies) holding one phoneme each. The hero is **Sonea's heir** (ties to the castle/prince hints already in the data). Mystery: did the 魔王 silence them, or did they stop speaking out of fear?
- **Recovering a word = a villager comes back to life.** The child resurrects people through sound.

## Learning spine (teach → hear → imitate → gentle recognise → produce; NEVER scold)
- **Phase A — Phonics** (Jolly Phonics SATPIN order): s, a, t, i, p, n, then group 2/3 as needed (c,e,h,r,m,d,g,o,u,b,f,x). Each: show letter → auto-play pure phoneme audio → 🔊 replay/imitate → 2-option "which says /s/?" (each option a speaker button).
- **Phase B — Blend CVC** (ONLY on-英検5級-syllabus words; verified in eiken5_vocab.json): cat, dog, sun, box, bag, bed, big, bad, pen, man, hat, top, hot, bus, run, red, fox, leg, lip, can, map. Segmented audio "c…a…t……cat" + picture-match. (Nonsense SATPIN words like "sat" used only as Sura's blending-practice, never as vocab.)
- **Phase C — short 5級 words + 2-3-word phrases**: red → "a red cat" → "I see a dog" → greetings "Hello!/I'm fine". Then **hands off** to the existing 20-encounter grammar arc (now fair, because the child can read the options).

## First 12 steps (authored — see agent transcript for full text)
1 /s/ 灰守セル · 2 /a/ アン · 3 /t/ タオ · 4 blend-mechanic s-a-t (Sura) · 5 /c/ コル · 6 **cat** (ミィ, first real word) · 7 /o/ オド · 8 /g/ グレン · 9 **dog** (ロブ) · 10 **sun** (ノナ, color returns) · 11 **red** + "a red cat" (ベラ) · 12 **Hello!** (Sura's first sentence → hands into existing arc).

## App structure (engineering spec)
Current `QuestEncounter{npcName,npcEmoji,npcLine,npcLineJa,choices,correctIndex,onCorrect}` is a silent 4-choice quiz that flashes red on wrong — cannot do Phase A/B. Add a typed step model:
- `enum QuestStepKind { teachSound, blendWord, teachWord, phrase, quiz }`
- `QuestStep{ kind, npcName, npcEmoji, villagerLostLine?, teachJa, autoPlayAudio?, practicePromptJa, pictureAsset?, List<QuestOption> options, onCorrect, bool penalizeWrong }`; `QuestOption{label, audioAsset?, isCorrect}`. Keep `QuestEncounter` as the `quiz` kind so the other towns aren't rewritten.
- New widgets in dq_ui: `PhonicsLetterCard` (giant glyph + auto-play + 🔊 replay), `BlendWordCard` (c·a·t tiles highlight with segmented audio, then picture+word-tiles), `AudioOptionButton` (a `DqChoice` that plays its `audioAsset` on tap). 
- **No-scold:** for kinds != quiz (penalizeWrong=false), a wrong tap replays audio + keeps the card active, NO red/`DqChoiceState.wrong`. Gate the existing red branch (quest_screen.dart ~line 165) behind `_enc.penalizeWrong`.
- Audio: reuse `WordAudioPlayerService`/`SoundService`; add `AudioCueService.play(assetKey)` sourcing `assets/audio/phonics/`.

## Audio clips to generate (scripts/generate_kokoro_audio.py extended; register assets/audio/phonics/ in pubspec)
- **Phonemes (pure sounds, NOT letter-names):** phoneme_{s,a,t,i,p,n,c,e,h,r,m,d,g,o,u,b,f,x}.mp3 — add a PHONEME_TEXT map (TTS says "ess" by default; author "sss"/"aah" exemplars or hand-curate).
- **Blends (segmented+whole):** blend_{cat,dog,sun,box,bag,bed,big,bad,pen,man,hat,top,hot,bus,run,red,fox,sat}.mp3 — reuse the existing multi-segment/silence format.
- **Phrases:** phrase_{a_red_cat,i_see_a_dog,hello,im_fine,thank_you}.mp3. Single 5級 words (word_red.mp3 etc.) already exist in assets/audio/eiken5/.

## Definition of Done
A zero-English child completes steps 1–12 by listening+imitating alone: every step auto-plays audio + every option is a tappable speaker (no reading prerequisite); teach always precedes test; step N+1 adds exactly one new sound (all else review); wrong answers never scolded; every regained WORD is on the 600-word 5級 syllabus; all ~40 clips exist + auto-play; step 12 hands into the existing arc.

Sources (June 2026): Jolly Phonics SATPIN (creativemindsacademy.in), Synthetic phonics (Wikipedia), Five from Five SSP, 英検公式 2024renewal, J-Research/RareJob 5級語彙. Full design + citations in workflow agent transcript a163665f4759232bb.

---

## ★ HARDENED (4-expert panel cross-verified, 2026-06-04 — supersedes the draft above where they conflict). Full hardened spec: workflow wrf7am2gb output / synthesize agent.

The panel (phonics-EFL / 英検-examiner / child-UX / engineer-audio) found the draft ships on FALSE PREMISES. Resolutions (all GATE the build):

- **C2 PHONEME AUDIO (the load-bearing failure): TTS CANNOT make pure phonemes.** For stop consonants (p/t/c/d/g/b — half the first 12) TTS appends a schwa → "tuh","kuh", which TEACHES the thing that BREAKS blending (/kuh/-/a/-/tuh/ can't blend "cat"). FIX: **espeak-ng** (verified installed; Kokoro is NOT) generates DRAFT isolated phonemes via `[[…]]`, then a **phonics-literate human EAR-verifies all ~18** (continuants sustained, stops clipped, no schwa, no letter-name); any failing clip is **hand-recorded** (~30-min session). DoD = LISTENING-verified, not existence-verified. Blends/words still use Kokoro/existing pipeline.
- **C3 WEB AUTOPLAY blocked without a user gesture** (and preview quest5 bypasses the start-tap → NotAllowedError). FIX: never fire audio from initState/build; fire from tap handlers (_start/_next/_choose); EVERY step shows a large always-visible 🔊 button (the real contract; autoplay is best-effort).
- **C1 PHONICS-DEPTH vs 英検5級-COVERAGE → LAYER, don't choose.** Listening = 50% of 5級 score (425/850). Keep phonics phases narrow/deep BUT: the existing 20 grammar encounters are NOT demoted — they become first-class **Phase C**; add thin **Phase L (listening)** beats across all phases (大問1応答型 + 大問3イラスト型); vocab breadth (the other ~580 words) is DELEGATED to Word-Battle/FSRS. The stage owns decoding skill + ~20 anchor words, not the whole curriculum.
- **C4 MODEL: adopt the sealed `QuestStep` hierarchy + kind-dispatch in quest_screen + migrate `quest_data_test.dart`** (which currently iterates `.npcLine/.choices` and breaks under a union type). **DROP picture-match** — no per-word art exists and a non-reader can't match audio→text-tiles; Phase B meaning is carried by AUDIO + the villager-revival animation. Remove `pictureAsset`.
- **EFL fixes:** katakana-contaminated real words (cat=キャット, dog, sun, bus) are HARDER → come AFTER nonsense-CVC blends (sat/pin/pan), reversing the draft's "cat = first real word." Handle Japanese L1 interference explicitly: anti-epenthesis (clip stops, never model trailing /u/), minimal-pair distractors (short-/a/ vs カタカナ「ア」; later /r/-/l/). The 4 story words peach/castle/traveller/picture are OFF-syllabus — replace with on-5級 words.
- **Honesty fix:** no ASR is CORRECT (child ASR WER ~0.64; would punish/mislead) — but the measurable outcome is **receptive discrimination + blend recognition**, NOT production (the app is deaf). Don't claim "produces."

BUILD ORDER (gated): 1) audio infra (espeak-ng phoneme gen + human ear-QA + 🔊-button autoplay-safe playback) → 2) sealed QuestStep model + test migration → 3) phonics/blend cards (no pictures) → 4) author re-sequenced steps (nonsense-before-real, on-syllabus) → 5) in-app screenshot+LISTEN verification.

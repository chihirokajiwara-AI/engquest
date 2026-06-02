/// Content filter for child-safe NPC dialog input and output.
///
/// Enforced before sending user input to the Claude API and after receiving
/// the model's response, ensuring age-appropriate content for users aged 4-18.
class ContentFilter {
  // ── Block lists ────────────────────────────────────────────────────────────

  /// Common English profanity and offensive terms (lowercase).
  static const List<String> _englishProfanity = [
    'fuck',
    'shit',
    'ass',
    'bitch',
    'bastard',
    'cunt',
    'dick',
    'cock',
    'pussy',
    'whore',
    'slut',
    'damn',
    'hell',
    'crap',
    'piss',
    'fag',
    'nigger',
    'nigga',
    'retard',
    'idiot',
    'stupid',
    'kill',
    'rape',
    'murder',
    'suicide',
    'bomb',
    'gun',
    'shoot',
    'stab',
    'sex',
    'porn',
    'naked',
    'nude',
    'breast',
    'penis',
    'vagina',
    'condom',
    'drug',
    'weed',
    'cocaine',
    'heroin',
    'meth',
  ];

  /// Common Japanese profanity and offensive terms.
  static const List<String> _japaneseProfanity = [
    'くそ',
    'ばか',
    'うんこ',
    'ちんこ',
    'まんこ',
    'きもい',
    'しね',
    'ころす',
    'きる',
    'ころせ',
    'うせろ',
    'きえろ',
    'でていけ',
    'アホ',
    'バカ',
    'クソ',
    '死ね',
    '殺す',
    '殺せ',
    'キモい',
    'うざい',
    'ウザい',
    'ゴミ',
    'クズ',
    'ハゲ',
    'ブス',
    'デブ',
  ];

  /// Violence-toward-others keywords (English, lowercase). Self-harm / suicidal
  /// signals are handled SEPARATELY by [isCrisisSignal] → [crisisMessage], so a
  /// child in distress is offered support, never rejected as if they swore.
  static const List<String> _violentKeywords = [
    'blow up',
    'explode',
    'terrorist',
    'weapon',
  ];

  /// High-confidence self-harm / suicidal-ideation signals (English + Japanese).
  /// These route to [crisisMessage], NOT to the profanity rejection.
  static const List<String> _selfHarmSignals = [
    // English
    'kill myself', 'killing myself', 'want to die', 'wanna die', 'suicide',
    'suicidal', 'self-harm', 'selfharm', 'self harm', 'hurt myself',
    'cut myself', 'cutting myself', 'end my life', 'end it all',
    'hang myself', 'hate myself', 'no reason to live', "don't want to live",
    // Japanese
    'しにたい', '死にたい', '自殺', 'きえたい', '消えたい', 'いなくなりたい',
    'リストカット', 'リスカ', '自傷', '生きたくない', '死のう',
  ];

  /// Sexual content keywords (English, lowercase).
  static const List<String> _sexualKeywords = [
    'hentai',
    'sexy',
    'seduce',
    'orgasm',
    'masturbat',
    'erotic',
    'pornography',
    'obscene',
    'xxx',
  ];

  // ── Patterns ───────────────────────────────────────────────────────────────

  /// Matches common phone number formats (JP and international).
  static final RegExp _phonePattern = RegExp(
    r'(\+?[\d\-\(\)\s]{7,})',
  );

  /// Matches email addresses.
  static final RegExp _emailPattern = RegExp(
    r'[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}',
  );

  /// Matches Japanese postal codes (〒xxx-xxxx or 7 digits).
  static final RegExp _postalCodePattern = RegExp(
    r'〒?\d{3}[-－]\d{4}',
  );

  // (No regex for Unicode character classes — use the helper below instead.)

  // ── Max length ─────────────────────────────────────────────────────────────

  /// Maximum allowed input length in characters.
  static const int maxLength = 200;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns `true` if [input] is safe for a child to send.
  ///
  /// Checks:
  /// 1. Non-empty after trimming whitespace
  /// 2. Does not exceed [maxLength]
  /// 3. Contains at least one allowed character (Latin/Japanese/digit)
  /// 4. No profanity (English or Japanese)
  /// 5. No personal information patterns
  /// 6. No violent/sexual keywords
  static bool isSafe(String input) {
    return sanitize(input) != null;
  }

  /// Returns a sanitized (trimmed) version of [input], or `null` if the
  /// input is completely unsafe and should be rejected entirely.
  static String? sanitize(String input) {
    final trimmed = input.trim();

    // 1. Reject empty / whitespace-only
    if (trimmed.isEmpty) return null;

    // 2. Reject over-length
    if (trimmed.length > maxLength) return null;

    // 3. Reject if input contains NO allowed characters
    if (!_hasAllowedChar(trimmed)) return null;

    final lower = trimmed.toLowerCase();

    // 4. Profanity check (English)
    for (final word in _englishProfanity) {
      if (lower.contains(word)) return null;
    }

    // 5. Profanity check (Japanese)
    for (final word in _japaneseProfanity) {
      if (trimmed.contains(word)) return null;
    }

    // 6. Personal information patterns
    if (_phonePattern.hasMatch(trimmed)) return null;
    if (_emailPattern.hasMatch(trimmed)) return null;
    if (_postalCodePattern.hasMatch(trimmed)) return null;

    // 7. Violent / self-harm keywords
    for (final kw in _violentKeywords) {
      if (lower.contains(kw)) return null;
    }

    // 8. Sexual keywords
    for (final kw in _sexualKeywords) {
      if (lower.contains(kw)) return null;
    }

    return trimmed;
  }

  /// Returns a child-friendly rejection message in Japanese (hiragana).
  static String rejectionMessage() {
    return 'その言葉は使えないよ。べつの言い方をしてみてね！';
  }

  /// True if [input] contains a self-harm / suicidal-ideation signal. Checked
  /// BEFORE the profanity gate so a child in crisis is supported, not scolded.
  static bool isCrisisSignal(String input) {
    final lower = input.toLowerCase();
    for (final s in _selfHarmSignals) {
      if (lower.contains(s)) return true;
    }
    return false;
  }

  /// Supportive response shown when [isCrisisSignal] is true. Never scolds and
  /// never calls the AI. Points to verified Japanese crisis lines (厚生労働省
  /// 「まもろうよ こころ」, numbers confirmed 2026-06-02).
  ///
  /// DRAFT — wording pending CEO / child-mental-health professional sign-off.
  /// Deliberately does NOT auto-notify a parent (a parent may be the stressor).
  static String crisisMessage() {
    return 'はなしてくれてありがとう。あなたのことが心配です。\n'
        'つらいときは、ひとりでがまんしないで、信頼できる大人や、'
        'つぎのまどぐちに話してみてください。\n\n'
        '・チャイルドライン　0120-99-7777（毎日 16〜21時）\n'
        '・#いのちSOS　0120-061-338（24時間）\n'
        '・よりそいホットライン　0120-279-338（24時間）\n\n'
        'あなたは大切な存在です。';
  }

  /// Checks whether [response] from the AI contains any blocked keywords.
  ///
  /// Used to post-filter Claude's output. Returns a safe fallback message
  /// if the response is flagged, otherwise returns [response] unchanged.
  static String filterResponse(String response) {
    final lower = response.toLowerCase();

    for (final word in _englishProfanity) {
      if (lower.contains(word)) return _safeFallback();
    }
    for (final word in _japaneseProfanity) {
      if (response.contains(word)) return _safeFallback();
    }
    for (final kw in _violentKeywords) {
      if (lower.contains(kw)) return _safeFallback();
    }
    for (final kw in _sexualKeywords) {
      if (lower.contains(kw)) return _safeFallback();
    }

    return response;
  }

  static String _safeFallback() {
    return 'Let us talk about something fun! What do you like to do?';
  }

  /// Returns true if [text] contains at least one Latin letter, digit, or
  /// Japanese character (hiragana, katakana, CJK unified ideograph).
  ///
  /// This rejects input composed entirely of unsupported scripts (e.g. Arabic,
  /// Cyrillic) that fall outside the app's English/Japanese scope.
  static bool _hasAllowedChar(String text) {
    for (final rune in text.runes) {
      // ASCII letters and digits (a-z, A-Z, 0-9)
      if ((rune >= 0x0041 && rune <= 0x005A) ||
          (rune >= 0x0061 && rune <= 0x007A) ||
          (rune >= 0x0030 && rune <= 0x0039)) {
        return true;
      }
      // Hiragana (ぁ–ん): U+3041–U+3096
      if (rune >= 0x3041 && rune <= 0x3096) return true;
      // Katakana (ァ–ン): U+30A1–U+30F6
      if (rune >= 0x30A1 && rune <= 0x30F6) return true;
      // Halfwidth katakana: U+FF66–U+FF9F
      if (rune >= 0xFF66 && rune <= 0xFF9F) return true;
      // CJK Unified Ideographs: U+4E00–U+9FFF
      if (rune >= 0x4E00 && rune <= 0x9FFF) return true;
      // CJK Extension A: U+3400–U+4DBF
      if (rune >= 0x3400 && rune <= 0x4DBF) return true;
    }
    return false;
  }
}

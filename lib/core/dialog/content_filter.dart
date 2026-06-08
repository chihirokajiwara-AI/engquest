/// Content filter for the AI NPC dialog.
///
/// PRODUCT DECISION (CEO, 2026-06-08): the app does NOT react to individual
/// words a child types. Profanity or self-harm phrasing in the child's INPUT is
/// neither scolded nor blocked — learning interactions are judged only correct
/// vs incorrect. So this filter no longer word-polices input; [sanitize] only
/// (a) caps length and (b) keeps a child's personal info (phone/email/postal)
/// from being transmitted to the external AI (privacy / COPPA — a data concern,
/// not word-policing).
///
/// The block lists below are retained for ONE purpose only: [filterResponse]
/// post-filters the MODEL'S OUTPUT so the AI never shows a child something
/// inappropriate (protecting the child FROM the model — a different axis than
/// reacting to the child). Model-level safety also comes from the system-prompt
/// prefix in DialogService.
class ContentFilter {
  // ── Output block lists (used by [filterResponse] only) ──────────────────────

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
    'しにたい',
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

  /// Violent or self-harm keywords (English, lowercase).
  static const List<String> _violentKeywords = [
    'suicide',
    'self-harm',
    'selfharm',
    'cutting',
    'die',
    'hang myself',
    'kill myself',
    'end my life',
    'want to die',
    'hate myself',
    'blow up',
    'explode',
    'terrorist',
    'weapon',
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

  /// Prepares the child's [input] for the AI, or returns `null` when there is
  /// nothing to forward.
  ///
  /// Deliberately does NOT react to vocabulary: profanity or self-harm phrasing
  /// is neither scolded nor blocked (CEO decision, 2026-06-08 — the app judges
  /// only correct/incorrect and does not police individual words). It only:
  ///   1. trims and caps length (truncates rather than rejecting);
  ///   2. returns null for empty / unsupported-script-only input (nothing to
  ///      send — the caller continues without reacting);
  ///   3. keeps personal info (phone/email/postal) from reaching the external
  ///      AI by returning null when present — a privacy/COPPA data guard, not
  ///      word-policing; the caller does not scold, it simply continues.
  static String? sanitize(String input) {
    var trimmed = input.trim();

    if (trimmed.isEmpty) return null;
    if (!_hasAllowedChar(trimmed)) return null;
    if (trimmed.length > maxLength) trimmed = trimmed.substring(0, maxLength);

    // Privacy: never transmit a child's personal info to the AI service.
    if (_phonePattern.hasMatch(trimmed)) return null;
    if (_emailPattern.hasMatch(trimmed)) return null;
    if (_postalCodePattern.hasMatch(trimmed)) return null;

    return trimmed;
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

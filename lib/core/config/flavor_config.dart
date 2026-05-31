// Flavor configuration for multi-variant builds.
//
// Two flavors are supported:
//   - Flavor.edilab — free, all content unlocked, for EDILAB students.
//   - Flavor.aken   — commercial freemium (¥999/month via Stripe).
//
// The active flavor is set once at startup via FlavorConfig.setFlavor and
// is then available anywhere via FlavorConfig.instance.

// ---------------------------------------------------------------------------
// Flavor enum
// ---------------------------------------------------------------------------

enum Flavor {
  /// Free variant distributed to EDILAB students.
  /// All grades unlocked, no payment required.
  edilab,

  /// Commercial variant sold as "A-KEN Quest".
  /// Grade 5 is free; all other grades require ¥999/month Stripe subscription.
  aken,
}

// ---------------------------------------------------------------------------
// Per-flavor settings
// ---------------------------------------------------------------------------

class FlavorConfig {
  FlavorConfig._({
    required this.flavor,
    required this.appName,
    required this.bundleId,
    required this.primaryColor,
    required this.splashText,
    required this.paymentRequired,
    required this.freeGrades,
  });

  // ── Singleton ─────────────────────────────────────────────────────────────

  static FlavorConfig? _instance;

  /// Returns the active [FlavorConfig].
  ///
  /// Throws a [StateError] if [setFlavor] has not been called yet.
  static FlavorConfig get instance {
    if (_instance == null) {
      throw StateError(
        'FlavorConfig.setFlavor() must be called before accessing instance.',
      );
    }
    return _instance!;
  }

  /// Initialises the singleton with the given [flavor].
  ///
  /// Call this once in your flavor-specific main entry point before [runApp].
  static void setFlavor(Flavor flavor) {
    _instance = _buildFor(flavor);
  }

  // ── Fields ────────────────────────────────────────────────────────────────

  final Flavor flavor;

  /// Display name shown in the OS app switcher / MaterialApp title.
  final String appName;

  /// Reverse-DNS bundle/application identifier.
  final String bundleId;

  /// Primary brand color (used in [ColorScheme.primary]).
  final int primaryColor;

  /// Short motivational line shown on the loading splash.
  final String splashText;

  /// Whether a paid Stripe subscription is required to access locked content.
  final bool paymentRequired;

  /// Set of CEFR grade labels that are always free in this flavor.
  /// Empty means all grades are locked behind payment (except explicit free content).
  final Set<String> freeGrades;

  // ── Convenience helpers ───────────────────────────────────────────────────

  bool get isEdilabFlavor => flavor == Flavor.edilab;
  bool get isAkenFlavor => flavor == Flavor.aken;

  /// Returns true if the given CEFR [grade] (e.g. "A1", "A2") is accessible
  /// without payment for this flavor.
  bool isGradeFree(String grade) {
    if (!paymentRequired) return true;
    return freeGrades.contains(grade.toUpperCase());
  }

  // ── Factory ───────────────────────────────────────────────────────────────

  static FlavorConfig _buildFor(Flavor flavor) {
    switch (flavor) {
      case Flavor.edilab:
        return FlavorConfig._(
          flavor: flavor,
          appName: 'ENG Quest',
          bundleId: 'jp.co.aesthetic.engquest.edilab',
          primaryColor: 0xFF4FC3F7, // sky blue — matches existing brand
          splashText: 'EDILAB英語の冒険へ、出発！',
          paymentRequired: false,
          freeGrades: {},
        );

      case Flavor.aken:
        return FlavorConfig._(
          flavor: flavor,
          appName: 'A-KEN Quest',
          bundleId: 'jp.co.aesthetic.akenquest',
          primaryColor: 0xFF7C4DFF, // deep purple — distinct brand accent
          splashText: '英検合格への冒険、始まる！',
          paymentRequired: true,
          // Grade 5 (roughly A1) is free; all others require subscription.
          freeGrades: {'A1'},
        );
    }
  }
}

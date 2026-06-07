import 'package:flutter/material.dart';

/// Bundled Japanese serif typography.
///
/// The app previously rendered ALL Japanese text via `google_fonts`, which
/// fetches the font at RUNTIME from the gstatic CDN. On the demo that fetch did
/// not reliably land, so every Japanese glyph fell back to tofu (□) and the app
/// was effectively unreadable (CEO hands-on, 2026-06-07; confirmed in our own
/// render screenshots). Bundling the font as a pubspec asset makes rendering
/// deterministic and offline-safe — no network dependency on first paint.
///
/// A single ~13MB variable TTF (`assets/fonts/NotoSerifJP.ttf`, family declared
/// in pubspec.yaml) carries every weight; [TextStyle.fontWeight] drives the
/// `wght` axis, so all former google_fonts weight requests (w300–w900) are
/// served from the one file. This also removes the runtime font download from
/// the cold-boot path (helps the load-speed P0).
const String kJpSerifFamily = 'Noto Serif JP';

/// Drop-in replacement for `GoogleFonts.notoSerifJp(...)` backed by the bundled
/// font instead of a runtime download. Mirrors the parameters this codebase
/// actually passes.
TextStyle notoSerifJp({
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
  double? letterSpacing,
  double? height,
  FontStyle? fontStyle,
  TextDecoration? decoration,
  Color? backgroundColor,
  List<Shadow>? shadows,
}) =>
    TextStyle(
      fontFamily: kJpSerifFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      fontStyle: fontStyle,
      decoration: decoration,
      backgroundColor: backgroundColor,
      shadows: shadows,
    );

/// Latin serif uses the same family — Noto Serif JP includes full Latin glyphs,
/// so the single bundled file covers both scripts.
TextStyle notoSerif({
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
  double? letterSpacing,
  double? height,
}) =>
    notoSerifJp(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );

/// Drop-in for `GoogleFonts.notoSerifJpTextTheme(base)` — applies the bundled
/// family across an existing [TextTheme].
TextTheme notoSerifJpTextTheme([TextTheme? base]) =>
    (base ?? const TextTheme()).apply(fontFamily: kJpSerifFamily);

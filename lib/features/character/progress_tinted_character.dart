// lib/features/character/progress_tinted_character.dart
// CEO 3758 (2026-06-10) approved character mechanism (hybrid-asymmetric ①): the
// locked protagonist art (M5/M6) is shown GREY at the start and gains COLOUR as the
// child's HONEST 英検 readiness rises — a runtime ColorFiltered overlay, NO new art.
// Colour == real progress (on-brand with the honesty pillar): a child only sees
// their hero "come to life" by genuinely getting closer to 合格.

import 'package:flutter/material.dart';

/// A luminance-preserving saturation [ColorFilter] for [progress] in [0,1]:
/// 0 → full greyscale, 1 → full colour, linearly interpolated. Rec.709 luma
/// weights so the greyscale is perceptually correct. Top-level + public so the
/// matrix is unit-testable.
List<double> progressSaturationMatrix(double progress) {
  final s = progress.clamp(0.0, 1.0);
  const lr = 0.2126, lg = 0.7152, lb = 0.0722; // Rec.709 luma
  // Each channel = (1-s)·luma + s·(that channel) — i.e. interpolate between the
  // all-luma (greyscale) matrix and the identity (full-colour) matrix.
  double diag(double w) => (1 - s) * w + s;
  double off(double w) => (1 - s) * w;
  return <double>[
    diag(lr), off(lg), off(lb), 0, 0,
    off(lr), diag(lg), off(lb), 0, 0,
    off(lr), off(lg), diag(lb), 0, 0,
    0, 0, 0, 1, 0,
  ];
}

ColorFilter progressSaturationFilter(double progress) =>
    ColorFilter.matrix(progressSaturationMatrix(progress));

/// Shows [asset] tinted by [readiness] (0–1): grey when far from 合格, full colour
/// at the 目安. Drive [readiness] from the HONEST cse_model readinessPct/100 — never
/// a fabricated value (the colour must mean real progress).
class ProgressTintedCharacter extends StatelessWidget {
  const ProgressTintedCharacter({
    super.key,
    required this.asset,
    required this.readiness,
    this.size = 120,
    this.width,
    this.height,
    this.semanticLabel,
  });

  final String asset;

  /// 0–1 honest readiness. Clamped; values outside [0,1] are tolerated.
  final double readiness;

  /// Square fallback used when [width]/[height] are not given. The mains are
  /// portrait, so callers usually pass an explicit [width]/[height].
  final double size;
  final double? width;
  final double? height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final w = width ?? size;
    final h = height ?? size;
    return ColorFiltered(
      colorFilter: progressSaturationFilter(readiness),
      child: Image.asset(
        asset,
        width: w,
        height: h,
        fit: BoxFit.contain,
        semanticLabel: semanticLabel,
        // A missing art asset must never crash the screen — degrade to nothing.
        errorBuilder: (_, __, ___) => SizedBox(width: w, height: h),
      ),
    );
  }
}

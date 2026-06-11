// lib/core/ui/responsive.dart
// Shared responsive primitives (CEO 1212: the product ships on mobile + tablet;
// every screen must lay out correctly on phone portrait/landscape AND tablet).
//
// Strategy (Material 3 window size classes, 2026):
//   compact  : width < 600   (phone portrait)
//   medium   : 600 ≤ width < 840 (phone landscape, small tablet portrait)
//   expanded : width ≥ 840   (tablet landscape, large tablet)
// Ref: https://m3.material.io/foundations/layout/applying-layout/window-size-classes
//
// The 80% fix for a content-centric app is [ResponsiveCenter]: cap the main
// content to a readable width and centre it on wide screens (so it doesn't
// stretch edge-to-edge on a tablet) while staying full-width on a phone. It is
// PURE LAYOUT (Align + ConstrainedBox) — no MediaQuery, no rebuild-on-resize
// cost, behaviour-identical on phone portrait (where maxWidth never binds).

import 'package:flutter/widgets.dart';

/// Material 3 window size class for the current view.
enum WindowClass { compact, medium, expanded }

extension ResponsiveContext on BuildContext {
  /// Logical width of the nearest MediaQuery (rebuilds only on size change).
  double get windowWidth => MediaQuery.sizeOf(this).width;

  /// Logical height of the nearest MediaQuery.
  double get windowHeight => MediaQuery.sizeOf(this).height;

  /// Material 3 window size class.
  WindowClass get windowClass {
    final w = windowWidth;
    if (w < 600) return WindowClass.compact;
    if (w < 840) return WindowClass.medium;
    return WindowClass.expanded;
  }

  /// True on phone portrait (the baseline layout).
  bool get isCompact => windowClass == WindowClass.compact;

  /// True on tablet / phone-landscape (medium or expanded) — reflow allowed.
  bool get isWide => windowClass != WindowClass.compact;

  /// True when the viewport is short (phone landscape) — content must scroll.
  bool get isShort => windowHeight < 500;
}

/// Caps [child] to [maxWidth] and centres it horizontally on wide screens, while
/// leaving it full-width on a phone (where the cap never binds). Use it to wrap a
/// screen's main (scrollable) content so a tablet shows a readable column with the
/// dark scene in the side margins instead of edge-to-edge stretched UI.
class ResponsiveCenter extends StatelessWidget {
  final Widget child;

  /// Readable content cap. 600 suits single-column reading/exam content; pass a
  /// larger value (e.g. 840) for grid/dashboard screens that use the extra width.
  final double maxWidth;

  /// Horizontal padding applied INSIDE the cap (keeps content off the edges on
  /// a phone too).
  final EdgeInsetsGeometry? padding;

  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = 600,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    );
    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }
    return Align(alignment: Alignment.topCenter, child: content);
  }
}

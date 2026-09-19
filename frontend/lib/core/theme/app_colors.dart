import 'package:flutter/material.dart';

@immutable
class TradePulseColors extends ThemeExtension<TradePulseColors> {
  const TradePulseColors({
    required this.canvas,
    required this.canvasAlt,
    required this.card,
    required this.sidebar,
    required this.chart,
    required this.chartGrid,
    required this.accent,
    required this.accentSecondary,
    required this.success,
    required this.danger,
    required this.warning,
    required this.glow,
    required this.glowSecondary,
    required this.cardBorder,
    required this.mutedText,
    required this.gradientTop,
    required this.gradientBottom,
    required this.inputFill,
  });

  final Color canvas;
  final Color canvasAlt;
  final Color card;
  final Color sidebar;
  final Color chart;
  final Color chartGrid;
  final Color accent;
  final Color accentSecondary;
  final Color success;
  final Color danger;
  final Color warning;
  final Color glow;
  final Color glowSecondary;
  final Color cardBorder;
  final Color mutedText;
  final Color gradientTop;
  final Color gradientBottom;
  final Color inputFill;

  static const dark = TradePulseColors(
    canvas: Color(0xFF0B1730),
    canvasAlt: Color(0xFF102044),
    card: Color(0xFF152445),
    sidebar: Color(0xFF0C1B38),
    chart: Color(0xFF05070C),
    chartGrid: Color(0xFF1C2433),
    accent: Color(0xFF2EE6C8),
    accentSecondary: Color(0xFF6B7CFF),
    success: Color(0xFF2BD67B),
    danger: Color(0xFFE85D6A),
    warning: Color(0xFFE0B84A),
    glow: Color(0x332EE6C8),
    glowSecondary: Color(0x286B7CFF),
    cardBorder: Color(0xFF2E4568),
    mutedText: Color(0xFF93A6C4),
    gradientTop: Color(0xFF13285A),
    gradientBottom: Color(0xFF0B1730),
    inputFill: Color(0xFF101E3C),
  );

  static const light = TradePulseColors(
    canvas: Color(0xFFE7EEF8),
    canvasAlt: Color(0xFFD7E3F4),
    card: Color(0xFFFFFFFF),
    sidebar: Color(0xFFF3F7FC),
    chart: Color(0xFF05070C),
    chartGrid: Color(0xFF1C2433),
    accent: Color(0xFF0FA392),
    accentSecondary: Color(0xFF4F63E6),
    success: Color(0xFF1A9A58),
    danger: Color(0xFFD04545),
    warning: Color(0xFFC4921F),
    glow: Color(0x220FA392),
    glowSecondary: Color(0x1A4F63E6),
    cardBorder: Color(0xFFC5D2E4),
    mutedText: Color(0xFF5B6B82),
    gradientTop: Color(0xFFDCE7F8),
    gradientBottom: Color(0xFFE7EEF8),
    inputFill: Color(0xFFFFFFFF),
  );

  LinearGradient get pageGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [gradientTop, canvas, gradientBottom],
      );

  @override
  TradePulseColors copyWith({
    Color? canvas,
    Color? canvasAlt,
    Color? card,
    Color? sidebar,
    Color? chart,
    Color? chartGrid,
    Color? accent,
    Color? accentSecondary,
    Color? success,
    Color? danger,
    Color? warning,
    Color? glow,
    Color? glowSecondary,
    Color? cardBorder,
    Color? mutedText,
    Color? gradientTop,
    Color? gradientBottom,
    Color? inputFill,
  }) {
    return TradePulseColors(
      canvas: canvas ?? this.canvas,
      canvasAlt: canvasAlt ?? this.canvasAlt,
      card: card ?? this.card,
      sidebar: sidebar ?? this.sidebar,
      chart: chart ?? this.chart,
      chartGrid: chartGrid ?? this.chartGrid,
      accent: accent ?? this.accent,
      accentSecondary: accentSecondary ?? this.accentSecondary,
      success: success ?? this.success,
      danger: danger ?? this.danger,
      warning: warning ?? this.warning,
      glow: glow ?? this.glow,
      glowSecondary: glowSecondary ?? this.glowSecondary,
      cardBorder: cardBorder ?? this.cardBorder,
      mutedText: mutedText ?? this.mutedText,
      gradientTop: gradientTop ?? this.gradientTop,
      gradientBottom: gradientBottom ?? this.gradientBottom,
      inputFill: inputFill ?? this.inputFill,
    );
  }

  @override
  TradePulseColors lerp(TradePulseColors? other, double t) {
    if (other is! TradePulseColors) return this;
    return TradePulseColors(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      canvasAlt: Color.lerp(canvasAlt, other.canvasAlt, t)!,
      card: Color.lerp(card, other.card, t)!,
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      chart: Color.lerp(chart, other.chart, t)!,
      chartGrid: Color.lerp(chartGrid, other.chartGrid, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSecondary: Color.lerp(accentSecondary, other.accentSecondary, t)!,
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      glow: Color.lerp(glow, other.glow, t)!,
      glowSecondary: Color.lerp(glowSecondary, other.glowSecondary, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      gradientTop: Color.lerp(gradientTop, other.gradientTop, t)!,
      gradientBottom: Color.lerp(gradientBottom, other.gradientBottom, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
    );
  }
}

extension TradePulseThemeX on BuildContext {
  TradePulseColors get tpColors =>
      Theme.of(this).extension<TradePulseColors>() ?? TradePulseColors.dark;
}

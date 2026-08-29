import 'package:flutter/material.dart';

/// Single source of truth for the app's visual scale.
///
/// Mirrors SpotiFLAC's design tokens so the UI shares one consistent radius,
/// spacing, cover-size and motion vocabulary. Anything reused across more than
/// one screen belongs here so a design change is a one-line edit.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.radiusBadge,
    required this.radiusThumb,
    required this.radiusCover,
    required this.radiusControl,
    required this.radiusCard,
    required this.radiusSheet,
    required this.gapXs,
    required this.gapSm,
    required this.gapMd,
    required this.gapLg,
    required this.gapXl,
    required this.coverMini,
    required this.coverCompact,
    required this.coverList,
    required this.badgeFontSize,
    required this.badgePadding,
    required this.minTouchTarget,
    required this.headerExpandedHeight,
    required this.headerCollapsedTitleSize,
    required this.headerExpandedTitleSize,
    required this.motionFast,
    required this.motionMedium,
    required this.motionSlow,
  });

  /// Sade tokenler — LA Player gibi küçük radius, az boşluk, hızlı motion
  static const AppTokens standard = AppTokens(
    radiusBadge: 4,
    radiusThumb: 6,
    radiusCover: 8,
    radiusControl: 10,
    radiusCard: 12,
    radiusSheet: 16,
    gapXs: 4,
    gapSm: 8,
    gapMd: 12,
    gapLg: 16,
    gapXl: 20,
    coverMini: 44,
    coverCompact: 48,
    coverList: 56,
    badgeFontSize: 11,
    badgePadding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    minTouchTarget: 48,
    headerExpandedHeight: 100,
    headerCollapsedTitleSize: 18,
    headerExpandedTitleSize: 24,
    motionFast: Duration(milliseconds: 120),
    motionMedium: Duration(milliseconds: 200),
    motionSlow: Duration(milliseconds: 300),
  );

  final double radiusBadge;
  final double radiusThumb;
  final double radiusCover;
  final double radiusControl;
  final double radiusCard;
  final double radiusSheet;

  final double gapXs;
  final double gapSm;
  final double gapMd;
  final double gapLg;
  final double gapXl;

  final double coverMini;
  final double coverCompact;
  final double coverList;

  final double badgeFontSize;
  final EdgeInsets badgePadding;

  final double minTouchTarget;

  final double headerExpandedHeight;
  final double headerCollapsedTitleSize;
  final double headerExpandedTitleSize;

  final Duration motionFast;
  final Duration motionMedium;
  final Duration motionSlow;

  BorderRadius get borderRadiusBadge => BorderRadius.circular(radiusBadge);
  BorderRadius get borderRadiusThumb => BorderRadius.circular(radiusThumb);
  BorderRadius get borderRadiusCover => BorderRadius.circular(radiusCover);
  BorderRadius get borderRadiusCard => BorderRadius.circular(radiusCard);

  RoundedRectangleBorder get sheetShape => RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radiusSheet)),
      );

  @override
  AppTokens copyWith({
    double? radiusBadge,
    double? radiusThumb,
    double? radiusCover,
    double? radiusControl,
    double? radiusCard,
    double? radiusSheet,
    double? gapXs,
    double? gapSm,
    double? gapMd,
    double? gapLg,
    double? gapXl,
    double? coverMini,
    double? coverCompact,
    double? coverList,
    double? badgeFontSize,
    EdgeInsets? badgePadding,
    double? minTouchTarget,
    double? headerExpandedHeight,
    double? headerCollapsedTitleSize,
    double? headerExpandedTitleSize,
    Duration? motionFast,
    Duration? motionMedium,
    Duration? motionSlow,
  }) {
    return AppTokens(
      radiusBadge: radiusBadge ?? this.radiusBadge,
      radiusThumb: radiusThumb ?? this.radiusThumb,
      radiusCover: radiusCover ?? this.radiusCover,
      radiusControl: radiusControl ?? this.radiusControl,
      radiusCard: radiusCard ?? this.radiusCard,
      radiusSheet: radiusSheet ?? this.radiusSheet,
      gapXs: gapXs ?? this.gapXs,
      gapSm: gapSm ?? this.gapSm,
      gapMd: gapMd ?? this.gapMd,
      gapLg: gapLg ?? this.gapLg,
      gapXl: gapXl ?? this.gapXl,
      coverMini: coverMini ?? this.coverMini,
      coverCompact: coverCompact ?? this.coverCompact,
      coverList: coverList ?? this.coverList,
      badgeFontSize: badgeFontSize ?? this.badgeFontSize,
      badgePadding: badgePadding ?? this.badgePadding,
      minTouchTarget: minTouchTarget ?? this.minTouchTarget,
      headerExpandedHeight: headerExpandedHeight ?? this.headerExpandedHeight,
      headerCollapsedTitleSize:
          headerCollapsedTitleSize ?? this.headerCollapsedTitleSize,
      headerExpandedTitleSize:
          headerExpandedTitleSize ?? this.headerExpandedTitleSize,
      motionFast: motionFast ?? this.motionFast,
      motionMedium: motionMedium ?? this.motionMedium,
      motionSlow: motionSlow ?? this.motionSlow,
    );
  }

  @override
  AppTokens lerp(covariant AppTokens? other, double t) {
    if (other == null) return this;
    return AppTokens(
      radiusBadge: lerpDouble(radiusBadge, other.radiusBadge, t),
      radiusThumb: lerpDouble(radiusThumb, other.radiusThumb, t),
      radiusCover: lerpDouble(radiusCover, other.radiusCover, t),
      radiusControl: lerpDouble(radiusControl, other.radiusControl, t),
      radiusCard: lerpDouble(radiusCard, other.radiusCard, t),
      radiusSheet: lerpDouble(radiusSheet, other.radiusSheet, t),
      gapXs: lerpDouble(gapXs, other.gapXs, t),
      gapSm: lerpDouble(gapSm, other.gapSm, t),
      gapMd: lerpDouble(gapMd, other.gapMd, t),
      gapLg: lerpDouble(gapLg, other.gapLg, t),
      gapXl: lerpDouble(gapXl, other.gapXl, t),
      coverMini: lerpDouble(coverMini, other.coverMini, t),
      coverCompact: lerpDouble(coverCompact, other.coverCompact, t),
      coverList: lerpDouble(coverList, other.coverList, t),
      badgeFontSize: lerpDouble(badgeFontSize, other.badgeFontSize, t),
      badgePadding:
          EdgeInsets.lerp(badgePadding, other.badgePadding, t) ?? badgePadding,
      minTouchTarget: lerpDouble(minTouchTarget, other.minTouchTarget, t),
      headerExpandedHeight:
          lerpDouble(headerExpandedHeight, other.headerExpandedHeight, t),
      headerCollapsedTitleSize: lerpDouble(
          headerCollapsedTitleSize, other.headerCollapsedTitleSize, t),
      headerExpandedTitleSize: lerpDouble(
          headerExpandedTitleSize, other.headerExpandedTitleSize, t),
      motionFast: t < 0.5 ? motionFast : other.motionFast,
      motionMedium: t < 0.5 ? motionMedium : other.motionMedium,
      motionSlow: t < 0.5 ? motionSlow : other.motionSlow,
    );
  }

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

extension AppTokensContext on BuildContext {
  /// The active [AppTokens]. Falls back to [AppTokens.standard] when the widget
  /// is built outside a theme that registered the extension.
  AppTokens get tokens =>
      Theme.of(this).extension<AppTokens>() ?? AppTokens.standard;
}

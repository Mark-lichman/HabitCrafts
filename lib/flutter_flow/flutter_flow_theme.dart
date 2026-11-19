// ignore_for_file: overridden_fields, annotate_overrides

// HAND-MAINTAINED. Adopted under S3.
//
// This file began as FlutterFlow export scaffolding. The colour and type layers have been
// replaced by hand to implement Quiet Room (docs/design-direction.md v2.0, 2026-09-26);
// section refs below are [D §n] in that document. It is no longer generated code and does
// not get the "generated, review lightly" discount.
//
// WHERE THE VALUES LIVE: nowhere in this file. Every colour resolves through
// quiet_room.dart, which is the closed token layer. [D §6 veto list] If you need a
// colour that is not there, add a semantic token there. Do not add a hex here.
//
// WHY THE LEGACY NAMES SURVIVE: 101 files read `FlutterFlowTheme.of(context).<name>`.
// Renaming those fields is a 101-file change with no visual payoff, so the FlutterFlow
// names are kept as an adapter onto Quiet Room. Two consequences worth knowing:
//
//   1. The names lie about their values, and always did. `primaryBackground` is a blue,
//      not a background. `secondaryText` is near-white. `textColor` is white. These are
//      inherited misnomers, preserved deliberately.
//   2. Each legacy name keeps the colour ROLE it had before, so no screen that was
//      legible becomes illegible. The values change; the roles do not. Re-pointing a
//      role (making `secondaryText` a dark ink, say) is a per-screen decision that needs
//      a screen in front of you, and is not done here.
//
// Prefer `QuietRoomTokens.of(context)` in new code.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'quiet_room.dart';

abstract class FlutterFlowTheme {
  /// Resolves Daylight or Nightfall from the ambient theme brightness.
  ///
  /// The export shipped this as an unconditional `return LightModeTheme()`, which is why
  /// the app had no dark mode despite `main.dart` already carrying a `ThemeMode`. Quiet
  /// Room specifies both palettes [D §2.5], so this now reads the theme.
  static FlutterFlowTheme of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? DarkModeTheme()
          : LightModeTheme();

  @Deprecated('Use primary instead')
  Color get primaryColor => primary;
  @Deprecated('Use secondary instead')
  Color get secondaryColor => secondary;
  @Deprecated('Use tertiary instead')
  Color get tertiaryColor => tertiary;

  late Color primary;
  late Color secondary;
  late Color tertiary;
  late Color alternate;
  late Color primaryText;
  late Color secondaryText;
  late Color primaryBackground;
  late Color secondaryBackground;
  late Color accent1;
  late Color accent2;
  late Color accent3;
  late Color accent4;
  late Color success;
  late Color warning;
  late Color error;
  late Color info;

  late Color background;
  late Color darkBackground;
  late Color textColor;
  late Color grayDark;
  late Color grayLight;
  late Color whiteOverlay;
  late Color messageTextBG;
  late Color whiteTransparent10;
  late Color neutral;

  /// The Quiet Room token set behind this theme. New code should prefer this over the
  /// legacy names above.
  QuietRoomTokens get tokens;

  FFDesignTokens get designToken => FFDesignTokens(this);

  @Deprecated('Use displaySmallFamily instead')
  String get title1Family => displaySmallFamily;
  @Deprecated('Use displaySmall instead')
  TextStyle get title1 => typography.displaySmall;
  @Deprecated('Use headlineMediumFamily instead')
  String get title2Family => typography.headlineMediumFamily;
  @Deprecated('Use headlineMedium instead')
  TextStyle get title2 => typography.headlineMedium;
  @Deprecated('Use headlineSmallFamily instead')
  String get title3Family => typography.headlineSmallFamily;
  @Deprecated('Use headlineSmall instead')
  TextStyle get title3 => typography.headlineSmall;
  @Deprecated('Use titleMediumFamily instead')
  String get subtitle1Family => typography.titleMediumFamily;
  @Deprecated('Use titleMedium instead')
  TextStyle get subtitle1 => typography.titleMedium;
  @Deprecated('Use titleSmallFamily instead')
  String get subtitle2Family => typography.titleSmallFamily;
  @Deprecated('Use titleSmall instead')
  TextStyle get subtitle2 => typography.titleSmall;
  @Deprecated('Use bodyMediumFamily instead')
  String get bodyText1Family => typography.bodyMediumFamily;
  @Deprecated('Use bodyMedium instead')
  TextStyle get bodyText1 => typography.bodyMedium;
  @Deprecated('Use bodySmallFamily instead')
  String get bodyText2Family => typography.bodySmallFamily;
  @Deprecated('Use bodySmall instead')
  TextStyle get bodyText2 => typography.bodySmall;

  String get displayLargeFamily => typography.displayLargeFamily;
  bool get displayLargeIsCustom => typography.displayLargeIsCustom;
  TextStyle get displayLarge => typography.displayLarge;
  String get displayMediumFamily => typography.displayMediumFamily;
  bool get displayMediumIsCustom => typography.displayMediumIsCustom;
  TextStyle get displayMedium => typography.displayMedium;
  String get displaySmallFamily => typography.displaySmallFamily;
  bool get displaySmallIsCustom => typography.displaySmallIsCustom;
  TextStyle get displaySmall => typography.displaySmall;
  String get headlineLargeFamily => typography.headlineLargeFamily;
  bool get headlineLargeIsCustom => typography.headlineLargeIsCustom;
  TextStyle get headlineLarge => typography.headlineLarge;
  String get headlineMediumFamily => typography.headlineMediumFamily;
  bool get headlineMediumIsCustom => typography.headlineMediumIsCustom;
  TextStyle get headlineMedium => typography.headlineMedium;
  String get headlineSmallFamily => typography.headlineSmallFamily;
  bool get headlineSmallIsCustom => typography.headlineSmallIsCustom;
  TextStyle get headlineSmall => typography.headlineSmall;
  String get titleLargeFamily => typography.titleLargeFamily;
  bool get titleLargeIsCustom => typography.titleLargeIsCustom;
  TextStyle get titleLarge => typography.titleLarge;
  String get titleMediumFamily => typography.titleMediumFamily;
  bool get titleMediumIsCustom => typography.titleMediumIsCustom;
  TextStyle get titleMedium => typography.titleMedium;
  String get titleSmallFamily => typography.titleSmallFamily;
  bool get titleSmallIsCustom => typography.titleSmallIsCustom;
  TextStyle get titleSmall => typography.titleSmall;
  String get labelLargeFamily => typography.labelLargeFamily;
  bool get labelLargeIsCustom => typography.labelLargeIsCustom;
  TextStyle get labelLarge => typography.labelLarge;
  String get labelMediumFamily => typography.labelMediumFamily;
  bool get labelMediumIsCustom => typography.labelMediumIsCustom;
  TextStyle get labelMedium => typography.labelMedium;
  String get labelSmallFamily => typography.labelSmallFamily;
  bool get labelSmallIsCustom => typography.labelSmallIsCustom;
  TextStyle get labelSmall => typography.labelSmall;
  String get bodyLargeFamily => typography.bodyLargeFamily;
  bool get bodyLargeIsCustom => typography.bodyLargeIsCustom;
  TextStyle get bodyLarge => typography.bodyLarge;
  String get bodyMediumFamily => typography.bodyMediumFamily;
  bool get bodyMediumIsCustom => typography.bodyMediumIsCustom;
  TextStyle get bodyMedium => typography.bodyMedium;
  String get bodySmallFamily => typography.bodySmallFamily;
  bool get bodySmallIsCustom => typography.bodySmallIsCustom;
  TextStyle get bodySmall => typography.bodySmall;

  Typography get typography => ThemeTypography(this);
}

/// Daylight. [D §1]
class LightModeTheme extends FlutterFlowTheme {
  @Deprecated('Use primary instead')
  Color get primaryColor => primary;
  @Deprecated('Use secondary instead')
  Color get secondaryColor => secondary;
  @Deprecated('Use tertiary instead')
  Color get tertiaryColor => tertiary;

  @override
  final QuietRoomTokens tokens = const DaylightTokens();

  late Color primary = Daylight.brand600;
  late Color secondary = Daylight.brand700;
  late Color tertiary = Daylight.surfaceTinted;

  /// 167 call sites, the most-used colour in the app. It was pure white; in Quiet Room
  /// pure white is reserved for sheets and menus, so cards land on `surface` instead.
  /// This one line is most of what makes the room quiet.
  late Color alternate = Daylight.surface;

  late Color primaryText = Daylight.ink;

  /// Near-white, and it stays near-white. This is the label colour on the hero blue and
  /// on dark chrome; re-pointing it at a dark ink would erase text on every one of those
  /// surfaces. See the header note on roles.
  late Color secondaryText = Daylight.surfaceRaised;

  /// A blue, despite the name. It is the hero surface. [D §4.8]
  late Color primaryBackground = Daylight.brand700;
  late Color secondaryBackground = Daylight.surface;

  late Color accent1 = Daylight.gold500;

  /// Was teal. Teal is retired from the UI and survives only in illustration. [D §4.4]
  /// Sage is the closest surviving intent: a secondary, growth-flavoured accent.
  late Color accent2 = Daylight.sage500;

  late Color accent3 = Daylight.canvasSunken;
  late Color accent4 = Daylight.canvas;

  late Color success = Daylight.sage600;

  /// Care, not alarm. There is no pure red or pure yellow in the closed palette.
  late Color warning = Daylight.amber700;
  late Color error = Daylight.clay600;
  late Color info = Daylight.brand600;

  /// The ground inversion. [D §5.1] This was #1A1F24, a dark value on a light app.
  late Color background = Daylight.canvas;
  late Color darkBackground = Daylight.canvasSunken;

  /// One call site, on dark chrome. Stays white.
  late Color textColor = Daylight.surfaceRaised;

  late Color grayDark = Daylight.inkMuted;
  late Color grayLight = Daylight.border;

  /// Overlays are alpha on whatever is beneath them, so they are theme-independent and
  /// are not tokens.
  late Color whiteOverlay = const Color(0x1AFFFFFF);
  late Color messageTextBG = Daylight.canvasSunken;
  late Color whiteTransparent10 = const Color(0x19FFFFFF);
  late Color neutral = Daylight.border;
}

/// Nightfall. Surfaces are tinted with the brand hue, never neutral grey. [D §1]
class DarkModeTheme extends FlutterFlowTheme {
  @Deprecated('Use primary instead')
  Color get primaryColor => primary;
  @Deprecated('Use secondary instead')
  Color get secondaryColor => secondary;
  @Deprecated('Use tertiary instead')
  Color get tertiaryColor => tertiary;

  @override
  final QuietRoomTokens tokens = const NightfallTokens();

  late Color primary = Nightfall.brand;
  late Color secondary = Nightfall.brand;
  late Color tertiary = Nightfall.surfaceTinted;
  late Color alternate = Nightfall.surface;
  late Color primaryText = Nightfall.ink;
  late Color secondaryText = Nightfall.inkStrong;
  late Color primaryBackground = Nightfall.brandHero;
  late Color secondaryBackground = Nightfall.surface;
  late Color accent1 = Nightfall.gold;
  late Color accent2 = Nightfall.sage;
  late Color accent3 = Nightfall.surfaceRaised;
  late Color accent4 = Nightfall.canvas;
  late Color success = Nightfall.sage;
  late Color warning = Nightfall.amber;
  late Color error = Nightfall.clay;
  late Color info = Nightfall.brand;

  late Color background = Nightfall.canvas;
  late Color darkBackground = Nightfall.canvas;
  late Color textColor = Nightfall.inkStrong;
  late Color grayDark = Nightfall.inkMuted;
  late Color grayLight = Nightfall.border;
  late Color whiteOverlay = const Color(0x1AFFFFFF);
  late Color messageTextBG = Nightfall.surfaceRaised;
  late Color whiteTransparent10 = const Color(0x19FFFFFF);
  late Color neutral = Nightfall.border;
}

abstract class Typography {
  String get displayLargeFamily;
  bool get displayLargeIsCustom;
  TextStyle get displayLarge;
  String get displayMediumFamily;
  bool get displayMediumIsCustom;
  TextStyle get displayMedium;
  String get displaySmallFamily;
  bool get displaySmallIsCustom;
  TextStyle get displaySmall;
  String get headlineLargeFamily;
  bool get headlineLargeIsCustom;
  TextStyle get headlineLarge;
  String get headlineMediumFamily;
  bool get headlineMediumIsCustom;
  TextStyle get headlineMedium;
  String get headlineSmallFamily;
  bool get headlineSmallIsCustom;
  TextStyle get headlineSmall;
  String get titleLargeFamily;
  bool get titleLargeIsCustom;
  TextStyle get titleLarge;
  String get titleMediumFamily;
  bool get titleMediumIsCustom;
  TextStyle get titleMedium;
  String get titleSmallFamily;
  bool get titleSmallIsCustom;
  TextStyle get titleSmall;
  String get labelLargeFamily;
  bool get labelLargeIsCustom;
  TextStyle get labelLarge;
  String get labelMediumFamily;
  bool get labelMediumIsCustom;
  TextStyle get labelMedium;
  String get labelSmallFamily;
  bool get labelSmallIsCustom;
  TextStyle get labelSmall;
  String get bodyLargeFamily;
  bool get bodyLargeIsCustom;
  TextStyle get bodyLarge;
  String get bodyMediumFamily;
  bool get bodyMediumIsCustom;
  TextStyle get bodyMedium;
  String get bodySmallFamily;
  bool get bodySmallIsCustom;
  TextStyle get bodySmall;
}

/// The Quiet Room type ramp. [D §4.2]
///
/// Fraunces is a DAILY voice, not an event voice: it takes page titles, streak numerals,
/// milestone headlines and empty-state headings. Body, labels, buttons and nav are
/// strictly Figtree. The mapping below is display*/headline* -> Fraunces,
/// title*/label*/body* -> Figtree, because in this codebase `title*` is what buttons and
/// list rows use.
///
/// MINIMUM TEXT SIZE IS 13px, NO EXCEPTIONS. [D §6] That rule moves `labelMedium` from
/// 12px and `labelSmall` from 11px up to 13px; they now differ from `bodySmall` by
/// weight and tracking rather than by size, which is the deviation tokens.css logs for
/// the same reason.
///
/// DEVIATION: the direction specifies Fraunces variable axes (SOFT 50, WONK 0). The
/// google_fonts package serves static instances and exposes no axis control, so the axes
/// are not set here. Nothing renders wrong; the terminals are simply not softened.
class ThemeTypography extends Typography {
  ThemeTypography(this.theme);

  final FlutterFlowTheme theme;

  static const _display = 'Fraunces';
  static const _ui = 'Figtree';

  String get displayLargeFamily => _display;
  bool get displayLargeIsCustom => false;
  TextStyle get displayLarge => GoogleFonts.fraunces(
        color: theme.primaryText,
        fontWeight: FontWeight.w600,
        fontSize: 48.0,
        height: 52.0 / 48.0,
        letterSpacing: 48.0 * -0.02,
      );

  String get displayMediumFamily => _display;
  bool get displayMediumIsCustom => false;
  TextStyle get displayMedium => GoogleFonts.fraunces(
        color: theme.secondaryText,
        fontWeight: FontWeight.w600,
        fontSize: 32.0,
        height: 38.0 / 32.0,
        letterSpacing: 32.0 * -0.015,
      );

  String get displaySmallFamily => _display;
  bool get displaySmallIsCustom => false;
  TextStyle get displaySmall => GoogleFonts.fraunces(
        color: theme.primaryText,
        fontWeight: FontWeight.w600,
        fontSize: 32.0,
        height: 38.0 / 32.0,
        letterSpacing: 32.0 * -0.015,
      );

  String get headlineLargeFamily => _display;
  bool get headlineLargeIsCustom => false;
  TextStyle get headlineLarge => GoogleFonts.fraunces(
        color: theme.primaryText,
        fontWeight: FontWeight.w600,
        fontSize: 32.0,
        height: 38.0 / 32.0,
        letterSpacing: 32.0 * -0.015,
      );

  String get headlineMediumFamily => _display;
  bool get headlineMediumIsCustom => false;
  TextStyle get headlineMedium => GoogleFonts.fraunces(
        color: theme.tokens.heroInk,
        fontWeight: FontWeight.w600,
        fontSize: 24.0,
        height: 30.0 / 24.0,
        letterSpacing: 24.0 * -0.01,
      );

  String get headlineSmallFamily => _display;
  bool get headlineSmallIsCustom => false;
  TextStyle get headlineSmall => GoogleFonts.fraunces(
        color: theme.primaryText,
        fontWeight: FontWeight.w600,
        fontSize: 20.0,
        height: 26.0 / 20.0,
        letterSpacing: 20.0 * -0.005,
      );

  String get titleLargeFamily => _ui;
  bool get titleLargeIsCustom => false;
  TextStyle get titleLarge => GoogleFonts.figtree(
        color: theme.primaryText,
        fontWeight: FontWeight.w600,
        fontSize: 20.0,
        height: 26.0 / 20.0,
        letterSpacing: 20.0 * -0.005,
      );

  String get titleMediumFamily => _ui;
  bool get titleMediumIsCustom => false;
  TextStyle get titleMedium => GoogleFonts.figtree(
        color: theme.secondaryText,
        fontWeight: FontWeight.w600,
        fontSize: 17.0,
        height: 26.0 / 17.0,
      );

  String get titleSmallFamily => _ui;
  bool get titleSmallIsCustom => false;
  TextStyle get titleSmall => GoogleFonts.figtree(
        color: theme.alternate,
        fontWeight: FontWeight.w600,
        fontSize: 15.0,
        height: 22.0 / 15.0,
      );

  String get labelLargeFamily => _ui;
  bool get labelLargeIsCustom => false;
  TextStyle get labelLarge => GoogleFonts.figtree(
        color: theme.primaryText,
        fontWeight: FontWeight.w600,
        fontSize: 13.0,
        height: 16.0 / 13.0,
        letterSpacing: 13.0 * 0.01,
      );

  String get labelMediumFamily => _ui;
  bool get labelMediumIsCustom => false;
  TextStyle get labelMedium => GoogleFonts.figtree(
        color: theme.primaryText,
        fontWeight: FontWeight.w500,
        fontSize: 13.0,
        height: 16.0 / 13.0,
        letterSpacing: 13.0 * 0.02,
      );

  String get labelSmallFamily => _ui;
  bool get labelSmallIsCustom => false;
  TextStyle get labelSmall => GoogleFonts.figtree(
        color: theme.primaryText,
        fontWeight: FontWeight.w500,
        fontSize: 13.0,
        height: 16.0 / 13.0,
        letterSpacing: 13.0 * 0.02,
      );

  String get bodyLargeFamily => _ui;
  bool get bodyLargeIsCustom => false;
  TextStyle get bodyLarge => GoogleFonts.figtree(
        color: theme.primaryText,
        fontWeight: FontWeight.normal,
        fontSize: 17.0,
        height: 26.0 / 17.0,
      );

  String get bodyMediumFamily => _ui;
  bool get bodyMediumIsCustom => false;
  TextStyle get bodyMedium => GoogleFonts.figtree(
        color: theme.primaryText,
        fontWeight: FontWeight.normal,
        fontSize: 15.0,
        height: 22.0 / 15.0,
      );

  String get bodySmallFamily => _ui;
  bool get bodySmallIsCustom => false;
  TextStyle get bodySmall => GoogleFonts.figtree(
        color: theme.secondaryText,
        fontWeight: FontWeight.normal,
        fontSize: 13.0,
        height: 19.0 / 13.0,
        letterSpacing: 13.0 * 0.005,
      );
}

class FFDesignTokens {
  const FFDesignTokens(this.theme);
  final FlutterFlowTheme theme;
  FFSpacing get spacing => const FFSpacing();
  FFRadius get radius => const FFRadius();
  FFShadows get shadow => FFShadows(theme);
}

/// The 8px baseline grid; 12 is the one half-step.
class FFSpacing {
  const FFSpacing();
  double get xs => QuietRoomMetrics.space4;
  double get sm => QuietRoomMetrics.space8;
  double get halfStep => QuietRoomMetrics.space12;
  double get md => QuietRoomMetrics.space16;
  double get lg => QuietRoomMetrics.space24;
  double get xl => QuietRoomMetrics.space32;
  double get xxl => QuietRoomMetrics.space48;
  double get xxxl => QuietRoomMetrics.space64;
}

/// The radius scale that retires the app's nine drifting values.
///
/// `sm` was 8 and is now 12: 8 is `xs` in Quiet Room. That renaming is the point of the
/// retirement, not an accident.
class FFRadius {
  const FFRadius();
  double get xs => QuietRoomMetrics.radiusXs;
  double get sm => QuietRoomMetrics.radiusSm;
  double get md => QuietRoomMetrics.radiusMd;
  double get lg => QuietRoomMetrics.radiusLg;
  double get xl => QuietRoomMetrics.radiusXl;
  double get full => QuietRoomMetrics.radiusFull;
}

/// Two elevation layers only: paper (tone and hairline, no shadow at rest) and floating.
/// [D §4.3]
///
/// `sm` and `xs` were DELETED from the system. They are absent here rather than aliased,
/// so a call site that wants a resting shadow fails to compile instead of quietly getting
/// one. Dark carries elevation by tone and border only, so all three are empty in
/// Nightfall.
class FFShadows {
  const FFShadows(this.theme);
  final FlutterFlowTheme theme;

  /// Hover-lift only.
  List<BoxShadow> get md => theme.tokens.shadowMd;

  /// Nav, FAB, modal.
  List<BoxShadow> get lg => theme.tokens.shadowLg;

  /// The hero card only.
  List<BoxShadow> get hero => theme.tokens.shadowHero;
}

extension TextStyleHelper on TextStyle {
  TextStyle override({
    TextStyle? font,
    String? fontFamily,
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    FontStyle? fontStyle,
    bool useGoogleFonts = false,
    TextDecoration? decoration,
    double? lineHeight,
    List<Shadow>? shadows,
    String? package,
  }) {
    if (useGoogleFonts && fontFamily != null && fontFamily.isNotEmpty) {
      font = GoogleFonts.getFont(fontFamily,
          fontWeight: fontWeight ?? this.fontWeight,
          fontStyle: fontStyle ?? this.fontStyle);
    }

    return font != null
        ? font.copyWith(
            color: color ?? this.color,
            fontSize: fontSize ?? this.fontSize,
            letterSpacing: letterSpacing ?? this.letterSpacing,
            fontWeight: fontWeight ?? this.fontWeight,
            fontStyle: fontStyle ?? this.fontStyle,
            decoration: decoration,
            height: lineHeight,
            shadows: shadows,
          )
        : copyWith(
            fontFamily: fontFamily,
            package: package,
            color: color,
            fontSize: fontSize,
            letterSpacing: letterSpacing,
            fontWeight: fontWeight,
            fontStyle: fontStyle,
            decoration: decoration,
            height: lineHeight,
            shadows: shadows,
          );
  }
}

// HAND-MAINTAINED. Adopted under S3.
//
// The Quiet Room token layer, ported from the prototype's closed token system at
// habitcrafts-prototype-kl/prototype/css/tokens.css, which is itself traceable to
// docs/design-direction.md v2.0 (2026-09-26). Section refs below use that document's
// numbering: [D §n].
//
// THE PALETTE IS CLOSED. [D §6 veto list] No new colour may be added here or anywhere
// else in lib/. If a screen needs a colour that is not below, it needs a new *semantic*
// token mapped onto an existing raw value, not a new hex.
//
// The central rule the values encode: the room is quiet so that one object can be loud.
// Everything structural (canvas, surface, border, chrome) sits inside a narrow lightness
// band; the contrast budget is spent on text and on the single object that wants the
// person. [D §1]
//
// Contrast ratios in comments are carried from tokens.css, where they were computed with
// the WCAG 2.x relative luminance formula. Do not restate them elsewhere: one rule, one
// home.

import 'package:flutter/material.dart';

/// Raw Daylight palette. Declared once, never consumed by widgets directly.
/// Widgets read [QuietRoomTokens]. [D §1]
abstract final class Daylight {
  // Neutrals. A cool paper: the whole chrome sits within about 15 dL.
  static const canvas = Color(0xFFEEF0F1);
  static const canvasSunken = Color(0xFFE3E6E8);
  static const surface = Color(0xFFF8F9FA);
  static const surfaceRaised = Color(0xFFFFFFFF); // sheets and menus only
  static const surfaceTinted = Color(0xFFE2EAF0);
  static const border = Color(0xFFC4CACE); // 14.6 dL vs surface: the soft edge
  static const borderControl = Color(0xFF79858D); // 3.59:1 on surface
  static const borderFocus = Color(0xFF3D6B8A); // 5.01:1 vs canvas

  // Ink. Blue-grey, never neutral grey.
  static const inkStrong = Color(0xFF1C262C); // 13.48:1 vs canvas
  static const ink = Color(0xFF28333A); // 11.31:1 canvas / 12.26:1 surface
  static const inkMuted = Color(0xFF5A6771); // 5.08:1 canvas / 5.51:1 surface
  static const inkSubtle = Color(0xFF828E97); // 3.18:1 — NOT body text

  // Brand blue, the anchor ramp.
  static const brand50 = Color(0xFFF2F5F8);
  static const brand100 = Color(0xFFE2EAF0);
  static const brand200 = Color(0xFFC8D7E2);
  static const brand300 = Color(0xFFA6BFD0);
  static const brand400 = Color(0xFF7D9FB8); // decorative only
  static const brand500 = Color(0xFF4C7897); // white label = 4.73:1
  static const brand600 = Color(0xFF3D6B8A); // 5.01:1 interactive text, links
  static const brand700 = Color(0xFF2F5675); // HERO SURFACE, white on it 7.75:1
  static const brand800 = Color(0xFF26455E);
  static const brand900 = Color(0xFF1C262C);

  // Gold. Two values because it has two jobs: gold500 FILLS, gold700 MARKS. [D §4.6]
  // v1 used one value for both, which cannot work: a fill carrying ink must be light,
  // a mark on a light surface must be dark.
  static const gold300 = Color(0xFFE4CE93); // confetti, glow, chart fill
  static const gold400 = Color(0xFFDCB44A);
  static const gold500 = Color(0xFFD4A733); // gild FILL only, ink on it 5.77:1
  static const goldSurface = Color(0xFFF2E9D6);
  static const gold700 = Color(0xFF7A5B12); // gold TEXT, 5.51:1 canvas

  // Sage. Marks a kept day. It no longer fills a finished card. [D §4.7]
  static const sage100 = Color(0xFFE4EBE6);
  static const sage300 = Color(0xFFA8C0AE);
  static const sage500 = Color(0xFF5E8A6A); // decorative fill, NOT a boundary
  static const sage600 = Color(0xFF456C51); // 5.22:1 rings, checkmarks
  static const sage700 = Color(0xFF3A5C45);

  // Clay and amber: care, not alarm. Clay is the LOUD OBJECT colour.
  static const claySurface = Color(0xFFF1E5DF);
  static const clay600 = Color(0xFF8A5535); // 5.35:1 canvas
  static const amberSurface = Color(0xFFF3EBDA);
  static const amber700 = Color(0xFF856012); // 4.99:1 vs canvas
  static const amber750 = Color(0xFF7A570F);

  // Teal is RETIRED FROM THE UI. [D §4.4] Illustration compositions only.
  // Never a UI fill, never text, never a chart series.
  static const teal400 = Color(0xFF8FB3BE);
  static const teal650 = Color(0xFF3E6B76);
}

/// Raw Nightfall palette. Dark surfaces are tinted with the brand hue, never neutral
/// grey. The same compression applies: canvas to border spans about 12 dL, and gold at
/// roughly 58 dL against surface is the one thing in the room that shines. [D §1]
abstract final class Nightfall {
  static const canvas = Color(0xFF14191D);
  static const surface = Color(0xFF1B2127);
  static const surfaceRaised = Color(0xFF222931);
  static const surfaceTinted = Color(0xFF23303C);
  static const border = Color(0xFF2F373F); // 8.8 dL vs surface
  static const borderControl = Color(0xFF6A7885); // 3.59:1 on surface

  static const inkStrong = Color(0xFFE9EEF2); // 15.15:1 vs canvas
  static const ink = Color(0xFFD5DDE4); // 12.89:1 canvas / 11.82:1 surface
  static const inkMuted = Color(0xFF9BA8B3); // 6.68:1 vs surface
  static const inkSubtle = Color(0xFF7A8792); // 4.41:1 vs surface

  static const brand = Color(0xFF7FA8C6); // 7.01:1 canvas / 6.43:1 surface
  static const brand300 = Color(0xFF4E6E8C);
  static const brand400 = Color(0xFF6E93B4);
  static const brandHero = Color(0xFF22303D); // white on it 13.48:1
  static const brandHeroLate = Color(0xFF1A2530); // after-20:00 gradient end

  static const gold = Color(0xFFE3C065); // 9.27:1 vs surface
  static const goldSoft = Color(0xFFEBD08A);
  static const goldSurface = Color(0xFF2B2414);

  static const sage = Color(0xFF83A98D); // 6.20:1 vs surface
  static const sage300 = Color(0xFF3E5442);
  static const sageSurface = Color(0xFF1A2420);

  static const clay = Color(0xFFD18F77); // 6.11:1 vs surface
  static const claySurface = Color(0xFF2A1D18);
  static const amber = Color(0xFFD9AE62); // 7.87:1 vs surface
  static const amberSurface = Color(0xFF2A2416);
  static const teal = Color(0xFF77A8B4); // illustration only
}

/// The semantic layer. This is what widgets are allowed to read.
///
/// If you need a colour that is not on this interface, add a semantic token here and map
/// it onto an existing raw value in both implementations. Do not reach past this into
/// [Daylight] or [Nightfall].
abstract class QuietRoomTokens {
  const QuietRoomTokens();

  /// Resolves the token set for the ambient theme brightness.
  factory QuietRoomTokens.of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const NightfallTokens()
          : const DaylightTokens();

  bool get isDark;

  Color get canvas;
  Color get canvasSunken;
  Color get surface;
  Color get surfaceRaised;
  Color get surfaceTinted;
  Color get border;
  Color get borderControl;
  Color get borderFocus;

  Color get inkStrong;
  Color get ink;
  Color get inkMuted;
  Color get inkSubtle;

  Color get brand50;
  Color get brand100;
  Color get brand200;
  Color get brand300;
  Color get brand400;
  Color get brand500;
  Color get brand600;
  Color get brand700;
  Color get brand800;
  Color get brand900;

  Color get gold300;
  Color get gold400;
  Color get gold500;
  Color get gold700;
  Color get goldSurface;

  Color get sage100;
  Color get sage300;
  Color get sage500;
  Color get sage600;
  Color get sage700;

  Color get clay600;
  Color get claySurface;
  Color get amber700;
  Color get amber750;
  Color get amberSurface;

  /// Illustration only. Never a UI fill, never text, never a chart series. [D §4.4]
  Color get teal400;
  Color get teal650;

  /// The one deep-blue surface. Not Today's background any more. [D §4.8]
  Color get heroFill;
  Color get heroFillLate; // after-20:00 gradient stop [D §2.5]
  Color get heroInk;
  Color get heroInkMuted;
  Color get heroBorder;
  Color get onBrand;

  /// Label on a gold FILL. Deliberately not [ink]: in Nightfall ink is light and sits
  /// at 1.27:1 on gold.
  Color get onGold;

  Color get arcOnHero;
  Color get ringTrack;
  Color get ringStart; // hold t=0
  Color get ringEnd; // hold t=450
  Color get sparkA;
  Color get sparkB;

  /// The inversion. [D §4.7] A finished habit gives up its fill AND its border and
  /// recedes into the canvas, so the only cards still carrying contrast are the ones
  /// that still want the person.
  Color get doneSurface;
  Color get doneBorder;
  Color get doneInk;

  Color get illusLine;
  Color get scrim;

  /// Two elevation layers only: paper (tone and hairline, no shadow at rest) and
  /// floating. There is no `sm` and no `xs`; they were deleted from the system and must
  /// not be re-added. [D §4.3] Dark carries elevation by tone and border only, so every
  /// shadow below is null in Nightfall.
  List<BoxShadow> get shadowMd; // hover-lift only
  List<BoxShadow> get shadowLg; // nav, FAB, modal
  List<BoxShadow> get shadowHero; // hero card only
}

class DaylightTokens extends QuietRoomTokens {
  const DaylightTokens();

  @override
  bool get isDark => false;

  @override
  Color get canvas => Daylight.canvas;
  @override
  Color get canvasSunken => Daylight.canvasSunken;
  @override
  Color get surface => Daylight.surface;
  @override
  Color get surfaceRaised => Daylight.surfaceRaised;
  @override
  Color get surfaceTinted => Daylight.surfaceTinted;
  @override
  Color get border => Daylight.border;
  @override
  Color get borderControl => Daylight.borderControl;
  @override
  Color get borderFocus => Daylight.borderFocus;

  @override
  Color get inkStrong => Daylight.inkStrong;
  @override
  Color get ink => Daylight.ink;
  @override
  Color get inkMuted => Daylight.inkMuted;
  @override
  Color get inkSubtle => Daylight.inkSubtle;

  @override
  Color get brand50 => Daylight.brand50;
  @override
  Color get brand100 => Daylight.brand100;
  @override
  Color get brand200 => Daylight.brand200;
  @override
  Color get brand300 => Daylight.brand300;
  @override
  Color get brand400 => Daylight.brand400;
  @override
  Color get brand500 => Daylight.brand500;
  @override
  Color get brand600 => Daylight.brand600;
  @override
  Color get brand700 => Daylight.brand700;
  @override
  Color get brand800 => Daylight.brand800;
  @override
  Color get brand900 => Daylight.brand900;

  @override
  Color get gold300 => Daylight.gold300;
  @override
  Color get gold400 => Daylight.gold400;
  @override
  Color get gold500 => Daylight.gold500;
  @override
  Color get gold700 => Daylight.gold700;
  @override
  Color get goldSurface => Daylight.goldSurface;

  @override
  Color get sage100 => Daylight.sage100;
  @override
  Color get sage300 => Daylight.sage300;
  @override
  Color get sage500 => Daylight.sage500;
  @override
  Color get sage600 => Daylight.sage600;
  @override
  Color get sage700 => Daylight.sage700;

  @override
  Color get clay600 => Daylight.clay600;
  @override
  Color get claySurface => Daylight.claySurface;
  @override
  Color get amber700 => Daylight.amber700;
  @override
  Color get amber750 => Daylight.amber750;
  @override
  Color get amberSurface => Daylight.amberSurface;

  @override
  Color get teal400 => Daylight.teal400;
  @override
  Color get teal650 => Daylight.teal650;

  @override
  Color get heroFill => Daylight.brand700;
  @override
  Color get heroFillLate => Daylight.brand800;
  @override
  Color get heroInk => const Color(0xFFFFFFFF); // 8.23:1 on brand700
  @override
  Color get heroInkMuted => Daylight.brand100; // 7.04:1 on brand700
  @override
  Color get heroBorder => const Color(0x00000000);
  @override
  Color get onBrand => const Color(0xFFFFFFFF);
  @override
  Color get onGold => Daylight.ink; // 5.77:1

  @override
  Color get arcOnHero => Daylight.sage300; // 4.10:1 on brand700
  @override
  Color get ringTrack => Daylight.canvasSunken;
  @override
  Color get ringStart => Daylight.brand500;
  @override
  Color get ringEnd => Daylight.sage600;
  @override
  Color get sparkA => Daylight.sage500;
  @override
  Color get sparkB => Daylight.gold500;

  @override
  Color get doneSurface => Daylight.canvas; // recedes: no card of its own
  @override
  Color get doneBorder => const Color(0x00000000);
  @override
  Color get doneInk => Daylight.inkMuted; // 5.08:1 on canvas

  @override
  Color get illusLine => Daylight.brand700;
  @override
  Color get scrim => const Color(0x661C262C); // 40% ink-strong

  // Shadow colour is the ink hue, never neutral black. Alpha values are the CSS
  // fractions from tokens.css quantised to 8-bit: 0.09 -> 0x17, 0.13 -> 0x21,
  // 0.22 -> 0x38. `spreadRadius` carries the CSS negative spread, which is what keeps
  // these shadows from haloing.
  @override
  List<BoxShadow> get shadowMd => const [
        BoxShadow(
          color: Color(0x1716232F),
          offset: Offset(0, 6),
          blurRadius: 16,
          spreadRadius: -4,
        ),
      ];
  @override
  List<BoxShadow> get shadowLg => const [
        BoxShadow(
          color: Color(0x2116232F),
          offset: Offset(0, 14),
          blurRadius: 34,
          spreadRadius: -10,
        ),
      ];
  @override
  List<BoxShadow> get shadowHero => const [
        BoxShadow(
          color: Color(0x38325171),
          offset: Offset(0, 20),
          blurRadius: 48,
          spreadRadius: -16,
        ),
      ];
}

class NightfallTokens extends QuietRoomTokens {
  const NightfallTokens();

  @override
  bool get isDark => true;

  @override
  Color get canvas => Nightfall.canvas;
  @override
  Color get canvasSunken => Nightfall.surfaceRaised;
  @override
  Color get surface => Nightfall.surface;
  @override
  Color get surfaceRaised => Nightfall.surfaceRaised;
  @override
  Color get surfaceTinted => Nightfall.surfaceTinted;
  @override
  Color get border => Nightfall.border;
  @override
  Color get borderControl => Nightfall.borderControl;
  @override
  Color get borderFocus => Nightfall.brand;

  @override
  Color get inkStrong => Nightfall.inkStrong;
  @override
  Color get ink => Nightfall.ink;
  @override
  Color get inkMuted => Nightfall.inkMuted;
  @override
  Color get inkSubtle => Nightfall.inkSubtle;

  // The brand ramp collapses in dark: interactive steps all resolve to the one
  // accessible brand tint, structural steps to tinted surfaces.
  @override
  Color get brand50 => Nightfall.surface;
  @override
  Color get brand100 => Nightfall.surfaceTinted;
  @override
  Color get brand200 => Nightfall.border;
  @override
  Color get brand300 => Nightfall.brand300;
  @override
  Color get brand400 => Nightfall.brand400;
  @override
  Color get brand500 => Nightfall.brand;
  @override
  Color get brand600 => Nightfall.brand;
  @override
  Color get brand700 => Nightfall.brandHero;
  @override
  Color get brand800 => Nightfall.brandHeroLate;
  @override
  Color get brand900 => Nightfall.inkStrong;

  @override
  Color get gold300 => Nightfall.goldSoft;
  @override
  Color get gold400 => Nightfall.gold;
  @override
  Color get gold500 => Nightfall.gold;
  @override
  Color get gold700 => Nightfall.gold; // gold TEXT is legible in dark
  @override
  Color get goldSurface => Nightfall.goldSurface;

  @override
  Color get sage100 => Nightfall.sageSurface;
  @override
  Color get sage300 => Nightfall.sage300;
  @override
  Color get sage500 => Nightfall.sage;
  @override
  Color get sage600 => Nightfall.sage;
  @override
  Color get sage700 => Nightfall.sage;

  @override
  Color get clay600 => Nightfall.clay;
  @override
  Color get claySurface => Nightfall.claySurface;
  @override
  Color get amber700 => Nightfall.amber;
  @override
  Color get amber750 => Nightfall.amber;
  @override
  Color get amberSurface => Nightfall.amberSurface;

  @override
  Color get teal400 => Nightfall.teal;
  @override
  Color get teal650 => Nightfall.teal;

  @override
  Color get heroFill => Nightfall.brandHero;
  @override
  Color get heroFillLate => Nightfall.brandHeroLate;
  @override
  Color get heroInk => const Color(0xFFFFFFFF);
  @override
  Color get heroInkMuted => const Color(0xFFC4D6E6);
  @override
  Color get heroBorder => Nightfall.border;
  @override
  Color get onBrand => Nightfall.canvas; // 8.44:1
  @override
  Color get onGold => Nightfall.canvas; // 10.11:1

  @override
  Color get arcOnHero => Nightfall.sage; // 5.0:1 on brandHero
  @override
  Color get ringTrack => Nightfall.surfaceRaised;
  @override
  Color get ringStart => Nightfall.brand;
  @override
  Color get ringEnd => Nightfall.sage;
  @override
  Color get sparkA => Nightfall.sage;
  @override
  Color get sparkB => Nightfall.gold;

  @override
  Color get doneSurface => Nightfall.canvas;
  @override
  Color get doneBorder => const Color(0x00000000);
  @override
  Color get doneInk => Nightfall.inkMuted; // 7.29:1 on canvas

  @override
  Color get illusLine => Nightfall.brand;
  @override
  Color get scrim => const Color(0x8C04080C); // 55%

  // No shadows in dark. Elevation is tone and border only. [D §4.3]
  @override
  List<BoxShadow> get shadowMd => const [];
  @override
  List<BoxShadow> get shadowLg => const [];
  @override
  List<BoxShadow> get shadowHero => const [];
}

/// Spacing, radius and stroke. Everything sits on the 8px baseline grid; 12 is the one
/// half-step. This scale retires the app's nine drifting radius values.
abstract final class QuietRoomMetrics {
  static const space4 = 4.0;
  static const space8 = 8.0;
  static const space12 = 12.0;
  static const space16 = 16.0;
  static const space24 = 24.0;
  static const space32 = 32.0;
  static const space48 = 48.0;
  static const space64 = 64.0;

  static const radiusXs = 8.0;
  static const radiusSm = 12.0;
  static const radiusMd = 16.0; // habit card, all cards
  static const radiusLg = 24.0; // sheets, modals, floating nav bar
  static const radiusXl = 32.0;
  static const radiusFull = 999.0;

  static const strokeHairline = 1.0;
  static const strokeControl = 1.5;
  static const strokeRing = 3.0;
  static const strokeFocus = 2.0;

  /// One number satisfying WCAG 2.5.8 AA (24), 2.5.5 AAA (44), Apple 44pt and
  /// Material 48dp.
  static const targetMin = 48.0;

  /// The direction sets a 24px screen gutter on mobile. [D §3 global rules]
  static const gutter = 24.0;

  /// 🚨 Content must be CONSTRAINED. [D §5.3] "Desktop web must be a different layout,
  /// not a bigger phone." These screens were built to the 390x844 artboards; run
  /// unconstrained at desktop width, a full-width brand button stops being one loud
  /// object and becomes a wall. Capping is the floor, not the answer: §5.3 wants a real
  /// bento at 1280 and a nav rail above 600, which is separate work.
  static const readMax = 600.0; // reading column, about 60ch
  static const contentMax = 1184.0;
  static const shellMax = 1440.0;
}

/// Motion. Durations are verbatim from the direction; Flutter has real springs, so the
/// CSS bezier approximations are not carried over. Curves here are the non-spring ones.
///
/// LAW: never apply a spatial spring to a colour or opacity transition. The overshoot
/// produces a visible tint wobble. Use [standard] for colour.
abstract final class QuietRoomMotion {
  static const micro = Duration(milliseconds: 120);
  static const quick = Duration(milliseconds: 180);
  static const base = Duration(milliseconds: 260);
  static const moderate = Duration(milliseconds: 340);
  static const slow = Duration(milliseconds: 420);
  static const celebrate = Duration(milliseconds: 900);
  static const milestone = Duration(milliseconds: 1600);

  /// Signature-moment timings. [D §2.1–2.4]
  static const hold = Duration(milliseconds: 450); // press-and-hold to check in
  static const press = Duration(milliseconds: 120); // card 1.0 -> 0.97
  static const checkmark = Duration(milliseconds: 200);
  static const particles = Duration(milliseconds: 400);
  static const cardTone = Duration(milliseconds: 240);
  static const echoIn = Duration(milliseconds: 240);
  static const echoDwell = Duration(milliseconds: 5000);
  static const arcStep = Duration(milliseconds: 260);
  static const arcGlint = Duration(milliseconds: 600);
  static const arcFlush = Duration(milliseconds: 300);
  static const reorder = Duration(milliseconds: 260);

  /// The one permitted loop: the empty-state leaf drift.
  static const drift = Duration(milliseconds: 4000);

  /// The spring-bounce release peak. [D §2.1]
  static const overshoot = 1.08;

  static const standard = Cubic(0.2, 0, 0, 1);
  static const enter = Cubic(0.05, 0.7, 0.1, 1);
  static const exit = Cubic(0.3, 0, 0.8, 0.15);
  static const emphasized = Cubic(0.2, 0, 0, 1);
}

// HAND-WRITTEN. Not FlutterFlow output, so S3 has nothing to adopt.
//
// Shared pieces for the Japanese study screens: one loader for
// assets/lessons/jp_grammar.json (written by pipeline/jp/publish.py, never by hand)
// and the few Quiet Room building blocks every study screen repeats.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/flutter_flow/quiet_room.dart';

/// Loaded once per app run. Every study screen reads the same file, so a second load
/// would only parse the same 200 KB again.
class JpGrammarData {
  static Future<Map<String, dynamic>>? _doc;

  static Future<Map<String, dynamic>> load() => _doc ??= rootBundle
      .loadString('assets/lessons/jp_grammar.json')
      .then((raw) => json.decode(raw) as Map<String, dynamic>);
}

/// Mari's own tracking columns (after class, can use it, review needed), kept on the
/// phone. There is no login in this build, so there is no account to sync them to.
class SelfCheck {
  static const _prefix = 'jp.selfcheck.';

  static Future<String?> get(String id) async =>
      (await SharedPreferences.getInstance()).getString('$_prefix$id');

  static Future<void> set(String id, String? value) async {
    final p = await SharedPreferences.getInstance();
    value == null
        ? await p.remove('$_prefix$id')
        : await p.setString('$_prefix$id', value);
  }
}

TextStyle qrTitle(QuietRoomTokens t, {double size = 26}) =>
    GoogleFonts.fraunces(
      fontSize: size,
      fontWeight: FontWeight.w600,
      letterSpacing: size * -0.015,
      height: 1.15,
      color: t.inkStrong,
    );

TextStyle qrText(QuietRoomTokens t,
        {double size = 14,
        Color? color,
        FontWeight weight = FontWeight.w400,
        double height = 1.4}) =>
    GoogleFonts.schibstedGrotesk(
        fontSize: size,
        fontWeight: weight,
        height: height,
        color: color ?? t.ink);

/// Canvas ground, a back arrow, and content held to the reading width.
class QrStudyScaffold extends StatelessWidget {
  const QrStudyScaffold({super.key, required this.child, this.showBack = true});

  final Widget child;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final t = QuietRoomTokens.of(context);
    return Scaffold(
      backgroundColor: t.canvas,
      appBar: showBack
          ? AppBar(
              backgroundColor: t.canvas,
              surfaceTintColor: t.canvas,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: t.ink, size: 22),
                onPressed: () => Navigator.of(context).maybePop(),
                tooltip: 'Back',
              ),
            )
          : null,
      body: SafeArea(
        top: !showBack,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: QuietRoomMetrics.readMax),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A load that fails says so. An empty screen with no reason is a silent failure (S4).
class QrLoad extends StatelessWidget {
  const QrLoad({super.key, required this.builder});

  final Widget Function(BuildContext, Map<String, dynamic>) builder;

  @override
  Widget build(BuildContext context) {
    final t = QuietRoomTokens.of(context);
    return FutureBuilder<Map<String, dynamic>>(
      future: JpGrammarData.load(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
              child: Text('Could not load the grammar lessons.',
                  style: qrText(t, color: t.clay600)));
        }
        if (!snap.hasData) {
          return Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(t.inkSubtle)),
            ),
          );
        }
        return builder(context, snap.data!);
      },
    );
  }
}

/// Surface card with a hairline and no shadow at rest [direction §4.3].
class QrCard extends StatelessWidget {
  const QrCard(
      {super.key,
      required this.child,
      this.onTap,
      this.color,
      this.borderColor});

  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final t = QuietRoomTokens.of(context);
    final box = Container(
      constraints: const BoxConstraints(minHeight: QuietRoomMetrics.targetMin),
      decoration: BoxDecoration(
        color: color ?? t.surface,
        border: Border.all(color: borderColor ?? t.border, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
      child: child,
    );
    if (onTap == null) return box;
    return Material(
      color: Colors.transparent,
      child: InkWell(
          borderRadius: BorderRadius.circular(12), onTap: onTap, child: box),
    );
  }
}

/// A horizontal strip of numbered pills, the same control as the vocabulary screen.
class QrNumberStrip extends StatelessWidget {
  const QrNumberStrip(
      {super.key,
      required this.values,
      required this.selected,
      required this.onSelect});

  final List<int> values;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (context, i) {
          final on = values[i] == selected;
          return QrPill(
              label: '${values[i]}', on: on, onTap: () => onSelect(values[i]));
        },
      ),
    );
  }
}

class QrPill extends StatelessWidget {
  const QrPill(
      {super.key,
      required this.label,
      required this.on,
      required this.onTap,
      this.solid = true});

  final String label;
  final bool on;
  final VoidCallback onTap;

  /// Solid = a selection in a sequence (lesson number). Tinted = a filter.
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final t = QuietRoomTokens.of(context);
    final fill = on ? (solid ? t.brand600 : t.surfaceTinted) : t.surface;
    final ink = on ? (solid ? t.onBrand : t.brand600) : t.inkMuted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        // No Container alignment here: inside a Wrap it would stretch the pill to the
        // full row width. A min-size Row centers the label and keeps the pill snug.
        child: Container(
          constraints: const BoxConstraints(minWidth: 40, minHeight: 36),
          decoration: BoxDecoration(
            color: fill,
            border: Border.all(color: on ? t.brand600 : t.border, width: 1),
            borderRadius: BorderRadius.circular(999),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  style: qrText(t,
                      size: 13.5,
                      color: ink,
                      weight: on ? FontWeight.w600 : FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The legend from the source sheet, in Quiet Room color. The color is data: it says
/// which readings change sound and which are words to learn whole.
class ReadingMark {
  static Color fill(QuietRoomTokens t, String mark) => switch (mark) {
        'sound_change' => t.amberSurface,
        'special' => t.surfaceTinted,
        _ => t.surface,
      };

  static Color ink(QuietRoomTokens t, String mark) => switch (mark) {
        'sound_change' => t.amber700,
        'special' => t.brand600,
        _ => t.ink,
      };

  static String label(String mark) => switch (mark) {
        'sound_change' => 'sound change',
        'special' => 'special reading',
        _ => '',
      };
}

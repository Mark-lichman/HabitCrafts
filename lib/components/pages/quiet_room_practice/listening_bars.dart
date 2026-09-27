// HAND-WRITTEN. Not FlutterFlow output, so S3 has nothing to adopt.
//
// The microphone indicator: a symmetric row of bars that rises and falls with the voice it
// is hearing. The shape follows the reference Mark picked out -- the audio-visualiser
// spectrum of the podcast/voice-recording genre -- rather than the ripples it replaces.
//
// 🚨 IT TELLS THE TRUTH OR IT SAYS NOTHING, and this is the part that is easy to get wrong.
// Stock visualisers of this kind are LOOPS: they animate on a timer whether or not anyone
// is speaking, because they are decoration over a finished recording. This one is driven by
// live amplitude, so:
//
//   * silence collapses every bar to a flat row of dots -- the resting state, not a hold
//     frame of a loop;
//   * where no amplitude exists at all the row stays flat and dim and the caption says
//     "Listening", never "Hearing you".
//
// What is honest and what is decoration, stated plainly. The AMOUNT of movement is real
// amplitude. The DISTRIBUTION across the bars is not a spectrum -- `speech_to_text` gives
// one scalar, not an FFT -- so bar-to-bar variation comes from a fixed per-bar envelope
// plus a slow phase offset, scaled by that real amplitude. That is the same licence the
// genre takes, and it is why the bars must never move when the scalar is zero: the shape is
// invented, the presence and size of the motion are not.
//
// 🚨 `live` is DISCOVERED, not declared. An earlier version took it as a constructor flag
// read once when the panel mounted, but the first level arrives after that, so it was
// permanently false and the indicator never came alive even on Android.

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;

import '/flutter_flow/quiet_room.dart';

class ListeningBars extends StatefulWidget {
  const ListeningBars({
    super.key,
    required this.level,
    this.onRealDetected,
    this.height = 56,
    this.barCount = 33,
  });

  /// 0..1 amplitude. Stays at 0 where the platform reports nothing.
  final ValueListenable<double> level;

  /// Fires once, when genuine microphone data first arrives.
  final VoidCallback? onRealDetected;

  final double height;

  /// Odd, so one bar sits exactly on the centre line and the row is truly symmetric.
  final int barCount;

  @override
  State<ListeningBars> createState() => _ListeningBarsState();
}

class _ListeningBarsState extends State<ListeningBars>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final List<double> _heights;
  late final List<double> _phase;

  Duration _now = Duration.zero;
  double _smoothed = 0;
  bool _sawReal = false;

  @override
  void initState() {
    super.initState();
    final n = widget.barCount;
    _heights = List<double>.filled(n, 0);
    // A fixed irregular phase per bar. Deterministic seed so the row looks identical every
    // time the panel opens; neighbours differ enough that they never march in lockstep,
    // which is what makes a bar row read as sound rather than as a loading spinner.
    final rnd = math.Random(7);
    _phase = List<double>.generate(n, (_) => rnd.nextDouble() * math.pi * 2);
    _ticker = createTicker(_tick)..start();
  }

  /// Centre-weighted envelope: the middle bars can reach full height, the outer ones taper.
  /// Gives the row a shaped silhouette instead of a flat block.
  double _envelope(int i) {
    final mid = (widget.barCount - 1) / 2;
    final d = (i - mid).abs() / mid; // 0 centre, 1 edge
    return 0.32 + 0.68 * math.pow(1 - d * d, 0.9).toDouble();
  }

  void _tick(Duration elapsed) {
    _now = elapsed;
    final raw = widget.level.value.clamp(0.0, 1.0);
    if (raw > 0.02 && !_sawReal) {
      _sawReal = true;
      widget.onRealDetected?.call();
    }
    // Rise quickly so a syllable registers; fall gently so the row settles between words
    // rather than snapping shut.
    _smoothed += (raw - _smoothed) * (raw > _smoothed ? 0.45 : 0.10);

    final tSec = _now.inMilliseconds / 1000.0;
    for (var i = 0; i < _heights.length; i++) {
      // Two slow waves at different rates keep the variation from looking periodic.
      final wobble = 0.58 +
          0.42 *
              (0.5 +
                  0.5 *
                      math.sin(tSec * 7.0 + _phase[i]) *
                      math.cos(tSec * 2.3 + _phase[i] * 0.5));
      final target = _smoothed * _envelope(i) * wobble;
      // Per-bar smoothing, slightly staggered, so the row does not move as one object.
      final attack = 0.42 + (i % 3) * 0.06;
      _heights[i] +=
          (target - _heights[i]) * (target > _heights[i] ? attack : 0.14);
    }

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = QuietRoomTokens.of(context);
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: CustomPaint(
        painter: _BarsPainter(
          heights: reduce ? List<double>.filled(_heights.length, 0) : _heights,
          live: _sawReal,
          colour: t.brand600,
          idle: t.border,
        ),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.heights,
    required this.live,
    required this.colour,
    required this.idle,
  });

  final List<double> heights;
  final bool live;
  final Color colour;
  final Color idle;

  /// The resting dot: the same small mark as the 14 dots of the Today day row, so silence
  /// reads as a familiar quiet row rather than as a dead meter.
  static const _minHeight = 3.0;

  static const _maxBarWidth = 5.0;
  static const _minBarWidth = 2.0;

  /// The row stays ONE OBJECT rather than stretching edge to edge. Letting it span a wide
  /// desktop panel would either fatten the bars into slabs or open the gaps until the row
  /// stopped reading as a single thing; capping it keeps the same considered shape at every
  /// width, which is what the rest of the direction does with its 600px reading measure.
  static const _maxSpan = 320.0;

  @override
  void paint(Canvas canvas, Size size) {
    final n = heights.length;
    final span = math.min(size.width * 0.92, _maxSpan);
    final pitch = span / n;
    final w = (pitch * 0.5).clamp(_minBarWidth, _maxBarWidth);
    final g = pitch - w;
    final left = (size.width - (n * w + (n - 1) * g)) / 2;
    final midY = size.height / 2;
    final maxHalf = size.height / 2;

    for (var i = 0; i < n; i++) {
      final h = (_minHeight + heights[i] * (size.height - _minHeight))
          .clamp(_minHeight, size.height);
      final half = (h / 2).clamp(_minHeight / 2, maxHalf);
      final x = left + i * (w + g);
      // Bars grow from the centre line outward, so the row stays balanced about its axis
      // the way the reference does, rather than sitting on a baseline.
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTRB(x, midY - half, x + w, midY + half),
        Radius.circular(w / 2),
      );
      // Taller bars sit at full strength; the resting dots stay quiet so silence is calm.
      final lift = (heights[i] * 3).clamp(0.0, 1.0);
      canvas.drawRRect(
        rect,
        Paint()
          ..color = live
              ? Color.lerp(colour.withValues(alpha: 0.28), colour, lift)!
              : idle.withValues(alpha: 0.55),
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) => true; // driven by a ticker
}

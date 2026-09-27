// HAND-WRITTEN. Not FlutterFlow output, so S3 has nothing to adopt.
//
// The Quiet Room Today screen, built to the ClientDay / ClientNight artboards on the
// "HabitCrafts Coach Dashboard" canvas. Those two boards are structurally identical and
// differ only in colour, which is why this is one widget reading the theme rather than
// two screens.
//
// THE INVERSION [direction §4.7] is the load-bearing idea and the thing most likely to
// be "fixed" by someone who does not know it is deliberate: a habit that is DONE gives
// up its surface AND its border and recedes into the canvas. Only the habits that still
// want the person carry contrast, so the screen empties as the day succeeds. Do not give
// a completed card a fill, a tick badge, or a colour. That is the old behaviour and it
// made completion the loudest event on the screen.
//
// No deep-blue hero here either [§4.8]: at ~51 dL it would outshout the habit that still
// needs doing.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_fonts/google_fonts.dart';

import '/backend/backend.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/quiet_room.dart';
import '/components/pages/quiet_room_lesson/quiet_room_lesson_widget.dart';
import '/components/pages/create_habit_page/create_habit_page_widget.dart';

class QuietRoomTodayWidget extends StatefulWidget {
  const QuietRoomTodayWidget({super.key});

  static String routeName = 'quietRoomToday';
  static String routePath = '/quietRoomToday';

  @override
  State<QuietRoomTodayWidget> createState() => _QuietRoomTodayWidgetState();
}

class _QuietRoomTodayWidgetState extends State<QuietRoomTodayWidget> {
  Map<String, dynamic>? _lesson;

  @override
  void initState() {
    super.initState();
    _loadLesson();
  }

  Future<void> _loadLesson() async {
    try {
      final raw = await rootBundle.loadString('assets/lessons/jp_lessons.json');
      if (mounted)
        setState(() => _lesson = json.decode(raw) as Map<String, dynamic>);
    } catch (_) {
      // A missing bundled lesson is not worth failing the screen for; the card simply
      // does not render. Silent here is deliberate and bounded, not a swallowed error:
      // the only consequence is one absent card.
    }
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Consecutive days ending today or yesterday. Yesterday counts so a streak is not
  /// reported as broken before the person has had their day.
  static int _streak(List<DateTime> done) {
    if (done.isEmpty) return 0;
    final days = done.map((d) => DateTime(d.year, d.month, d.day)).toSet();
    var cursor = DateTime.now();
    cursor = DateTime(cursor.year, cursor.month, cursor.day);
    if (!days.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!days.contains(cursor)) return 0;
    }
    var n = 0;
    while (days.contains(cursor)) {
      n++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final t = QuietRoomTokens.of(context);

    return Scaffold(
      backgroundColor: t.canvas,
      body: SafeArea(
        child: StreamBuilder<List<HabitsRecord>>(
          stream: queryHabitsRecord(
            queryBuilder: (h) => h
                .where('user', isEqualTo: currentUserReference)
                .where('is_finished', isEqualTo: false),
          ),
          builder: (context, snapshot) {
            final habits = snapshot.data ?? const <HabitsRecord>[];
            final today = DateTime.now();
            final doneCount = habits
                .where((h) => h.complete.any((d) => _sameDay(d, today)))
                .length;
            final remaining = habits.length - doneCount;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                            maxWidth: QuietRoomMetrics.readMax),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _wordmark(t),
                            const SizedBox(height: 18),
                            _greeting(t, habits.length, doneCount, remaining),
                            const SizedBox(height: 18),
                            if (snapshot.hasData) ...[
                              ...habits.map((h) => Padding(
                                    padding: const EdgeInsets.only(bottom: 9),
                                    child: _habitCard(t, h, today),
                                  )),
                              _addHabit(t, first: habits.isEmpty),
                            ],
                            if (!snapshot.hasData)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          t.inkSubtle),
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 9),
                            if (_lesson != null) _lessonCard(t),
                            const SizedBox(height: 18),
                            _dayDots(t, habits),
                            const SizedBox(height: 22),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                _bottomNav(t),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _wordmark(QuietRoomTokens t) => Row(
        children: [
          Image.asset('assets/images/Habit_Craft_Logo_File-06.png',
              width: 30, height: 30, fit: BoxFit.contain),
          const SizedBox(width: 7),
          Text(
            'HabitCrafts',
            style: GoogleFonts.fraunces(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 14 * -0.005,
              color: t.inkMuted,
            ),
          ),
        ],
      );

  Widget _greeting(QuietRoomTokens t, int total, int done, int remaining) {
    final hour = DateTime.now().hour;
    final part = hour < 12 ? 'morning' : (hour < 18 ? 'afternoon' : 'evening');
    final name = (currentUserDisplayName).split(' ').first;
    final sub = total == 0
        ? 'Nothing set up yet.'
        : (remaining == 0
            ? "That's everything. Go enjoy your day."
            : '$remaining left today.');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? 'Good $part' : 'Good $part, $name',
                style: GoogleFonts.fraunces(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 26 * -0.015,
                  height: 1.15,
                  color: t.inkStrong,
                ),
              ),
              const SizedBox(height: 5),
              Text(sub,
                  style: GoogleFonts.schibstedGrotesk(
                      fontSize: 14, color: t.inkMuted)),
            ],
          ),
        ),
        const SizedBox(width: 14),
        if (total > 0)
          SizedBox(
            width: 54,
            height: 54,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(54, 54),
                  painter: _ArcPainter(
                    progress: total == 0 ? 0 : done / total,
                    track: t.canvasSunken,
                    fill: t.sage600,
                  ),
                ),
                Text('$done/$total',
                    style: GoogleFonts.fraunces(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: t.ink)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _habitCard(QuietRoomTokens t, HabitsRecord h, DateTime today) {
    final done = h.complete.any((d) => _sameDay(d, today));
    final streak = _streak(h.complete);
    final gilded = streak >= 365;

    final when = [
      if (h.prompt.isNotEmpty) h.prompt,
      if (streak > 0) 'kept $streak ${streak == 1 ? 'day' : 'days'}',
    ].join(' · ');

    return Container(
      decoration: BoxDecoration(
        // The inversion. A done habit takes the canvas and loses its edge.
        color: done ? t.doneSurface : t.surface,
        border: Border.all(color: done ? t.doneBorder : t.border, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        h.behavior,
                        style: GoogleFonts.schibstedGrotesk(
                          fontSize: 15.5,
                          height: 1.3,
                          letterSpacing: 15.5 * -0.005,
                          fontWeight: done ? FontWeight.w500 : FontWeight.w600,
                          color: done ? t.doneInk : t.inkStrong,
                        ),
                      ),
                    ),
                    if (gilded) ...[
                      const SizedBox(width: 7),
                      // Gold is not decoration: it is what long-kept things earn. [§4.6]
                      CustomPaint(
                          size: const Size(13, 13),
                          painter: _GildPainter(t.gold700)),
                    ],
                  ],
                ),
                if (when.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(when,
                      style: GoogleFonts.schibstedGrotesk(
                          fontSize: 12.5, color: t.inkMuted)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 13),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? Colors.transparent : t.surface,
              border: Border.all(
                color: done ? t.sage600 : t.borderControl,
                width: done ? 1.5 : 2.5,
              ),
            ),
            child: done
                ? Center(
                    child: CustomPaint(
                        size: const Size(17, 17),
                        painter: _CheckPainter(t.sage600)))
                : null,
          ),
        ],
      ),
    );
  }

  /// Creating a habit. The ClientDay artboard has no such control because it depicts a
  /// COACHED client whose habits are proposed for them; this app's users make their own,
  /// so the screen needs one and the artboard cannot be followed literally here.
  ///
  /// Two weights on purpose. With no habits yet, creating one IS the thing that wants the
  /// person, so it takes the loud treatment. Once habits exist they are the subject of the
  /// screen, and a permanent saturated button beside them would be a second loud object,
  /// which [direction §1] vetoes. It drops back to a hairline row at the end of the list.
  Widget _addHabit(QuietRoomTokens t, {required bool first}) {
    void open() => context.pushNamed(CreateHabitPageWidget.routeName);

    if (first) {
      return Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 4),
        child: SizedBox(
          width: double.infinity,
          height: QuietRoomMetrics.targetMin,
          child: ElevatedButton.icon(
            onPressed: open,
            icon: Icon(Icons.add, size: 20, color: t.onBrand),
            label: Text('Add your first habit',
                style: GoogleFonts.schibstedGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: t.onBrand)),
            style: ElevatedButton.styleFrom(
              backgroundColor: t.brand600,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(QuietRoomMetrics.radiusMd)),
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: open,
        child: Container(
          constraints:
              const BoxConstraints(minHeight: QuietRoomMetrics.targetMin),
          decoration: BoxDecoration(
            border: Border.all(color: t.border, width: 1),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
          child: Row(
            children: [
              Icon(Icons.add, size: 19, color: t.inkMuted),
              const SizedBox(width: 11),
              Text('Add a habit',
                  style: GoogleFonts.schibstedGrotesk(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: t.inkMuted)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lessonCard(QuietRoomTokens t) {
    final l = _lesson!;
    final lessons = (l['lessons'] as List?) ?? const [];
    final latest =
        lessons.isEmpty ? null : lessons.last as Map<String, dynamic>;
    final count = latest == null ? 0 : (latest['items'] as List).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DAILY LESSON',
          style: GoogleFonts.schibstedGrotesk(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 11 * 0.07,
            color: t.inkMuted,
          ),
        ),
        const SizedBox(height: 7),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const QuietRoomLessonWidget()),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: t.surfaceTinted,
                border: Border.all(color: t.border, width: 1),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          latest == null
                              ? 'Vocabulary'
                              : '第${latest['lesson']}課 vocabulary',
                          style: GoogleFonts.schibstedGrotesk(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                            color: t.inkStrong,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${l['course']} · $count words',
                          style: GoogleFonts.schibstedGrotesk(
                              fontSize: 12.5, color: t.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 18, color: t.brand600),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Fourteen days, from real check-in history. A day counts as kept when any habit was
  /// completed on it. Missed days are drawn small and faint on purpose: a miss is not a
  /// verdict. [§7.5]
  Widget _dayDots(QuietRoomTokens t, List<HabitsRecord> habits) {
    final all = <DateTime>{};
    for (final h in habits) {
      for (final d in h.complete) {
        all.add(DateTime(d.year, d.month, d.day));
      }
    }
    final now = DateTime.now();
    final days = List.generate(14, (i) {
      final d = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: 13 - i));
      return all.contains(d);
    });
    final kept = days.where((k) => k).length;

    return Row(
      children: [
        ...days.map((k) => Padding(
              padding: const EdgeInsets.only(right: 5),
              child: Container(
                width: k ? 9 : 5,
                height: k ? 9 : 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: k ? t.sage600 : t.border,
                ),
              ),
            )),
        const SizedBox(width: 6),
        Text('$kept of 14 days kept',
            style: GoogleFonts.schibstedGrotesk(
                fontSize: 12.5, color: t.inkMuted)),
      ],
    );
  }

  Widget _bottomNav(QuietRoomTokens t) => Container(
        height: 64,
        decoration: BoxDecoration(
          color: t.surface,
          border: Border(top: BorderSide(color: t.border, width: 1)),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: QuietRoomMetrics.readMax),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(t, Icons.home_outlined, 'Today', true, null),
                _navItem(t, Icons.menu_book_outlined, 'Library', false,
                    'libraryPage'),
                _navItem(t, Icons.bar_chart_outlined, 'Progress', false,
                    'progressPage'),
                _navItem(t, Icons.person_outline, 'You', false, 'profilePage'),
              ],
            ),
          ),
        ),
      );

  Widget _navItem(QuietRoomTokens t, IconData icon, String label, bool active,
      String? route) {
    final c = active ? t.ink : t.inkMuted;
    return Semantics(
      selected: active,
      child: InkWell(
        onTap: active || route == null ? null : () => context.pushNamed(route),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: c),
              const SizedBox(height: 3),
              Text(label,
                  style: GoogleFonts.schibstedGrotesk(
                      fontSize: 11,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      color: c)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The 270-degree progress arc from the artboard: open at the bottom, round caps.
class _ArcPainter extends CustomPainter {
  _ArcPainter(
      {required this.progress, required this.track, required this.fill});

  final double progress;
  final Color track;
  final Color fill;

  static const _start = 2.3561944901923448; // 135 degrees
  static const _sweep = 4.71238898038469; // 270 degrees

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * (5 / 72);
    final rect = Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawArc(rect, _start, _sweep, false, base);
    if (progress > 0) {
      canvas.drawArc(rect, _start, _sweep * progress.clamp(0.0, 1.0), false,
          base..color = fill);
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress || old.track != track || old.fill != fill;
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 20;
    final p = Path()
      ..moveTo(4 * s, 10.5 * s)
      ..lineTo(8 * s, 14.5 * s)
      ..lineTo(16 * s, 5.5 * s);
    canvas.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4 * s
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.color != color;
}

class _GildPainter extends CustomPainter {
  _GildPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 16;
    final c = Offset(8 * s, 8 * s);
    canvas.drawCircle(
      c,
      6 * s,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 * s
        ..color = color,
    );
    canvas.drawCircle(c, 2.4 * s, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_GildPainter old) => old.color != color;
}

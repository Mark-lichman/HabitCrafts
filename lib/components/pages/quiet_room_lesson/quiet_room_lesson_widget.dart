// HAND-WRITTEN. Not FlutterFlow output, so S3 has nothing to adopt.
//
// The Japanese vocabulary screen, in the Quiet Room material. It renders
// assets/lessons/jp_lessons.json: 620 words across 25 lessons, extracted from the real
// Langoal word-list PDFs rather than typed by hand.
//
// NO ROMAJI, BY DESIGN. The sheets print kana, romaji and a gloss with no labels, and
// reading order does not say which Latin string is which. Rather than keep a field the
// sheets spell inconsistently (mīthingu for ミーティング, yotē for よてい) the extractor
// romanises the kana itself, uses that only to identify and DISCARD the printed romaji,
// and keeps kana and English. A learner reading kana is the point; a crutch spelled
// three different ways across one course is not.
//
// LESSONS 1, 18, 19, 20 AND 21 ARE ABSENT AND THE SCREEN SAYS SO. There is no Langoal
// sheet for 19, and the Minna slide decks covering the other four scramble under
// extraction (lesson 20 pairs しゅうり with "denwa, repair, call"). A stated gap is
// honest; silently shipping wrong vocabulary is not. Do not "fix" this by re-adding
// those decks without solving the multi-item page problem first.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_fonts/google_fonts.dart';

import '/flutter_flow/quiet_room.dart';
import '/components/pages/quiet_room_practice/quiet_room_practice_widget.dart';
import '/components/pages/quiet_room_practice/speech_service.dart';

class QuietRoomLessonWidget extends StatefulWidget {
  const QuietRoomLessonWidget({super.key, this.initialLesson});

  final int? initialLesson;

  static String routeName = 'quietRoomLesson';
  static String routePath = '/quietRoomLesson';

  @override
  State<QuietRoomLessonWidget> createState() => _QuietRoomLessonWidgetState();
}

class _QuietRoomLessonWidgetState extends State<QuietRoomLessonWidget> {
  Map<String, dynamic>? _doc;
  String? _error;
  int? _lesson;
  int _filter = 0; // 0 all, 1 verbs, 2 pairs

  /// Which cards have been turned over. Keyed by position, not by kana: a lesson can
  /// list the same word twice for two senses (lesson 30 has まとめます as both "put ~
  /// together" and "sum up"), and keying by text would flip both at once.
  final Set<int> _revealed = <int>{};

  @override
  void initState() {
    super.initState();
    _lesson = widget.initialLesson;
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString('assets/lessons/jp_lessons.json');
      final d = json.decode(raw) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _doc = d;
        final ls = (d['lessons'] as List).cast<Map<String, dynamic>>();
        _lesson ??= ls.isEmpty ? null : ls.last['lesson'] as int;
      });
    } catch (_) {
      // Surfaced, not swallowed: an empty screen with no explanation is a silent
      // failure, which S4 forbids.
      if (mounted) setState(() => _error = 'Could not load the vocabulary.');
    }
  }

  List<Map<String, dynamic>> get _lessons =>
      ((_doc?['lessons'] as List?) ?? const []).cast<Map<String, dynamic>>();

  Map<String, dynamic>? get _current {
    for (final l in _lessons) {
      if (l['lesson'] == _lesson) return l;
    }
    return _lessons.isEmpty ? null : _lessons.last;
  }

  @override
  Widget build(BuildContext context) {
    final t = QuietRoomTokens.of(context);
    return Scaffold(
      backgroundColor: t.canvas,
      appBar: AppBar(
        backgroundColor: t.canvas,
        surfaceTintColor: t.canvas,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: t.ink, size: 22),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Back',
        ),
      ),
      body: SafeArea(
        top: false,
        child: _error != null
            ? Center(
                child: Text(_error!,
                    style: GoogleFonts.schibstedGrotesk(
                        fontSize: 14, color: t.clay600)))
            : _doc == null
                ? Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(t.inkSubtle)),
                    ),
                  )
                : _body(t),
      ),
    );
  }

  Widget _body(QuietRoomTokens t) {
    final lesson = _current;
    if (lesson == null) {
      return Center(
          child: Text('No lessons available.',
              style: GoogleFonts.schibstedGrotesk(
                  fontSize: 14, color: t.inkMuted)));
    }
    final all = (lesson['items'] as List).cast<Map<String, dynamic>>();
    final verbs = all.where((i) => i.containsKey('verbGroup')).length;
    final pairs = all.where((i) => i.containsKey('intransitive')).length;
    final items = switch (_filter) {
      1 => all.where((i) => i.containsKey('verbGroup')).toList(),
      2 => all.where((i) => i.containsKey('intransitive')).toList(),
      _ => all,
    };
    final missing =
        ((_doc?['missingLessons'] as List?) ?? const []).cast<int>();

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: QuietRoomMetrics.readMax),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            Text(
              '第${lesson['lesson']}課',
              style: GoogleFonts.fraunces(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                letterSpacing: 26 * -0.015,
                height: 1.15,
                color: t.inkStrong,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '${_doc!['course']} · ${all.length} words',
              style:
                  GoogleFonts.schibstedGrotesk(fontSize: 14, color: t.inkMuted),
            ),
            const SizedBox(height: 16),
            _lessonStrip(t, missing),
            const SizedBox(height: 14),
            _practiceButton(t, lesson['lesson'] as int),
            const SizedBox(height: 14),
            Row(
              children: [
                if (verbs > 0 || pairs > 0) ...[
                  _chip(t, 'All ${all.length}', 0),
                  if (verbs > 0) ...[
                    const SizedBox(width: 8),
                    _chip(t, 'Verbs $verbs', 1)
                  ],
                  if (pairs > 0) ...[
                    const SizedBox(width: 8),
                    _chip(t, 'Pairs $pairs', 2)
                  ],
                ],
                const Spacer(),
                _revealAllButton(t, items.length),
              ],
            ),
            const SizedBox(height: 14),
            ...items.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: _item(t, e.value, e.key),
                )),
            const SizedBox(height: 10),
            Text(
              'Kana and English only. The sheets’ romaji is dropped: it is spelled '
              'inconsistently across the course, and reading the kana is the point.'
              '${missing.isEmpty ? '' : ' Lessons ${missing.join(', ')} have no usable source sheet.'}',
              style: GoogleFonts.schibstedGrotesk(
                  fontSize: 11.5, height: 1.45, color: t.inkSubtle),
            ),
          ],
        ),
      ),
    );
  }

  /// A horizontal run of lesson numbers. The set is genuinely a sequence, so numbering
  /// encodes something true rather than decorating the list.
  Widget _lessonStrip(QuietRoomTokens t, List<int> missing) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _lessons.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (context, idx) {
          final l = _lessons[idx];
          final no = l['lesson'] as int;
          final on = no == _lesson;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => setState(() {
                _lesson = no;
                _filter = 0;
                _revealed.clear();
              }),
              child: Container(
                alignment: Alignment.center,
                constraints: const BoxConstraints(minWidth: 40),
                decoration: BoxDecoration(
                  color: on ? t.brand600 : t.surface,
                  border:
                      Border.all(color: on ? t.brand600 : t.border, width: 1),
                  borderRadius: BorderRadius.circular(999),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '$no',
                  style: GoogleFonts.schibstedGrotesk(
                    fontSize: 13.5,
                    fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                    color: on ? t.onBrand : t.inkMuted,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// The one loud object on this screen. Speaking practice was previously a text link in a
  /// crowded row and simply was not found.
  Widget _practiceButton(QuietRoomTokens t, int lesson) => SizedBox(
        width: double.infinity,
        height: QuietRoomMetrics.targetMin,
        child: ElevatedButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => QuietRoomPracticeWidget(lesson: lesson),
          )),
          icon: Icon(Icons.mic_none, size: 19, color: t.onBrand),
          label: Text('Practise speaking',
              style: GoogleFonts.schibstedGrotesk(
                  fontSize: 15, fontWeight: FontWeight.w600, color: t.onBrand)),
          style: ElevatedButton.styleFrom(
            backgroundColor: t.brand600,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(QuietRoomMetrics.radiusSm)),
          ),
        ),
      );

  Widget _chip(QuietRoomTokens t, String label, int value) {
    final on = _filter == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => setState(() {
          _filter = value;
          _revealed.clear();
        }),
        child: Container(
          decoration: BoxDecoration(
            color: on ? t.surfaceTinted : t.surface,
            border: Border.all(color: on ? t.brand600 : t.border, width: 1),
            borderRadius: BorderRadius.circular(999),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          child: Text(
            label,
            style: GoogleFonts.schibstedGrotesk(
              fontSize: 12.5,
              fontWeight: on ? FontWeight.w600 : FontWeight.w500,
              color: on ? t.brand600 : t.inkMuted,
            ),
          ),
        ),
      ),
    );
  }

  /// "Reveal all" doubles as "hide all" once everything is showing, because a study
  /// session needs to get back to a clean slate more often than it needs a second way in.
  Widget _revealAllButton(QuietRoomTokens t, int count) {
    final allShown = count > 0 && _revealed.length >= count;
    return TextButton(
      onPressed: () => setState(() {
        if (allShown) {
          _revealed.clear();
        } else {
          _revealed.addAll(List.generate(count, (n) => n));
        }
      }),
      style: TextButton.styleFrom(
        minimumSize: const Size(0, QuietRoomMetrics.targetMin),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      child: Text(allShown ? 'Hide all' : 'Show all',
          style: GoogleFonts.schibstedGrotesk(
              fontSize: 12.5, fontWeight: FontWeight.w600, color: t.brand600)),
    );
  }

  /// A recall card. The English is hidden until the card is turned over, so the default
  /// state asks a question instead of answering it.
  ///
  /// The verb-group badge stays visible while hidden ON PURPOSE: the group is a property
  /// of the Japanese, derivable from the ます form, so showing it gives nothing away and
  /// it is often the thing being practised.
  Widget _item(QuietRoomTokens t, Map<String, dynamic> i, int index) {
    final group = i['verbGroup'] as int?;
    final uncertain = i['groupUncertain'] == true;
    final pair = i['intransitive'] as String?;
    final shown = _revealed.contains(index);
    final kana = i['kana'] as String? ?? '';

    return Semantics(
      button: true,
      toggled: shown,
      label: shown ? '$kana, ${i['gloss']}' : '$kana, tap to show the meaning',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() {
            if (!_revealed.remove(index)) _revealed.add(index);
          }),
          child: Container(
            constraints:
                const BoxConstraints(minHeight: QuietRoomMetrics.targetMin),
            decoration: BoxDecoration(
              color: t.surface,
              border: Border.all(color: t.border, width: 1),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (i['image'] != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(i['image'] as String,
                            width: 54, height: 41, fit: BoxFit.contain),
                      ),
                      const SizedBox(width: 11),
                    ],
                    Expanded(
                      child: Text(
                        kana,
                        style: GoogleFonts.schibstedGrotesk(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: t.inkStrong),
                      ),
                    ),
                    // Hearing the word gives nothing away that the kana does not already
                    // show, so it stays available while the gloss is still hidden.
                    IconButton(
                      icon: Icon(Icons.volume_up_outlined,
                          size: 19, color: t.inkMuted),
                      tooltip: 'Hear it',
                      visualDensity: VisualDensity.compact,
                      onPressed: () async {
                        // S4: a speaker that does nothing and says nothing is a silent
                        // failure. Report the reason.
                        final err = await SpeechService.instance.speak(kana);
                        if (err != null && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(err,
                                style:
                                    GoogleFonts.schibstedGrotesk(fontSize: 13)),
                            duration: const Duration(seconds: 5),
                          ));
                        }
                      },
                    ),
                    if (group != null) _groupBadge(t, group, uncertain),
                  ],
                ),
                const SizedBox(height: 5),
                // Size animates, contents crossfade. Colour and opacity never get a
                // spatial spring -- the overshoot shows up as a tint wobble. [tokens §7]
                AnimatedSize(
                  duration: QuietRoomMotion.base,
                  curve: QuietRoomMotion.standard,
                  alignment: Alignment.topLeft,
                  child: AnimatedSwitcher(
                    duration: QuietRoomMotion.quick,
                    switchInCurve: QuietRoomMotion.standard,
                    switchOutCurve: QuietRoomMotion.standard,
                    child: shown
                        ? Column(
                            key: const ValueKey(true),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                i['gloss'] as String? ?? '',
                                style: GoogleFonts.schibstedGrotesk(
                                    fontSize: 13.5, height: 1.35, color: t.ink),
                              ),
                              if (pair != null) ...[
                                const SizedBox(height: 7),
                                Row(
                                  children: [
                                    Text('transitive',
                                        style: GoogleFonts.schibstedGrotesk(
                                            fontSize: 11.5, color: t.inkMuted)),
                                    const SizedBox(width: 6),
                                    Icon(Icons.swap_horiz,
                                        size: 14, color: t.inkSubtle),
                                    const SizedBox(width: 6),
                                    Text(pair,
                                        style: GoogleFonts.schibstedGrotesk(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: t.amber700)),
                                  ],
                                ),
                              ],
                            ],
                          )
                        : Text(
                            'Tap to show',
                            key: const ValueKey(false),
                            style: GoogleFonts.schibstedGrotesk(
                                fontSize: 12.5, color: t.inkSubtle),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Group is derived, not printed on the sheet. Where the ます form alone cannot decide
  /// it, the badge says so rather than presenting a guess as a fact.
  Widget _groupBadge(QuietRoomTokens t, int group, bool uncertain) {
    final label = ['', 'I', 'II', 'III'][group];
    return Container(
      decoration: BoxDecoration(
        color: uncertain ? t.amberSurface : t.sage100,
        border: Border.all(color: uncertain ? t.amber700 : t.sage600, width: 1),
        borderRadius: BorderRadius.circular(999),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      child: Text(
        uncertain ? '$label?' : label,
        style: GoogleFonts.schibstedGrotesk(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: uncertain ? t.amber700 : t.sage700,
        ),
      ),
    );
  }
}

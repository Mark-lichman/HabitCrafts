// HAND-WRITTEN. Not FlutterFlow output, so S3 has nothing to adopt.
//
// Three recall drills on extracted, checked data (pipeline/jp, sources 1, 2, 3, 5):
//
//   reference    counters, months, dates, lengths of time. Cells keep the sheet's legend
//                (sound change, special reading) as Quiet Room amber and blue.
//   pairs        transitive / intransitive verbs, from Mari's table and the textbook.
//   conjugation  one verb, one form, tap to check. Answers come from conjugate.py,
//                which reproduces all of Mari's worked conjugations.
//
// Kana first. Where the source printed kanji (the textbook page), it sits behind a tap.
//
// Every drill is self-graded (plan 2026-11-02, Task 11, PIN-13): the learner says the answer,
// reveals it, then marks Got it (clear) or Missed it (wrong). Each mark writes one attempt
// through the [AttemptRecorder]:
//
//   conjugation  against the idea conj.<form>.g<group>, the verb as the probe.
//   pairs        against the pair, the direction as the probe and the template. One mark
//                per reveal; switching the direction hides every card.
//   reference    against the row ref.<table>.<row>, the column as the probe. One mark per
//                revealed cell. Show all is a lookup and asks for no mark.
//
// A reveal alone writes nothing, and a cell or card hidden again before its mark writes
// nothing.
//
// A practice card's "Review the lesson" opens a drill at one idea (plan 2026-11-06, Task 1):
// a conjugation idea at its form ([QuietRoomDrillsWidget.form]), a verb pair at its row
// ([QuietRoomDrillsWidget.pair], the pair's item id) and a table row at its table and row
// ([QuietRoomDrillsWidget.table] and [QuietRoomDrillsWidget.row]). The pair's card and the
// row's cell are outlined and scrolled into view, and [QuietRoomDrillsWidget.fromCard] shows
// the "Back to practice" bar. Opening at an idea reveals nothing and writes nothing. The plain
// entry, with none of these set, is unchanged.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

import '/flutter_flow/quiet_room.dart';
import '/components/pages/quiet_room_mastery/attempt.dart';
import '/components/pages/quiet_room_mastery/drill_recorder.dart';
import '/components/pages/quiet_room_mastery/item_catalog.dart';
import '/components/pages/quiet_room_practice/speech_service.dart';
import 'jp_study_kit.dart';

enum JpDrill { reference, pairs, conjugation }

class QuietRoomDrillsWidget extends StatefulWidget {
  const QuietRoomDrillsWidget(
      {super.key,
      this.mode = 'reference',
      this.table,
      this.form,
      this.pair,
      this.row,
      this.fromCard = false,
      this.recorder});

  final String mode;

  /// Deep links from the catalog search: which table or form to open on.
  final String? table;
  final String? form;

  /// Opens the pairs drill at this pair (its item id, item_catalog.dart `pairItemIds`).
  final String? pair;

  /// Opens the reference drill at this row of [table] (`3` of `ref.counters.3`).
  final String? row;

  /// A practice card opened the screen: the "Back to practice" bar shows.
  final bool fromCard;

  /// Where the self-marks go. Null writes to the app's study store, with one recorder per
  /// visit to the screen.
  final AttemptRecorder? recorder;

  static String routeName = 'quietRoomDrills';
  static String routePath = '/quietRoomDrills';

  @override
  State<QuietRoomDrillsWidget> createState() => _QuietRoomDrillsWidgetState();
}

class _QuietRoomDrillsWidgetState extends State<QuietRoomDrillsWidget> {
  AttemptRecorder? _own;

  AttemptRecorder get _recorder =>
      widget.recorder ?? (_own ??= AttemptRecorder());

  /// Writes one self-graded answer: Got it is clear and Missed it is wrong (PIN-13). The
  /// screen never waits on the write. A write that is lost (the recorder has reported it)
  /// tells the learner through [_notSaved], so a mark on screen is never taken for credit.
  void _record(
      {required String itemId,
      required String probeId,
      required String template,
      required bool production,
      required bool gotIt}) {
    _recorder
        .record(DrillAnswer(
      itemId: itemId,
      probeId: probeId,
      template: template,
      production: production,
      revealed: true,
      grade: gradeAnswer(
          outcome: gotIt ? Outcome.right : Outcome.wrong,
          selfGraded: true,
          revealed: true),
    ))
        .then((a) {
      if (a == null) _notSaved();
    });
  }

  /// Shown when a mark did not reach the study record (S4: the learner sees it).
  void _notSaved() {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
        content: Text(kAnswerNotSaved), duration: Duration(seconds: 5)));
  }

  @override
  Widget build(BuildContext context) {
    final drill = JpDrill.values.firstWhere((d) => d.name == widget.mode,
        orElse: () => JpDrill.reference);
    return QrStudyScaffold(
      fromCard: widget.fromCard,
      child: QrLoad(
        builder: (context, doc) => switch (drill) {
          JpDrill.reference => _Reference(
              doc: doc, table: widget.table, row: widget.row, record: _record),
          JpDrill.pairs => _Pairs(
              doc: doc, pair: widget.pair, record: _record, lost: _notSaved),
          JpDrill.conjugation =>
            _Conjugation(doc: doc, form: widget.form, record: _record),
        },
      ),
    );
  }
}

/// Writes one self-graded mark; see [_QuietRoomDrillsWidgetState._record].
typedef _Record = void Function(
    {required String itemId,
    required String probeId,
    required String template,
    required bool production,
    required bool gotIt});

/// Missed it and Got it, side by side, the way every drill places them.
Widget _markButtons(QuietRoomTokens t, void Function(bool gotIt) onMark) =>
    Row(children: [
      Expanded(child: _markButton(t, 'Missed it', false, onMark)),
      const SizedBox(width: 10),
      Expanded(child: _markButton(t, 'Got it', true, onMark)),
    ]);

Widget _markButton(QuietRoomTokens t, String label, bool right,
        void Function(bool gotIt) onMark) =>
    SizedBox(
      height: QuietRoomMetrics.targetMin,
      child: OutlinedButton(
        onPressed: () => onMark(right),
        style: OutlinedButton.styleFrom(
          backgroundColor: right ? t.brand600 : t.surface,
          side: BorderSide(color: right ? t.brand600 : t.borderControl),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(QuietRoomMetrics.radiusSm)),
        ),
        child: Text(label,
            style: qrText(t,
                size: 14.5,
                weight: FontWeight.w600,
                color: right ? t.onBrand : t.ink)),
      ),
    );

/// The line a mark leaves behind.
Widget _markedLine(QuietRoomTokens t, bool gotIt) =>
    Text(gotIt ? 'Marked as got it.' : 'Marked as missed.',
        style: qrText(t,
            size: 13,
            weight: FontWeight.w600,
            color: gotIt ? t.sage700 : t.inkMuted));

/// Scrolls [key]'s widget into view after the frame that lays it out.
void _scrollIntoViewAfterFrame(GlobalKey key) =>
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = key.currentContext;
      if (target == null || !target.mounted) return;
      Scrollable.ensureVisible(target, duration: Duration.zero);
    });

Future<void> _speak(BuildContext context, String text) async {
  final err = await SpeechService.instance.speak(text);
  if (err != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), duration: const Duration(seconds: 5)));
  }
}

// ───────────────────────────── reference tables ─────────────────────────────

class _Reference extends StatefulWidget {
  const _Reference(
      {required this.doc, this.table, this.row, required this.record});

  final Map<String, dynamic> doc;
  final String? table;

  /// The row opened at, outlined in every column of [table] until the table changes.
  final String? row;
  final _Record record;

  @override
  State<_Reference> createState() => _ReferenceState();
}

class _ReferenceState extends State<_Reference> {
  int _table = 0;

  @override
  void initState() {
    super.initState();
    final ids = (widget.doc['reference'] as List).map((t) => t['id']).toList();
    _table = ids.indexOf(widget.table).clamp(0, ids.length - 1);
    if (widget.row != null && ids[_table] == widget.table) {
      _row = widget.row;
      _scrollIntoViewAfterFrame(_rowKey);
    }
  }

  /// The row opened at, and its cell's key for the first scroll. Cleared with a new table.
  String? _row;
  final _rowKey = GlobalKey();

  int _col = 0;
  final Set<String> _shown = {};
  bool _all = false;

  /// The revealed cell (its row) waiting for Got it or Missed it, and the last mark given.
  /// One mark per reveal: hiding the cell, another reveal, Show all, or a new table or
  /// column drops an unmarked one, which writes nothing.
  String? _pending;
  bool? _lastMark;

  void _clearMarks() {
    _pending = null;
    _lastMark = null;
  }

  void _mark(Map<String, dynamic> table, Map<String, dynamic> col, bool gotIt) {
    final row = _pending;
    if (row == null) return;
    widget.record(
      itemId: tableRowItemId(table['id'] as String, row),
      probeId: col['written'] as String,
      template: kCellTemplate,
      production: false,
      gotIt: gotIt,
    );
    setState(() {
      _pending = null;
      _lastMark = gotIt;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = QuietRoomTokens.of(context);
    final tables =
        (widget.doc['reference'] as List).cast<Map<String, dynamic>>();
    final table = tables[_table];
    final cols = (table['columns'] as List).cast<Map<String, dynamic>>();
    final col = cols[_col.clamp(0, cols.length - 1)];
    final cells = (table['cells'] as List)
        .cast<Map<String, dynamic>>()
        .where((c) => c['col'] == col['written'])
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      children: [
        Text('Numbers and counters', style: qrTitle(t)),
        const SizedBox(height: 5),
        Text('Say the reading, then tap to check.',
            style: qrText(t, color: t.inkMuted)),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (var i = 0; i < tables.length; i++)
            QrPill(
              label: tables[i]['title'] as String,
              on: i == _table,
              solid: false,
              onTap: () => setState(() {
                if (i != _table) _row = null;
                _table = i;
                _col = 0;
                _shown.clear();
                _all = false;
                _clearMarks();
              }),
            ),
        ]),
        if (cols.length > 1) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: cols.length,
              separatorBuilder: (_, __) => const SizedBox(width: 7),
              itemBuilder: (context, i) => QrPill(
                label: cols[i]['written'] as String,
                on: i == _col,
                onTap: () => setState(() {
                  _col = i;
                  _shown.clear();
                  _all = false;
                  _clearMarks();
                }),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: Text(
              [col['kana'], col['gloss']]
                  .where((s) => (s as String).isNotEmpty)
                  .join(' · '),
              style: qrText(t, size: 13, color: t.inkMuted),
            ),
          ),
          TextButton(
            onPressed: () => setState(() {
              _all = !_all;
              _shown.clear();
              _clearMarks();
            }),
            style: TextButton.styleFrom(
                minimumSize: const Size(0, QuietRoomMetrics.targetMin)),
            child: Text(_all ? 'Hide all' : 'Show all',
                style: qrText(t,
                    size: 12.5, weight: FontWeight.w600, color: t.brand600)),
          ),
        ]),
        const SizedBox(height: 6),
        _legend(t),
        const SizedBox(height: 12),
        // Always the same height, so the grid never moves under the finger.
        SizedBox(
          height: QuietRoomMetrics.targetMin,
          child: _pending != null
              ? _markButtons(t, (gotIt) => _mark(table, col, gotIt))
              : Align(
                  alignment: Alignment.centerLeft,
                  child: _lastMark == null
                      ? Text(
                          _all ? '' : 'Tap a cell to check it, then mark it.',
                          style: qrText(t, size: 13, color: t.inkSubtle))
                      : _markedLine(t, _lastMark!),
                ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: table['id'] == 'dates' ? 3 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: table['id'] == 'dates' ? 1.25 : 2.2,
          children: cells.map((c) => _cell(t, table, col, c)).toList(),
        ),
      ],
    );
  }

  Widget _legend(QuietRoomTokens t) => Row(children: [
        for (final m in const ['sound_change', 'special']) ...[
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: ReadingMark.fill(t, m),
              border: Border.all(color: ReadingMark.ink(t, m), width: 1),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 6),
          Text(ReadingMark.label(m),
              style: qrText(t, size: 12, color: t.inkMuted)),
          const SizedBox(width: 16),
        ],
      ]);

  Widget _cell(QuietRoomTokens t, Map<String, dynamic> table,
      Map<String, dynamic> col, Map<String, dynamic> c) {
    final key = '${c['row']}';
    final shown = _all || _shown.contains(key);
    final mark = c['mark'] as String;
    final alt = ((c['alt'] as List?) ?? const []).cast<String>();
    final target = _row != null && key == _row;
    final label = table['id'] == 'dates'
        ? '${c['row']}日'
        : table['id'] == 'months'
            ? '${c['row']} ${col['written']}'.replaceAll('〜', '')
            : '${c['row']} ${col['written']}';
    return Material(
      key: target ? _rowKey : null,
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() {
          if (!_shown.remove(key)) _shown.add(key);
          if (shown) {
            // Hidden again before its mark: nothing is written.
            if (_pending == key) _pending = null;
            return;
          }
          _pending = key;
          _lastMark = null;
          _speak(context, c['reading'] as String);
        }),
        child: AnimatedContainer(
          duration: QuietRoomMotion.quick,
          decoration: BoxDecoration(
            // The legend color shows only once the answer does. Showing it first
            // would give away whether the reading is regular.
            color: shown ? ReadingMark.fill(t, mark) : t.surface,
            border: Border.all(
                color: target
                    ? t.brand600
                    : shown && mark != 'regular'
                        ? ReadingMark.ink(t, mark)
                        : t.border,
                width: target ? 2 : 1),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: qrText(t, size: 13, color: t.inkMuted)),
              const SizedBox(height: 3),
              Text(
                shown ? c['reading'] as String : '?',
                textAlign: TextAlign.center,
                style: qrText(t,
                    size: 16.5,
                    weight: FontWeight.w600,
                    color: shown ? ReadingMark.ink(t, mark) : t.inkSubtle),
              ),
              if (shown && alt.isNotEmpty)
                Text('(${alt.join('、')})',
                    style: qrText(t, size: 11.5, color: t.inkMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────── verb pairs ─────────────────────────────

class _Pairs extends StatefulWidget {
  const _Pairs(
      {required this.doc, this.pair, required this.record, required this.lost});

  final Map<String, dynamic> doc;

  /// The pair opened at (its item id), outlined.
  final String? pair;
  final _Record record;

  /// Tells the learner a mark was not saved; see [_QuietRoomDrillsWidgetState._notSaved].
  final VoidCallback lost;

  @override
  State<_Pairs> createState() => _PairsState();
}

class _PairsState extends State<_Pairs> {
  final Set<int> _shown = {};
  final Set<int> _kanji = {};

  /// The mark given on each card's current reveal: true Got it, false Missed it.
  final Map<int, bool> _marks = {};

  /// False: shown the が verb, recall the を verb. True: the reverse.
  bool _reverse = false;

  /// The pair ids, in the order of the pairs (item_catalog.dart `pairItemIds`). Null when the
  /// asset's pairs and catalog rows do not line up; the catalog refuses that asset too, so
  /// the drill then writes nothing rather than a mark under a wrong id. The mismatch goes
  /// to [FlutterError.reportError] once, and every mark after it tells the learner (S4).
  late final List<String>? _ids = () {
    try {
      return pairItemIds(widget.doc);
    } on StateError catch (e, s) {
      FlutterError.reportError(FlutterErrorDetails(
          exception: e,
          stack: s,
          library: 'quiet room drills',
          context: ErrorDescription('while mapping the verb pairs to items')));
      return null;
    }
  }();

  /// The index of [_Pairs.pair] in the list, or -1.
  late final int _target =
      widget.pair == null ? -1 : (_ids?.indexOf(widget.pair!) ?? -1);
  final _targetKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (_target >= 0) _scrollIntoViewAfterFrame(_targetKey);
  }

  void _mark(int i, bool gotIt) {
    final ids = _ids;
    if (_marks.containsKey(i)) return;
    if (ids == null) {
      widget.lost();
    } else {
      final probe = _reverse ? kPairToIntransitive : kPairToTransitive;
      widget.record(
        itemId: ids[i],
        probeId: probe,
        template: probe,
        production: false,
        gotIt: gotIt,
      );
    }
    setState(() => _marks[i] = gotIt);
  }

  @override
  Widget build(BuildContext context) {
    final t = QuietRoomTokens.of(context);
    final pairs = (widget.doc['pairs'] as List).cast<Map<String, dynamic>>();
    return ListView(
      // Opened at a pair, every card is built, so the pair's card has a context to scroll to.
      scrollCacheExtent:
          _target >= 0 ? const ScrollCacheExtent.pixels(100000) : null,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      children: [
        Text('Verb pairs', style: qrTitle(t)),
        const SizedBox(height: 5),
        Text(
            'が: it happens. を: someone does it. See one side, recall the other.',
            style: qrText(t, color: t.inkMuted)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final reverse in const [false, true])
            QrPill(
              label: reverse ? 'を → が' : 'が → を',
              on: reverse == _reverse,
              solid: false,
              onTap: () => setState(() {
                if (_reverse == reverse) return;
                _reverse = reverse;
                _shown.clear();
                _marks.clear();
              }),
            ),
        ]),
        const SizedBox(height: 16),
        for (var i = 0; i < pairs.length; i++)
          Padding(
              key: i == _target ? _targetKey : null,
              padding: const EdgeInsets.only(bottom: 9),
              child: i == _target
                  ? DecoratedBox(
                      key: const ValueKey('pair-target'),
                      position: DecorationPosition.foreground,
                      decoration: BoxDecoration(
                        border: Border.all(color: t.brand600, width: 2),
                        borderRadius:
                            BorderRadius.circular(QuietRoomMetrics.radiusMd),
                      ),
                      child: _pair(t, i, pairs[i]))
                  : _pair(t, i, pairs[i])),
      ],
    );
  }

  Widget _pair(QuietRoomTokens t, int i, Map<String, dynamic> p) {
    final shown = _shown.contains(i);
    final kanji = _kanji.contains(i);
    final mark = _marks[i];
    final hasKanji = p['kanji_transitive'] != null;
    final exIn = kanji ? p['kanji_intransitive'] : p['ex_intransitive'];
    final exTr = kanji ? p['kanji_transitive'] : p['ex_transitive'];
    final gloss = p['gloss'] as String? ?? '';
    // The side shown first, and the side to recall.
    final given = _reverse
        ? _side(t, 'を', p['transitive'] as String, p['transitive_group'])
        : _side(t, 'が', p['intransitive'] as String, p['intransitive_group']);
    final asked = _reverse
        ? _side(t, 'が', p['intransitive'] as String, p['intransitive_group'])
        : _side(t, 'を', p['transitive'] as String, p['transitive_group']);
    final exGiven = _reverse ? exTr : exIn;
    final exAsked = _reverse ? exIn : exTr;
    return QrCard(
      onTap: () => setState(() {
        if (shown) {
          // Hidden again: the next reveal asks for its own mark.
          _shown.remove(i);
          _marks.remove(i);
        } else {
          _shown.add(i);
        }
      }),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            given,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Icon(Icons.swap_horiz, size: 18, color: t.inkSubtle),
            ),
            shown
                ? asked
                : Text(_reverse ? 'が ?' : 'を ?',
                    style: qrText(t,
                        size: 18, weight: FontWeight.w600, color: t.inkSubtle)),
            const Spacer(),
            if (hasKanji)
              TextButton(
                onPressed: () =>
                    setState(() => kanji ? _kanji.remove(i) : _kanji.add(i)),
                style: TextButton.styleFrom(minimumSize: const Size(44, 36)),
                child: Text(kanji ? 'かな' : '漢字',
                    style: qrText(t,
                        size: 13, weight: FontWeight.w600, color: t.brand600)),
              ),
          ]),
          if (gloss.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(gloss, style: qrText(t, size: 13, color: t.inkMuted)),
          ],
          const SizedBox(height: 8),
          Text(exGiven as String,
              style: qrText(t, size: 15.5, color: t.inkStrong)),
          AnimatedSize(
            duration: QuietRoomMotion.base,
            curve: QuietRoomMotion.standard,
            alignment: Alignment.topLeft,
            child: shown
                ? Text(exAsked as String,
                    style: qrText(t, size: 15.5, color: t.amber700))
                : const SizedBox(width: double.infinity),
          ),
          if (shown) ...[
            const SizedBox(height: 10),
            mark == null
                ? _markButtons(t, (gotIt) => _mark(i, gotIt))
                : _markedLine(t, mark),
          ],
        ],
      ),
    );
  }

  Widget _side(
          QuietRoomTokens t, String particle, String verb, Object? group) =>
      Row(children: [
        Text(particle, style: qrText(t, size: 13, color: t.inkMuted)),
        const SizedBox(width: 4),
        Text(verb,
            style: qrText(t,
                size: 18, weight: FontWeight.w600, color: t.inkStrong)),
        if (group != null) ...[
          const SizedBox(width: 5),
          Text(['', 'I', 'II', 'III'][group as int],
              style: qrText(t,
                  size: 11, weight: FontWeight.w600, color: t.sage700)),
        ],
      ]);
}

// ───────────────────────────── conjugation ─────────────────────────────

const _formLabels = {
  'masu': 'ます form',
  'te': 'て form',
  'ta': 'た form',
  'nai': 'ない form',
  'potential': 'potential',
  'volitional': 'volitional',
  'conditional': 'conditional (ば)',
  'imperative': 'imperative',
  'prohibitive': 'do not (な)',
  'passive': 'passive',
  'causative': 'causative',
  'causative_passive': 'causative passive',
};

class _Conjugation extends StatefulWidget {
  const _Conjugation({required this.doc, this.form, required this.record});

  final Map<String, dynamic> doc;
  final String? form;
  final _Record record;

  @override
  State<_Conjugation> createState() => _ConjugationState();
}

class _ConjugationState extends State<_Conjugation> {
  final _rng = Random();
  String _form = 'te';
  late List<Map<String, dynamic>> _deck;
  int _i = 0;
  bool _shown = false;
  int _right = 0, _seen = 0;

  @override
  void initState() {
    super.initState();
    _form = widget.form ?? _form;
    _shuffle();
  }

  void _shuffle() {
    _deck = (widget.doc['conjugation']['verbs'] as List)
        .cast<Map<String, dynamic>>()
        .toList()
      ..shuffle(_rng);
    _i = 0;
    _shown = false;
  }

  @override
  Widget build(BuildContext context) {
    final t = QuietRoomTokens.of(context);
    final forms = (widget.doc['conjugation']['forms'] as List).cast<String>();
    final v = _deck[_i % _deck.length];
    final answer = v[_form] as String;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      children: [
        Text('Conjugation', style: qrTitle(t)),
        const SizedBox(height: 5),
        Text('${_deck.length} verbs · checked against Mari\'s forms',
            style: qrText(t, color: t.inkMuted)),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final f in forms)
            QrPill(
              label: _formLabels[f] ?? f,
              on: f == _form,
              solid: false,
              onTap: () => setState(() {
                _form = f;
                _shown = false;
              }),
            ),
        ]),
        const SizedBox(height: 20),
        QrCard(
          onTap: _shown
              ? null
              : () {
                  setState(() => _shown = true);
                  _speak(context, answer);
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Column(children: [
              Text(v['dictionary'] as String,
                  style: qrText(t,
                      size: 30, weight: FontWeight.w600, color: t.inkStrong)),
              const SizedBox(height: 4),
              Text(
                  'group ${[
                    '',
                    'I',
                    'II',
                    'III'
                  ][v['group'] as int]}  →  ${_formLabels[_form]}',
                  style: qrText(t, size: 13, color: t.inkMuted)),
              const SizedBox(height: 18),
              AnimatedSwitcher(
                duration: QuietRoomMotion.quick,
                child: _shown
                    ? Text(answer,
                        key: const ValueKey('a'),
                        style: qrText(t,
                            size: 26,
                            weight: FontWeight.w600,
                            color: t.brand600))
                    : Text('Say it, then tap',
                        key: const ValueKey('q'),
                        style: qrText(t, size: 14, color: t.inkSubtle)),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        if (_shown) _markButtons(t, (gotIt) => _mark(v, gotIt)),
        const SizedBox(height: 12),
        if (_seen > 0)
          Text('$_right of $_seen this session',
              textAlign: TextAlign.center,
              style: qrText(t, size: 12.5, color: t.inkMuted)),
      ],
    );
  }

  /// One mark per reveal: the buttons go with the card, so a second tap cannot land.
  void _mark(Map<String, dynamic> v, bool gotIt) {
    if (!_shown) return;
    // The catalog has no probe for a verb with no form here; such a card writes nothing.
    if ((v[_form] as String? ?? '').isNotEmpty) {
      widget.record(
        itemId: conjugationItemId(_form, v['group'] as int),
        probeId: v['dictionary'] as String,
        template: kConjugateTemplate,
        production: true,
        gotIt: gotIt,
      );
    }
    setState(() {
      _seen++;
      if (gotIt) _right++;
      _i++;
      _shown = false;
    });
  }
}

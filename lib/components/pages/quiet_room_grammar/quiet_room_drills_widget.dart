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

import 'dart:math';

import 'package:flutter/material.dart';

import '/flutter_flow/quiet_room.dart';
import '/components/pages/quiet_room_practice/speech_service.dart';
import 'jp_study_kit.dart';

enum JpDrill { reference, pairs, conjugation }

class QuietRoomDrillsWidget extends StatelessWidget {
  const QuietRoomDrillsWidget(
      {super.key, this.mode = 'reference', this.table, this.form});

  final String mode;

  /// Deep links from the catalog search: which table or form to open on.
  final String? table;
  final String? form;

  static String routeName = 'quietRoomDrills';
  static String routePath = '/quietRoomDrills';

  @override
  Widget build(BuildContext context) {
    final drill = JpDrill.values
        .firstWhere((d) => d.name == mode, orElse: () => JpDrill.reference);
    return QrStudyScaffold(
      child: QrLoad(
        builder: (context, doc) => switch (drill) {
          JpDrill.reference => _Reference(doc: doc, table: table),
          JpDrill.pairs => _Pairs(doc: doc),
          JpDrill.conjugation => _Conjugation(doc: doc, form: form),
        },
      ),
    );
  }
}

Future<void> _speak(BuildContext context, String text) async {
  final err = await SpeechService.instance.speak(text);
  if (err != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), duration: const Duration(seconds: 5)));
  }
}

// ───────────────────────────── reference tables ─────────────────────────────

class _Reference extends StatefulWidget {
  const _Reference({required this.doc, this.table});

  final Map<String, dynamic> doc;
  final String? table;

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
  }

  int _col = 0;
  final Set<String> _shown = {};
  bool _all = false;

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
                _table = i;
                _col = 0;
                _shown.clear();
                _all = false;
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
    final label = table['id'] == 'dates'
        ? '${c['row']}日'
        : table['id'] == 'months'
            ? '${c['row']} ${col['written']}'.replaceAll('〜', '')
            : '${c['row']} ${col['written']}';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() {
          if (!_shown.remove(key)) _shown.add(key);
          if (shown) return;
          _speak(context, c['reading'] as String);
        }),
        child: AnimatedContainer(
          duration: QuietRoomMotion.quick,
          decoration: BoxDecoration(
            // The legend color shows only once the answer does. Showing it first
            // would give away whether the reading is regular.
            color: shown ? ReadingMark.fill(t, mark) : t.surface,
            border: Border.all(
                color: shown && mark != 'regular'
                    ? ReadingMark.ink(t, mark)
                    : t.border),
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
  const _Pairs({required this.doc});

  final Map<String, dynamic> doc;

  @override
  State<_Pairs> createState() => _PairsState();
}

class _PairsState extends State<_Pairs> {
  final Set<int> _shown = {};
  final Set<int> _kanji = {};

  @override
  Widget build(BuildContext context) {
    final t = QuietRoomTokens.of(context);
    final pairs = (widget.doc['pairs'] as List).cast<Map<String, dynamic>>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      children: [
        Text('Verb pairs', style: qrTitle(t)),
        const SizedBox(height: 5),
        Text(
            'が: it happens. を: someone does it. See one side, recall the other.',
            style: qrText(t, color: t.inkMuted)),
        const SizedBox(height: 16),
        for (var i = 0; i < pairs.length; i++)
          Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _pair(t, i, pairs[i])),
      ],
    );
  }

  Widget _pair(QuietRoomTokens t, int i, Map<String, dynamic> p) {
    final shown = _shown.contains(i);
    final kanji = _kanji.contains(i);
    final hasKanji = p['kanji_transitive'] != null;
    final exIn = kanji ? p['kanji_intransitive'] : p['ex_intransitive'];
    final exTr = kanji ? p['kanji_transitive'] : p['ex_transitive'];
    final gloss = p['gloss'] as String? ?? '';
    return QrCard(
      onTap: () => setState(() => shown ? _shown.remove(i) : _shown.add(i)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _side(t, 'が', p['intransitive'] as String, p['intransitive_group']),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Icon(Icons.swap_horiz, size: 18, color: t.inkSubtle),
            ),
            shown
                ? _side(
                    t, 'を', p['transitive'] as String, p['transitive_group'])
                : Text('を ?',
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
          Text(exIn as String,
              style: qrText(t, size: 15.5, color: t.inkStrong)),
          AnimatedSize(
            duration: QuietRoomMotion.base,
            curve: QuietRoomMotion.standard,
            alignment: Alignment.topLeft,
            child: shown
                ? Text(exTr as String,
                    style: qrText(t, size: 15.5, color: t.amber700))
                : const SizedBox(width: double.infinity),
          ),
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
  const _Conjugation({required this.doc, this.form});

  final Map<String, dynamic> doc;
  final String? form;

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
        if (_shown)
          Row(children: [
            Expanded(child: _grade(t, 'Missed it', false)),
            const SizedBox(width: 10),
            Expanded(child: _grade(t, 'Got it', true)),
          ]),
        const SizedBox(height: 12),
        if (_seen > 0)
          Text('$_right of $_seen this session',
              textAlign: TextAlign.center,
              style: qrText(t, size: 12.5, color: t.inkMuted)),
      ],
    );
  }

  Widget _grade(QuietRoomTokens t, String label, bool right) => SizedBox(
        height: QuietRoomMetrics.targetMin,
        child: OutlinedButton(
          onPressed: () {
            setState(() {
              _seen++;
              if (right) _right++;
              _i++;
              _shown = false;
            });
          },
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
}

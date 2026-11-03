// HAND-WRITTEN. Not FlutterFlow output, so S3 has nothing to adopt.
//
// Speaking practice. Shows the illustration from the source sheet, asks the learner to say the
// word, listens, and reports what it heard.
//
// 🚨 IT IS A RECALL DRILL, NOT PRONUNCIATION SCORING, and the copy says so. speech_to_text checks
// WHICH word was produced, never how well it was pronounced. See speech_service.dart.
//
// THE HINT LADDER is deliberately ordered from least to most revealing, and the learner chooses
// how far down it to go: English gloss, then the conjugation group, then the first mora, then the
// whole answer. Giving the answer as the only option makes the hint worthless as a hint.
//
// Quiet Room: the illustration is the one loud object on the screen. Everything else -- the
// controls, the hints, the chrome -- stays inside the quiet band until the learner asks for it.

import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_fonts/google_fonts.dart';

import '/flutter_flow/quiet_room.dart';
import 'listening_bars.dart';
import 'speech_service.dart';

class QuietRoomPracticeWidget extends StatefulWidget {
  const QuietRoomPracticeWidget({super.key, this.lesson});

  /// Null practises every lesson at once.
  final int? lesson;

  static String routeName = 'quietRoomPractice';
  static String routePath = '/quietRoomPractice';

  @override
  State<QuietRoomPracticeWidget> createState() =>
      _QuietRoomPracticeWidgetState();
}

class _QuietRoomPracticeWidgetState extends State<QuietRoomPracticeWidget> {
  final _speech = SpeechService.instance;
  final _rng = Random();

  List<Map<String, dynamic>> _pool = const [];
  Map<String, dynamic>? _card;
  String? _error;

  int _hintLevel = 0; // 0 none, 1 gloss, 2 group, 3 first mora, 4 answer
  bool _listening = false;

  /// 🚨 Set from SpeechService.lastError. Without it a recogniser failure was indistinguishable
  /// from a slow answer: the drill waited out its whole timeout and then said "could not
  /// check", which reads as the learner's fault rather than the device's.
  String? _micError;
  SpeechResult? _result;
  int _seen = 0;
  int _right = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _speech.cancel();
    _speech.stopSpeaking();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString('assets/lessons/jp_lessons.json');
      final d = json.decode(raw) as Map<String, dynamic>;
      final lessons = (d['lessons'] as List).cast<Map<String, dynamic>>();
      final pool = <Map<String, dynamic>>[];
      for (final l in lessons) {
        if (widget.lesson != null && l['lesson'] != widget.lesson) continue;
        for (final i in (l['items'] as List).cast<Map<String, dynamic>>()) {
          // Only illustrated words can be a picture prompt.
          if (i['image'] != null) pool.add({...i, 'lesson': l['lesson']});
        }
      }
      if (!mounted) return;
      if (pool.isEmpty) {
        setState(() => _error = 'No illustrated words in this lesson.');
        return;
      }
      setState(() {
        _pool = pool;
        _card = pool[_rng.nextInt(pool.length)];
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load the vocabulary.');
    }
  }

  void _next() {
    if (_pool.isEmpty) return;
    setState(() {
      _card = _pool[_rng.nextInt(_pool.length)];
      _hintLevel = 0;
      _result = null;
    });
  }

  Future<void> _listen() async {
    final card = _card;
    if (card == null || _listening) return;
    setState(() {
      _listening = true;
      _result = null;
      _heardVoice = false;
      _micError = null;
    });
    try {
      final r = await _speech.listenOnce(
        expectedKana: card['kana'] as String,
        kanjiForms: ((card['kanji'] as List?) ?? const []).cast<String>(),
      );
      if (!mounted) return;
      setState(() {
        _result = r;
        _seen++;
        if (r.judgement == Judgement.correct ||
            r.judgement == Judgement.close) {
          _right++;
        }
      });
    } finally {
      // Leaving the panel open on a throw would strand the drill mid-listen.
      if (mounted) {
        setState(() {
          _listening = false;
          _micError = _speech.lastError;
        });
      }
    }
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
        title: Text(
          _seen == 0 ? 'Say it' : '$_right of $_seen',
          style: GoogleFonts.schibstedGrotesk(
              fontSize: 14, fontWeight: FontWeight.w600, color: t.inkMuted),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _error != null
            ? Center(
                child: Text(_error!,
                    style: GoogleFonts.schibstedGrotesk(
                        fontSize: 14, color: t.clay600)))
            : _card == null
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
                : _body(t, _card!),
      ),
    );
  }

  Widget _body(QuietRoomTokens t, Map<String, dynamic> card) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: QuietRoomMetrics.readMax),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            Text(
              'What is this?',
              style: GoogleFonts.fraunces(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: 22 * -0.015,
                color: t.inkStrong,
              ),
            ),
            const SizedBox(height: 4),
            Text('Say it in Japanese.',
                style: GoogleFonts.schibstedGrotesk(
                    fontSize: 13.5, color: t.inkMuted)),
            const SizedBox(height: 16),

            // The one loud object -- but capped. Full-bleed at 265:200 it swallowed the
            // screen on anything wider than a phone and pushed the controls below the fold.
            Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 294, maxHeight: 222),
                child: Container(
                  decoration: BoxDecoration(
                    color: t.surfaceRaised,
                    border: Border.all(color: t.border, width: 1),
                    borderRadius:
                        BorderRadius.circular(QuietRoomMetrics.radiusMd),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: AspectRatio(
                    aspectRatio: 265 / 200,
                    // 🚨 Labelled as the PROMPT, never with the word. The gloss here would
                    // read the answer aloud to exactly the learner being asked for it.
                    child: Image.asset(card['image'] as String,
                        fit: BoxFit.contain,
                        semanticLabel: 'Picture prompt for this word'),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (_listening) _listeningPanel(t) else _micRow(t, card),
            if (_micError != null) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: t.clay600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _micError!,
                      style: GoogleFonts.schibstedGrotesk(
                          fontSize: 12.5, color: t.clay600),
                    ),
                  ),
                ],
              ),
            ],
            if (_result != null) ...[
              const SizedBox(height: 14),
              _verdict(t, card)
            ],

            const SizedBox(height: 18),
            _hints(t, card),

            const SizedBox(height: 22),
            Center(
              child: TextButton(
                onPressed: _next,
                style: TextButton.styleFrom(
                    minimumSize: const Size(0, QuietRoomMetrics.targetMin)),
                child: Text('Next word',
                    style: GoogleFonts.schibstedGrotesk(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: t.brand600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// While the microphone is open. The label is deliberately different depending on
  /// whether the bars mean anything: on a platform that reports amplitude it says the
  /// voice is being heard, and where it does not it only claims to be listening.
  bool _heardVoice = false;

  Widget _listeningPanel(QuietRoomTokens t) {
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.borderControl, width: 1),
        borderRadius: BorderRadius.circular(QuietRoomMetrics.radiusSm),
      ),
      padding: const EdgeInsets.fromLTRB(15, 12, 15, 12),
      child: Column(
        children: [
          ListeningBars(
            level: _speech.level,
            onRealDetected: () {
              if (mounted && !_heardVoice) setState(() => _heardVoice = true);
            },
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_heardVoice ? 'Hearing you' : 'Listening',
                  style: GoogleFonts.schibstedGrotesk(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: t.inkMuted)),
              const SizedBox(width: 10),
              TextButton(
                onPressed: () async {
                  await _speech.cancel();
                  if (mounted) setState(() => _listening = false);
                },
                style: TextButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 8)),
                child: Text('Stop',
                    style: GoogleFonts.schibstedGrotesk(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: t.brand600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _micRow(QuietRoomTokens t, Map<String, dynamic> card) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: QuietRoomMetrics.targetMin,
            child: ElevatedButton.icon(
              onPressed: _listening ? null : _listen,
              icon: Icon(_listening ? Icons.graphic_eq : Icons.mic_none,
                  size: 20, color: t.onBrand),
              label: Text(_listening ? 'Listening…' : 'Speak',
                  style: GoogleFonts.schibstedGrotesk(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: t.onBrand)),
              style: ElevatedButton.styleFrom(
                backgroundColor: t.brand600,
                disabledBackgroundColor: t.brand400,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(QuietRoomMetrics.radiusSm)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: QuietRoomMetrics.targetMin,
          width: QuietRoomMetrics.targetMin,
          child: OutlinedButton(
            onPressed: () async {
              final err = await _speech.speak(card['kana'] as String);
              if (err != null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(err,
                      style: GoogleFonts.schibstedGrotesk(fontSize: 13)),
                  duration: const Duration(seconds: 5),
                ));
              }
            },
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              side: BorderSide(
                  color: t.borderControl,
                  width: QuietRoomMetrics.strokeControl),
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(QuietRoomMetrics.radiusSm)),
            ),
            child: Icon(Icons.volume_up_outlined, size: 20, color: t.ink),
          ),
        ),
      ],
    );
  }

  Widget _verdict(QuietRoomTokens t, Map<String, dynamic> card) {
    final r = _result!;
    late final Color c;
    late final String head;
    late final String body;
    switch (r.judgement) {
      case Judgement.correct:
        c = t.sage600;
        head = 'That’s it';
        body = card['kana'] as String;
      case Judgement.close:
        c = t.sage600;
        head = 'Close enough';
        body = 'Heard “${r.heard}” · answer ${card['kana']}';
      case Judgement.wrong:
        c = t.clay600;
        head = 'Not quite';
        body = 'Heard “${r.heard}” · answer ${card['kana']}';
      case Judgement.unverified:
        // Being unable to check is not the same as being wrong, and the copy must not blur them.
        c = t.amber700;
        head = r.heard.isEmpty ? 'Didn’t catch that' : 'Can’t check this one';
        body = r.heard.isEmpty
            ? 'Nothing was heard. Try again, or check the microphone permission.'
            : 'Heard “${r.heard}” in kanji, which can’t be checked against hiragana here. '
                'The answer is ${card['kana']} — did you say it?';
    }
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: c, width: 1),
        borderRadius: BorderRadius.circular(QuietRoomMetrics.radiusSm),
      ),
      padding: const EdgeInsets.fromLTRB(15, 12, 15, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(head,
              style: GoogleFonts.schibstedGrotesk(
                  fontSize: 14, fontWeight: FontWeight.w600, color: c)),
          const SizedBox(height: 3),
          Text(body,
              style: GoogleFonts.schibstedGrotesk(
                  fontSize: 13.5, height: 1.35, color: t.ink)),
          // When the machine genuinely cannot judge, ask the person rather than guess.
          // Scoring a correct answer as wrong is worse than admitting the limit.
          if (r.judgement == Judgement.unverified && r.heard.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(children: [
              OutlinedButton(
                onPressed: () => setState(() {
                  _right++;
                  _result = SpeechResult(r.heard, Judgement.correct);
                }),
                style: OutlinedButton.styleFrom(
                    side: BorderSide(color: t.sage600, width: 1),
                    foregroundColor: t.sage700),
                child: Text('I said it',
                    style: GoogleFonts.schibstedGrotesk(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: t.sage700)),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => setState(
                    () => _result = SpeechResult(r.heard, Judgement.wrong)),
                style: OutlinedButton.styleFrom(
                    side: BorderSide(color: t.border, width: 1),
                    foregroundColor: t.inkMuted),
                child: Text('I didn’t',
                    style: GoogleFonts.schibstedGrotesk(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: t.inkMuted)),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  /// Least revealing first. The learner decides how much help to take.
  Widget _hints(QuietRoomTokens t, Map<String, dynamic> card) {
    final kana = card['kana'] as String;
    final group = card['verbGroup'] as int?;
    final steps = <String>[
      'Meaning: ${card['gloss']}',
      if (group != null)
        'Group ${[
          '',
          'I',
          'II',
          'III'
        ][group]}${card['groupUncertain'] == true ? ', though the ます form alone cannot settle it' : ''}',
      'Starts with 「${kana.characters.first}」',
      kana,
    ];
    final maxLevel = steps.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('HINTS',
                style: GoogleFonts.schibstedGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 11 * 0.07,
                    color: t.inkMuted)),
            const Spacer(),
            if (_hintLevel < maxLevel)
              TextButton(
                onPressed: () => setState(() => _hintLevel++),
                style: TextButton.styleFrom(
                    minimumSize: const Size(0, QuietRoomMetrics.targetMin),
                    padding: const EdgeInsets.symmetric(horizontal: 8)),
                child: Text(_hintLevel == 0 ? 'Give me a hint' : 'More',
                    style: GoogleFonts.schibstedGrotesk(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: t.brand600)),
              ),
          ],
        ),
        if (_hintLevel == 0)
          Text('None taken.',
              style: GoogleFonts.schibstedGrotesk(
                  fontSize: 12.5, color: t.inkSubtle))
        else
          ...steps.take(_hintLevel).map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: t.surfaceTinted,
                    border: Border.all(color: t.border, width: 1),
                    borderRadius:
                        BorderRadius.circular(QuietRoomMetrics.radiusSm),
                  ),
                  padding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
                  child: Text(s,
                      style: GoogleFonts.schibstedGrotesk(
                          fontSize: 13.5, height: 1.35, color: t.ink)),
                ),
              )),
      ],
    );
  }
}

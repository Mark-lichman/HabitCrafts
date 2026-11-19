// A PronunciationService whose every check waits until the test answers it, shared by the
// probe widget and session tests (plan 2026-11-06, Task 5): no microphone, no network and no
// Firebase. The real service's scoring is tested in pronunciation_service_test.dart.

import 'dart:async';
import 'dart:typed_data';

import 'package:habit_craft/components/pages/quiet_room_practice/pronunciation_service.dart';

class _NoRecorder implements PronRecorder {
  @override
  Future<Stream<Uint8List>?> start(int sampleRate) async => null;
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

/// A pronunciation service whose every check waits until the test answers it.
class FakePronunciation extends PronunciationService {
  FakePronunciation()
      : super(
            recorder: _NoRecorder(),
            signIn: () async {},
            score: (_) async => null);

  final List<Completer<PronunciationResult>> checks = [];
  final List<String> referenceTexts = [];
  int cancels = 0;

  /// When set, a cancel counts but leaves the check open, so the test can end it itself.
  bool holdOnCancel = false;

  @override
  Future<PronunciationResult> check(String hiragana) {
    referenceTexts.add(hiragana);
    final c = Completer<PronunciationResult>();
    checks.add(c);
    return c.future;
  }

  @override
  Future<void> cancel() async {
    cancels++;
    if (holdOnCancel) return;
    for (final c in checks) {
      if (!c.isCompleted) c.complete(const PronunciationResult.unverified());
    }
  }

  /// Ends the last check with [j]. A verified verdict carries a score; unverified has none.
  void answer(Judgement j) => checks.last.complete(PronunciationResult(
      verdict: j, overall: j == Judgement.unverified ? null : 70));

  /// Ends the check the way a seam that throws does (the real check never throws).
  void fail(Object error) => checks.last.completeError(error);

  int disposes = 0;

  @override
  Future<void> dispose() async {
    disposes++;
    await super.dispose();
  }
}

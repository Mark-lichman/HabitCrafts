// Pins the speak wait (PIN-15): SpeechService.speak waits for the voice for at most
// SpeechService.speakWait, and that one named constant is the only place the wait is set.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_craft/components/pages/quiet_room_practice/speech_service.dart';

const _servicePath =
    'lib/components/pages/quiet_room_practice/speech_service.dart';
const _drillPath =
    'lib/components/pages/quiet_room_grammar/quiet_room_speak_widget.dart';

void main() {
  group('speak wait', () {
    test('is capped at 3 seconds', () {
      expect(SpeechService.speakWait, const Duration(seconds: 3));
    });

    test('speak() times out on the named constant, not a literal', () {
      final src = File(_servicePath).readAsStringSync();
      final speakBody = src.substring(src.indexOf('Future<String?> speak('),
          src.indexOf('Future<List<String>> voices('));
      expect(speakBody, contains('.timeout(speakWait'));
      expect(
          RegExp(r'\.timeout\(\s*const Duration').hasMatch(speakBody), isFalse);
    });

    test('no comment in the service or the drill names the old wait', () {
      final old = RegExp(r'\b(4|four)[- ]?(s|sec|second|seconds)\b',
          caseSensitive: false);
      for (final path in [_servicePath, _drillPath]) {
        final src = File(path).readAsStringSync();
        expect(old.hasMatch(src), isFalse, reason: path);
        expect(src.contains('seconds: 4'), isFalse, reason: path);
      }
    });
  });
}

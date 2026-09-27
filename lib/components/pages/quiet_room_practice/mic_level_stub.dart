// HAND-WRITTEN. Not FlutterFlow output, so S3 has nothing to adopt.
//
// The non-web half of [MicLevelTap]. On Android and iOS `speech_to_text` already reports
// amplitude through `onSoundLevelChange`, so there is nothing to add here and this returns
// a tap that never starts.

/// Independent microphone-amplitude source, used only where the speech recogniser
/// does not report one. See `mic_level_web.dart` for the implementation that does work.
class MicLevelTap {
  /// Returns false everywhere but the web, meaning "I am not the amplitude source here".
  Future<bool> start(void Function(double rms) onLevel) async => false;

  Future<void> stop() async {}
}

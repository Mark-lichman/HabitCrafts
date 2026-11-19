// HAND-WRITTEN. Not FlutterFlow output, so S3 has nothing to adopt.
//
// Real microphone amplitude on the web, via the Web Audio API.
//
// WHY THIS EXISTS. `speech_to_text` reports amplitude through `onSoundLevelChange` on
// Android and iOS, and its web implementation NEVER DOES -- the Web Speech API simply has
// no such callback. Until now that left the listening indicator flat in Chrome, which is
// the one platform this app is actually developed on, so the animation could not be judged
// without a full APK cycle.
//
// So we take our own reading: open a second microphone stream, run it through an
// AnalyserNode, and compute RMS off the time-domain buffer. That is the SAME SHAPE of data
// the mobile callback gives -- one amplitude scalar -- so both platforms feed the identical
// renderer and the animation looks the same everywhere. An FFT here would have been real
// too, but it would have made web show a spectrum that Android cannot.
//
// 🚨 IT STILL TELLS THE TRUTH OR SAYS NOTHING. Chrome permits several consumers of one
// microphone, so this normally coexists with speech recognition; where it does not, or
// where the user declines the prompt, [start] returns false, the level stays at 0, and the
// indicator falls back to its still state. A failure here must never fabricate motion.
//
// No dependency is added for this. `package:web` is only a transitive dependency of the
// Firebase plugins, and depending on it directly would be a promise we did not make (S11),
// so the four interfaces actually needed are declared below with `dart:js_interop`, which
// ships with the SDK.

import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data' show Uint8List;

@JS('navigator.mediaDevices')
external _MediaDevices? get _mediaDevices;

extension type _MediaDevices._(JSObject _) implements JSObject {
  external JSPromise<_MediaStream> getUserMedia(JSObject constraints);
}

extension type _MediaStream._(JSObject _) implements JSObject {
  external JSArray<_MediaStreamTrack> getTracks();
}

extension type _MediaStreamTrack._(JSObject _) implements JSObject {
  external void stop();
}

@JS('AudioContext')
extension type _AudioContext._(JSObject _) implements JSObject {
  external _AudioContext();
  external _AnalyserNode createAnalyser();
  external _AudioNode createMediaStreamSource(_MediaStream stream);
  external JSPromise<JSAny?> close();
  external JSPromise<JSAny?> resume();
  external String get state;
}

extension type _AudioNode._(JSObject _) implements JSObject {
  external void connect(JSObject destination);
  external void disconnect();
}

extension type _AnalyserNode._(JSObject _) implements _AudioNode {
  external set fftSize(int value);
  external int get frequencyBinCount;
  external void getByteTimeDomainData(JSUint8Array array);
}

/// Independent microphone-amplitude source for the web.
class MicLevelTap {
  static const _fftSize = 1024;

  /// ~30 Hz. Fast enough that a syllable registers, slow enough to cost nothing.
  static const _interval = Duration(milliseconds: 33);

  _AudioContext? _ctx;
  _MediaStream? _stream;
  _AnalyserNode? _analyser;
  JSUint8Array? _buffer;
  Timer? _poll;

  /// Opens the microphone and begins reporting RMS amplitude, 0..1.
  ///
  /// Returns false if the platform, the permission or the audio graph would not cooperate.
  /// The caller must treat false as "there is no amplitude here" and show a still state.
  Future<bool> start(void Function(double rms) onLevel) async {
    if (_poll != null) return true;
    final devices = _mediaDevices;
    if (devices == null) return false;
    try {
      final constraints = <String, Object>{'audio': true}.jsify() as JSObject;
      final stream = await devices.getUserMedia(constraints).toDart;
      final ctx = _AudioContext();
      // Autoplay policy can hand back a suspended context even inside a gesture.
      if (ctx.state != 'running') {
        await ctx.resume().toDart;
      }
      final analyser = ctx.createAnalyser()..fftSize = _fftSize;
      // Deliberately NOT connected to ctx.destination: routing the microphone to the
      // speakers would feed it straight back and howl.
      ctx.createMediaStreamSource(stream).connect(analyser);

      _stream = stream;
      _ctx = ctx;
      _analyser = analyser;
      _buffer = Uint8List(analyser.frequencyBinCount).toJS;

      _poll = Timer.periodic(_interval, (_) => _read(onLevel));
      return true;
    } catch (_) {
      // Permission refused, no input device, or a browser without Web Audio. Leave the
      // indicator still rather than inventing a level.
      await stop();
      return false;
    }
  }

  void _read(void Function(double rms) onLevel) {
    final analyser = _analyser;
    final buffer = _buffer;
    if (analyser == null || buffer == null) return;
    analyser.getByteTimeDomainData(buffer);
    final samples = buffer.toDart;
    // Time-domain bytes are centred on 128. RMS of the deviation is the loudness.
    var sum = 0.0;
    for (final s in samples) {
      final d = (s - 128) / 128.0;
      sum += d * d;
    }
    final rms = math.sqrt(sum / samples.length);
    // Speech RMS sits low (roughly 0.02 to 0.25), so lift it into a usable range here and
    // let the caller's decaying-maximum normaliser do the per-device fitting.
    onLevel((rms * 4).clamp(0.0, 1.0));
  }

  Future<void> stop() async {
    _poll?.cancel();
    _poll = null;
    try {
      _analyser?.disconnect();
      for (final t
          in _stream?.getTracks().toDart ?? const <_MediaStreamTrack>[]) {
        t.stop();
      }
      await _ctx?.close().toDart;
    } catch (_) {
      // Tearing down a graph that never fully came up is not worth reporting.
    }
    _analyser = null;
    _stream = null;
    _ctx = null;
    _buffer = null;
  }
}

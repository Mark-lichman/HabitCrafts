// Pure request and response logic for the scorePronunciation callable.
//
// Nothing here imports firebase-functions or touches the network on its own:
// index.js passes in the caller, the key, the region and an HTTP client, so
// score.test.js runs with plain `node --test` and a stubbed client.
//
// The function scores 16 kHz mono 16-bit PCM WAV (PIN-6) against the
// sentence's hiragana (PIN-1) with Azure Pronunciation Assessment on the
// short-audio REST endpoint, and returns the overall scores plus, per word,
// its score, its error type and its syllable scores in order (PIN-8).
'use strict';

// 30 seconds of 16 kHz mono 16-bit PCM is 960,000 bytes, plus the 44-byte
// header. The client stops listening well before that (PIN-5), and Azure's
// short-audio endpoint takes at most 60 seconds.
const MAX_AUDIO_SECONDS = 30;
const WAV_HEADER_BYTES = 44;
const MAX_AUDIO_BYTES = MAX_AUDIO_SECONDS * 16000 * 2 + WAV_HEADER_BYTES;
// A lesson sentence is short. This bounds the header Azure receives.
const MAX_REFERENCE_CHARS = 200;

// Error codes are Firebase callable codes, so index.js maps them 1:1 to
// HttpsError. The client treats every error as unverified, never as wrong (PIN-3).
class ScoreError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'ScoreError';
    this.code = code;
  }
}

function azureEndpoint(region) {
  const host = `${encodeURIComponent(region)}.stt.speech.microsoft.com`;
  return (
    `https://${host}/speech/recognition/conversation/cognitiveservices/v1` +
    '?language=ja-JP&format=detailed'
  );
}

// Granularity Phoneme also returns per-syllable scores, which the drill uses
// to color each hiragana letter (PIN-8). Miscue on marks inserted and omitted
// words.
function pronunciationAssessmentHeader(referenceText) {
  const params = {
    ReferenceText: referenceText,
    GradingSystem: 'HundredMark',
    Granularity: 'Phoneme',
    Dimension: 'Comprehensive',
    EnableMiscue: true,
  };
  return Buffer.from(JSON.stringify(params), 'utf8').toString('base64');
}

function buildAzureRequest({ audio, referenceText, key, region }) {
  return {
    url: azureEndpoint(region),
    init: {
      method: 'POST',
      headers: {
        'Ocp-Apim-Subscription-Key': key,
        'Content-Type': 'audio/wav; codecs=audio/pcm; samplerate=16000',
        Accept: 'application/json',
        'Pronunciation-Assessment': pronunciationAssessmentHeader(referenceText.trim()),
      },
      body: audio,
    },
  };
}

// Walks the RIFF chunks and checks the fmt chunk: PCM, 1 channel, 16 kHz,
// 16 bits. Recorders may put a LIST chunk before fmt, so the walk does not
// assume a fixed offset.
function checkWav(buf) {
  if (
    buf.length < WAV_HEADER_BYTES ||
    buf.toString('ascii', 0, 4) !== 'RIFF' ||
    buf.toString('ascii', 8, 12) !== 'WAVE'
  ) {
    throw new ScoreError('invalid-argument', 'audio is not a WAV file');
  }
  let offset = 12;
  while (offset + 8 <= buf.length) {
    const id = buf.toString('ascii', offset, offset + 4);
    const size = buf.readUInt32LE(offset + 4);
    if (id === 'fmt ') {
      if (offset + 8 + 16 > buf.length) break;
      const format = buf.readUInt16LE(offset + 8);
      const channels = buf.readUInt16LE(offset + 10);
      const sampleRate = buf.readUInt32LE(offset + 12);
      const bits = buf.readUInt16LE(offset + 22);
      if (format !== 1 || channels !== 1 || sampleRate !== 16000 || bits !== 16) {
        throw new ScoreError(
          'invalid-argument',
          `audio must be 16 kHz mono 16-bit PCM WAV, got format ${format}, ` +
            `${channels} channel(s), ${sampleRate} Hz, ${bits} bits`,
        );
      }
      return;
    }
    offset += 8 + size + (size % 2);
  }
  throw new ScoreError('invalid-argument', 'audio has no WAV fmt chunk');
}

function checkInput(data) {
  if (!data || typeof data !== 'object') {
    throw new ScoreError('invalid-argument', 'expected { audio, referenceText }');
  }
  const { audio, referenceText } = data;
  if (typeof audio !== 'string' || audio.length === 0) {
    throw new ScoreError('invalid-argument', 'audio must be a non-empty base64 string');
  }
  // Reject on the encoded length first, so an oversized payload is never decoded.
  if (audio.length > Math.ceil(MAX_AUDIO_BYTES / 3) * 4 + 4) {
    throw new ScoreError('invalid-argument', `audio is over the size cap of ${MAX_AUDIO_BYTES} bytes`);
  }
  const bytes = Buffer.from(audio, 'base64');
  if (bytes.length > MAX_AUDIO_BYTES) {
    throw new ScoreError('invalid-argument', `audio is over the size cap of ${MAX_AUDIO_BYTES} bytes`);
  }
  checkWav(bytes);
  if (typeof referenceText !== 'string' || referenceText.trim().length === 0) {
    throw new ScoreError('invalid-argument', 'referenceText must be the sentence in hiragana');
  }
  if ([...referenceText.trim()].length > MAX_REFERENCE_CHARS) {
    throw new ScoreError('invalid-argument', `referenceText is over ${MAX_REFERENCE_CHARS} characters`);
  }
  return { audio: bytes, referenceText };
}

function num(value) {
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

// Azure returns empty syllable text for ja-JP, so the client maps syllables
// to letters by index (PIN-8). Order is kept exactly as Azure sends it.
function parseAzureReply(reply) {
  if (!reply || typeof reply !== 'object' || typeof reply.RecognitionStatus !== 'string') {
    throw new ScoreError('internal', 'Azure reply has no RecognitionStatus');
  }
  if (reply.RecognitionStatus !== 'Success') {
    throw new ScoreError('failed-precondition', `Azure could not recognize the audio: ${reply.RecognitionStatus}`);
  }
  const best = Array.isArray(reply.NBest) ? reply.NBest[0] : undefined;
  if (!best || num(best.PronScore) === null || !Array.isArray(best.Words)) {
    throw new ScoreError('internal', 'Azure reply has no pronunciation scores');
  }
  return {
    pronScore: best.PronScore,
    accuracyScore: num(best.AccuracyScore),
    fluencyScore: num(best.FluencyScore),
    completenessScore: num(best.CompletenessScore),
    recognizedText: typeof reply.DisplayText === 'string' ? reply.DisplayText : '',
    words: best.Words.map((w) => ({
      word: typeof w.Word === 'string' ? w.Word : '',
      accuracyScore: num(w.AccuracyScore),
      errorType: typeof w.ErrorType === 'string' ? w.ErrorType : 'None',
      syllableScores: Array.isArray(w.Syllables) ? w.Syllables.map((s) => num(s.AccuracyScore)) : [],
    })),
  };
}

// The whole callable body. `request` is the onCall request ({ auth, data }).
// Any signed-in Firebase user passes, anonymous included (PIN-9). No sign-in
// at all is rejected before anything else runs (PIN-2).
async function scorePronunciation(request, { key, region, httpPost }) {
  if (!request || !request.auth) {
    throw new ScoreError('unauthenticated', 'sign in to score pronunciation');
  }
  const { audio, referenceText } = checkInput(request.data);
  if (!key || !region) {
    throw new ScoreError('failed-precondition', 'AZURE_SPEECH_KEY or AZURE_SPEECH_REGION is not set');
  }
  const { url, init } = buildAzureRequest({ audio, referenceText, key, region });
  let response;
  try {
    response = await httpPost(url, init);
  } catch (err) {
    // The message of a network error can echo request details, so it is not passed on.
    throw new ScoreError('unavailable', 'could not reach Azure Speech');
  }
  if (!response || !response.ok) {
    throw new ScoreError('unavailable', `Azure Speech returned HTTP ${response ? response.status : 'nothing'}`);
  }
  let reply;
  try {
    reply = await response.json();
  } catch (err) {
    throw new ScoreError('internal', 'Azure Speech returned a body that is not JSON');
  }
  return parseAzureReply(reply);
}

module.exports = {
  MAX_AUDIO_SECONDS,
  MAX_AUDIO_BYTES,
  MAX_REFERENCE_CHARS,
  ScoreError,
  azureEndpoint,
  buildAzureRequest,
  checkWav,
  pronunciationAssessmentHeader,
  parseAzureReply,
  scorePronunciation,
};

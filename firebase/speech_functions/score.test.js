// Tests for the pure scoring logic behind scorePronunciation.
// Run: node --test firebase/speech_functions/*.test.js
//
// No network and no firebase-functions install: the Azure HTTP call is a stub,
// and the replies are the real ones Azure returned for Mark's voice on
// 2026-10-27 (fixtures/).
'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const {
  MAX_AUDIO_BYTES,
  MAX_REFERENCE_CHARS,
  ScoreError,
  azureEndpoint,
  buildAzureRequest,
  pronunciationAssessmentHeader,
  parseAzureReply,
  scorePronunciation,
} = require('./score.js');

const REFERENCE = 'あたまがいたいんです';

function fixture(name) {
  return JSON.parse(
    fs.readFileSync(path.join(__dirname, 'fixtures', name), 'utf8'),
  );
}

const GOOD = fixture('azure-reply-L26-1-mark.json');
const BAD = fixture('azure-reply-L26-1-mark-mispronounced.json');

// A valid 16 kHz mono 16-bit PCM WAV with `samples` samples of silence.
function wav({
  samples = 1600,
  sampleRate = 16000,
  channels = 1,
  bits = 16,
  format = 1,
} = {}) {
  const dataBytes = samples * channels * (bits / 8);
  const buf = Buffer.alloc(44 + dataBytes);
  buf.write('RIFF', 0, 'ascii');
  buf.writeUInt32LE(36 + dataBytes, 4);
  buf.write('WAVE', 8, 'ascii');
  buf.write('fmt ', 12, 'ascii');
  buf.writeUInt32LE(16, 16);
  buf.writeUInt16LE(format, 20);
  buf.writeUInt16LE(channels, 22);
  buf.writeUInt32LE(sampleRate, 24);
  buf.writeUInt32LE(sampleRate * channels * (bits / 8), 28);
  buf.writeUInt16LE(channels * (bits / 8), 32);
  buf.writeUInt16LE(bits, 34);
  buf.write('data', 36, 'ascii');
  buf.writeUInt32LE(dataBytes, 40);
  return buf;
}

function okHttp(reply, calls = []) {
  return async (url, init) => {
    calls.push({ url, init });
    return { status: 200, ok: true, json: async () => reply };
  };
}

const CONFIG = { key: 'test-key-not-real', region: 'eastus' };

function call(overrides = {}) {
  return {
    auth: { uid: 'u1', token: { firebase: { sign_in_provider: 'anonymous' } } },
    data: { audio: wav().toString('base64'), referenceText: REFERENCE },
    ...overrides,
  };
}

// --- caller and input checks ------------------------------------------------

test('rejects a caller with no Firebase sign-in (PIN-2)', async () => {
  const calls = [];
  await assert.rejects(
    scorePronunciation(call({ auth: null }), { ...CONFIG, httpPost: okHttp(GOOD, calls) }),
    (err) => err instanceof ScoreError && err.code === 'unauthenticated',
  );
  await assert.rejects(
    scorePronunciation(call({ auth: undefined }), { ...CONFIG, httpPost: okHttp(GOOD, calls) }),
    (err) => err instanceof ScoreError && err.code === 'unauthenticated',
  );
  assert.equal(calls.length, 0, 'no Azure call for an unauthenticated caller');
});

test('accepts an anonymous Firebase user as a caller (PIN-9)', async () => {
  const result = await scorePronunciation(call(), { ...CONFIG, httpPost: okHttp(GOOD) });
  assert.equal(result.pronScore, 98.6);
});

test('rejects audio over the size cap before calling Azure', async () => {
  const calls = [];
  const samples = (MAX_AUDIO_BYTES - 44) / 2 + 1;
  const big = wav({ samples }).toString('base64');
  await assert.rejects(
    scorePronunciation(call({ data: { audio: big, referenceText: REFERENCE } }), {
      ...CONFIG,
      httpPost: okHttp(GOOD, calls),
    }),
    (err) => err.code === 'invalid-argument' && /size cap/.test(err.message),
  );
  assert.equal(calls.length, 0);
});

test('accepts audio exactly at the size cap', async () => {
  const samples = (MAX_AUDIO_BYTES - 44) / 2;
  const atCap = wav({ samples });
  assert.equal(atCap.length, MAX_AUDIO_BYTES);
  const result = await scorePronunciation(
    call({ data: { audio: atCap.toString('base64'), referenceText: REFERENCE } }),
    { ...CONFIG, httpPost: okHttp(GOOD) },
  );
  assert.equal(result.pronScore, 98.6);
});

test('rejects audio that is not 16 kHz mono 16-bit PCM WAV (PIN-6)', async () => {
  const bad = [
    Buffer.from('not a wav file at all, just text padding.....'),
    wav({ sampleRate: 44100 }),
    wav({ channels: 2 }),
    wav({ bits: 8 }),
    wav({ format: 3 }),
  ];
  for (const audio of bad) {
    await assert.rejects(
      scorePronunciation(call({ data: { audio: audio.toString('base64'), referenceText: REFERENCE } }), {
        ...CONFIG,
        httpPost: okHttp(GOOD),
      }),
      (err) => err.code === 'invalid-argument',
    );
  }
});

test('rejects missing or empty audio and reference text', async () => {
  const cases = [
    {},
    { audio: '', referenceText: REFERENCE },
    { audio: wav().toString('base64') },
    { audio: wav().toString('base64'), referenceText: '   ' },
    { audio: wav().toString('base64'), referenceText: 'あ'.repeat(MAX_REFERENCE_CHARS + 1) },
    { audio: 42, referenceText: REFERENCE },
  ];
  for (const data of cases) {
    await assert.rejects(
      scorePronunciation(call({ data }), { ...CONFIG, httpPost: okHttp(GOOD) }),
      (err) => err.code === 'invalid-argument',
    );
  }
  await assert.rejects(
    scorePronunciation(call({ data: null }), { ...CONFIG, httpPost: okHttp(GOOD) }),
    (err) => err.code === 'invalid-argument',
  );
});

test('fails with failed-precondition when the key or region is not set', async () => {
  for (const cfg of [{ key: '', region: 'eastus' }, { key: 'k', region: '' }]) {
    await assert.rejects(
      scorePronunciation(call(), { ...cfg, httpPost: okHttp(GOOD) }),
      (err) => err.code === 'failed-precondition',
    );
  }
});

// --- the Azure request ------------------------------------------------------

test('the request goes to the ja-JP short-audio endpoint in the configured region', () => {
  const url = new URL(azureEndpoint('eastus'));
  assert.equal(url.origin, 'https://eastus.stt.speech.microsoft.com');
  assert.equal(url.pathname, '/speech/recognition/conversation/cognitiveservices/v1');
  assert.equal(url.searchParams.get('language'), 'ja-JP');
  assert.equal(url.searchParams.get('format'), 'detailed');
});

test('the Pronunciation-Assessment header carries the hiragana reference text (PIN-1)', () => {
  const header = pronunciationAssessmentHeader(REFERENCE);
  const decoded = JSON.parse(Buffer.from(header, 'base64').toString('utf8'));
  assert.deepEqual(decoded, {
    ReferenceText: REFERENCE,
    GradingSystem: 'HundredMark',
    Granularity: 'Phoneme',
    Dimension: 'Comprehensive',
    EnableMiscue: true,
  });
});

test('the request posts the WAV body with the key, content type and header', async () => {
  const calls = [];
  const audio = wav();
  await scorePronunciation(
    call({ data: { audio: audio.toString('base64'), referenceText: REFERENCE } }),
    { ...CONFIG, httpPost: okHttp(GOOD, calls) },
  );
  assert.equal(calls.length, 1);
  const { url, init } = calls[0];
  assert.equal(url, azureEndpoint('eastus'));
  assert.equal(init.method, 'POST');
  assert.equal(init.headers['Ocp-Apim-Subscription-Key'], CONFIG.key);
  assert.equal(init.headers['Content-Type'], 'audio/wav; codecs=audio/pcm; samplerate=16000');
  assert.equal(init.headers['Accept'], 'application/json');
  const pa = JSON.parse(Buffer.from(init.headers['Pronunciation-Assessment'], 'base64').toString('utf8'));
  assert.equal(pa.ReferenceText, REFERENCE);
  assert.equal(pa.EnableMiscue, true);
  assert.ok(Buffer.from(init.body).equals(audio), 'body is the decoded WAV bytes');
});

test('buildAzureRequest trims the reference text', () => {
  const req = buildAzureRequest({ audio: wav(), referenceText: `  ${REFERENCE}\n`, ...CONFIG });
  const pa = JSON.parse(Buffer.from(req.init.headers['Pronunciation-Assessment'], 'base64').toString('utf8'));
  assert.equal(pa.ReferenceText, REFERENCE);
});

// --- the Azure reply --------------------------------------------------------

test('parses the good L26-1 reply: overall, per-word and per-syllable scores', () => {
  const r = parseAzureReply(GOOD);
  assert.deepEqual(
    {
      pronScore: r.pronScore,
      accuracyScore: r.accuracyScore,
      fluencyScore: r.fluencyScore,
      completenessScore: r.completenessScore,
    },
    { pronScore: 98.6, accuracyScore: 98, fluencyScore: 99, completenessScore: 100 },
  );
  assert.equal(r.recognizedText, 'あ、たまがいたいんです。');
  assert.deepEqual(r.words, [
    { word: 'あたま', accuracyScore: 97, errorType: 'None', syllableScores: [85, 100, 100] },
    { word: 'が', accuracyScore: 100, errorType: 'None', syllableScores: [100] },
    { word: 'いたい', accuracyScore: 97, errorType: 'None', syllableScores: [95, 98, 93] },
    { word: 'ん', accuracyScore: 100, errorType: 'None', syllableScores: [100] },
    { word: 'です', accuracyScore: 97, errorType: 'None', syllableScores: [93, 79] },
  ]);
});

test('parses the mispronounced L26-1 reply, keeping the inserted word and error types', () => {
  const r = parseAzureReply(BAD);
  assert.equal(r.pronScore, 44.8);
  assert.equal(r.accuracyScore, 60);
  assert.equal(r.fluencyScore, 44);
  assert.equal(r.completenessScore, 40);
  assert.deepEqual(r.words, [
    { word: 'あたま', accuracyScore: 44, errorType: 'Insertion', syllableScores: [72, 14, 82] },
    { word: 'あたま', accuracyScore: 49, errorType: 'Mispronunciation', syllableScores: [12, 64, 0] },
    { word: 'が', accuracyScore: 100, errorType: 'None', syllableScores: [100] },
    { word: 'いたい', accuracyScore: 50, errorType: 'Mispronunciation', syllableScores: [7, 79, 42] },
    { word: 'ん', accuracyScore: 6, errorType: 'Mispronunciation', syllableScores: [6] },
    { word: 'です', accuracyScore: 97, errorType: 'None', syllableScores: [88, 76] },
  ]);
});

test('scorePronunciation returns the parsed scores for both recorded replies', async () => {
  const good = await scorePronunciation(call(), { ...CONFIG, httpPost: okHttp(GOOD) });
  assert.deepEqual(good, parseAzureReply(GOOD));
  const bad = await scorePronunciation(call(), { ...CONFIG, httpPost: okHttp(BAD) });
  assert.deepEqual(bad, parseAzureReply(BAD));
});

test('a word with no syllables or a missing error type still parses', () => {
  const r = parseAzureReply({
    RecognitionStatus: 'Success',
    DisplayText: 'x',
    NBest: [
      {
        PronScore: 50,
        AccuracyScore: 50,
        FluencyScore: 50,
        CompletenessScore: 50,
        Words: [{ Word: 'です', AccuracyScore: 0 }],
      },
    ],
  });
  assert.deepEqual(r.words, [
    { word: 'です', accuracyScore: 0, errorType: 'None', syllableScores: [] },
  ]);
});

test('a reply Azure could not recognize fails as no-match, not as a score', () => {
  for (const status of ['NoMatch', 'InitialSilenceTimeout', 'BabbleTimeout', 'Error']) {
    assert.throws(
      () => parseAzureReply({ RecognitionStatus: status }),
      (err) => err instanceof ScoreError && err.code === 'failed-precondition' && err.message.includes(status),
    );
  }
});

test('a malformed reply fails as internal', () => {
  for (const reply of [
    null,
    {},
    { RecognitionStatus: 'Success' },
    { RecognitionStatus: 'Success', NBest: [] },
    { RecognitionStatus: 'Success', NBest: [{ AccuracyScore: 1 }] },
  ]) {
    assert.throws(() => parseAzureReply(reply), (err) => err.code === 'internal');
  }
});

// --- Azure call failures ----------------------------------------------------

test('an Azure HTTP error fails as unavailable, never as a score (PIN-3)', async () => {
  for (const status of [400, 401, 429, 500, 503]) {
    const httpPost = async () => ({ status, ok: false, json: async () => ({}) });
    await assert.rejects(
      scorePronunciation(call(), { ...CONFIG, httpPost }),
      (err) => err.code === 'unavailable' && err.message.includes(String(status)),
    );
  }
});

test('a network failure fails as unavailable and does not leak the key', async () => {
  const httpPost = async () => {
    throw new Error(`socket hang up ${CONFIG.key}`);
  };
  await assert.rejects(
    scorePronunciation(call(), { ...CONFIG, httpPost }),
    (err) => err.code === 'unavailable' && !err.message.includes(CONFIG.key),
  );
});

test('an unparseable Azure body fails as internal', async () => {
  const httpPost = async () => ({
    status: 200,
    ok: true,
    json: async () => {
      throw new SyntaxError('Unexpected token');
    },
  });
  await assert.rejects(
    scorePronunciation(call(), { ...CONFIG, httpPost }),
    (err) => err.code === 'internal',
  );
});

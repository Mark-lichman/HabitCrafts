// The speech_functions codebase: one callable, scorePronunciation.
//
// The Azure key lives only in Secret Manager (AZURE_SPEECH_KEY), never in the
// repo or the app (PIN-2). The region is a plain param (AZURE_SPEECH_REGION),
// not a secret. All request and reply logic is in score.js.
'use strict';

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret, defineString } = require('firebase-functions/params');
const { scorePronunciation, ScoreError } = require('./score.js');

const azureSpeechKey = defineSecret('AZURE_SPEECH_KEY');
const azureSpeechRegion = defineString('AZURE_SPEECH_REGION');

exports.scorePronunciation = onCall(
  { region: 'us-central1', secrets: [azureSpeechKey], timeoutSeconds: 60, memory: '256MiB' },
  async (request) => {
    try {
      return await scorePronunciation(request, {
        key: azureSpeechKey.value(),
        region: azureSpeechRegion.value(),
        httpPost: (url, init) => fetch(url, init),
      });
    } catch (err) {
      if (err instanceof ScoreError) {
        throw new HttpsError(err.code, err.message);
      }
      throw new HttpsError('internal', 'scorePronunciation failed');
    }
  },
);

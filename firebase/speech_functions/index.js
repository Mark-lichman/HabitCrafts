// The speech_functions codebase: one callable, scorePronunciation.
//
// The Azure key lives only in Secret Manager (AZURE_SPEECH_KEY), never in the
// repo or the app (PIN-2). The region is a plain param (AZURE_SPEECH_REGION),
// not a secret. All request and reply logic is in score.js.
'use strict';

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');
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
        // A stalled Azure connection aborts after 20 s; score.js maps the
        // rejected post to unavailable, so no new handling is needed.
        httpPost: (url, init) => fetch(url, { ...init, signal: AbortSignal.timeout(20000) }),
      });
    } catch (err) {
      // The SDK logs only errors that are not HttpsError, so log the cause
      // here. ScoreError messages are sanitized and carry the Azure HTTP
      // status; the key is never part of them.
      if (err instanceof ScoreError) {
        logger.warn('scorePronunciation rejected', { code: err.code, message: err.message });
        throw new HttpsError(err.code, err.message);
      }
      logger.error('scorePronunciation failed', err);
      throw new HttpsError('internal', 'scorePronunciation failed');
    }
  },
);

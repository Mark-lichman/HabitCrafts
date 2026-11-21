// Account delete removes the synced record (End states 8 and 17, PIN-13 and
// PIN-14).
//
// Runs under `firebase emulators:exec` with the Auth, Functions and Firestore
// emulators (see package.json). The test deletes a real Auth user, so the real
// `deleteAllUserData` trigger in custom_cloud_functions runs, and the test
// waits until it has emptied users/{uid}/jp_events, jp_days and devices.
'use strict';

const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { randomUUID } = require('node:crypto');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const {
  doc,
  getDoc,
  getDocs,
  collection,
  setDoc,
  deleteDoc,
} = require('firebase/firestore');

const PROJECT_ID = process.env.GCLOUD_PROJECT || 'demo-habitcrafts';
const AUTH_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';
const AUTH_ADMIN = `http://${AUTH_HOST}/identitytoolkit.googleapis.com/v1/projects/${PROJECT_ID}`;

/** The trigger starts a Node worker on first use, so allow it some time. */
const CASCADE_TIMEOUT_MS = 60000;

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8'),
    },
  });
});

after(async () => {
  if (env) await env.cleanup();
});

/** Calls the Auth emulator's admin API. `Bearer owner` is its admin token. */
async function authAdmin(route, body) {
  const res = await fetch(`${AUTH_ADMIN}/${route}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: 'Bearer owner' },
    body: JSON.stringify(body),
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`Auth emulator ${route} returned ${res.status}: ${text}`);
  return text ? JSON.parse(text) : {};
}

async function createAuthUser(uid) {
  await authAdmin('accounts', {
    localId: uid,
    email: `${uid}@example.com`,
    password: 'not-a-real-password',
  });
}

async function deleteAuthUser(uid) {
  await authAdmin('accounts:delete', { localId: uid });
}

/** A document read or written past the rules, as the admin SDK would. */
async function asAdmin(fn) {
  let result;
  await env.withSecurityRulesDisabled(async (ctx) => {
    result = await fn(ctx.firestore());
  });
  return result;
}

async function countDocs(uid, sub) {
  return asAdmin(async (db) => (await getDocs(collection(db, 'users', uid, sub))).size);
}

async function exists(docPath) {
  return asAdmin(async (db) => (await getDoc(doc(db, docPath))).exists());
}

/** Polls until `check` returns true, or fails with the last state seen. */
async function waitFor(check, describe) {
  const deadline = Date.now() + CASCADE_TIMEOUT_MS;
  for (;;) {
    if (await check()) return;
    if (Date.now() > deadline) {
      throw new Error(`timed out after ${CASCADE_TIMEOUT_MS} ms: ${await describe()}`);
    }
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
}

function owner(uid) {
  return env.authenticatedContext(uid, { firebase: { sign_in_provider: 'password' } }).firestore();
}

function event(id) {
  return {
    id,
    deviceId: 'device-a',
    eventTime: 1763500000000,
    kind: 'attempt',
    body: { itemId: 'jp:kanji:日' },
  };
}

function day() {
  return {
    day: 20411,
    plan: '{"entries":[]}',
    position: 0,
    completed: false,
    deviceId: 'device-a',
    builtAt: 1763500000000,
  };
}

/** A signed-up account that has synced from two devices. */
async function seedSyncedAccount(uid) {
  await createAuthUser(uid);
  await asAdmin((db) => setDoc(doc(db, 'users', uid), { uid, display_name: 'Learner' }));
  const phone = owner(uid);
  const browser = owner(uid);
  await assertSucceeds(setDoc(doc(phone, 'users', uid, 'jp_events', 'p1'), event('p1')));
  await assertSucceeds(setDoc(doc(browser, 'users', uid, 'jp_events', 'b1'), event('b1')));
  await assertSucceeds(setDoc(doc(phone, 'users', uid, 'jp_days', '20411'), day()));
  await assertSucceeds(setDoc(doc(phone, 'users', uid, 'devices', 'device-a'), { lastSyncAt: 1 }));
  await assertSucceeds(setDoc(doc(browser, 'users', uid, 'devices', 'device-b'), { lastSyncAt: 1 }));
}

async function cascadeState(uid) {
  return JSON.stringify({
    profile: await exists(`users/${uid}`),
    marker: await exists(`deleted_accounts/${uid}`),
    jp_events: await countDocs(uid, 'jp_events'),
    jp_days: await countDocs(uid, 'jp_days'),
    devices: await countDocs(uid, 'devices'),
  });
}

async function cascadeDone(uid) {
  return (
    !(await exists(`users/${uid}`)) &&
    (await countDocs(uid, 'jp_events')) === 0 &&
    (await countDocs(uid, 'jp_days')) === 0 &&
    (await countDocs(uid, 'devices')) === 0
  );
}

test('deleting the Auth user empties jp_events, jp_days and devices (PIN-14)', async () => {
  const uid = `cascade-${randomUUID()}`;
  await seedSyncedAccount(uid);
  assert.equal(await countDocs(uid, 'jp_events'), 2);
  assert.equal(await countDocs(uid, 'jp_days'), 1);
  assert.equal(await countDocs(uid, 'devices'), 2);

  await deleteAuthUser(uid);

  await waitFor(() => cascadeDone(uid), () => cascadeState(uid));
  assert.equal(
    await exists(`deleted_accounts/${uid}`),
    true,
    'the cleanup leaves a deleted_accounts marker',
  );
});

test('after account delete, a device that recreates users/{uid} still cannot write study data (PIN-13)', async () => {
  const uid = `recreate-${randomUUID()}`;
  await seedSyncedAccount(uid);
  await deleteAuthUser(uid);
  await waitFor(() => cascadeDone(uid), () => cascadeState(uid));

  // The browser still holds an unexpired token. The unchanged users rule lets
  // it recreate the profile, which used to reopen the jp rules.
  const browser = owner(uid);
  await assertSucceeds(setDoc(doc(browser, 'users', uid), { uid, display_name: 'Learner' }));

  await assertFails(setDoc(doc(browser, 'users', uid, 'jp_events', 'late'), event('late')));
  await assertFails(setDoc(doc(browser, 'users', uid, 'jp_days', '20412'), { ...day(), day: 20412 }));
  await assertFails(setDoc(doc(browser, 'users', uid, 'devices', 'device-b'), { lastSyncAt: 2 }));
  assert.equal(await countDocs(uid, 'jp_events'), 0);
  assert.equal(await countDocs(uid, 'jp_days'), 0);
  assert.equal(await countDocs(uid, 'devices'), 0);
});

test('deleted_accounts is admin only: no client may read or write a marker', async () => {
  const uid = `marker-${randomUUID()}`;
  await asAdmin((db) => setDoc(doc(db, 'deleted_accounts', uid), { deletedAt: 1 }));
  const db = owner(uid);
  await assertFails(getDoc(doc(db, 'deleted_accounts', uid)));
  await assertFails(getDocs(collection(db, 'deleted_accounts')));
  await assertFails(setDoc(doc(db, 'deleted_accounts', uid), { deletedAt: 2 }));
  await assertFails(deleteDoc(doc(db, 'deleted_accounts', uid)));
  // A user cannot plant a marker for themselves or for someone else.
  const fresh = `marker-${randomUUID()}`;
  await assertFails(setDoc(doc(owner(fresh), 'deleted_accounts', fresh), { deletedAt: 3 }));
  await assertFails(setDoc(doc(owner(fresh), 'deleted_accounts', uid), { deletedAt: 3 }));
});

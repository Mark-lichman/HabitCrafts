// Rules for the synced Japanese record: users/{uid}/jp_events, jp_days and
// devices (End states 5 and 17).
//
// Runs on the Firestore emulator under `firebase emulators:exec` (see
// package.json). Every test uses its own uids, because the functions emulator
// runs the real triggers on users/{uid} and a slow trigger from one test must
// not touch the documents of the next.
'use strict';

const { test, before, after } = require('node:test');
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
  updateDoc,
  deleteDoc,
} = require('firebase/firestore');

const PROJECT_ID = process.env.GCLOUD_PROJECT || 'demo-habitcrafts';

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

/** A fresh uid, so no two tests share a profile. */
function newUid(name) {
  return `${name}-${randomUUID()}`;
}

/**
 * The users/{uid} profile, written past the rules as sign-up would. It
 * carries display_name because the addSearchTermsForUsers trigger reads it;
 * the trigger only updates the profile, so it never recreates a deleted one.
 */
async function seedProfile(uid) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users', uid), { uid, display_name: 'Learner' });
  });
}

/** A document written past the rules. */
async function seed(docPath, data) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), docPath), data);
  });
}

/**
 * What the account-delete cleanup does: the deleted_accounts marker first,
 * then the profile and every subcollection.
 */
async function deleteProfile(uid) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'deleted_accounts', uid), { deletedAt: 1763500000000 });
    for (const sub of ['jp_events', 'jp_days', 'devices']) {
      const snap = await getDocs(collection(db, 'users', uid, sub));
      for (const d of snap.docs) await deleteDoc(d.ref);
    }
    await deleteDoc(doc(db, 'users', uid));
  });
}

function owner(uid) {
  return env.authenticatedContext(uid, { firebase: { sign_in_provider: 'google.com' } }).firestore();
}

function anonymous(uid) {
  return env.authenticatedContext(uid, { firebase: { sign_in_provider: 'anonymous' } }).firestore();
}

function signedOut() {
  return env.unauthenticatedContext().firestore();
}

function event(id, extra = {}) {
  return {
    id,
    deviceId: 'device-a',
    eventTime: 1763500000000,
    kind: 'attempt',
    body: { itemId: 'jp:kanji:日' },
    ...extra,
  };
}

function day(extra = {}) {
  return {
    day: 20411,
    plan: '{"entries":[]}',
    position: 0,
    completed: false,
    deviceId: 'device-a',
    builtAt: 1763500000000,
    ...extra,
  };
}

// ---------------------------------------------------------------- jp_events

test('jp_events: the owner can create and read their events', async () => {
  const uid = newUid('alice');
  await seedProfile(uid);
  const db = owner(uid);
  const ref = doc(db, 'users', uid, 'jp_events', 'e1');
  await assertSucceeds(setDoc(ref, event('e1')));
  await assertSucceeds(getDoc(ref));
  await assertSucceeds(getDocs(collection(db, 'users', uid, 'jp_events')));
});

test('jp_events: an event is never updated, even by its owner', async () => {
  const uid = newUid('alice');
  await seedProfile(uid);
  await seed(`users/${uid}/jp_events/e1`, event('e1'));
  const ref = doc(owner(uid), 'users', uid, 'jp_events', 'e1');
  await assertFails(updateDoc(ref, { kind: 'seed' }));
  // A second create of the same id is an update, so it fails too.
  await assertFails(setDoc(ref, event('e1', { kind: 'seed' })));
});

test('jp_events: an event is never deleted by a client', async () => {
  const uid = newUid('alice');
  await seedProfile(uid);
  await seed(`users/${uid}/jp_events/e1`, event('e1'));
  await assertFails(deleteDoc(doc(owner(uid), 'users', uid, 'jp_events', 'e1')));
});

test('jp_events: another signed-in user can neither read nor write them', async () => {
  const uid = newUid('alice');
  const other = newUid('bob');
  await seedProfile(uid);
  await seedProfile(other);
  await seed(`users/${uid}/jp_events/e1`, event('e1'));
  const db = owner(other);
  await assertFails(getDoc(doc(db, 'users', uid, 'jp_events', 'e1')));
  await assertFails(getDocs(collection(db, 'users', uid, 'jp_events')));
  await assertFails(setDoc(doc(db, 'users', uid, 'jp_events', 'e2'), event('e2')));
});

test('jp_events: an anonymous user never syncs, even under their own uid', async () => {
  const uid = newUid('anon');
  await seedProfile(uid);
  await seed(`users/${uid}/jp_events/e1`, event('e1'));
  const db = anonymous(uid);
  await assertFails(getDoc(doc(db, 'users', uid, 'jp_events', 'e1')));
  await assertFails(getDocs(collection(db, 'users', uid, 'jp_events')));
  await assertFails(setDoc(doc(db, 'users', uid, 'jp_events', 'e2'), event('e2')));
});

test('jp_events: a signed-out client can neither read nor write them', async () => {
  const uid = newUid('alice');
  await seedProfile(uid);
  await seed(`users/${uid}/jp_events/e1`, event('e1'));
  const db = signedOut();
  await assertFails(getDoc(doc(db, 'users', uid, 'jp_events', 'e1')));
  await assertFails(setDoc(doc(db, 'users', uid, 'jp_events', 'e2'), event('e2')));
});

test('jp_events: no create without a users/{uid} profile', async () => {
  const uid = newUid('alice');
  await assertFails(setDoc(doc(owner(uid), 'users', uid, 'jp_events', 'e1'), event('e1')));
});

// ------------------------------------------------------------------ jp_days

test('jp_days: the owner can create and read a day plan', async () => {
  const uid = newUid('alice');
  await seedProfile(uid);
  const ref = doc(owner(uid), 'users', uid, 'jp_days', '20411');
  await assertSucceeds(setDoc(ref, day()));
  await assertSucceeds(getDoc(ref));
});

test('jp_days: the first plan wins, and a second device cannot replace it', async () => {
  const uid = newUid('alice');
  await seedProfile(uid);
  const deviceA = owner(uid);
  const deviceB = owner(uid);
  await assertSucceeds(setDoc(doc(deviceA, 'users', uid, 'jp_days', '20411'), day()));
  await assertFails(
    setDoc(
      doc(deviceB, 'users', uid, 'jp_days', '20411'),
      day({ plan: '{"entries":["other"]}', deviceId: 'device-b', builtAt: 1763500009999 }),
    ),
  );
  await assertFails(
    updateDoc(doc(deviceB, 'users', uid, 'jp_days', '20411'), { plan: '{"entries":["other"]}' }),
  );
});

test('jp_days: position moves forward and completed turns on', async () => {
  const uid = newUid('alice');
  await seedProfile(uid);
  await seed(`users/${uid}/jp_days/20411`, day({ position: 2 }));
  const ref = doc(owner(uid), 'users', uid, 'jp_days', '20411');
  await assertSucceeds(updateDoc(ref, { position: 3 }));
  await assertSucceeds(updateDoc(ref, { position: 5, completed: true }));
});

test('jp_days: a re-push at the same position succeeds', async () => {
  const uid = newUid('alice');
  await seedProfile(uid);
  await seed(`users/${uid}/jp_days/20411`, day({ position: 3 }));
  const ref = doc(owner(uid), 'users', uid, 'jp_days', '20411');
  // An idempotent push resends the position the server already holds.
  await assertSucceeds(updateDoc(ref, { position: 3 }));
  await assertSucceeds(updateDoc(ref, { position: 3, completed: false }));
});

test('jp_days: completed turns on with the position unchanged', async () => {
  const uid = newUid('alice');
  await seedProfile(uid);
  await seed(`users/${uid}/jp_days/20411`, day({ position: 7 }));
  const ref = doc(owner(uid), 'users', uid, 'jp_days', '20411');
  await assertSucceeds(updateDoc(ref, { completed: true }));
  const snap = await getDoc(ref);
  if (snap.get('position') !== 7 || snap.get('completed') !== true) {
    throw new Error(`expected position 7 and completed true, got ${JSON.stringify(snap.data())}`);
  }
});

test('jp_days: position never moves back', async () => {
  const uid = newUid('alice');
  await seedProfile(uid);
  await seed(`users/${uid}/jp_days/20411`, day({ position: 4 }));
  const ref = doc(owner(uid), 'users', uid, 'jp_days', '20411');
  await assertFails(updateDoc(ref, { position: 3 }));
  await assertFails(updateDoc(ref, { position: 'five' }));
});

test('jp_days: a completed day cannot be reopened', async () => {
  const uid = newUid('alice');
  await seedProfile(uid);
  await seed(`users/${uid}/jp_days/20411`, day({ position: 6, completed: true }));
  await assertFails(
    updateDoc(doc(owner(uid), 'users', uid, 'jp_days', '20411'), { completed: false }),
  );
});

test('jp_days: no other field changes after create, and no delete', async () => {
  const uid = newUid('alice');
  await seedProfile(uid);
  await seed(`users/${uid}/jp_days/20411`, day());
  const ref = doc(owner(uid), 'users', uid, 'jp_days', '20411');
  await assertFails(updateDoc(ref, { deviceId: 'device-b' }));
  await assertFails(updateDoc(ref, { position: 1, builtAt: 1 }));
  await assertFails(deleteDoc(ref));
});

test('jp_days: a create needs an int position and a bool completed', async () => {
  const uid = newUid('alice');
  await seedProfile(uid);
  const db = owner(uid);
  await assertFails(setDoc(doc(db, 'users', uid, 'jp_days', '1'), day({ position: '0' })));
  await assertFails(setDoc(doc(db, 'users', uid, 'jp_days', '2'), day({ completed: 'no' })));
});

test('jp_days: another user, an anonymous user and a signed-out client are refused', async () => {
  const uid = newUid('alice');
  const other = newUid('bob');
  await seedProfile(uid);
  await seedProfile(other);
  await seed(`users/${uid}/jp_days/20411`, day());
  for (const db of [owner(other), anonymous(uid), signedOut()]) {
    await assertFails(getDoc(doc(db, 'users', uid, 'jp_days', '20411')));
    await assertFails(updateDoc(doc(db, 'users', uid, 'jp_days', '20411'), { position: 1 }));
    await assertFails(setDoc(doc(db, 'users', uid, 'jp_days', '20412'), day({ day: 20412 })));
  }
});

// ------------------------------------------------------------------ devices

test('devices: the owner can read and write a device record', async () => {
  const uid = newUid('alice');
  await seedProfile(uid);
  const db = owner(uid);
  const ref = doc(db, 'users', uid, 'devices', 'device-a');
  await assertSucceeds(setDoc(ref, { name: 'Pixel', lastSyncAt: 1 }));
  await assertSucceeds(updateDoc(ref, { lastSyncAt: 2 }));
  await assertSucceeds(getDoc(ref));
  await assertSucceeds(getDocs(collection(db, 'users', uid, 'devices')));
  await assertSucceeds(deleteDoc(ref));
});

test('devices: another user, an anonymous user and a signed-out client are refused', async () => {
  const uid = newUid('alice');
  const other = newUid('bob');
  await seedProfile(uid);
  await seedProfile(other);
  await seed(`users/${uid}/devices/device-a`, { name: 'Pixel', lastSyncAt: 1 });
  for (const db of [owner(other), anonymous(uid), signedOut()]) {
    await assertFails(getDoc(doc(db, 'users', uid, 'devices', 'device-a')));
    await assertFails(getDocs(collection(db, 'users', uid, 'devices')));
    await assertFails(setDoc(doc(db, 'users', uid, 'devices', 'device-b'), { lastSyncAt: 1 }));
  }
});

// ------------------------------------------- late writes after account delete

test('two devices: after the profile is deleted, neither signed-in device can write', async () => {
  const uid = newUid('alice');
  await seedProfile(uid);
  const phone = owner(uid);
  const browser = owner(uid);

  // Both devices sync while the account exists.
  await assertSucceeds(setDoc(doc(phone, 'users', uid, 'jp_events', 'p1'), event('p1')));
  await assertSucceeds(
    setDoc(doc(browser, 'users', uid, 'jp_events', 'b1'), event('b1', { deviceId: 'device-b' })),
  );
  await assertSucceeds(setDoc(doc(phone, 'users', uid, 'jp_days', '20411'), day()));
  await assertSucceeds(setDoc(doc(browser, 'users', uid, 'devices', 'device-b'), { lastSyncAt: 1 }));

  // The phone deletes the account; the cleanup removes the profile.
  await deleteProfile(uid);

  // The browser is still signed in and tries a late sync. Every write fails.
  for (const db of [browser, phone]) {
    await assertFails(setDoc(doc(db, 'users', uid, 'jp_events', 'late'), event('late')));
    await assertFails(setDoc(doc(db, 'users', uid, 'jp_days', '20412'), day({ day: 20412 })));
    await assertFails(setDoc(doc(db, 'users', uid, 'devices', 'device-b'), { lastSyncAt: 2 }));
  }
});

test('after account delete, recreating users/{uid} does not reopen the study data', async () => {
  const uid = newUid('alice');
  await seedProfile(uid);
  const browser = owner(uid);
  await assertSucceeds(setDoc(doc(browser, 'users', uid, 'jp_events', 'b1'), event('b1')));

  await deleteProfile(uid);

  // The unchanged users rule lets a device with an unexpired token recreate
  // the profile. The deleted_accounts marker still blocks every jp request.
  await assertSucceeds(setDoc(doc(browser, 'users', uid), { uid, display_name: 'Learner' }));
  await assertFails(setDoc(doc(browser, 'users', uid, 'jp_events', 'late'), event('late')));
  await assertFails(setDoc(doc(browser, 'users', uid, 'jp_days', '20412'), day({ day: 20412 })));
  await assertFails(setDoc(doc(browser, 'users', uid, 'devices', 'device-b'), { lastSyncAt: 2 }));
  await assertFails(getDocs(collection(browser, 'users', uid, 'jp_events')));
});

test('after the profile is deleted, a surviving day plan cannot move forward', async () => {
  const uid = newUid('alice');
  await seedProfile(uid);
  await seed(`users/${uid}/jp_days/20411`, day());
  await seed(`users/${uid}/devices/device-a`, { lastSyncAt: 1 });
  await env.withSecurityRulesDisabled(async (ctx) => {
    await deleteDoc(doc(ctx.firestore(), 'users', uid));
  });
  const db = owner(uid);
  await assertFails(updateDoc(doc(db, 'users', uid, 'jp_days', '20411'), { position: 1 }));
  await assertFails(updateDoc(doc(db, 'users', uid, 'devices', 'device-a'), { lastSyncAt: 2 }));
});

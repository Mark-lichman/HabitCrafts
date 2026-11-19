# HabitCrafts on the web, with one account and a synced Japanese record

**Evidence consumed** (one row per linked artifact):
- `lib/components/pages/quiet_room_mastery/jp_store.dart`, `jp_store_sqlite.dart` (`openJpStore`, the `CREATE TABLE` block), `attempt.dart` at `ee79af6` (branch `dev/2026-11-06-jp-tutor-loop`) · read
- `firebase/firestore.rules`, `firebase/firebase.json`, `firebase/functions/index.js` (`onUserDeleted`), `firebase/custom_cloud_functions/index.js` at the working tree of `feat/quiet-room-japanese-lessons` · read
- PR #183 (`fix/account-deletion-and-read-rules`, commit `1028e8e` message) and its merge at `b77ada4` · read
- `.github/workflows/ci.yml`, `pubspec.yaml` at `ee79af6` · read
- `docs/plans/2026-11-02-jp-mastery-queue.md` (guardrails, A4) · read
- `docs/learnings/rules-use-signedin-helper-never-bare-request-auth.md` · read
- PR #178, PR #181 (state only, `gh pr list`, 2026-11-19) · read
- `https://habitcraftapp.com/homePage` response headers and NS records (2026-11-19) · read
- war-memory batched prefetch · unread: not run this interview (fail-open)

**Trials run**:
- TRIAL-1 · pair beat · sync shape · candidates: A event log (one Firestore document per event) vs B whole-record copy (one `StudyLog` document) · scored on merge without loss, phone offline, size over a year, change to `JpStore`, build effort · chosen: A (user) Q3

## Context — the gap / problem

Mark studies Japanese in the HabitCrafts phone app. The record lives only on the phone: a SQLite database behind the `JpStore` interface plus a few `SharedPreferences` keys (verified: `jp_store_sqlite.dart`, `jp_study_kit.dart` at `ee79af6`). Nothing reaches Firestore, so a web version cannot see it (verified: no `collection(` call in `quiet_room_mastery/` at `ee79af6`).

The record is an append-only event log (attempts and seeds) plus derived tables (`srs`, `mastery`) that a pure replay rebuilds (verified: `jp_store.dart` "Replays the log from nothing", at `ee79af6`). Rows take SQLite `AUTOINCREMENT` ids, which collide across two devices (verified: `jp_store_sqlite.dart` `CREATE TABLE attempts` at `ee79af6`).

The Flutter repo already carries a `web/` folder and the Firebase web packages (verified: `pubspec.yaml` `firebase_auth_web`, `cloud_firestore_web` at `ee79af6`). Sign-in already exists with Google, Apple, email and anonymous providers (verified: `lib/auth/firebase_auth/` at `ee79af6`). An earlier FlutterFlow web publish still serves `habitcraftapp.com/homePage` from Google Cloud Storage, last modified 2025-06-05, with DNS at Porkbun (verified: response headers and NS lookup, 2026-11-19).

The Japanese stack (PRs #66 to #178) and the delete fix (PR #183) merged to `main` on 2026-11-19 (verified: `main` at `b77ada4`). `deleteAllUserData` now removes the profile last with `recursiveDelete`, which also removes its subcollections (verified: PR #183, commit `1028e8e` message). No test covers the Firestore rules (verified: rules lesson in `docs/learnings/`).

Mark wants to study on the phone or the web and see the same record on both, under one HabitCrafts account, and wants the whole app on the web (user).

## Pivotal constraints

- Prerequisites, done 2026-11-19: PR #178 and the delete fix (PR #183) are on `main` at `b77ada4` (PIN-2, PIN-11). Phase 1 cuts from `main`.
- One repo: `Mark-lichman/habitcrafts` (the Flutter app, including `firebase/`).
- Hand-written code follows `docs/standards.md` S1 to S11. CI blocks only on `error` analyzer findings (verified: `ci.yml` `flutter analyze --no-fatal-infos --no-fatal-warnings`).
- New Firestore rules call `signedIn()`, never a bare `request.auth != null` (verified: rules lesson).
- The Flutter binary on the dev machine is `/c/src/flutter/bin/flutter` (verified: the 11/02 plan's Done-when commands).
- The emulator suite needs Java and `firebase-tools` [assumed: CI's `ubuntu-latest` ships Java, and the job installs `firebase-tools` with npm. If wrong: the job adds `actions/setup-java`].

## Resolved design tree

| # | Decision | Resolution | Source | Landing class |
|---|----------|------------|--------|---------------|
| D1 | Which web app syncs with the phone | a Flutter web build of the real app, not the JS prototype | (user) Q1 | PIN-1→context |
| D2 | Base branch | `main` after PR #178 merges | (user) Q2 | PIN-2→context ‡ |
| D3 | Sync shape | event log: `users/{uid}/jp_events/{eventId}`, one document per attempt, seed, note change or Discuss change, never updated | (user) Q3, after TRIAL-1 | PIN-3→guardrail ‡ |
| D4 | Rules proof | a Firestore emulator suite in CI | (user) Q4 | PIN-4→end-state |
| D5 | Web scope | the whole app, every route | (user) Q5 | PIN-5→end-state |
| D6 | Phone-only features on web | build web versions: push, reminders, speech, file save | (user) Q6 | PIN-6→slice (T9, T10, T11) |
| D7 | Hosting | Firebase Hosting serving `habitcraftapp.com`, `/homePage` kept as a route | (user) Q7 | PIN-7→backstop |
| D8 | Account features on web | same account as the phone, stay signed in, sign-out wipes this browser's study data, password reset, delete removes the synced record, a signed-in devices list | (user) Q8 | PIN-8→end-state |
| D9 | Floor | the latitude and guardrail split in Commander's Intent | (user) Q10 | PIN-9→guardrail ‡ |
| D10 | Same-day plan | the day's plan syncs; the first plan written for a day wins, and position only moves forward | (user) Q11 | PIN-10→slice (T3) |
| D11 | Delete fix | merge `fix/account-deletion-and-read-rules` first, then extend it | (user) Q12 | PIN-11→context |
| D12 | Notes and Discuss marks | last write wins by event time | (user) Q10 | PIN-12→guardrail |

## Assumptions ledger

| ID | Assumption | Basis | Blast radius if wrong | Check |
|----|-----------|-------|----------------------|-------|
| A1 | Mark is signed in (not anonymous) on the phone | [assumed: the profile page has sign-out and delete, at `ee79af6`. If wrong: the first sync asks him to sign in] | an extra sign-in step on the phone | backstop row 1 |
| A2 | Web reminders can ride `sendScheduledPushNotifications` | [assumed: the function exists in `firebase/functions/index.js`. If wrong: T11 adds a scheduled function] | T11 grows | backstop row 2 |
| A3 | `speech_to_text` 7.5.0 recognizes `ja-JP` in Chrome on the web | [assumed: the package lists web support. If wrong: say-it falls back to type-it on every browser] | spoken cards are type-only on web | End state 10's test, backstop row 1 |
| A4 | Firestore's web offline cache is enough as the web study store | [assumed: implementer's choice under the latitude. If wrong: T5 adds an IndexedDB store] | T5 grows | End state 7's test |
| A5 | CI's `ubuntu-latest` has Java for the emulator | [assumed: the image lists Temurin. If wrong: add `actions/setup-java`] | the rules job fails to start | End state 5's check in CI |
| A6 | Retired 2026-11-19: the delete fix conflicted on both rules files, and `main` already held a stricter version, so the merge kept `main`'s rules (verified: PR #183) | n/a | n/a | n/a |
| A7 | Mark controls Porkbun DNS for `habitcraftapp.com`, the Apple Services ID and the FCM web key | [assumed: he owns the domain and the Firebase project] | the deploy runbook stalls | backstop rows 3 and 4 |
| A8 | Volume is about 50 answers a day | [assumed: the 15 to 20 minute daily budget in the 11/02 plan. If wrong: reads grow, the cursor pull still bounds them] | Firestore cost | none needed |

## Non-goals / deferred

- The JS prototype and the student pilot (Plans 1 and 2 in their repos). Students keep link tokens and Cloudflare KV.
- Moving the phone off SQLite.
- Sync for non-Japanese data: groups, habits and chats already live in Firestore.
- An app store web listing or an installable PWA prompt.

## New domain terms · Recommended ADRs

- **Event id**: a global id on every logged event, unique across devices.
- **Sync cursor**: the latest server time a device has pulled up to.
- **Day plan**: the stored `DayRecord` for one local day, now shared across devices.
- Recommended ADR: "The Japanese record syncs as an append-only event log" (hard to reverse, a genuine trade-off against a whole-record copy).

## Commander's Intent

Confirmed by the operator at echo-back on 2026-11-19 (user).

- **Purpose:** study Japanese on the phone or the web, and both always show the same record, under one HabitCrafts account (user).
- **Method:** build the real Flutter app for the web; give every logged event a global id; copy the event log to Firestore and replay the merged log on each device; share the day plan; make account features work on the web; give push, reminders, speech and file save web versions; host on Firebase at `habitcraftapp.com` (user).
- **Mechanism latitude:** the web study store (Firestore's offline cache, `sqflite` on web, IndexedDB or another), the event id format (UUID or ULID), when sync runs (on open, after each answer, a live listener), and the web libraries for speech, push and download are implementer's choice; substituting any of these mechanisms while the End states and binding guardrails hold is not a plan deviation and warrants no issue (user).
- **Binding guardrails:** the event log is append-only, and `jp_events` documents are never updated or deleted except by account delete (PIN-3) · replay stays pure, and the schedule and mastery are a function of the merged log alone · notes and Discuss marks resolve by last write wins on event time (PIN-12) · `JpStore` stays the one seam for study data · new rules call `signedIn()`, and anonymous users never sync · the rules for existing collections do not change · the phone keeps working fully offline (PIN-9).
- **End state:**
  1. An answer recorded on one device appears on the other after its next sync · check: `/c/src/flutter/bin/flutter test test/jp_sync_test.dart` (prints `All tests passed!`).
  2. Answers made offline on both devices sync on reconnect with no loss and no duplicate · check: `/c/src/flutter/bin/flutter test test/jp_sync_test.dart` (prints `All tests passed!`).
  3. After a sync, both devices replay to identical `srs` and `mastery` for every item · check: `/c/src/flutter/bin/flutter test test/jp_sync_test.dart` (prints `All tests passed!`).
  4. The phone's existing history gets event ids once, keeps them on every later open, and uploads once · check: `/c/src/flutter/bin/flutter test test/jp_event_test.dart test/jp_sync_test.dart` (prints `All tests passed!`).
  5. The rules let only the owner read `jp_events`, `jp_days` and `devices`, refuse update and delete on `jp_events`, and refuse anonymous users (PIN-4) · check: `npm --prefix firebase/rules-tests test` (prints `# fail 0`).
  6. The whole app builds for the web in CI (PIN-5) · check: `/c/src/flutter/bin/flutter build web --release` (prints `Built build/web`).
  7. On the web, Google and email sign-in reach the same uid as the phone, the session survives a reload, and sign-out clears this browser's study data (PIN-8) · check: `/c/src/flutter/bin/flutter test test/web_auth_test.dart test/jp_sync_host_test.dart` (prints `All tests passed!`).
  8. A password reset email can be requested from the web, and deleting the account removes `jp_events`, `jp_days` and `devices` · check: `/c/src/flutter/bin/flutter test test/web_auth_test.dart` (prints `All tests passed!`) and `npm --prefix firebase/rules-tests test` (prints `# fail 0`).
  9. A devices page lists each device that synced, with its last sync time · check: `/c/src/flutter/bin/flutter test test/devices_page_test.dart` (prints `All tests passed!`).
  10. On the web, say-it cards use browser speech where available and fall back to type-it otherwise · check: `/c/src/flutter/bin/flutter test test/speech_service_web_test.dart` (prints `All tests passed!`).
  11. On the web, saving a file downloads it through the browser · check: `/c/src/flutter/bin/flutter test test/save_file_test.dart` (prints `All tests passed!`).
  12. Web push and web reminders arrive in a real browser · backstop: row 2.
  13. `habitcraftapp.com/homePage` serves the new build · backstop: row 3.
  14. Both devices on the same local day show the same day plan; the first plan written wins and position never moves back (PIN-10) · check: `/c/src/flutter/bin/flutter test test/jp_sync_test.dart` (prints `All tests passed!`).
  15. The whole Flutter suite stays green · gate: `flutter test` (the CI `analyze-and-test` job).

## Build order (for /war)

Phase 1 (record ready to sync) → Phase 2 (sync engine and delete) → Phase 3 (accounts on web) → Phase 4 (web stand-ins) → Phase 5 (ship).

## Phase 1 — Record ready to sync

### Task 1: Global event ids and their migration
- Files: `lib/components/pages/quiet_room_mastery/jp_event.dart`, `lib/components/pages/quiet_room_mastery/jp_store.dart`, `lib/components/pages/quiet_room_mastery/jp_store_sqlite.dart`, `lib/components/pages/quiet_room_mastery/jp_store_memory.dart`, `test/jp_event_test.dart`
- Plan slice: add `JpEvent` (event id, device id, event time, kind attempt | seed | note | discuss, body) and its Firestore map form. Give attempts and seeds an event id and device id. Record note and Discuss changes as timestamped events so last write wins (PIN-12). A one-time migration assigns ids to existing rows, stable on every later open. Add `JpStore` methods to list events not yet pushed, mark them pushed, and append remote events without duplicates. Day records carry the device and time that built them. Replay stays pure.
- Done when: `/c/src/flutter/bin/flutter test test/jp_event_test.dart` (prints `All tests passed!`)
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

### Task 2: Firestore rules and the emulator suite
- Files: `firebase/firestore.rules`, `firebase/firebase.json`, `firebase/rules-tests/package.json`, `firebase/rules-tests/jp_rules.test.js`, `.github/workflows/ci.yml`
- Plan slice: add owner-only rules under `users/{uid}` for `jp_events/{eventId}` (create and read only), `jp_days/{day}` (create once, then only a forward position or completed change) and `devices/{deviceId}` (read and write), each through `signedIn()` (PIN-3). Leave every existing rule as it is. Add the emulator block to `firebase.json`, a `node --test` suite run under `firebase emulators:exec`, and a CI job that runs it.
- Done when: `npm --prefix firebase/rules-tests test` (prints `# fail 0`)
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

## Phase 2 — Sync engine and delete

### Task 3: JpSync: push, pull, replay, day plan
- Files: `lib/components/pages/quiet_room_mastery/jp_sync.dart`, `lib/components/pages/quiet_room_mastery/jp_remote.dart`, `lib/components/pages/quiet_room_mastery/jp_remote_firestore.dart`, `test/jp_sync_test.dart`
- Plan slice: `JpRemote` is the remote interface, with an in-memory fake for tests and a Firestore version. `JpSync.run()` pushes unpushed events, pulls events after the sync cursor, appends them, replays, and writes the device's last sync time to `devices/{deviceId}`. The day plan syncs: the first plan created for a day wins and position only moves forward (PIN-10). Tests drive two stores against one fake remote, online and offline.
- Done when: `/c/src/flutter/bin/flutter test test/jp_sync_test.dart` (prints `All tests passed!`)
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

### Task 4: Account delete removes the synced record
- Files: `firebase/custom_cloud_functions/delete_all_user_data.js`, `firebase/rules-tests/delete_cascade.test.js`
- Plan slice: prove on the emulator that an account delete removes `users/{uid}/jp_events`, `jp_days` and `devices` (the one allowed delete of `jp_events`, PIN-3). The merged `recursiveDelete` of the profile should already cover them, so change the function only if the test fails.
- Done when: `npm --prefix firebase/rules-tests test` (prints `# fail 0`)
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

### Task 5: The web study store
- Files: `lib/components/pages/quiet_room_mastery/jp_store_web.dart`, `lib/components/pages/quiet_room_mastery/jp_store_sqlite.dart`, `pubspec.yaml`, `test/open_jp_store_test.dart`
- Plan slice: on the web, `openJpStore` returns a store that keeps the record across reloads (mechanism is latitude, A4). It passes the same store contract tests as the SQLite and memory stores.
- Done when: `/c/src/flutter/bin/flutter test test/open_jp_store_test.dart` (prints `All tests passed!`)
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

## Phase 3 — Accounts on web

### Task 6: Sync host and sign-out wipe
- Files: `lib/components/pages/quiet_room_mastery/jp_sync_host.dart`, `lib/main.dart`, `lib/components/pages/profile_page/profile_page_widget.dart`, `test/jp_sync_host_test.dart`
- Plan slice: start sync after a non-anonymous sign-in and on app resume; never sync an anonymous user. Sign-out clears the local study store on the web. Add a "Signed-in devices" entry to the profile page that opens the `DevicesPage` route.
- Done when: `/c/src/flutter/bin/flutter test test/jp_sync_host_test.dart` (prints `All tests passed!`)
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

### Task 7: Devices page
- Files: `lib/components/pages/devices_page/devices_page_widget.dart`, `lib/flutter_flow/nav/nav.dart`, `test/devices_page_test.dart`
- Plan slice: a `DevicesPage` route that lists `users/{uid}/devices` with a plain device name and last sync time, newest first.
- Done when: `/c/src/flutter/bin/flutter test test/devices_page_test.dart` (prints `All tests passed!`)
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

### Task 8: Web sign-in, stay signed in, password reset
- Files: `lib/auth/firebase_auth/firebase_auth_manager.dart`, `lib/auth/firebase_auth/google_auth.dart`, `web/index.html`, `test/web_auth_test.dart`
- Plan slice: Google and email sign-in work on the web and reach the phone's uid. The web session persists across reloads. Password reset sends from the web. Apple sign-in on web is wired, and its Services ID setup goes in the runbook (Task 12).
- Done when: `/c/src/flutter/bin/flutter test test/web_auth_test.dart` (prints `All tests passed!`)
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

## Phase 4 — Web stand-ins

### Task 9: Browser speech with a type-it fallback
- Files: `lib/components/pages/quiet_room_practice/speech_service.dart`, `test/speech_service_web_test.dart`
- Plan slice: on the web, speech uses the browser's recognizer for `ja-JP` where available (A3). Where it is not, say-it cards fall back to type-it and log no spoken attempt (PIN-6).
- Done when: `/c/src/flutter/bin/flutter test test/speech_service_web_test.dart` (prints `All tests passed!`)
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

### Task 10: File save as a browser download
- Files: `lib/components/pages/quiet_room_mastery/save_file.dart`, `lib/components/pages/quiet_room_mastery/mastery_debug_widget.dart`, `test/save_file_test.dart`
- Plan slice: one `saveFile` helper: the file picker on the phone and a browser download on the web. The debug page's export uses it (PIN-6).
- Done when: `/c/src/flutter/bin/flutter test test/save_file_test.dart` (prints `All tests passed!`)
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

### Task 11: Web push and web reminders
- Files: `lib/backend/push_notifications/push_notifications_util.dart`, `web/firebase-messaging-sw.js`, `firebase/functions/index.js`, `test/push_web_test.dart`
- Plan slice: register the web FCM token with the existing `addFcmToken` function, add the messaging service worker, and send reminders to web tokens through the scheduled push function (A2, PIN-6). The FCM web key comes from config, never a secret in the repo.
- Done when: `/c/src/flutter/bin/flutter test test/push_web_test.dart` (prints `All tests passed!`)
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

## Phase 5 — Ship

### Task 12: Web build in CI, Firebase Hosting, deploy, runbook
- Files: `firebase/firebase.json`, `.github/workflows/ci.yml`, `.github/workflows/deploy-web.yml`, `docs/web-app-runbook.md`
- Plan slice: a CI job runs `flutter build web --release`. Hosting serves `build/web` with a rewrite to `index.html`, so `/homePage` and every route resolve. A deploy workflow publishes on merge to `main`. The runbook covers the Porkbun DNS change for `habitcraftapp.com` (PIN-7), Firebase authorized domains, the Apple Services ID, the FCM web key, and `firebase deploy --only firestore:rules,functions`.
- Done when: `/c/src/flutter/bin/flutter build web --release` (prints `Built build/web`)
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

## Deferred validations (backstops)

- Real phone and real browser, same account: answer on the phone, see it on the web after refresh; go offline on both, answer on both, reconnect, and both show the same counts · why deferred: needs two real devices and the live project · runner: Mark, after the first deploy.
- Web push and a web reminder arrive in Chrome · why deferred: needs a real browser, the FCM web key and the live functions · runner: Mark, after the first deploy.
- `curl -sI https://habitcraftapp.com/homePage` shows Firebase Hosting headers, not `x-goog-generation` (PIN-7) · why deferred: needs the Porkbun DNS change · runner: Mark, per the runbook.
- Google and Apple sign-in succeed on `habitcraftapp.com` · why deferred: needs authorized domains and the Apple Services ID · runner: Mark, per the runbook.
- The deployed Firestore rules equal the committed `firebase/firestore.rules` · why deferred: deploy is an operator action · runner: Mark, per the runbook.

## Notes / conscious deviations

- This plan replaces two items of `docs/plans/2026-11-02-jp-mastery-queue.md`: the guardrail "no login screen" (sync needs a signed-in account) and A4 "web keeps nothing between loads" (the web store now persists and syncs) (user, echo-back 1).
- `firebase/firebase.json` is written in Phase 1 (Task 2) and Phase 5 (Task 12), and `jp_store_sqlite.dart` in Phase 1 (Task 1) and Phase 2 (Task 5). Different phases, so no same-phase collision.

## Open decisions

None.

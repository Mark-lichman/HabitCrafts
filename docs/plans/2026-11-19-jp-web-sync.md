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
- The emulator suite needs Java 21 for `firebase-tools` 14 and later, and CI's default JDK is 17 (verified: red-team dep-resolves probe, 2026-11-19). The rules job sets up Java 21 and a pinned Node with `actions/setup-java` and `actions/setup-node`.
- On Node 23 and later, `node --test` prints `# fail 0` only with `--test-reporter=tap` (verified: red-team executable-proof probe, Node 24.13.0). The rules suite pins that reporter.
- A hand edit to a FlutterFlow-generated file needs a row in `docs/architecture/adopted-files.md` (verified: `docs/standards.md` S3 and `docs/learnings/generated-auth-file-hand-edit-needs-an-adopted-files-row.md`). One task per phase owns that file: Task 8 in Phase 3, Task 14 in Phase 4.
- `flutter build web --release` already succeeds at `b77ada4`, and Flutter prints a backslash path on Windows (verified: red-team command-diff probe). A build alone proves nothing, so web proof runs in Chrome (PIN-15).

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
| D10 | Same-day plan | the day's plan syncs; the first plan to reach the server wins (`jp_days/{day}` is create-once), and position only moves forward | (user) Q11, tiebreak (user) red-team 2026-11-19 | PIN-10→slice (T3) |
| D11 | Delete fix | merge `fix/account-deletion-and-read-rules` first, then extend it | (user) Q12 | PIN-11→context |
| D12 | Notes and Discuss marks | last write wins by event time | (user) Q10 | PIN-12→guardrail |
| D13 | Late writes after account delete | the rules for `jp_events`, `jp_days` and `devices` also require `users/{uid}` to exist, so a device still signed in cannot write after the cleanup deletes the profile | (user) red-team 2026-11-19 | PIN-13→guardrail |
| D14 | Delete proof | the real `deleteAllUserData` auth trigger runs on the Auth, Functions and Firestore emulators | (user) red-team 2026-11-19 | PIN-14→slice (T4) |
| D15 | Web proof | web End states run with `flutter test --platform chrome`, and a smoke test opens every route in Chrome | (user) red-team 2026-11-19 | PIN-15→end-state |
| D16 | Data outside the store | the say-it score log (`jp.speak.scores`) and the last grammar lesson (`jp.grammar.lastLesson`) both sync as events | (user) red-team 2026-11-19 | PIN-16→slice (T13) |

## Assumptions ledger

| ID | Assumption | Basis | Blast radius if wrong | Check |
|----|-----------|-------|----------------------|-------|
| A1 | Mark is signed in (not anonymous) on the phone | [assumed: the profile page has sign-out and delete, at `ee79af6`. If wrong: the first sync asks him to sign in] | an extra sign-in step on the phone | backstop row 1 |
| A2 | Web reminders can ride `sendScheduledPushNotifications` | [assumed: the function exists in `firebase/functions/index.js`. If wrong: T11 adds a scheduled function] | T11 grows | backstop row 2 |
| A3 | `speech_to_text` recognizes `ja_JP` in Chrome | (verified: `speech_service.dart` already calls it on web with `localeId: 'ja_JP'`); recognition quality per browser [assumed. If wrong: type-it fallback] | spoken cards are type-only on that browser | End state 10's test, backstop row 1 |
| A4 | Firestore's web offline cache is enough as the web study store | [assumed: implementer's choice under the latitude. If wrong: T5 adds an IndexedDB store] | T5 grows | End state 7's test |
| A5 | Retired 2026-11-19: CI's default JDK is 17 and current `firebase-tools` needs 21, so the rules job sets up Java 21 (verified: red-team) | n/a | n/a | n/a |
| A6 | Retired 2026-11-19: the delete fix conflicted on both rules files, and `main` already held a stricter version, so the merge kept `main`'s rules (verified: PR #183) | n/a | n/a | n/a |
| A7 | Mark controls Porkbun DNS for `habitcraftapp.com`, the Apple Services ID and the FCM web key | [assumed: he owns the domain and the Firebase project] | the deploy runbook stalls | backstop rows 3 and 4 |
| A9 | A Chrome widget test can open every route with Firebase faked | [assumed: fake Firebase packages run under `--platform chrome`. If wrong: Task 14 runs the smoke test against the emulators] | Task 14 grows | End state 6's check |
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
- **Binding guardrails:** the event log is append-only, and `jp_events` documents are never updated or deleted except by account delete (PIN-3) · replay stays pure, and the schedule and mastery are a function of the merged log alone · notes and Discuss marks resolve by last write wins on event time (PIN-12) · `JpStore` stays the one seam for study data · new rules call `signedIn()`, and anonymous users never sync · the new rules require `users/{uid}` to exist, so no write lands after account delete (PIN-13) · the rules for existing collections do not change · the phone keeps working fully offline (PIN-9).
- **End state:**
  1. An answer recorded on one device appears on the other after its next sync · check: `/c/src/flutter/bin/flutter test test/jp_sync_test.dart` (prints `All tests passed!`).
  2. Answers made offline on both devices sync on reconnect with no loss and no duplicate · check: `/c/src/flutter/bin/flutter test test/jp_sync_test.dart` (prints `All tests passed!`).
  3. After a sync, both devices replay to identical `srs` and `mastery` for every item · check: `/c/src/flutter/bin/flutter test test/jp_sync_test.dart` (prints `All tests passed!`).
  4. The phone's existing history gets event ids once, keeps them on every later open and through export and import, and uploads once · check: `/c/src/flutter/bin/flutter test test/jp_event_test.dart test/jp_sync_test.dart` (prints `All tests passed!`).
  5. The rules let only the owner read `jp_events`, `jp_days` and `devices`, refuse update and delete on `jp_events`, and refuse anonymous users (PIN-4) · check: `npm --prefix firebase/rules-tests test` (prints `# fail 0`, because the suite pins `--test-reporter=tap`).
  6. The whole app opens every route in Chrome with no uncaught error (PIN-5, PIN-15) · check: `/c/src/flutter/bin/flutter test --platform chrome test/web_routes_smoke_test.dart` (prints `All tests passed!`).
  7. On the web, Google and email sign-in reach the same uid as the phone, the session survives a reload, and sign-out clears this browser's study data (PIN-8) · check: `/c/src/flutter/bin/flutter test --platform chrome test/web_auth_test.dart test/jp_sync_host_test.dart` (prints `All tests passed!`).
  8. A password reset email can be requested from the web, and deleting the Auth user fires `deleteAllUserData`, which empties `jp_events`, `jp_days` and `devices` (PIN-14) · check: `/c/src/flutter/bin/flutter test --platform chrome test/web_auth_test.dart` (prints `All tests passed!`) and `npm --prefix firebase/rules-tests test` (prints `# fail 0`).
  9. A devices page lists each device that synced, with its last sync time · check: `/c/src/flutter/bin/flutter test test/devices_page_test.dart` (prints `All tests passed!`).
  10. On the web, say-it cards use browser speech where it works and fall back to type-it where it does not · check: `/c/src/flutter/bin/flutter test --platform chrome test/speech_service_web_test.dart` (prints `All tests passed!`).
  11. On the web, exporting the study record downloads it through the browser · check: `/c/src/flutter/bin/flutter test --platform chrome test/save_file_test.dart` (prints `All tests passed!`).
  12. Web push and web reminders arrive in a real browser · backstop: row 2.
  13. `habitcraftapp.com/homePage` serves the new build · backstop: row 3.
  14. Both devices on the same local day show the same day plan. The first plan to reach the server wins, and position never moves back (PIN-10) · check: `/c/src/flutter/bin/flutter test test/jp_sync_test.dart` (prints `All tests passed!`).
  15. The whole Flutter suite stays green · gate: `flutter test` (the CI `analyze-and-test` job).
  16. A note, Discuss mark, say-it score or last-opened lesson changed on one device shows on the other after sync, and the later event time wins (PIN-12, PIN-16) · check: `/c/src/flutter/bin/flutter test test/jp_sync_test.dart test/speak_lesson_events_test.dart` (prints `All tests passed!`).
  17. After the profile is deleted, a device still signed in cannot write `jp_events`, `jp_days` or `devices`, even after it recreates `users/{uid}` (PIN-13) · check: `npm --prefix firebase/rules-tests test` (prints `# fail 0`).

## Build order (for /war)

Phase 1 (record ready to sync) → Phase 2 (sync engine, delete, extra data) → Phase 3 (accounts on web) → Phase 4 (web stand-ins and guards) → Phase 5 (ship).

## Phase 1 — Record ready to sync

### Task 1: Global event ids and their migration
- Files: `lib/components/pages/quiet_room_mastery/jp_event.dart`, `lib/components/pages/quiet_room_mastery/jp_store.dart`, `lib/components/pages/quiet_room_mastery/jp_store_sqlite.dart`, `lib/components/pages/quiet_room_mastery/jp_store_memory.dart`, `lib/components/pages/quiet_room_mastery/attempt.dart`, `lib/components/pages/quiet_room_mastery/study_export.dart`, `test/jp_event_test.dart`
- Plan slice: add `JpEvent` (event id, device id, event time, kind attempt | seed | note | discuss | speak_score | last_lesson, body) and its Firestore map form. Give attempts (`attempt.dart`) and seeds an event id and device id. Record note, Discuss, say-it score and last-lesson changes as timestamped events, so last write wins (PIN-12, PIN-16). A one-time migration assigns ids to existing rows, stable on every later open. Legacy ids (the migration and pre-v3 imports) derive from a hash of the row content (time, item, session, kind), so a restored old backup maps onto the uploaded events, and an id-less import reuses a matching held id (operator ruling, Checkpoint 2026-11-19). Keep append order in replay here; Task 3 owns the canonical order. Fix forward from the first audit round: a position move on a migrated day keeps a null build time (#191), and a local tie bump is 1 ms, not 1 microsecond, so it holds on the web (#193). Export and import carry event ids and event times, with an export version bump. Add `JpStore` methods to list unpushed events, mark them pushed, and append remote events without duplicates. Day records carry the device and time that built them. Replay stays pure.
- Done when: `/c/src/flutter/bin/flutter test test/jp_event_test.dart` (prints `All tests passed!`)
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

### Task 2: Firestore rules and the emulator suite
- Files: `firebase/firestore.rules`, `firebase/firebase.json`, `firebase/rules-tests/package.json`, `firebase/rules-tests/package-lock.json`, `firebase/rules-tests/jp_rules.test.js`, `.github/workflows/ci.yml`
- Plan slice: add owner-only rules under `users/{uid}` for `jp_events/{eventId}` (create and read only), `jp_days/{day}` (create once, then only a forward position or completed change, PIN-10) and `devices/{deviceId}` (read and write). Each calls `signedIn()` and requires `users/{uid}` to exist (PIN-3, PIN-13). Leave every existing rule as it is. Add an emulators block for auth, functions and firestore to `firebase.json`. The suite runs under `firebase emulators:exec` with `node --test --test-reporter=tap` and a pinned `firebase-tools`. A new CI job sets up Java 21 and Node, installs the packages of every functions codebase, and runs the suite. Tests include the two-device late-write case (End state 17). Fix forward from the first audit round: the rules job sets `permissions: contents: read`, checks out with `persist-credentials: false`, and installs function codebases with `--ignore-scripts` (#195); add asserts for the equal-position and completed-only `jp_days` updates (#196).
- Done when: `npm --prefix firebase/rules-tests test` (prints `# fail 0`)
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

## Phase 2 — Sync engine, delete, extra data

### Task 3: JpSync: push, pull, replay, day plan
- Files: `lib/components/pages/quiet_room_mastery/jp_sync.dart`, `lib/components/pages/quiet_room_mastery/jp_remote.dart`, `lib/components/pages/quiet_room_mastery/jp_remote_firestore.dart`, `lib/components/pages/quiet_room_mastery/jp_store.dart`, `test/jp_sync_test.dart`
- Plan slice: `JpRemote` is the remote interface, with an in-memory fake for tests and a Firestore version. `JpSync.run()` pushes unpushed events, pulls events after the sync cursor, appends them, replays, and writes the device's last sync time to `devices/{deviceId}`. The day plan syncs: the first plan to reach the server wins, the other device adopts it and keeps its own answers, and position only moves forward (PIN-10). Replay, rebuild and import apply events in one canonical order, event time then event id, in `jp_store.dart` (operator ruling, Checkpoint 2026-11-19). Tests drive two stores against one fake remote, online and offline, and cover notes, Discuss marks, say-it scores and the last lesson (End state 16).
- Done when: `/c/src/flutter/bin/flutter test test/jp_sync_test.dart` (prints `All tests passed!`)
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

### Task 4: Account delete removes the synced record
- Files: `firebase/custom_cloud_functions/delete_all_user_data.js`, `firebase/firestore.rules`, `firebase/rules-tests/delete_cascade.test.js`
- Plan slice: on the Auth, Functions and Firestore emulators, delete an Auth user and wait until the `deleteAllUserData` trigger empties `users/{uid}/jp_events`, `jp_days` and `devices` (PIN-14). The merged `recursiveDelete` of the profile should already cover them, so change the cascade only if the test fails. Close the recreate window too: the cleanup writes a `deleted_accounts/{uid}` marker (admin only, never client-readable or writable) before it deletes, and the `jp_events`, `jp_days` and `devices` rules refuse a write when that marker exists, so a still-signed-in device that recreates `users/{uid}` still cannot write study data (operator ruling, Checkpoint 2026-11-19). Leave the existing `users` rule unchanged.
- Done when: `npm --prefix firebase/rules-tests test` (prints `# fail 0`)
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

### Task 5: The web study store
- Files: `lib/components/pages/quiet_room_mastery/jp_store_web.dart`, `lib/components/pages/quiet_room_mastery/jp_store_sqlite.dart`, `pubspec.yaml`, `pubspec.lock`, `test/jp_store_test.dart`, `test/open_jp_store_test.dart`
- Plan slice: on the web, `openJpStore` returns a store that keeps the record across reloads (mechanism is latitude, A4). It passes the same store contract tests as the SQLite and memory stores. Retire the A4 test "the web store is the memory store" in `test/jp_store_test.dart` and the "memory on web (A4)" comments in `jp_store_sqlite.dart`. Edit `pubspec.yaml` and `pubspec.lock` only if a package is added.
- Done when: `/c/src/flutter/bin/flutter test test/open_jp_store_test.dart test/jp_store_test.dart` (prints `All tests passed!`)
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

### Task 13: Say-it scores and the last lesson move into the store
- Files: `lib/components/pages/quiet_room_grammar/quiet_room_speak_widget.dart`, `lib/components/pages/quiet_room_grammar/quiet_room_grammar_widget.dart`, `lib/components/pages/quiet_room_mastery/lessons_path_widget.dart`, `lib/components/pages/quiet_room_mastery/seed_confirm_widget.dart`, `test/speak_lesson_events_test.dart`
- Plan slice: `SpeakScoreLog` and the last-lesson reads and writes go through the store as `speak_score` and `last_lesson` events (PIN-16). A one-time import moves the existing `jp.speak.scores` and `jp.grammar.lastLesson` values into the store. The last lesson resolves to the latest event time.
- Done when: `/c/src/flutter/bin/flutter test test/speak_lesson_events_test.dart` (prints `All tests passed!`)
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

## Phase 3 — Accounts on web

### Task 6: Sync host and sign-out wipe
- Files: `lib/components/pages/quiet_room_mastery/jp_sync_host.dart`, `lib/main.dart`, `lib/components/pages/profile_page/profile_page_widget.dart`, `test/jp_sync_host_test.dart`
- Plan slice: start sync after a non-anonymous sign-in and on app resume. Never sync an anonymous user. Sign-out clears the local study store on the web. Add a "Signed-in devices" entry to the profile page that opens `DevicesPageWidget.routeName` (Task 7). Task 8 adds this file's adopted-files row.
- Done when: `/c/src/flutter/bin/flutter test --platform chrome test/jp_sync_host_test.dart` (prints `All tests passed!`)
- requiresTest: true
- requiresPackaging: false
- deps: [7]
- target repo: superproject

### Task 7: Devices page
- Files: `lib/components/pages/devices_page/devices_page_widget.dart`, `lib/flutter_flow/nav/nav.dart`, `test/devices_page_test.dart`
- Plan slice: a `DevicesPageWidget` with `routeName` `DevicesPage`, registered in `nav.dart`, that lists `users/{uid}/devices` with a plain device name and last sync time, newest first.
- Done when: `/c/src/flutter/bin/flutter test test/devices_page_test.dart` (prints `All tests passed!`)
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

### Task 8: Web sign-in, stay signed in, password reset
- Files: `lib/auth/firebase_auth/firebase_auth_manager.dart`, `lib/auth/firebase_auth/google_auth.dart`, `web/index.html`, `docs/architecture/adopted-files.md`, `test/web_auth_test.dart`
- Plan slice: Google and email sign-in work on the web and reach the phone's uid. The web session persists across reloads. Password reset sends from the web. Apple sign-in on web is wired, and its Services ID setup goes in the runbook (Task 12). Add adopted-files rows for `firebase_auth_manager.dart`, `google_auth.dart` and `profile_page_widget.dart` (Task 6).
- Done when: `/c/src/flutter/bin/flutter test --platform chrome test/web_auth_test.dart` (prints `All tests passed!`)
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

## Phase 4 — Web stand-ins and guards

### Task 9: Type-it fallback where browser speech fails
- Files: `lib/components/pages/quiet_room_practice/speech_service.dart`, `lib/components/pages/quiet_room_grammar/quiet_room_speak_widget.dart`, `lib/components/pages/quiet_room_mastery/probe_widgets.dart`, `test/speech_service_web_test.dart`
- Plan slice: `SpeechService` already runs `speech_to_text` on the web with `localeId: 'ja_JP'`. Detect when the browser has no recognizer or no `ja_JP`. Then show the type-it form on say-it cards and log no spoken attempt (PIN-6).
- Done when: `/c/src/flutter/bin/flutter test --platform chrome test/speech_service_web_test.dart` (prints `All tests passed!`)
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

### Task 10: Prove the export download on the web
- Files: `lib/components/pages/quiet_room_mastery/mastery_debug_widget.dart`, `test/save_file_test.dart`
- Plan slice: `PickerStudyRecordFiles.save` already starts a browser download on the web through `FilePicker.platform.saveFile` with bytes. Keep that seam, add no new helper, and test it in Chrome. Replace the stale "The web store is in memory" comment (PIN-6).
- Done when: `/c/src/flutter/bin/flutter test --platform chrome test/save_file_test.dart` (prints `All tests passed!`)
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

### Task 11: Web push and web reminders
- Files: `lib/backend/push_notifications/push_notifications_util.dart`, `web/firebase-messaging-sw.js`, `firebase/functions/index.js`, `test/push_web_test.dart`
- Plan slice: register the web FCM token with the existing `addFcmToken` function, add the messaging service worker, and send reminders to web tokens through the scheduled push function (A2, PIN-6). The FCM web key comes from config, never a secret in the repo. Task 14 adds this file's adopted-files row.
- Done when: `/c/src/flutter/bin/flutter test --platform chrome test/push_web_test.dart` (prints `All tests passed!`)
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

### Task 14: Web guards and the route smoke test
- Files: `lib/custom_code/actions/fetch_contacts_action.dart`, `lib/custom_code/actions/open_notification_settings.dart`, `docs/architecture/adopted-files.md`, `pubspec.yaml`, `pubspec.lock`, `test/web_routes_smoke_test.dart`
- Plan slice: on the web, skip the contacts fetch so the home page init finishes. Make the Notifications row ask for browser notification permission in place of the native settings call. Add adopted-files rows for these two files and `push_notifications_util.dart` (Task 11). A Chrome smoke test opens every route in `nav.dart` with Firebase faked, and fails on any uncaught error (PIN-15, A9).
- Done when: `/c/src/flutter/bin/flutter test --platform chrome test/web_routes_smoke_test.dart` (prints `All tests passed!`)
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

## Phase 5 — Ship

### Task 12: Web build in CI, Firebase Hosting, deploy, runbook
- Files: `firebase/firebase.json`, `.github/workflows/ci.yml`, `.github/workflows/deploy-web.yml`, `docs/web-app-runbook.md`
- Plan slice: a CI job runs `flutter build web --release` and the `--platform chrome` tests. Hosting serves `build/web` with a rewrite to `/index.html`, so `/homePage` and every route resolve. A deploy workflow publishes on merge to `main`. The runbook covers the Porkbun DNS change for `habitcraftapp.com` (PIN-7), Firebase authorized domains, the Apple Services ID and the FCM web key. It points at `firebase/firebase.json` and `deploy-web.yml` for paths and deploy commands, and does not restate them.
- Done when: `node -e "const fs=require('fs');const c=fs.readFileSync('.github/workflows/ci.yml','utf8');const f=fs.readFileSync('firebase/firebase.json','utf8');const ok=/flutter build web --release/.test(c)&&/--platform chrome/.test(c)&&fs.existsSync('.github/workflows/deploy-web.yml')&&f.includes('/index.html');console.log(ok?'web-ship-ok':'web-ship-missing');process.exit(ok?0:1)"` (prints `web-ship-ok`)
- requiresTest: false
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
- Files written in more than one phase, never twice in one phase: `firebase/firebase.json` and `.github/workflows/ci.yml` (Tasks 2, 12), `firebase/firestore.rules` (Tasks 2, 4), `jp_store.dart` (Tasks 1, 3), `jp_store_sqlite.dart` (Tasks 1, 5), `quiet_room_speak_widget.dart` (Tasks 13, 9), `docs/architecture/adopted-files.md` (Tasks 8, 14), `pubspec.yaml` and `pubspec.lock` (Tasks 5, 14).
- The 11/02 plan's other floor items (`firebase/functions` untouched, no FlutterFlow-managed edits outside its listed files, the record stays phone-local) scoped that plan only. This plan replaces them (user, red-team 2026-11-19).
- Tasks 13 and 14 were added at red-team, so their numbers run out of order inside their phases.

## Open decisions

None.

# Reference — Firebase backend categories

Bodies for `rules-3way`, `ref-identity`, `schema-compat`, `data-lifecycle`, `query-bounds`,
`concurrency-offline`, `fn-reliability`, `time-tz`, `push-contract`.

Every embedded fact carries a **Check before citing** predicate. Run it. If it no longer holds,
the claim has expired — do not cite it, and apply the retirement instruction.

---

## `rules-3way` — Firestore and Storage rules, three directions

Firestore is reached directly from the client. There is no API tier. Per
`docs/architecture/01-system-context.md`, security rules "are not one layer of defence among
several — they are the *only* thing." Everything a rule fails to stop, nothing stops.

Reviewers habitually check one direction. There are three.

**Too open.** Does a collection allow unauthenticated read of user data? Does `create: if true` let
anyone write? Is any `*Public` privacy flag enforced in rules, or only in the UI?

> **Check before citing (#1):** `rg -n "Public" firebase/firestore.rules`
> At last measurement the `*Public` flags appeared nowhere in the rules, making them client-side
> decoration and every user document world-readable. If they now appear, #1 is closed — verify the
> enforcement rather than asserting its absence.

**Too closed.** Does the app perform a write the rules deny? Grep the client for `.update(`,
`.delete(`, and `.set(` against the collection being reviewed. A denied write that the client does
not guard aborts the surrounding action block.

> **Check before citing (#14):** `rg -n "reminders" firebase/firestore.rules`
> The habit-finishing bug works exactly this way: rules deny reminder deletes, and the unguarded
> delete aborts the action block before `is_finished` is ever written, so the habit reappears every
> session. Confirm the deny is still there before describing it in the present tense.

**Too expensive.** Firebase bills per document read. With rules as the only defence tier, a
world-readable collection with no bound is a billing denial-of-service any anonymous caller can
trigger by looping a query. Ask of every rule granting read: how many documents can one
unauthenticated caller pull, and what does that cost? Unbounded read on a collection that grows
with users is **Warning** even when the data is not sensitive.

Related: there is no App Check in this project, so any callable function is world-invocable by
anyone holding the project ID.

> **Check before citing:** `rg -ri "appcheck|app_check" lib/ firebase/ pubspec.yaml`
> Empty means the claim holds. Non-empty means App Check landed — stop asserting its absence.

Any rules change must be verified against the emulator, never deployed straight to production.

---

## `ref-identity` — reference versus string identity

`user`, `member`, `group`, and similar fields are `DocumentReference`, not uid strings. A query
comparing them to a string matches **zero documents and throws no error**.

- Flag any `where("user", "==", someUid)`. The correct form is `db.doc(\`users/${uid}\`)`.
- Flag `!==` or `===` between two `DocumentReference`s — compare `.path` or use `.isEqual()`.
  Object identity is always unequal.

This is half of why the deletion function deletes nothing: even with `db` defined, it queries by
uid string against reference fields.

> **Check before citing (#7):**
> `rg -n 'where\("(user|member)", "==", userId\)' firebase/custom_cloud_functions/delete_all_user_data.js`
> Cite the line numbers this returns, not remembered ones.

---

## `schema-compat` — backwards compatibility on a schemaless store

There is no schema, no migration step, and no forced client upgrade. Two consequences a Postgres
instinct will miss:

- **Documents written by the FlutterFlow-era app keep their old shape forever.** Nothing rewrites
  them. A field you stop writing today is still present, with its old value, on every document
  created before today.
- **After release, old clients keep writing old shapes.** A user on last month's build writes last
  month's fields into a collection your new code reads with new expectations, indefinitely.

Any change to a record class in `lib/backend/schema/`, a stored enum in
`lib/backend/schema/enums/`, or a persisted `FFAppState` key must answer **both** questions:

1. **New code reads an old document.** The field is absent, holds the old type, or holds a value the
   new enum does not contain. What happens? Record-class getters coerce absence to a type default,
   so absence usually renders as a plausible wrong value rather than an error.
2. **An old client writes into new expectations.** It writes the old field and not the new one, or
   writes the old type. Does the new read path handle that, or does it show zeros?

**This class is already in production — issue #24.** `users` carries a legacy `height` int *and*
the newer `height_feet` / `height_inch` strings. The settings screen reads the dead int, always 0;
the public preview reads the strings. Two shapes coexist in one collection, and J10 assertion 4
fails because of it.

> **Check before citing (#24):** `rg -n "height" lib/backend/schema/users_record.dart`
> Both `height` and `height_feet` must still be present for the dual-shape claim to hold. If one
> has been retired, #24 is resolved — cite it as precedent, not as a live defect.

Adding a third shape without retiring a previous one is **Warning**; doing it to a field a journey
asserts on is **Critical**.

**Renaming a field is not a rename.** It is an add plus a permanent dual-read, unless a backfill
script ships in the same change.

**Persisted `FFAppState` keys** live in shared preferences on installed devices. Changing a key's
name or type strands the old value on every existing install.

> **Check before citing:** `rg -n "prefs\.(set|get|remove)" lib/app_state.dart`
> Gives the current persisted key set. At last measurement there were seven `ff_*` keys.

### Do not flag

- Purely additive optional fields whose read path already treats absence correctly.
- In-memory-only `FFAppState` fields with no `prefs.set*` call.
- Fields on collections never written to in production.

---

## `data-lifecycle` — the create/delete/disclose invariant

The worst incident class in this codebase is deletion that does not delete. `delete_all_user_data.js`
referenced an undefined `db` and swallowed the ReferenceError as success, so nothing has ever been
deleted (#7, J12). Separately, its collection list is shorter than J12 assertion 2 requires.

> **Check before citing:**
> `rg -n "collectionsToDeleteFrom|\"[a-z_]+\"," firebase/custom_cloud_functions/delete_all_user_data.js`
> At last measurement it swept `chat_messages`, `checkins`, `goals`, `habits`, `reminders`,
> `user_group_search` by `user`, then `group_member_state`, `checkins`, `goals` by `member`.
> J12 also requires `users` and `users/{uid}/user_activity`. Re-derive the gap from the current
> file and the current J12 text; do not cite the frozen list above.

The forward-looking rule:

> **Any change that adds a new user-data field or a new collection must, in the same change, update
> all three of: (a) `firebase/firestore.rules` — or `storage.rules` for files, (b) the collection
> list in `firebase/custom_cloud_functions/delete_all_user_data.js`, and (c) the privacy labels in
> both App Store Connect and the Play Console Data Safety form.**

All three, or none. A new collection with rules but no deletion path is a deletion bug the day it
ships. A new personal field with deletion but no privacy-label update is a store-compliance defect
that surfaces at submission, when it is most expensive.

Same rule for Cloud Storage prefixes: a new upload path needs a matching removal in the deletion
path and a matching `storage.rules` entry.

Report a miss as **Critical** and name which of the three was missed. If (c) cannot be done in the
same commit because it lives in a web console, the change must still record it — an issue, or a
line in a release checklist, cited in the review.

### Do not flag

- New fields on documents that are already swept wholesale by document deletion (the deletion path
  removes the whole document, so a new field on it needs no separate entry) — but it still needs
  the privacy-label answer if it is personal data.
- Derived or cached fields holding no information not already present elsewhere.

---

## `query-bounds`

Flag:

- Any Firestore query with no `limit` or range filter that grows with user history. #21 is the live
  case: the progress page query is unbounded and all-time.
- Any per-item `.get()` inside a loop — use `Future.wait` or a `whereIn` batch.
- Any widget that rebuilds a derived collection on every frame rather than on data change.

### Do not flag

- Queries against fixed reference collections whose size does not grow with users or usage:
  `categories`, `feelings`, `icons`, `celebration_suggestions`, `articles`, `lessons`, `webinars`,
  `monthly_challenges`, `application_messages`.
- Single-document `.get()` by known ID.
- Queries already bounded by a `whereIn` over a bounded list.

> **Check before citing:** `ls lib/backend/schema/*_record.dart` gives the current collection set.
> If a collection above no longer exists, or a new fixed reference collection appeared, update this
> list rather than reasoning from it.

---

## `concurrency-offline`

The Firestore mobile SDKs enable offline persistence by default and nothing here disables it. A
user can check in on a phone with no signal, open the web app, check in again, and have both writes
land minutes apart in an order neither client chose. Last-write-wins is the default, and it
silently discards one of them.

> **Check before citing:** `rg -rn "persistenceEnabled|Settings\(" lib/backend/firebase/ lib/main.dart`
> Empty means defaults are in force, which is the assumption above.

Check for:

- **Read-modify-write on a shared document.** Reading a document, mutating a field in Dart, and
  writing the whole document back overwrites any concurrent change to *other* fields. Prefer
  field-level updates, `FieldValue.increment`, or a transaction. `group_member_state` and
  `chats.last_message_seen_by` are the live examples — both are written from multiple paths.
- **Counters computed client-side.** Member counts, streaks, and check-in tallies derived by
  read-then-write are wrong under concurrency. Use `FieldValue.increment` or derive at read time.
- **Client clock as authority.** `DateTime.now()` on a device with a wrong or deliberately-set clock
  produces a timestamp the server accepts. For any field that orders events, establishes "today",
  or gates a streak, the authority should be `FieldValue.serverTimestamp()`. Where the client clock
  must be used — offline writes cannot obtain a server timestamp at write time — say so, and say
  what breaks when it is wrong.
- **Offline optimism.** A write queued offline resolves its future locally, so success handlers run
  before anything reaches the server, and a rules denial surfaces only on reconnect, potentially
  after the screen is gone. Any UI reporting "saved" must mean it or say otherwise.

### Do not flag

- Create-only paths minting a new document with a fresh ID.
- Single-writer documents under `users/{uid}` that no other actor touches.
- Reads that never write back.

---

## `fn-reliability` — Cloud Function reliability

Applies to `firebase/custom_cloud_functions/` and `firebase/functions/`.

- **Undefined variables.** `const db = admin.firestore()` must exist in the module. Two shipped
  functions referenced an undefined `db`.
- **Swallow-all catches.** `catch (e) { console.error(e) }` converts a crash into a false success
  and prevents retry. Rethrow.
- **Floating promises.** `.then()` chains neither returned nor awaited let the function terminate
  before the write lands.
- **Idempotency.** Triggers retry. Unconditional `.add()` in an `onUpdate` handler mints a duplicate
  on every fire — #12: reminders are cloned on every membership update, and membership updates on
  every check-in. Prefer deterministic IDs with `set()`, or query before writing.
- **Batch limits.** Firestore commits cap at 500 operations. Chunk.
- **Unbounded scans.** A scheduled function reading an entire collection scales its cost with user
  count. Query only the due set.
- **Explicit timeouts.** Scheduled work needs `timeoutSeconds` set deliberately.
- **Trusting client input.** Callable and HTTPS functions receive attacker-controlled data. Verify
  `context.auth` exists, verify the caller owns what they are acting on, and validate shapes.

> **Check before citing:** `ls firebase/custom_cloud_functions/*.js` for the current function set,
> and `rg -Ln "admin.firestore\(\)" firebase/custom_cloud_functions/*.js` for modules that use `db`
> without defining it.

---

## `time-tz` — time and timezone correctness

This app's product is daily reminders, and its worst bugs are date bugs.

- Flag any `new Date()` or `DateTime.now()` used for day-of-week or day comparison where the user's
  locale matters. Server time is UTC; the user's Monday evening is Tuesday in UTC. This is #10,
  which skips evening reminders across the Americas entirely.
- If a function offsets the clock for an hour comparison, the day comparison must use the **same**
  offset value.
- Flag day-of-month equality (`a.day == b.day`) used as recurrence — it matches every month.

The timezone helpers in `lib/flutter_flow/custom_functions.dart` reach the reminder scheduler.
A change to one without a unit test is **Warning**.

> **Check before citing:** `rg -n "localTo|startOfDay|isToday" lib/flutter_flow/custom_functions.dart`
> Gives the current helper set. At last measurement the file held 25 functions total, and the
> `unit/` tier in `docs/testing/README.md` is scoped to exactly that set — if the count has moved,
> the testing doc needs updating too, which is an Architecture Note.

---

## `push-contract` — push notification contract

- `parameter_data` must be a **JSON string**, never an object. FCM rejects non-string data values,
  and the failure surfaces only as `status: failed` on a Firestore document nobody reads. #11: every
  onboarding drip notification fails validation this way.
- Deep-link parameters must be sent under `parameterData`, the key the client handler actually
  reads. Top-level FCM data keys are silently dropped (#9).

Anything touching notifications also gets the full `plat-matrix` walk — Android runtime permission,
iOS APNs, web service worker — because the three delivery paths share almost no code.

> **Check before citing:** `rg -rn "parameterData|parameter_data" lib/ firebase/`
> Confirms which key each side uses before asserting a mismatch.

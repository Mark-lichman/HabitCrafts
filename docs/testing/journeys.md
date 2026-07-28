# HabitCrafts User Journeys

The behavioural baseline. Each journey is the specification a test asserts against.

## How to read this

**These journeys are derived from source, not from observation.** The app has not yet been run —
the first build is still being repaired. Steps and assertions describe what the code says should
happen. Each will need confirmation against the running app, and anything contradicted by
observed behaviour should be corrected here first, then in the test.

**Status values:**

- `WORKS` — confirmed against a running build
- `UNVERIFIED` — derived from source, never observed
- `BROKEN (#n)` — a defect is known and ticketed; the journey cannot complete as written

Nothing is `WORKS` yet, because nothing has been run.

**Assertions describe intended behaviour.** Where a journey is `BROKEN`, the assertions describe
what *should* happen. Those tests will fail until the issue is fixed. That is correct.

---

## J1 — First run and sign up

**Actor:** new user · **Status:** UNVERIFIED

**Preconditions:** app freshly installed, no session.

**Steps:** launch → `/initialPage` → Sign Up → enter email and password → `/onboarding` → complete
onboarding → `/homePage`.

**Assertions:**
1. A cold launch with no session lands on `/initialPage`, not `/homePage`.
2. Sign-up creates exactly one `users/{uid}` document whose id equals the Firebase Auth uid.
3. `created_time` is set; `display_name` and `email` are populated from the sign-up form.
4. Onboarding is shown once — `FFAppState.showOnboard` is persisted false afterwards, and a
   subsequent launch goes straight to `/homePage`.
5. EULA acceptance is recorded in `FFAppState.eulaAccepted`.

**Data:** `users`

---

## J2 — Sign in, sign out, password reset

**Actor:** returning user · **Status:** UNVERIFIED

**Steps:** `/initialPage` → Login → credentials → `/homePage`. Separately: Login → Forgot Password
→ `/forgotPassword` → submit email.

**Assertions:**
1. Valid credentials land on `/homePage`; the session persists across a cold restart.
2. Invalid credentials surface an error and remain on `/loginPage` — they do not hang on a spinner.
3. Google Sign-In completes and reuses the existing `users/{uid}` when the email matches.
4. Sign-out returns to `/initialPage` and clears the session.
5. Password reset submits without error for both known and unknown emails, and does not disclose
   which is which.

**Data:** `users`, Firebase Auth

**Note:** no route sets `requireAuth` (#6), so a signed-out user reaching `/profilePage` by URL or
deep link is not redirected. Assertion 6, once #6 lands: any signed-in-only route reached without a
session redirects to `/initialPage` and returns to the intended destination after login.

---

## J3 — Create a habit

**Actor:** signed-in user · **Status:** UNVERIFIED

**Steps:** `/homePage` → Create Habit (or `/exploreHabitsPage` → pick a suggestion) →
`/createHabitPage` → set behaviour, why, celebration, goal, icon, category → optionally set a
reminder → save.

**Assertions:**
1. Saving creates one `habits` document with `user` set to the caller's `users/{uid}` **reference**,
   not a uid string.
2. `behavior`, `why`, `celebration`, `created_time` persist as entered.
3. `goal`, `icon`, `category` are stored as DocumentReferences that resolve.
4. `is_finished` is false on creation.
5. Setting a reminder creates one `reminders` document with `hour_local` and `minute_local` — the
   fields the scheduler queries — and links it via `habits.reminder`.
6. The new habit appears in the home list without a manual refresh.

**Data:** `habits`, `goals`, `reminders`, `user_activity`

---

## J4 — Daily check-in

**Actor:** signed-in user · **Status:** BROKEN (#20)

**Steps:** `/homePage` → check-in → set feeling on the slider → enter what went well and what needs
improvement → optionally share to group → submit.

**Assertions:**
1. Submitting creates one `checkins` document with `user` as a reference and `date` set.
2. `feeling` equals the value the slider **currently displays**.
3. `what_went_well` and `what_needs_improvement` persist as entered.
4. With share-to-group enabled, `group` is set and the check-in appears in that group's feed.
5. A second check-in in the same session starts from a neutral slider state, and submitting without
   touching the slider does not record the previous check-in's value.

**Currently fails at 2 and 5.** `FFAppState.checkinSliderValue` is never reset, so the widget
shows the first emoji while the stored value is whatever was last selected (#20).

**Data:** `checkins`, `user_activity`, `group_member_state`

---

## J5 — Finish a habit

**Actor:** signed-in user · **Status:** BROKEN (#14)

**Steps:** `/homePage` or `/profilePage` → open a habit → Finish.

**Assertions:**
1. `habits.is_finished` becomes true and `finished` is timestamped.
2. The habit leaves the active list and appears under finished habits.
3. An attached reminder is deleted, and no further notifications fire for it.
4. The habit stays finished across a restart.

**Currently fails for any habit with a reminder.** `firestore.rules:120` denies reminder deletes,
and the unguarded delete at `goal_habit_list_item_model.dart:68` aborts the action block before
`is_finished` is ever written — so the habit reappears every session (#14).

**Data:** `habits`, `reminders`

---

## J6 — Groups: browse, join, participate

**Actor:** signed-in user · **Status:** UNVERIFIED

**Steps:** `/groupsPage` → browse or search → join a group → view members → complete a group
check-in.

**Assertions:**
1. Joining creates one `group_member_state` document with `member` as a reference and the correct
   status.
2. The group appears in the user's list immediately after joining.
3. Member count reflects live membership and excludes deleted accounts.
4. A group check-in updates `group_member_state.recent_checkin` and appears in the group feed.
5. Searching a group by name returns it.
6. Joining creates **at most one** reminder for that user and group, and repeated check-ins create
   no additional ones.

**Assertion 5 cannot pass today** — `add_search_terms_for_groups.js` throws a ReferenceError on
every group creation, so `search_terms` has never been populated (#22).

**Assertion 6 cannot pass today** — the onUpdate trigger clones a reminder on every membership
update, and membership updates on every check-in (#12).

**Data:** `groups`, `group_member_state`, `user_group_search`, `reminders`, `checkins`

---

## J7 — Group chat

**Actor:** signed-in group member · **Status:** UNVERIFIED

**Steps:** `/groupsPage` → `/chat2Main` → send a message → react → open an image → invite users.

**Assertions:**
1. A sent message creates one `chat_messages` document with `chat`, `user`, `timestamp`, and text.
2. It appears for other members without a manual refresh.
3. Reactions attach to the correct message and are attributed to the reacting user.
4. `last_message_seen_by` updates once per viewer — not repeatedly, and not for chats the user has
   left.
5. Leaving a chat detaches its listener; no further writes occur from that screen.

**Assertions 4 and 5 are at risk** — the listener at `chat_thread_component_widget.dart:110` is
created inside `build()` and never cancelled, and its callback writes with no `mounted` guard (#15).

**Data:** `chats`, `chat_messages`, `reactions`

---

## J8 — Report a message

**Actor:** signed-in user · **Status:** BROKEN (#17)

**Steps:** open a message → long-press → Report → choose a reason (or Other, with free text) →
submit.

**Assertions:**
1. Reporting in a **group** chat creates a `flags` document and notifies the group's leaders.
2. Reporting in a **direct** message creates a `flags` document and routes to the moderation path
   without crashing.
3. Choosing "Other" stores the **typed text** as the reason.
4. No report routes to a hardcoded individual account.

**All four fail today.** DM reports throw on a null `chat.group`; the branch at line 336 is
inverted so group reports skip leaders; "Other" stores `hasFocus.toString()`; and everything routes
to a hardcoded UID in `app_state.dart:183` (#17).

Both app stores require working content moderation for user-generated content.

**Data:** `flags`, `chat_messages`

---

## J9 — Progress and streaks

**Actor:** signed-in user · **Status:** UNVERIFIED

**Steps:** `/progressPage` → view calendar → view chart → change month.

**Assertions:**
1. Each day with activity shows a marker.
2. A day containing **both** a habit completion and a check-in shows both, not one.
3. The chart reflects the last six weeks of real data.
4. Changing month does not refetch the entire activity history.

**Assertions 2 and 4 fail today** — the event map keys on exact timestamp so same-day entries
overwrite each other, and the query is unbounded and all-time (#21).

**Data:** `user_activity`, `checkins`, `habits`

---

## J10 — Profile and privacy settings

**Actor:** signed-in user · **Status:** UNVERIFIED

**Steps:** `/profilePage` → edit details → toggle per-field visibility → view own public preview →
view another member's profile.

**Assertions:**
1. Edits persist to `users/{uid}` and survive a restart.
2. Setting a field to private hides it from **other users**, enforced server-side — not merely
   hidden in the UI.
3. Viewing another member's profile shows **their** values for every field.
4. Height displays consistently between the settings screen and the public preview.

**Assertion 2 fails today** — the `*Public` flags appear nowhere in `firestore.rules`; they are
client-side decoration, and every user document is world-readable (#1).

**Assertion 3 fails for age** — the tag renders the **viewer's** birthday (#20).

**Assertion 4 fails** — settings shows the dead `height` int, always 0, while the preview shows
`height_feet`/`height_inch` (#24).

**Data:** `users`

---

## J11 — Reminders and notifications

**Actor:** signed-in user with a reminder · **Status:** BROKEN (#10, #12)

**Steps:** set a reminder time and days on a habit → wait for the scheduled time → receive a push →
tap it.

**Assertions:**
1. A reminder fires at the chosen local time, on the chosen local days.
2. It fires **once** per occurrence, not multiple times.
3. Tapping the notification deep-links to the relevant screen with its parameters intact.
4. Editing the time moves subsequent notifications.
5. Finishing the habit stops them.
6. Day-1-through-7 onboarding notifications arrive on their intended days.

**Assertion 1 fails** — the day-of-week check uses UTC, so evening reminders across the Americas
are skipped entirely (#10). **Assertion 2 is at risk** once #10 is fixed, because duplicate
reminders have been accumulating (#12). **Assertion 3 fails** — the deep link is sent as a
top-level FCM key the handler does not read (#9). **Assertion 4 fails** — rules deny reminder
writes (#14). **Assertion 6 fails** — every drip notification fails FCM validation (#11).

**Data:** `reminders`, `ff_user_push_notifications`, `fcm_tokens`

---

## J12 — Delete account

**Actor:** signed-in user · **Status:** BROKEN (#7)

**Steps:** `/profilePage` → Delete Account → confirm.

**Assertions:**
1. The confirmation states what will be deleted, and that statement is accurate.
2. After deletion, no document referencing that user remains in `users`, `habits`, `checkins`,
   `goals`, `group_member_state`, `chat_messages`, `reminders`, `user_group_search`, or
   `users/{uid}/user_activity`.
3. Uploaded files under the user's Storage prefix are removed.
4. The Firebase Auth account is deleted; the credentials no longer sign in.
5. The user disappears from group member lists and counts.
6. No further push notifications are delivered to that user's devices.

**Every assertion fails.** `delete_all_user_data.js` references an undefined `db`, and its catch
swallows the ReferenceError and reports success — nothing has ever been deleted (#7).

This is the highest-priority journey to fix: **both app stores require working in-app account
deletion**, so this blocks release on Google Play and the App Store independently of any privacy
regulation.

**Data:** all collections, Firebase Auth, Cloud Storage

---

## Coverage summary

Twelve journeys. **Six are known broken** (J4, J5, J8, J10, J11, J12) and the remaining six are
unverified. J6, J7, and J9 each contain individual assertions that already fail.

Reading down the list, the pattern is that **the create paths mostly work and the lifecycle paths
do not** — creating habits, check-ins, groups, and messages is intact, while finishing, editing,
reporting, and deleting are broken. That is consistent with how the app was built: the happy path
was exercised during development, and the exits were not.

## Suggested implementation order

1. **J12** — store-blocking, and the emulator tests double as the fix's acceptance criteria
2. **J5 and J11** — the reminder and rules cluster, which share one rules deployment
3. **J1, J2, J3** — the acquisition path, cheapest to automate and the base for every other journey
4. **J8** — store-required moderation
5. The remainder as their issues are picked up

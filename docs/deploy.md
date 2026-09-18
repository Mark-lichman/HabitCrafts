# Deploying to Firebase

The project is **`tiny-habits-jf61nl`**, and it is the only one. There is no staging
target: everything here touches the database real accounts live in.

There is no `.firebaserc`, so **every command names the project explicitly**. That is
deliberate rather than an oversight — nothing should default to production.

```sh
cd firebase
```

Every command below runs from that directory.

## Before the first deploy

```sh
npm install -g firebase-tools
firebase login                       # opens a browser; needs a real OAuth round trip
firebase projects:list               # tiny-habits-jf61nl should appear
```

`firebase login` cannot be scripted or run from a non-interactive session. If you are
automating this, use a CI service account rather than a personal token.

## Rules

### You cannot lock yourself out with a typo

Firebase **compiles rules server-side and refuses to publish invalid ones**. A syntax
error gives you a failed deploy with a line number; it does not push broken rules. On
top of that, rules keep full version history in the console with one-click rollback.

What that does *not* catch is a rule that compiles and is semantically wrong — one that
locks out real users while parsing perfectly. That is what the verification step below
is for, and it is not optional.

### Deploy

Rules before functions, always. They are instant, reversible, and they are the half that
closes a data leak.

```sh
firebase deploy --only firestore:rules,storage --project tiny-habits-jf61nl
```

### Verify, from outside

The check that matters is whether an **unauthenticated** caller can still read. No login,
no API key, nothing:

```sh
curl -s "https://firestore.googleapis.com/v1/projects/tiny-habits-jf61nl/databases/(default)/documents/users?pageSize=1"
```

* **Leaking:** HTTP 200 and a `"documents"` array. On 2026-09-18 this returned real
  records including `email` and `display_name` to a caller with no credentials at all.
* **Fixed:** `PERMISSION_DENIED`.

If documents still come back, the rules did not take. Stop and check the console's Rules
tab before doing anything else.

Then open the app **signed in** and confirm Community, group member lists and profile
photos still load. Tightening a read rule breaks exactly those things when it is wrong,
and nothing else will tell you.

## Functions

### Name the codebase, or you deploy twice as much as you meant to

`firebase.json` declares **two** codebases, `custom_cloud_functions` and `functions`, and
the first holds **ten** functions. A codebase-wide deploy redeploys all ten with freshly
resolved dependencies, which is how an unrelated function breaks on a day you only meant
to touch one.

```sh
firebase deploy --only functions:custom_cloud_functions:deleteAllUserData --project tiny-habits-jf61nl
```

The `custom_cloud_functions:` in the middle is the codebase. Omit it and you get both.

### Two things that will look like errors and are not

* **Node version.** The functions declare Node 20; your machine probably runs something
  newer. The runtime in Google Cloud is Node 20 regardless, so a local version warning is
  about your install, not the deployed function.
* **No `package-lock.json`.** `firebase-admin` is pinned as `^11.8.0` and resolves fresh
  at deploy, so two deploys a month apart can ship different minors. That is a real
  hazard worth fixing (S11), but it does not block a deploy.

## Proving account deletion actually deletes

**Do this on a throwaway account before trusting it with your own.**

The reason is specific. The previous version of `deleteAllUserData` reported success while
deleting nothing — `db` was never defined, the catch swallowed the error, and the app told
people their data was gone. It had never worked and could not have: the queries compared
`user` to a uid string while every `user` field in the schema is a DocumentReference.

A function that lies about deleting looks identical, from the app, to one that works. The
only way to tell them apart is to look in the database.

1. Sign up with a throwaway Google account.
2. Create a habit, check it in, set a reminder, upload a profile photo.
3. Delete the account from inside the app.
4. In the console, confirm **all** of:
   * `users/{uid}` is gone, and with it `users/{uid}/user_activity`
   * `habits`, `checkins`, `goals`, `reminders`, `user_group_search`,
     `chat_messages` hold nothing for that user
   * `group_member_state` holds nothing with that `member`
   * Storage `users/{uid}/` is empty
5. Read the Functions log. You want `Deleted data for <uid>: {...}` with real counts.

If anything survives, the function now **throws and the run shows as failed**. That is the
point of the rethrow: a deletion that did not happen must not look like one that did.

### What is deliberately left behind

Three collections are not touched, and each is a decision rather than an omission. They
are documented in `delete_all_user_data.js`:

| Collection | Why it stays |
|---|---|
| `groups` (`creator`) | Deleting a group removes it for every member. `deleteGroupsByCreator` exists for that and is a separate call. |
| `chats` | A thread has two sides; deleting it removes the other person's history. |
| `flags` | Moderation records. Both app stores expect the trail to outlive the reported party. |

If any of these should go, it needs its own ticket and its own argument.

## Do not deploy `cleanInvalidUserGroupEntries`

It has the same undefined `db` as the old deletion function, and **it must keep it**.

It is an `https.onRequest` endpoint with **no auth check**, inert today only because it
throws. Defining `db` switches on a publicly callable URL that bulk-deletes. Worse, it
passes a DocumentReference to `.doc()`, which expects a string, so `exists` is false for
every row — the first caller would wipe the entire `user_group_search` collection.

It needs deleting or securing. Not repairing.

## Rollback

* **Rules:** console → Firestore → Rules → History → pick the previous version → Publish.
  Takes about ten seconds.
* **Function:** `git revert <sha>`, then redeploy that one function with the same
  `--only` target.

## What deploying does not fix

Rules and the deletion function close the data objections. They do not touch:

* the reminder scheduler's UTC day-of-week bug, which skips evening reminders across the
  Americas (`docs/testing/journeys.md` J11)
* the five journeys still marked BROKEN, and the seven still UNVERIFIED
* the absence of any test at all

`flutter analyze` reports zero errors, and CI passes on `--no-fatal-warnings` with ~4,100
warnings and infos underneath. Per S10, treat that green check as asserting that nothing
is a hard error, and nothing more.

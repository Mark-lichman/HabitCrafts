const functions = require("firebase-functions");
const admin = require("firebase-admin");
// The modular import: `admin.firestore.FieldValue` is undefined on this
// namespace when the app is initialized through firebase-admin/app.
const { FieldValue } = require("firebase-admin/firestore");
// To avoid deployment errors, do not call admin.initializeApp() in your code

const db = admin.firestore();

/**
 * Delete everything belonging to a user when their auth account is deleted.
 *
 * WHY THIS WAS REWRITTEN. Account deletion had never worked and could not have
 * worked. Three faults were stacked:
 *
 *   1. `db` was used and never defined. Every invocation threw ReferenceError
 *      on the first query.
 *   2. The catch logged and returned, so the function reported success. The app
 *      told people their data was gone while none of it had been touched.
 *   3. Even with `db` defined it would have deleted nothing: the queries
 *      compared `user` to a uid STRING, and every `user`/`member` field in this
 *      schema is a DocumentReference. A reference never equals a string, so
 *      every query matched zero documents.
 *
 * It also never deleted the `users/{uid}` document itself, which is where the
 * email, phone number, birthday and photo live: the only records it aimed at
 * were the ones nobody would have minded leaving behind.
 *
 * Both app stores require working in-app account deletion, so this blocks
 * release independently of any privacy regulation.
 */

/**
 * Collections holding documents that belong to ONE person, and the field that
 * points at them. Every one of these fields is a DocumentReference, which is
 * why the query below is built from `userRef` rather than from the uid.
 */
const OWNED_BY_USER = [
  ["chat_messages", "user"],
  ["checkins", "user"],
  ["goals", "user"],
  ["habits", "user"],
  ["reminders", "user"],
  ["user_group_search", "user"],
  ["group_member_state", "member"],
];

/**
 * DELIBERATELY NOT DELETED HERE, because each one belongs to someone else as
 * much as to the departing user, and a deletion path is the wrong place to
 * make that call silently:
 *
 *   groups      `creator` — deleting a group removes it for every member.
 *               `deleteGroupsByCreator` exists for that and is a separate
 *               decision.
 *   chats       a thread has two sides; removing it deletes the other
 *               person's history too.
 *   flags       moderation records. Both app stores expect a moderation trail
 *               to survive the reported party leaving.
 *
 * If any of these should go, it needs its own ticket and its own argument.
 */

/** Firestore caps a batch at 500 writes. */
const BATCH_LIMIT = 400;

async function deleteMatching(collection, field, userRef) {
  const snapshot = await db.collection(collection).where(field, "==", userRef).get();
  if (snapshot.empty) return 0;

  const docs = snapshot.docs;
  for (let i = 0; i < docs.length; i += BATCH_LIMIT) {
    const batch = db.batch();
    docs.slice(i, i + BATCH_LIMIT).forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
  }
  return docs.length;
}

exports.deleteAllUserData = functions.auth.user().onDelete(async (user) => {
  const userId = user.uid;
  const userRef = db.collection("users").doc(userId);
  const deleted = {};

  try {
    /* First, before anything is deleted: the deleted_accounts/{uid} marker.
       A device still signed in keeps a valid ID token for up to an hour, and
       the users rule lets it recreate users/{uid}. The rules for jp_events,
       jp_days and devices refuse every request while this marker exists, so
       that device cannot write study data again (PIN-13). The marker holds
       only the time, and no client may read or write it. */
    await db
      .collection("deleted_accounts")
      .doc(userId)
      .set({ deletedAt: FieldValue.serverTimestamp() });
    deleted.marker = "deleted_accounts marker written";

    for (const [collection, field] of OWNED_BY_USER) {
      deleted[collection] = await deleteMatching(collection, field, userRef);
    }

    /* Uploaded files: avatars and anything attached to a message. Kept
       separate from the Firestore work because a Storage failure must not stop
       the profile document being removed - that document is the sensitive one.
       The error is re-raised at the end so the run still fails loudly. */
    let storageError = null;
    try {
      await admin.storage().bucket().deleteFiles({ prefix: `users/${userId}/` });
      deleted.storage = "ok";
    } catch (err) {
      storageError = err;
      deleted.storage = `FAILED: ${err.message}`;
    }

    /* Last, and the one that matters most: the profile document and every
       subcollection under it, which is where `user_activity` lives.
       recursiveDelete handles the subcollections; a plain delete would orphan
       them, leaving the activity history behind with no parent. The synced
       Japanese record (jp_events, jp_days, devices) lives here too, so this
       one call removes it (PIN-14). */
    await db.recursiveDelete(userRef);
    deleted.users = "profile and subcollections removed";

    console.log(`Deleted data for ${userId}: ${JSON.stringify(deleted)}`);

    if (storageError) throw storageError;
  } catch (error) {
    /* Log the context, then RETHROW. The previous version swallowed this and
       reported success, which is how a deletion that never ran looked like one
       that had. A thrown error is retried and shows up in the logs as a
       failure, which is the only honest outcome when data is still there. */
    console.error(
      `Failed deleting data for ${userId}. Progress: ${JSON.stringify(deleted)}`,
      error,
    );
    throw error;
  }
});

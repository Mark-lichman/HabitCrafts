const functions = require("firebase-functions");
const admin = require("firebase-admin");
// To avoid deployment errors, do not call admin.initializeApp() in your code

exports.deleteAllUserData = functions.auth.user().onDelete(async (user) => {
  try {
    const userId = user.uid;

    console.log(`User deleted: ${userId}`);

    // Collections to query
    const collectionsToDeleteFrom = [
      "chat_messages",
      "checkins",
      "goals",
      "habits",
      "reminders",
      "user_group_search",
    ];

    // Loop through collections and delete matching documents
    for (const collection of collectionsToDeleteFrom) {
      const querySnapshot = await db
        .collection(collection)
        .where("user", "==", userId)
        .get();

      const deletePromises = [];
      querySnapshot.forEach((doc) => {
        deletePromises.push(doc.ref.delete());
      });

      await Promise.all(deletePromises);
      console.log(`Deleted documents from collection: ${collection}`);
    }

    // Collections to query
    const othercollectionsToDeleteFrom = [
      "group_member_state",
      "checkins",
      "goals",
    ];

    // Loop through collections and delete matching documents
    for (const collection of othercollectionsToDeleteFrom) {
      const querySnapshot = await db
        .collection(collection)
        .where("member", "==", userId)
        .get();

      const deletePromises = [];
      querySnapshot.forEach((doc) => {
        deletePromises.push(doc.ref.delete());
      });

      await Promise.all(deletePromises);
      console.log(`Deleted documents from collection: ${collection}`);
    }

    console.log(`Cleanup completed for user: ${userId}`);
  } catch (error) {
    console.error(`Error cleaning up user data: ${error.message}`);
  }
});

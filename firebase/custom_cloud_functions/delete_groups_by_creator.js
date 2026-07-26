const functions = require("firebase-functions");
const admin = require("firebase-admin");
// To avoid deployment errors, do not call admin.initializeApp() in your code

const db = admin.firestore();

exports.deleteGroupsByCreator = functions.https.onCall(
  async (data, context) => {
    const userId = data.userId;
    //functions.https.onRequest(async (req, res) => {
    // 🔐 Hardcoded user ID to target

    if (!userId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Missing userId.",
      );
    }

    try {
      const groupSnap = await db
        .collection("groups")
        .where("creator", "==", db.doc(userId))
        .get();

      if (groupSnap.empty) {
        console.log(`No groups found for creator: ${userId}`);
        return { deletedGroups: 0, deletedGroupStates: 0 };
      }

      let deletedGroups = 0;
      let deletedGroupStates = 0;

      for (const groupDoc of groupSnap.docs) {
        const groupRef = groupDoc.ref;

        // Delete group_member_state entries that reference this group
        const memberStateSnap = await db
          .collection("group_member_state")
          .where("group", "==", groupRef)
          .get();

        const batch = db.batch();

        memberStateSnap.forEach((doc) => {
          batch.delete(doc.ref);
          deletedGroupStates++;
        });

        batch.delete(groupRef);
        deletedGroups++;

        await batch.commit();
      }

      return res.status(200).json({ deletedGroups, deletedGroupStates });
    } catch (err) {
      console.error("❌ Error deleting groups or group_member_state:", err);
      throw new functions.https.HttpsError("internal", "Error deleting data.");
    }
  },
);

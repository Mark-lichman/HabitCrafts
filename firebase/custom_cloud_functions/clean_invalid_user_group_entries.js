const functions = require("firebase-functions");
const admin = require("firebase-admin");
exports.cleanInvalidUserGroupEntries = functions.https.onRequest(
  async (req, res) => {
    try {
      const userGroupSnapshot = await db.collection("user_group_search").get();

      if (userGroupSnapshot.empty) {
        console.log("No entries found in user_group_search.");
        return res.status(200).send("No entries found in user_group_search.");
      }

      const deletions = [];

      for (const doc of userGroupSnapshot.docs) {
        const data = doc.data();
        const groupRef = db.collection("groups").doc(data.group);
        const userRef = db.collection("users").doc(data.user);

        const [groupSnap, userSnap] = await Promise.all([
          groupRef.get(),
          userRef.get(),
        ]);

        const groupExists = groupSnap.exists;
        const userExists = userSnap.exists;

        if (!groupExists || !userExists) {
          console.log(
            `Deleting orphaned entry: ${doc.id} (group: ${data.group}, user: ${data.user})`,
          );
          deletions.push(doc.ref.delete());
        }
      }

      await Promise.all(deletions);
      console.log(`Deleted ${deletions.length} orphaned entries.`);
      res.status(200).send(`Deleted ${deletions.length} orphaned entries.`);
    } catch (err) {
      console.error("Error cleaning chats:", err);
      return res.status(500).send("Internal server error");
    }
  },
);

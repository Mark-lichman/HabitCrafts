const functions = require("firebase-functions");
const admin = require("firebase-admin");
// To avoid deployment errors, do not call admin.initializeApp() in your code

const db = admin.firestore();

exports.cleanInvalidChatEntries = functions.https.onRequest(
  async (req, res) => {
    try {
      const chatsSnapshot = await db.collection("chats").get();

      if (chatsSnapshot.empty) {
        console.log("No entries found in chats.");
        return res.status(200).send("No chats found.");
      }

      const deletions = [];

      for (const doc of chatsSnapshot.docs) {
        const data = doc.data();
        const groupRef = db.collection("groups").doc(data.group);

        const groupSnap = await groupRef.get();

        if (!groupSnap.exists) {
          console.log(
            `Deleting orphaned entry: ${doc.id} (group: ${data.group})`,
          );
          deletions.push(doc.ref.delete());
        }
      }

      await Promise.all(deletions);
      console.log(`Deleted ${deletions.length} orphaned entries.`);

      return res
        .status(200)
        .send(`Deleted ${deletions.length} orphaned entries.`);
    } catch (err) {
      console.error("Error cleaning chats:", err);
      return res.status(500).send("Internal server error");
    }
  },
);

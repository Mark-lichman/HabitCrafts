const functions = require("firebase-functions");
const admin = require("firebase-admin");

exports.sendFirstSevenDayReminders = functions.pubsub
  .schedule("every 24 hours")
  .onRun(async (context) => {
    const now = new Date();
    const db = admin.firestore();
    const articles = [
      "/articles/FgujvEsBa3HgnUx5liFN",
      "/articles/0PLBMSkvdQJiDB3adQAV",
      "/articles/GP7Wu3m6iEUIpJt1NXGB",
      "/articles/l4Zd6OMql8K4N1w4TjDB",
      "/articles/kCVrW3q4Qwczys7vlcFD",
      "/articles/IWXWKac1kT20Onh2UtCT",
      "/articles/AyvXqP3JKisk5CudM64c",
    ];

    try {
      const batch = db.batch();
      const usersRef = db.collection("users");

      // Loop through last 7 days
      for (let dayOffset = 1; dayOffset <= 7; dayOffset++) {
        let startOfDay = new Date(now);
        startOfDay.setDate(now.getDate() - dayOffset);
        startOfDay.setHours(0, 0, 0, 0);

        let endOfDay = new Date(startOfDay);
        endOfDay.setHours(23, 59, 59, 999);

        const snapshot = await usersRef
          .where("created_time", ">=", startOfDay)
          .where("created_time", "<", endOfDay)
          .get();

        if (!snapshot.empty) {
          snapshot.forEach((doc) => {
            const userRef = doc.ref; // Reference to user document
            const notificationData = {
              initial_page_name: "libraryDetailPage",
              notification_text: `Check out the lesson for day ${dayOffset}`,
              notification_title: `Day ${dayOffset}`,
              timestamp: admin.firestore.Timestamp.now(),
              user_refs: userRef.path, // Storing Firestore reference
              parameter_data: { articleRef: articles[dayOffset - 1] },
            };

            const notifRef = db.collection("ff_user_push_notifications").doc();
            batch.set(notifRef, notificationData);
          });
        }
      }

      // Commit all writes at once
      await batch.commit();
      functions.logger.log(
        "Successfully sent push notifications for new users.",
      );
    } catch (error) {
      functions.logger.error("Error sending notifications:", error);
    }
  });

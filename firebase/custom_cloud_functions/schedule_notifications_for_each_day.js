const functions = require("firebase-functions");
const admin = require("firebase-admin");
// To avoid deployment errors, do not call admin.initializeApp() in your code
exports.scheduleNotificationsForEachDay = functions.pubsub
  .schedule("every 1 minutes")
  .onRun(async (context) => {
    const usersSnapshot = await admin.firestore().collection("users").get();
    if (usersSnapshot.empty) {
      console.log("No users found.");
      return;
    }

    for (const userDoc of usersSnapshot.docs) {
      const userId = userDoc.id;
      const userData = userDoc.data();
      const timezoneOffset = userData.local_offset || 0;

      const now = new Date();
      now.setMinutes(now.getMinutes() + timezoneOffset * 60);

      const currentHour = now.getHours();
      const currentMinute = now.getMinutes();

      console.log(
        `Checking reminders for user ${userId} at ${currentHour}:${currentMinute}`,
      );

      const remindersSnapshot = await admin
        .firestore()
        .collection("reminders")
        .where("user", "==", admin.firestore().doc(`users/${userId}`))
        .where("hour_local", "==", currentHour)
        .where("minute_local", "==", currentMinute)
        .get();

      if (remindersSnapshot.empty) {
        console.log(`No reminders for user ${userId} at this time.`);
        continue;
      }

      for (const reminderDoc of remindersSnapshot.docs) {
        const reminderData = reminderDoc.data();
        await processReminder(userDoc, reminderDoc, reminderData);
      }
    }
  });

async function processReminder(userDoc, reminderDoc, reminderData) {
  const userId = userDoc.id;
  const weekMap = {
    0: "Sun",
    1: "Mon",
    2: "Tues",
    3: "Wed",
    4: "Thurs",
    5: "Fri",
    6: "Sat",
  };
  const today = weekMap[new Date().getDay()];

  if (!reminderData.days.includes(today)) {
    console.log(
      `Reminder ${reminderDoc.id} not scheduled for today (${today}).`,
    );
    return;
  }

  let title = "Reminder";
  let text = "Time for your scheduled activity!";
  let page = "homePage";
  let data = {};

  if (reminderData.habit) {
    const habitDoc = await reminderData.habit.get();
    if (habitDoc.exists) {
      const habitData = habitDoc.data();
      title = "Complete habit";
      text = `Time to complete ${habitData.behavior}`;
    }
  }

  if (reminderData.group) {
    const groupDoc = await reminderData.group.get();
    if (groupDoc.exists) {
      const groupData = groupDoc.data();
      title = "Time to check-in";
      text = `Check-in with ${groupData.name}`;
      data = {
        initialPageName: "groupsPage",
        groupFromPush: reminderData.group.path,
      };
    }
  }

  await queueMessageForUser(page, title, text, data, userDoc);
}

async function queueMessageForUser(page, title, body, data, userDoc) {
  const tokensSnapshot = await admin
    .firestore()
    .collection("users")
    .doc(userDoc.id)
    .collection("fcm_tokens")
    .get();

  const tokens = tokensSnapshot.docs.map((doc) => doc.data().fcm_token);

  for (const token of tokens) {
    await sendMessage(page, title, body, data, token);
  }
}

async function sendMessage(page, title, body, data, token) {
  const message = {
    notification: { title, body },
    android: { priority: "high" },
    data,
    token,
  };

  try {
    await admin.messaging().send(message);
    console.log(`Notification sent to ${token}`);
  } catch (error) {
    console.error(`Error sending to ${token}:`, error);
  }
}

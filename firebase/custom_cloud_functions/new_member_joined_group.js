const functions = require("firebase-functions");
const admin = require("firebase-admin");
// To avoid deployment errors, do not call admin.initializeApp() in your code

exports.newMemberJoinedGroup = functions.firestore
  .document("group_member_state/{group_member_stateId}")
  .onCreate(async (groupMemberState) => {
    console.log("groupMemberState", groupMemberState);
    console.log("newMemberJoinedGroup");
    if (
      groupMemberState.get("status") === "Member" ||
      groupMemberState.get("status") === "Leader"
    ) {
      groupMemberState
        .get("group")
        .get()
        .then((groupDoc) => {
          console.log("groupDoc", groupDoc);
          addReminder(groupDoc, groupMemberState);
        });
    }
  });

function addReminder(groupDoc, groupMemberState) {
  // only add a reminder if a new member is added - not if a leader is a creator
  if (groupDoc.get("reminder_owner") !== groupMemberState.get("member")) {
    groupDoc
      .get("reminder_owner")
      .get()
      .then((reminderDoc) => {
        // console.log('reminderDoc', reminderDoc);
        if (!reminderDoc.exists) {
          console.log("No such document!");
        } else {
          // need to get the member to have the reminder fire in the user's local timezone
          groupMemberState
            .get("member")
            .get()
            .then((memberDoc) => {
              console.log("memberDoc", memberDoc);
              admin
                .firestore()
                .collection("reminders")
                .add({
                  days: reminderDoc.get("days"),
                  time: reminderDoc.get("time"),
                  hour: reminderDoc.get("hour"),
                  minute: reminderDoc.get("minute"),
                  timezone_offset: memberDoc.get("local_offset"),
                  group: reminderDoc.get("group"),
                  user: groupMemberState.get("member"),
                });
              functions.logger.log("new reminder to database");
              return groupDoc;
            });
        }
      });
  }
}

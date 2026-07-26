const functions = require("firebase-functions");
const admin = require("firebase-admin");
exports.addSearchTermsForUsers = functions.firestore
  .document("users/{users_id}")
  .onCreate(async (user) => {
    var displayName = user.get("display_name");
    var searchTerms = [];
    if (displayName.length > 2) {
      for (var i = 0; i < displayName.length - 2; i++) {
        searchTerms.push(displayName.substring(0, displayName.length - i));
      }
    }

    await user.ref.update({
      search_terms: searchTerms,
    });
  });

// const functions = require('firebase-functions');
// const admin = require('firebase-admin');

// exports.addSearchTermsForUsersRunNow =
//     functions.pubsub.schedule('every 1 minutes').onRun(async (context) => {

//     var usersRef = await admin.firestore().collection("users");

//     const snapshot = await usersRef.get();

//     if (snapshot.empty) {
//         console.log('No matching documents.');
//         return;
//     }

//     for (const userDoc of snapshot.docs) {
//       const displayName = userDoc.get("display_name");
//       const searchTerms = [];

//       if (displayName && displayName.length > 2) {
//         for (let i = 0; i < displayName.length - 2; i++) {
//           searchTerms.push(displayName.substring(0, displayName.length - i));
//           searchTerms.push(displayName.substring(0, displayName.length - i).toLowerCase());
//         }
//       }

//       await userDoc.ref.update({
//         search_terms: searchTerms,
//       });
//     }
// });

// const functions = require('firebase-functions');
// const admin = require('firebase-admin');
// // To avoid deployment errors, do not call admin.initializeApp() in your code
// exports.rebuildUserGroupSearch =
//     functions.pubsub
//     .schedule('every 1 minutes')
//     .onRun(async (context) => {
//       try {
//     // Step 1: Get all users
//     const usersSnapshot = await admin.firestore().collection("users").get();
//     if (usersSnapshot.empty) {
//       console.log("No users found.");
//     }

//     // Step 2: Get all groups
//     const groupsSnapshot = await admin.firestore().collection("groups").get();
//     if (groupsSnapshot.empty) {
//       console.log("No groups found.");
//     }

//     // Step 3: Clear existing user_group_search
//     const oldEntries = await admin.firestore().collection("user_group_search").get();
//     const deletePromises = oldEntries.docs.map((doc) => doc.ref.delete());
//     await Promise.all(deletePromises);
//     console.log(`Deleted ${deletePromises.length} existing entries.`);

//     // Step 4: Rebuild new entries
//     const createPromises = [];

//     for (const userDoc of usersSnapshot.docs) {
//       const userData = userDoc.data();
//       const userRef = userDoc.ref;
//       const userDisplayName = userData.display_name || "";

//         // Create one entry with user display name
//         createPromises.push(
//           admin.firestore().collection("user_group_search").add({
//             user: userRef,
//             search_term: userDisplayName,
//           })
//         );
//         }

//       for (const groupDoc of groupsSnapshot.docs) {
//         const groupData = groupDoc.data();
//         const groupRef = groupDoc.ref;
//         const groupName = groupData.name || "";
//         const groupDescription = groupData.description || "";

//         // Create one entry with group name
//         createPromises.push(
//           admin.firestore().collection("user_group_search").add({
//             group: groupRef,
//             search_term: groupName,
//             additional_search_terms: [groupDescription],
//           })
//         );
//       }

//     await Promise.all(createPromises);
//     console.log(`Created ${createPromises.length} new user_group_search entries.`);

//     console.log(`Rebuilt user_group_search with ${createPromises.length} entries.`);
//   } catch (err) {
//     console.error("Error rebuilding user_group_search:", err);
//   }
// });

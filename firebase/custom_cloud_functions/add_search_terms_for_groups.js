const functions = require("firebase-functions");
const admin = require("firebase-admin");
exports.addSearchTermsForGroups = functions.firestore
  .document("groups/{groups_id}")
  .onCreate(async (user) => {
    const displayName = groupDoc.get("name");
    const searchTerms = [];

    if (displayName && displayName.length > 2) {
      for (let i = 0; i < displayName.length - 2; i++) {
        searchTerms.push(displayName.substring(0, displayName.length - i));
        searchTerms.push(
          displayName.substring(0, displayName.length - i).toLowerCase(),
        );
      }
    }

    await groupDoc.ref.update({
      search_terms: searchTerms,
    });
  });

// const functions = require('firebase-functions');
// const admin = require('firebase-admin');

// exports.groupSearchTerms =
//     functions.pubsub.schedule('every 1 minutes').onRun(async (context) => {

//     var groupsRef = await admin.firestore().collection("groups");

//     const snapshot = await groupsRef.get();

//     if (snapshot.empty) {
//         console.log('No matching documents.');
//         return;
//     }

//     for (const groupDoc of snapshot.docs) {
//       const displayName = groupDoc.get("name");
//       const searchTerms = [];

//       if (displayName && displayName.length > 2) {
//         for (let i = 0; i < displayName.length - 2; i++) {
//           searchTerms.push(displayName.substring(0, displayName.length - i));
//           searchTerms.push(displayName.substring(0, displayName.length - i).toLowerCase());
//         }
//       }

//       await groupDoc.ref.update({
//         search_terms: searchTerms,
//       });
//     }
// });

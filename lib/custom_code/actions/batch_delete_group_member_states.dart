// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/backend/schema/enums/enums.dart';
import '/actions/actions.dart' as action_blocks;
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:cloud_firestore/cloud_firestore.dart';

Future batchDeleteGroupMemberStates(
    List<DocumentReference> docsToDelete) async {
  // Add your function code here!
  try {
    // Create a batch instance
    WriteBatch batch = FirebaseFirestore.instance.batch();
    // Iterate over the list of document references
    for (DocumentReference docRef in docsToDelete) {
      // Add each delete operation to the batch
      batch.delete(docRef);
    }
    // Commit the batch
    await batch.commit();
    print('Batch delete operation completed successfully.');
  } catch (e) {
    print('Error occurred during batch delete operation: $e');
  }
}

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

Future deleteSearchMemberListAction(
    List<UserGroupSearchRecord>? searchMemberList) async {
  // Add your function code here!
  if (searchMemberList != null) {
    FirebaseFirestore db = await FirebaseFirestore.instance;

    WriteBatch writeBatch = db.batch();

    for (final doc in searchMemberList!) {
      writeBatch.delete(doc.reference);
    }

    writeBatch.commit();
  }
}

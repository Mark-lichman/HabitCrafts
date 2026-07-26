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

import 'package:flutter_contacts/flutter_contacts.dart';

Future<List<DocumentReference>> fetchContactsAction(
    List<DocumentReference> currentMembers) async {
  List<DocumentReference> result = [];

  // Request contact permission
  if (await FlutterContacts.requestPermission()) {
    // Get all contacts (lightly fetched)

    List<Contact> contacts = await FlutterContacts.getContacts(
        withProperties: true, withPhoto: true);
    for (Contact contact in contacts) {
      for (Email email in contact.emails) {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: email.address)
            .get();

        for (int index = 0; index < snapshot.docs.length; index++) {
          final doc = snapshot.docs[index];
          final DocumentReference docRef = doc.reference;
          // Only display users that are not already in the group
          if (!currentMembers.contains(docRef)) {
            result.add(docRef);
          }
        }
      }
    }
    return result;
  }
  return result;
}

// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/backend/schema/enums/enums.dart';
import '/actions/actions.dart' as action_blocks;
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:flutter_contacts/flutter_contacts.dart';

class PhoneContactsWidget extends StatefulWidget {
  const PhoneContactsWidget({
    super.key,
    this.width,
    this.height,
  });

  final double? width;
  final double? height;

  @override
  State<PhoneContactsWidget> createState() => _PhoneContactsWidgetState();
}

class _PhoneContactsWidgetState extends State<PhoneContactsWidget> {
  @override
  void initState() {
    super.initState();
    // Fetch user data from API using BuildContext
    fetchUsersFromContactBook().then((users) {
      print(users);
    });
  }

  Future<List<UsersRecord>> fetchUsersFromContactBook() async {
    late List<Contact> _contacts;
    bool _permissionDenied = false;

    print('fetching users...');

    // Request contact permission
    if (await FlutterContacts.requestPermission()) {
      // Get all contacts (lightly fetched)

      print('got permission');
      final db = FirebaseFirestore.instance;
      List<Contact> contacts = await FlutterContacts.getContacts();
      for (Contact contact in contacts) {
        print(contact);
        for (Email email in contact.emails) {
          print(db
              .collection('users')
              .where('email', isEqualTo: email.address)
              .get());
        }
      }
    }

    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/components/group_components/new_group_created_modal/new_group_created_modal_widget.dart';
import '/flutter_flow/flutter_flow_autocomplete_options_list.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import 'dart:ui';
import '/actions/actions.dart' as action_blocks;
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/custom_functions.dart' as functions;
import 'create_group_component_widget.dart' show CreateGroupComponentWidget;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class CreateGroupComponentModel
    extends FlutterFlowModel<CreateGroupComponentWidget> {
  ///  Local state fields for this component.

  List<UsersRecord> teamLeaders = [];
  void addToTeamLeaders(UsersRecord item) => teamLeaders.add(item);
  void removeFromTeamLeaders(UsersRecord item) => teamLeaders.remove(item);
  void removeAtIndexFromTeamLeaders(int index) => teamLeaders.removeAt(index);
  void insertAtIndexInTeamLeaders(int index, UsersRecord item) =>
      teamLeaders.insert(index, item);
  void updateTeamLeadersAtIndex(int index, Function(UsersRecord) updateFn) =>
      teamLeaders[index] = updateFn(teamLeaders[index]);

  int loopIndex = 0;

  ///  State fields for stateful widgets in this component.

  final formKey = GlobalKey<FormState>();
  // State field(s) for nameField widget.
  FocusNode? nameFieldFocusNode;
  TextEditingController? nameFieldTextController;
  String? Function(BuildContext, String?)? nameFieldTextControllerValidator;
  String? _nameFieldTextControllerValidator(BuildContext context, String? val) {
    if (val == null || val.isEmpty) {
      return 'Field is required';
    }

    return null;
  }

  // State field(s) for descriptionField widget.
  FocusNode? descriptionFieldFocusNode;
  TextEditingController? descriptionFieldTextController;
  String? Function(BuildContext, String?)?
      descriptionFieldTextControllerValidator;
  // State field(s) for categoryField widget.
  FocusNode? categoryFieldFocusNode;
  TextEditingController? categoryFieldTextController;
  String? Function(BuildContext, String?)? categoryFieldTextControllerValidator;
  // State field(s) for DropDown widget.
  String? dropDownValue;
  FormFieldController<String>? dropDownValueController;
  DateTime? datePicked;
  // State field(s) for searchTextField widget.
  final searchTextFieldKey = GlobalKey();
  FocusNode? searchTextFieldFocusNode;
  TextEditingController? searchTextFieldTextController;
  String? searchTextFieldSelectedOption;
  String? Function(BuildContext, String?)?
      searchTextFieldTextControllerValidator;
  // Algolia Search Results from action on searchTextField
  List<UsersRecord>? algoliaSearchResults = [];
  // Stores action output result for [Firestore Query - Query a collection] action in IconButton widget.
  UsersRecord? selectedUser;
  // State field(s) for Switch widget.
  bool? switchValue;
  // Stores action output result for [Backend Call - Create Document] action in Button widget.
  GroupsRecord? newgroup;

  @override
  void initState(BuildContext context) {
    nameFieldTextControllerValidator = _nameFieldTextControllerValidator;
  }

  @override
  void dispose() {
    nameFieldFocusNode?.dispose();
    nameFieldTextController?.dispose();

    descriptionFieldFocusNode?.dispose();
    descriptionFieldTextController?.dispose();

    categoryFieldFocusNode?.dispose();
    categoryFieldTextController?.dispose();

    searchTextFieldFocusNode?.dispose();
  }

  /// Action blocks.
  Future extraCallsAfterGroupCreated(
    BuildContext context, {
    required GroupsRecord? newGroup,
  }) async {
    RemindersRecord? reminderCopy;

    if (datePicked != null) {
      logFirebaseEvent('extraCallsAfterGroupCreated_backend_call');

      var remindersRecordReference = RemindersRecord.collection.doc();
      await remindersRecordReference.set({
        ...createRemindersRecordData(
          time: datePicked,
          user: currentUserReference,
          hour: functions.localToHour(datePicked!),
          minute: functions.localToMinute(datePicked!),
          timezoneOffset: functions.localToUTCOffset(datePicked!),
          group: newgroup?.reference,
        ),
        ...mapToFirestore(
          {
            'days': [dropDownValue],
          },
        ),
      });
      reminderCopy = RemindersRecord.getDocumentFromData({
        ...createRemindersRecordData(
          time: datePicked,
          user: currentUserReference,
          hour: functions.localToHour(datePicked!),
          minute: functions.localToMinute(datePicked!),
          timezoneOffset: functions.localToUTCOffset(datePicked!),
          group: newgroup?.reference,
        ),
        ...mapToFirestore(
          {
            'days': [dropDownValue],
          },
        ),
      }, remindersRecordReference);
      logFirebaseEvent('extraCallsAfterGroupCreated_backend_call');

      await newgroup!.reference.update(createGroupsRecordData(
        reminderOwner: reminderCopy?.reference,
      ));
    }
    logFirebaseEvent('extraCallsAfterGroupCreated_backend_call');

    await GroupMemberStateRecord.collection
        .doc()
        .set(createGroupMemberStateRecordData(
          member: currentUserReference,
          group: newgroup?.reference,
          status: GroupMembershipStatus.Creator,
          lastActive: getCurrentTimestamp,
          checkinDay: dateTimeFormat("EEEE", newgroup?.checkinTime),
          recentCheckin: '1/1/1970',
        ));
    logFirebaseEvent('extraCallsAfterGroupCreated_action_block');
    await action_blocks.createChat(
      context,
      group: newgroup?.reference,
    );
    while (loopIndex < teamLeaders.length) {
      logFirebaseEvent('extraCallsAfterGroupCreated_backend_call');

      await GroupMemberStateRecord.collection
          .doc()
          .set(createGroupMemberStateRecordData(
            member: teamLeaders.elementAtOrNull(loopIndex)?.reference,
            group: newgroup?.reference,
            status: GroupMembershipStatus.Leader,
          ));
      logFirebaseEvent('extraCallsAfterGroupCreated_update_compo');
      loopIndex = loopIndex + 1;
    }
    logFirebaseEvent('extraCallsAfterGroupCreated_backend_call');

    await UserGroupSearchRecord.collection.doc().set({
      ...createUserGroupSearchRecordData(
        searchTerm: newgroup?.name,
        group: newgroup?.reference,
      ),
      ...mapToFirestore(
        {
          'additional_search_terms': [descriptionFieldTextController.text],
        },
      ),
    });
  }
}

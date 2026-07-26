import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/flutter_flow/custom_functions.dart' as functions;
import '/flutter_flow/random_data_util.dart' as random_data;
import '/index.dart';
import 'checkin_component_widget.dart' show CheckinComponentWidget;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class CheckinComponentModel extends FlutterFlowModel<CheckinComponentWidget> {
  ///  Local state fields for this component.

  String? activityTitle;

  ///  State fields for stateful widgets in this component.

  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode1;
  TextEditingController? textController1;
  String? Function(BuildContext, String?)? textController1Validator;
  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode2;
  TextEditingController? textController2;
  String? Function(BuildContext, String?)? textController2Validator;
  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode3;
  TextEditingController? textController3;
  String? Function(BuildContext, String?)? textController3Validator;
  // State field(s) for Switch widget.
  bool? switchValue1;
  // State field(s) for Switch widget.
  bool? switchValue2;
  // Stores action output result for [Backend Call - Create Document] action in Button widget.
  CheckinsRecord? newCheckin;
  // Stores action output result for [Firestore Query - Query a collection] action in Button widget.
  GroupMemberStateRecord? groupMemberState;
  // Stores action output result for [Backend Call - Create Document] action in Button widget.
  ChatMessagesRecord? newChatMessage;
  // Stores action output result for [Backend Call - Read Document] action in Button widget.
  ChatsRecord? chat;
  // Stores action output result for [Firestore Query - Query a collection] action in Button widget.
  List<GroupMemberStateRecord>? memberList;
  // Stores action output result for [Backend Call - Create Document] action in Button widget.
  ChatsRecord? newChatThread;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    textFieldFocusNode1?.dispose();
    textController1?.dispose();

    textFieldFocusNode2?.dispose();
    textController2?.dispose();

    textFieldFocusNode3?.dispose();
    textController3?.dispose();
  }
}

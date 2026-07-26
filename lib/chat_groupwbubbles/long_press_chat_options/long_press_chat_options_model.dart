import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/chat_groupwbubbles/flag_message_component/flag_message_component_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'long_press_chat_options_widget.dart' show LongPressChatOptionsWidget;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class LongPressChatOptionsModel
    extends FlutterFlowModel<LongPressChatOptionsWidget> {
  ///  State fields for stateful widgets in this component.

  // Stores action output result for [Backend Call - Read Document] action in LongPressChatOptions widget.
  ChatMessagesRecord? chatMessage;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}

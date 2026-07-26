import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/index.dart';
import 'chat_list_item_widget.dart' show ChatListItemWidget;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class ChatListItemModel extends FlutterFlowModel<ChatListItemWidget> {
  ///  Local state fields for this component.

  DocumentReference? otherUserRef;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}

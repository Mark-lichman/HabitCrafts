import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/components/profile_components/profile_preview_component/profile_preview_component_widget.dart';
import '/components/user_icon_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'chat_members_view_component_widget.dart'
    show ChatMembersViewComponentWidget;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class ChatMembersViewComponentModel
    extends FlutterFlowModel<ChatMembersViewComponentWidget> {
  ///  Local state fields for this component.

  List<GroupMembershipStatus> creatorLeaderMember = [
    GroupMembershipStatus.Leader,
    GroupMembershipStatus.Member,
    GroupMembershipStatus.Creator
  ];
  void addToCreatorLeaderMember(GroupMembershipStatus item) =>
      creatorLeaderMember.add(item);
  void removeFromCreatorLeaderMember(GroupMembershipStatus item) =>
      creatorLeaderMember.remove(item);
  void removeAtIndexFromCreatorLeaderMember(int index) =>
      creatorLeaderMember.removeAt(index);
  void insertAtIndexInCreatorLeaderMember(
          int index, GroupMembershipStatus item) =>
      creatorLeaderMember.insert(index, item);
  void updateCreatorLeaderMemberAtIndex(
          int index, Function(GroupMembershipStatus) updateFn) =>
      creatorLeaderMember[index] = updateFn(creatorLeaderMember[index]);

  ///  State fields for stateful widgets in this component.

  // Stores action output result for [Firestore Query - Query a collection] action in Button widget.
  ChatsRecord? chat;
  // Stores action output result for [Firestore Query - Query a collection] action in Button widget.
  GroupMemberStateRecord? groupMemberState;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}

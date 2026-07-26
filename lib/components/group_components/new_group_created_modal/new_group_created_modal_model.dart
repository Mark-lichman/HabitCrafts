import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/components/group_components/friends_view_component/friends_view_component_widget.dart';
import '/flutter_flow/flutter_flow_autocomplete_options_list.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/actions/actions.dart' as action_blocks;
import '/custom_code/actions/index.dart' as actions;
import 'new_group_created_modal_widget.dart' show NewGroupCreatedModalWidget;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class NewGroupCreatedModalModel
    extends FlutterFlowModel<NewGroupCreatedModalWidget> {
  ///  Local state fields for this component.

  List<GroupMembershipStatus> leaderOrCreator = [];
  void addToLeaderOrCreator(GroupMembershipStatus item) =>
      leaderOrCreator.add(item);
  void removeFromLeaderOrCreator(GroupMembershipStatus item) =>
      leaderOrCreator.remove(item);
  void removeAtIndexFromLeaderOrCreator(int index) =>
      leaderOrCreator.removeAt(index);
  void insertAtIndexInLeaderOrCreator(int index, GroupMembershipStatus item) =>
      leaderOrCreator.insert(index, item);
  void updateLeaderOrCreatorAtIndex(
          int index, Function(GroupMembershipStatus) updateFn) =>
      leaderOrCreator[index] = updateFn(leaderOrCreator[index]);

  ///  State fields for stateful widgets in this component.

  // Model for friendsViewComponent component.
  late FriendsViewComponentModel friendsViewComponentModel;
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
  // Stores action output result for [Action Block - inviteFriendToGroup] action in IconButton widget.
  bool? didInvite;

  @override
  void initState(BuildContext context) {
    friendsViewComponentModel =
        createModel(context, () => FriendsViewComponentModel());
  }

  @override
  void dispose() {
    friendsViewComponentModel.dispose();
    searchTextFieldFocusNode?.dispose();
  }
}

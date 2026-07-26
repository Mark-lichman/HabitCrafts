import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/components/bottom_nav_bar_component_widget.dart';
import '/components/group_components/empty_groups_component/empty_groups_component_widget.dart';
import '/components/group_components/group_checkin_list_component/group_checkin_list_component_widget.dart';
import '/components/group_components/group_create_modal/group_create_modal_widget.dart';
import '/components/group_components/group_invite_list_item/group_invite_list_item_widget.dart';
import '/components/group_components/group_list_contents/group_list_contents_widget.dart';
import '/components/group_components/group_management_component/group_management_component_widget.dart';
import '/components/group_components/in_app_notification_component/in_app_notification_component_widget.dart';
import '/components/group_components/search_list_item/search_list_item_widget.dart';
import '/components/monthly_challenge_list_item_widget.dart';
import '/components/no_webinars_component_widget.dart';
import '/components/webinar_list_item_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:async';
import 'dart:ui';
import '/flutter_flow/custom_functions.dart' as functions;
import '/index.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'groups_page_model.dart';
export 'groups_page_model.dart';

class GroupsPageWidget extends StatefulWidget {
  const GroupsPageWidget({
    super.key,
    this.groupFromPush,
  });

  final DocumentReference? groupFromPush;

  static String routeName = 'groupsPage';
  static String routePath = '/groupsPage';

  @override
  State<GroupsPageWidget> createState() => _GroupsPageWidgetState();
}

class _GroupsPageWidgetState extends State<GroupsPageWidget>
    with TickerProviderStateMixin {
  late GroupsPageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  late StreamSubscription<bool> _keyboardVisibilitySubscription;
  bool _isKeyboardVisible = false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => GroupsPageModel());

    logFirebaseEvent('screen_view', parameters: {'screen_name': 'groupsPage'});
    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      logFirebaseEvent('GROUPS_groupsPage_ON_INIT_STATE');
      if (widget!.groupFromPush != null) {
        logFirebaseEvent('groupsPage_tab_bar');
        safeSetState(() {
          _model.tabBarController!.animateTo(
            1,
            duration: Duration(milliseconds: 300),
            curve: Curves.ease,
          );
        });
      }
      logFirebaseEvent('groupsPage_action_block');
      await _model.fetchTodaysCheckins(context);
    });

    if (!isWeb) {
      _keyboardVisibilitySubscription =
          KeyboardVisibilityController().onChange.listen((bool visible) {
        safeSetState(() {
          _isKeyboardVisible = visible;
        });
      });
    }

    _model.tabBarController = TabController(
      vsync: this,
      length: 3,
      initialIndex: 0,
    )..addListener(() => safeSetState(() {}));

    _model.textController ??= TextEditingController();
    _model.textFieldFocusNode ??= FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();

    if (!isWeb) {
      _keyboardVisibilitySubscription.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        body: Align(
          alignment: AlignmentDirectional(0.0, -1.0),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: FFAppConstants.maxWidthForWeb.toDouble(),
            ),
            decoration: BoxDecoration(),
            child: Stack(
              children: [
                Align(
                  alignment: AlignmentDirectional(0.0, 0.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Align(
                        alignment: AlignmentDirectional(1.0, -1.0),
                        child: Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              0.0, 40.0, 10.0, 0.0),
                          child: FFButtonWidget(
                            onPressed: () async {
                              logFirebaseEvent('GROUPS_PAGE_PAGE__BTN_ON_TAP');
                              logFirebaseEvent('Button_navigate_to');

                              context.pushNamed(ProfilePageWidget.routeName);
                            },
                            text: '',
                            icon: Icon(
                              Icons.person_2,
                              size: 15.0,
                            ),
                            options: FFButtonOptions(
                              width: 40.0,
                              height: 40.0,
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  8.0, 0.0, 0.0, 0.0),
                              iconPadding: EdgeInsetsDirectional.fromSTEB(
                                  0.0, 0.0, 0.0, 0.0),
                              iconColor: FlutterFlowTheme.of(context).grayDark,
                              color: FlutterFlowTheme.of(context)
                                  .secondaryBackground,
                              textStyle: FlutterFlowTheme.of(context)
                                  .titleSmall
                                  .override(
                                    font: GoogleFonts.poppins(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .titleSmall
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleSmall
                                          .fontStyle,
                                    ),
                                    color: Colors.white,
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontStyle,
                                  ),
                              elevation: 3.0,
                              borderSide: BorderSide(
                                color: Colors.transparent,
                                width: 1.0,
                              ),
                              borderRadius: BorderRadius.circular(20.0),
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: AlignmentDirectional(0.0, 0.0),
                        child: Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              0.0, 30.0, 0.0, 0.0),
                          child: Text(
                            'Community',
                            style: FlutterFlowTheme.of(context)
                                .titleMedium
                                .override(
                                  font: GoogleFonts.poppins(
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .titleMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleMedium
                                        .fontStyle,
                                  ),
                                  letterSpacing: 0.0,
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .titleMedium
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .titleMedium
                                      .fontStyle,
                                ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Align(
                              alignment: Alignment(0.0, 0),
                              child: TabBar(
                                labelColor:
                                    FlutterFlowTheme.of(context).alternate,
                                unselectedLabelColor:
                                    FlutterFlowTheme.of(context).secondaryText,
                                labelStyle: FlutterFlowTheme.of(context)
                                    .titleMedium
                                    .override(
                                      font: GoogleFonts.poppins(
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .titleMedium
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .titleMedium
                                            .fontStyle,
                                      ),
                                      letterSpacing: 0.0,
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .titleMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleMedium
                                          .fontStyle,
                                    ),
                                unselectedLabelStyle: TextStyle(),
                                indicatorColor:
                                    FlutterFlowTheme.of(context).accent1,
                                padding: EdgeInsets.all(4.0),
                                tabs: [
                                  Tab(
                                    text: 'Chats',
                                  ),
                                  Tab(
                                    text: 'Group',
                                  ),
                                  Tab(
                                    text: 'Events',
                                  ),
                                ],
                                controller: _model.tabBarController,
                                onTap: (i) async {
                                  [() async {}, () async {}, () async {}][i]();
                                },
                              ),
                            ),
                            Expanded(
                              child: TabBarView(
                                controller: _model.tabBarController,
                                children: [
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        20.0, 10.0, 20.0, 0.0),
                                    child: SingleChildScrollView(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.max,
                                        children: [
                                          Padding(
                                            padding:
                                                EdgeInsetsDirectional.fromSTEB(
                                                    0.0, 10.0, 0.0, 0.0),
                                            child: TextFormField(
                                              controller: _model.textController,
                                              focusNode:
                                                  _model.textFieldFocusNode,
                                              onChanged: (_) =>
                                                  EasyDebounce.debounce(
                                                '_model.textController',
                                                Duration(milliseconds: 300),
                                                () async {
                                                  logFirebaseEvent(
                                                      'GROUPS_TextField_ceovz5lx_ON_TEXTFIELD_C');
                                                  logFirebaseEvent(
                                                      'TextField_algolia_search');
                                                  safeSetState(() => _model
                                                          .algoliaSearchResults =
                                                      null);
                                                  await UserGroupSearchRecord
                                                          .search(
                                                    term: _model
                                                        .textController.text,
                                                  )
                                                      .then((r) => _model
                                                              .algoliaSearchResults =
                                                          r)
                                                      .onError((_, __) => _model
                                                              .algoliaSearchResults =
                                                          [])
                                                      .whenComplete(() =>
                                                          safeSetState(() {}));

                                                  logFirebaseEvent(
                                                      'TextField_update_page_state');
                                                  _model.isShowFullList = _model
                                                              .textController
                                                              .text ==
                                                          null ||
                                                      _model.textController
                                                              .text ==
                                                          '';
                                                },
                                              ),
                                              autofocus: false,
                                              obscureText: false,
                                              decoration: InputDecoration(
                                                isDense: true,
                                                alignLabelWithHint: true,
                                                hintText:
                                                    'Search for a group or member',
                                                hintStyle: FlutterFlowTheme.of(
                                                        context)
                                                    .labelMedium
                                                    .override(
                                                      font: GoogleFonts.poppins(
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .fontStyle,
                                                      ),
                                                      color: Color(0xABE6EEF8),
                                                      fontSize: 14.0,
                                                      letterSpacing: 0.0,
                                                      fontWeight:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .labelMedium
                                                              .fontWeight,
                                                      fontStyle:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .labelMedium
                                                              .fontStyle,
                                                    ),
                                                enabledBorder:
                                                    OutlineInputBorder(
                                                  borderSide: BorderSide(
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .alternate,
                                                    width: 2.0,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12.0),
                                                ),
                                                focusedBorder:
                                                    OutlineInputBorder(
                                                  borderSide: BorderSide(
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .tertiary,
                                                    width: 2.0,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12.0),
                                                ),
                                                errorBorder: OutlineInputBorder(
                                                  borderSide: BorderSide(
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .error,
                                                    width: 2.0,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12.0),
                                                ),
                                                focusedErrorBorder:
                                                    OutlineInputBorder(
                                                  borderSide: BorderSide(
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .error,
                                                    width: 2.0,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12.0),
                                                ),
                                                prefixIcon: Icon(
                                                  Icons.search_sharp,
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .tertiary,
                                                  size: 20.0,
                                                ),
                                                suffixIcon: _model
                                                        .textController!
                                                        .text
                                                        .isNotEmpty
                                                    ? InkWell(
                                                        onTap: () async {
                                                          _model.textController
                                                              ?.clear();
                                                          logFirebaseEvent(
                                                              'GROUPS_TextField_ceovz5lx_ON_TEXTFIELD_C');
                                                          logFirebaseEvent(
                                                              'TextField_algolia_search');
                                                          safeSetState(() =>
                                                              _model.algoliaSearchResults =
                                                                  null);
                                                          await UserGroupSearchRecord
                                                                  .search(
                                                            term: _model
                                                                .textController
                                                                .text,
                                                          )
                                                              .then((r) => _model
                                                                      .algoliaSearchResults =
                                                                  r)
                                                              .onError((_,
                                                                      __) =>
                                                                  _model.algoliaSearchResults =
                                                                      [])
                                                              .whenComplete(() =>
                                                                  safeSetState(
                                                                      () {}));

                                                          logFirebaseEvent(
                                                              'TextField_update_page_state');
                                                          _model
                                                              .isShowFullList = _model
                                                                      .textController
                                                                      .text ==
                                                                  null ||
                                                              _model.textController
                                                                      .text ==
                                                                  '';
                                                          safeSetState(() {});
                                                        },
                                                        child: Icon(
                                                          Icons.clear,
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .tertiary,
                                                          size: 24.0,
                                                        ),
                                                      )
                                                    : null,
                                              ),
                                              style: FlutterFlowTheme.of(
                                                      context)
                                                  .bodyMedium
                                                  .override(
                                                    font: GoogleFonts.poppins(
                                                      fontWeight:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .bodyMedium
                                                              .fontWeight,
                                                      fontStyle:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .bodyMedium
                                                              .fontStyle,
                                                    ),
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .alternate,
                                                    letterSpacing: 0.0,
                                                    fontWeight:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .bodyMedium
                                                            .fontWeight,
                                                    fontStyle:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .bodyMedium
                                                            .fontStyle,
                                                  ),
                                              cursorColor:
                                                  FlutterFlowTheme.of(context)
                                                      .tertiary,
                                              validator: _model
                                                  .textControllerValidator
                                                  .asValidator(context),
                                            ),
                                          ),
                                          Builder(
                                            builder: (context) {
                                              if (_model.isShowFullList) {
                                                return StreamBuilder<
                                                    List<
                                                        GroupMemberStateRecord>>(
                                                  stream:
                                                      queryGroupMemberStateRecord(
                                                    queryBuilder:
                                                        (groupMemberStateRecord) =>
                                                            groupMemberStateRecord
                                                                .where(
                                                      'member',
                                                      isEqualTo:
                                                          currentUserReference,
                                                    ),
                                                  ),
                                                  builder: (context, snapshot) {
                                                    // Customize what your widget looks like when it's loading.
                                                    if (!snapshot.hasData) {
                                                      return Center(
                                                        child: SizedBox(
                                                          width: 40.0,
                                                          height: 40.0,
                                                          child:
                                                              CircularProgressIndicator(
                                                            valueColor:
                                                                AlwaysStoppedAnimation<
                                                                    Color>(
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .primary,
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                    List<GroupMemberStateRecord>
                                                        containerGroupMemberStateRecordList =
                                                        snapshot.data!;

                                                    return Container(
                                                      decoration:
                                                          BoxDecoration(),
                                                      child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.max,
                                                        children: [
                                                          StreamBuilder<
                                                              List<
                                                                  GroupMemberStateRecord>>(
                                                            stream:
                                                                queryGroupMemberStateRecord(
                                                              queryBuilder:
                                                                  (groupMemberStateRecord) =>
                                                                      groupMemberStateRecord
                                                                          .where(
                                                                            'member',
                                                                            isEqualTo:
                                                                                currentUserReference,
                                                                          )
                                                                          .where(
                                                                            'status',
                                                                            isEqualTo:
                                                                                GroupMembershipStatus.Invited.serialize(),
                                                                          ),
                                                            ),
                                                            builder: (context,
                                                                snapshot) {
                                                              // Customize what your widget looks like when it's loading.
                                                              if (!snapshot
                                                                  .hasData) {
                                                                return Center(
                                                                  child:
                                                                      SizedBox(
                                                                    width: 40.0,
                                                                    height:
                                                                        40.0,
                                                                    child:
                                                                        CircularProgressIndicator(
                                                                      valueColor:
                                                                          AlwaysStoppedAnimation<
                                                                              Color>(
                                                                        FlutterFlowTheme.of(context)
                                                                            .primary,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                );
                                                              }
                                                              List<GroupMemberStateRecord>
                                                                  containerGroupMemberStateRecordList =
                                                                  snapshot
                                                                      .data!;

                                                              return Container(
                                                                decoration:
                                                                    BoxDecoration(),
                                                                child:
                                                                    Visibility(
                                                                  visible:
                                                                      containerGroupMemberStateRecordList
                                                                              .length >
                                                                          0,
                                                                  child:
                                                                      Padding(
                                                                    padding: EdgeInsetsDirectional
                                                                        .fromSTEB(
                                                                            0.0,
                                                                            10.0,
                                                                            0.0,
                                                                            0.0),
                                                                    child:
                                                                        Container(
                                                                      width: double
                                                                          .infinity,
                                                                      decoration:
                                                                          BoxDecoration(
                                                                        color: Color(
                                                                            0x00FFFFFF),
                                                                      ),
                                                                      child:
                                                                          Column(
                                                                        mainAxisSize:
                                                                            MainAxisSize.max,
                                                                        children: [
                                                                          if (containerGroupMemberStateRecordList.length >
                                                                              0)
                                                                            Align(
                                                                              alignment: AlignmentDirectional(-1.0, 0.0),
                                                                              child: Text(
                                                                                'Invitations',
                                                                                textAlign: TextAlign.start,
                                                                                style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                      font: GoogleFonts.poppins(
                                                                                        fontWeight: FontWeight.w600,
                                                                                        fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                      ),
                                                                                      color: FlutterFlowTheme.of(context).alternate,
                                                                                      fontSize: 13.0,
                                                                                      letterSpacing: 0.0,
                                                                                      fontWeight: FontWeight.w600,
                                                                                      fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                    ),
                                                                              ),
                                                                            ),
                                                                          Padding(
                                                                            padding: EdgeInsetsDirectional.fromSTEB(
                                                                                0.0,
                                                                                4.0,
                                                                                0.0,
                                                                                0.0),
                                                                            child:
                                                                                Builder(
                                                                              builder: (context) {
                                                                                final groupMemberStateList = containerGroupMemberStateRecordList.toList();

                                                                                return Column(
                                                                                  mainAxisSize: MainAxisSize.max,
                                                                                  children: List.generate(groupMemberStateList.length, (groupMemberStateListIndex) {
                                                                                    final groupMemberStateListItem = groupMemberStateList[groupMemberStateListIndex];
                                                                                    return GroupInviteListItemWidget(
                                                                                      key: Key('Keyrvc_${groupMemberStateListIndex}_of_${groupMemberStateList.length}'),
                                                                                      groupMemberStateRef: groupMemberStateListItem.reference,
                                                                                    );
                                                                                  }).divide(SizedBox(height: 5.0)).addToEnd(SizedBox(height: 10.0)),
                                                                                );
                                                                              },
                                                                            ),
                                                                          ),
                                                                          if (containerGroupMemberStateRecordList.length >
                                                                              0)
                                                                            Container(
                                                                              width: double.infinity,
                                                                              height: 1.0,
                                                                              decoration: BoxDecoration(
                                                                                color: FlutterFlowTheme.of(context).accent1,
                                                                              ),
                                                                            ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                          Container(
                                                            decoration:
                                                                BoxDecoration(),
                                                            child:
                                                                wrapWithModel(
                                                              model: _model
                                                                  .groupCheckinListComponentModel,
                                                              updateCallback: () =>
                                                                  safeSetState(
                                                                      () {}),
                                                              child:
                                                                  GroupCheckinListComponentWidget(),
                                                            ),
                                                          ),
                                                          StreamBuilder<
                                                              List<
                                                                  ChatsRecord>>(
                                                            stream:
                                                                queryChatsRecord(
                                                              queryBuilder: (chatsRecord) =>
                                                                  chatsRecord
                                                                      .where(
                                                                        'users',
                                                                        arrayContains:
                                                                            currentUserReference,
                                                                      )
                                                                      .where(
                                                                        'last_message_time',
                                                                        isGreaterThan:
                                                                            functions.twoMonthsAgo(getCurrentTimestamp),
                                                                      )
                                                                      .orderBy(
                                                                          'last_message_time',
                                                                          descending:
                                                                              true),
                                                            ),
                                                            builder: (context,
                                                                snapshot) {
                                                              // Customize what your widget looks like when it's loading.
                                                              if (!snapshot
                                                                  .hasData) {
                                                                return Center(
                                                                  child:
                                                                      SizedBox(
                                                                    width: 40.0,
                                                                    height:
                                                                        40.0,
                                                                    child:
                                                                        CircularProgressIndicator(
                                                                      valueColor:
                                                                          AlwaysStoppedAnimation<
                                                                              Color>(
                                                                        FlutterFlowTheme.of(context)
                                                                            .primary,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                );
                                                              }
                                                              List<ChatsRecord>
                                                                  columnChatsRecordList =
                                                                  snapshot
                                                                      .data!;
                                                              if (columnChatsRecordList
                                                                  .isEmpty) {
                                                                return EmptyGroupsComponentWidget();
                                                              }

                                                              return Column(
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .max,
                                                                children: List.generate(
                                                                        columnChatsRecordList
                                                                            .length,
                                                                        (columnIndex) {
                                                                  final columnChatsRecord =
                                                                      columnChatsRecordList[
                                                                          columnIndex];
                                                                  return Builder(
                                                                    builder:
                                                                        (context) {
                                                                      if (columnChatsRecord
                                                                          .hasGroup()) {
                                                                        return StreamBuilder<
                                                                            List<GroupsRecord>>(
                                                                          stream:
                                                                              queryGroupsRecord(
                                                                            queryBuilder: (groupsRecord) =>
                                                                                groupsRecord.where(
                                                                              'chat',
                                                                              isEqualTo: columnChatsRecord.reference,
                                                                            ),
                                                                            singleRecord:
                                                                                true,
                                                                          ),
                                                                          builder:
                                                                              (context, snapshot) {
                                                                            // Customize what your widget looks like when it's loading.
                                                                            if (!snapshot.hasData) {
                                                                              return Center(
                                                                                child: SizedBox(
                                                                                  width: 40.0,
                                                                                  height: 40.0,
                                                                                  child: CircularProgressIndicator(
                                                                                    valueColor: AlwaysStoppedAnimation<Color>(
                                                                                      FlutterFlowTheme.of(context).primary,
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                              );
                                                                            }
                                                                            List<GroupsRecord>
                                                                                groupListContentsGroupsRecordList =
                                                                                snapshot.data!;
                                                                            // Return an empty Container when the item does not exist.
                                                                            if (snapshot.data!.isEmpty) {
                                                                              return Container();
                                                                            }
                                                                            final groupListContentsGroupsRecord = groupListContentsGroupsRecordList.isNotEmpty
                                                                                ? groupListContentsGroupsRecordList.first
                                                                                : null;

                                                                            return GroupListContentsWidget(
                                                                              key: Key('Keyrnl_${columnIndex}_of_${columnChatsRecordList.length}'),
                                                                              group: groupListContentsGroupsRecord!,
                                                                            );
                                                                          },
                                                                        );
                                                                      } else {
                                                                        return Padding(
                                                                          padding: EdgeInsetsDirectional.fromSTEB(
                                                                              0.0,
                                                                              0.0,
                                                                              0.0,
                                                                              5.0),
                                                                          child:
                                                                              InkWell(
                                                                            splashColor:
                                                                                Colors.transparent,
                                                                            focusColor:
                                                                                Colors.transparent,
                                                                            hoverColor:
                                                                                Colors.transparent,
                                                                            highlightColor:
                                                                                Colors.transparent,
                                                                            onTap:
                                                                                () async {
                                                                              logFirebaseEvent('GROUPS_Container_6npy9ipa_ON_TAP');
                                                                              logFirebaseEvent('Container_navigate_to');

                                                                              context.pushNamed(
                                                                                Chat2DetailsWidget.routeName,
                                                                                queryParameters: {
                                                                                  'chatRef': serializeParam(
                                                                                    columnChatsRecord,
                                                                                    ParamType.Document,
                                                                                  ),
                                                                                }.withoutNulls,
                                                                                extra: <String, dynamic>{
                                                                                  'chatRef': columnChatsRecord,
                                                                                },
                                                                              );
                                                                            },
                                                                            onLongPress:
                                                                                () async {
                                                                              logFirebaseEvent('GROUPS_Container_6npy9ipa_ON_LONG_PRESS');
                                                                              logFirebaseEvent('Container_alert_dialog');
                                                                              var confirmDialogResponse = await showDialog<bool>(
                                                                                    context: context,
                                                                                    builder: (alertDialogContext) {
                                                                                      return AlertDialog(
                                                                                        title: Text('Delete Chat?'),
                                                                                        content: Text('Are you sure you would like to permanently delete this chat?'),
                                                                                        actions: [
                                                                                          TextButton(
                                                                                            onPressed: () => Navigator.pop(alertDialogContext, false),
                                                                                            child: Text('Cancel'),
                                                                                          ),
                                                                                          TextButton(
                                                                                            onPressed: () => Navigator.pop(alertDialogContext, true),
                                                                                            child: Text('Yes'),
                                                                                          ),
                                                                                        ],
                                                                                      );
                                                                                    },
                                                                                  ) ??
                                                                                  false;
                                                                              if (confirmDialogResponse) {
                                                                                logFirebaseEvent('Container_backend_call');
                                                                                await columnChatsRecord.reference.delete();
                                                                              }
                                                                            },
                                                                            child:
                                                                                Container(
                                                                              width: double.infinity,
                                                                              height: 50.0,
                                                                              decoration: BoxDecoration(
                                                                                color: FlutterFlowTheme.of(context).tertiary,
                                                                                borderRadius: BorderRadius.circular(valueOrDefault<double>(
                                                                                  FFAppConstants.borderRadius,
                                                                                  0.0,
                                                                                )),
                                                                              ),
                                                                              child: Padding(
                                                                                padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 10.0, 0.0),
                                                                                child: StreamBuilder<UsersRecord>(
                                                                                  stream: UsersRecord.getDocument(columnChatsRecord.users.where((e) => e != currentUserReference).toList().firstOrNull!),
                                                                                  builder: (context, snapshot) {
                                                                                    // Customize what your widget looks like when it's loading.
                                                                                    if (!snapshot.hasData) {
                                                                                      return Center(
                                                                                        child: SizedBox(
                                                                                          width: 40.0,
                                                                                          height: 40.0,
                                                                                          child: CircularProgressIndicator(
                                                                                            valueColor: AlwaysStoppedAnimation<Color>(
                                                                                              FlutterFlowTheme.of(context).primary,
                                                                                            ),
                                                                                          ),
                                                                                        ),
                                                                                      );
                                                                                    }

                                                                                    final rowUsersRecord = snapshot.data!;

                                                                                    return Row(
                                                                                      mainAxisSize: MainAxisSize.max,
                                                                                      children: [
                                                                                        Padding(
                                                                                          padding: EdgeInsetsDirectional.fromSTEB(6.0, 0.0, 6.0, 0.0),
                                                                                          child: Container(
                                                                                            width: 8.0,
                                                                                            height: 8.0,
                                                                                            decoration: BoxDecoration(
                                                                                              color: columnChatsRecord.lastMessageSeenBy.contains(currentUserReference) == true ? Color(0x00F0D05F) : FlutterFlowTheme.of(context).info,
                                                                                              borderRadius: BorderRadius.circular(4.0),
                                                                                            ),
                                                                                          ),
                                                                                        ),
                                                                                        ClipRRect(
                                                                                          borderRadius: BorderRadius.circular(15.0),
                                                                                          child: Image.network(
                                                                                            rowUsersRecord.photoUrl != null && rowUsersRecord.photoUrl != '' ? rowUsersRecord.photoUrl : 'https://firebasestorage.googleapis.com/v0/b/habitcraft-78a3f.appspot.com/o/images%2Fdefault_person.png?alt=media&token=ad79337b-b569-4948-8b58-5ec4d7f740fc',
                                                                                            width: 30.0,
                                                                                            height: 30.0,
                                                                                            fit: BoxFit.cover,
                                                                                          ),
                                                                                        ),
                                                                                        Expanded(
                                                                                          child: Padding(
                                                                                            padding: EdgeInsetsDirectional.fromSTEB(10.0, 0.0, 0.0, 0.0),
                                                                                            child: Column(
                                                                                              mainAxisSize: MainAxisSize.max,
                                                                                              mainAxisAlignment: MainAxisAlignment.center,
                                                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                                                              children: [
                                                                                                Text(
                                                                                                  rowUsersRecord.displayName,
                                                                                                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                        font: GoogleFonts.poppins(
                                                                                                          fontWeight: FontWeight.w500,
                                                                                                          fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                        ),
                                                                                                        color: FlutterFlowTheme.of(context).secondary,
                                                                                                        fontSize: 12.0,
                                                                                                        letterSpacing: 0.0,
                                                                                                        fontWeight: FontWeight.w500,
                                                                                                        fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                      ),
                                                                                                ),
                                                                                                Text(
                                                                                                  columnChatsRecord.lastMessage,
                                                                                                  maxLines: 1,
                                                                                                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                        font: GoogleFonts.poppins(
                                                                                                          fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                          fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                        ),
                                                                                                        fontSize: 10.0,
                                                                                                        letterSpacing: 0.0,
                                                                                                        fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                        fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                      ),
                                                                                                ),
                                                                                              ],
                                                                                            ),
                                                                                          ),
                                                                                        ),
                                                                                        Text(
                                                                                          dateTimeFormat("relative", columnChatsRecord.lastMessageTime!),
                                                                                          style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                font: GoogleFonts.poppins(
                                                                                                  fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                  fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                ),
                                                                                                fontSize: 10.0,
                                                                                                letterSpacing: 0.0,
                                                                                                fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                              ),
                                                                                        ),
                                                                                      ],
                                                                                    );
                                                                                  },
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          ),
                                                                        );
                                                                      }
                                                                    },
                                                                  );
                                                                })
                                                                    .addToStart(
                                                                        SizedBox(
                                                                            height:
                                                                                5.0))
                                                                    .addToEnd(SizedBox(
                                                                        height:
                                                                            100.0)),
                                                              );
                                                            },
                                                          ),
                                                        ].addToEnd(SizedBox(
                                                            height: 100.0)),
                                                      ),
                                                    );
                                                  },
                                                );
                                              } else {
                                                return Builder(
                                                  builder: (context) {
                                                    if (_model
                                                            .algoliaSearchResults ==
                                                        null) {
                                                      return Center(
                                                        child: SizedBox(
                                                          width: 40.0,
                                                          height: 40.0,
                                                          child:
                                                              CircularProgressIndicator(
                                                            valueColor:
                                                                AlwaysStoppedAnimation<
                                                                    Color>(
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .primary,
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                    final searchItems = _model
                                                            .algoliaSearchResults
                                                            ?.toList() ??
                                                        [];

                                                    return ListView.separated(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                              vertical: 5.0),
                                                      shrinkWrap: true,
                                                      scrollDirection:
                                                          Axis.vertical,
                                                      itemCount:
                                                          searchItems.length,
                                                      separatorBuilder: (_,
                                                              __) =>
                                                          SizedBox(height: 5.0),
                                                      itemBuilder: (context,
                                                          searchItemsIndex) {
                                                        final searchItemsItem =
                                                            searchItems[
                                                                searchItemsIndex];
                                                        return SearchListItemWidget(
                                                          key: Key(
                                                              'Keyvii_${searchItemsIndex}_of_${searchItems.length}'),
                                                          userGroupSearch:
                                                              searchItemsItem,
                                                        );
                                                      },
                                                    );
                                                  },
                                                );
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  wrapWithModel(
                                    model: _model.groupManagementComponentModel,
                                    updateCallback: () => safeSetState(() {}),
                                    child: GroupManagementComponentWidget(),
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        20.0, 20.0, 20.0, 0.0),
                                    child: SingleChildScrollView(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Column(
                                            mainAxisSize: MainAxisSize.max,
                                            children: [
                                              Align(
                                                alignment: AlignmentDirectional(
                                                    -1.0, 0.0),
                                                child: Text(
                                                  'Monthly Challenges',
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyMedium
                                                      .override(
                                                        font:
                                                            GoogleFonts.poppins(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .alternate,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontStyle,
                                                      ),
                                                ),
                                              ),
                                              StreamBuilder<
                                                  List<
                                                      MonthlyChallengesRecord>>(
                                                stream:
                                                    queryMonthlyChallengesRecord(
                                                  queryBuilder:
                                                      (monthlyChallengesRecord) =>
                                                          monthlyChallengesRecord
                                                              .where(
                                                    'start_time',
                                                    isLessThan:
                                                        getCurrentTimestamp,
                                                  ),
                                                ),
                                                builder: (context, snapshot) {
                                                  // Customize what your widget looks like when it's loading.
                                                  if (!snapshot.hasData) {
                                                    return Center(
                                                      child: SizedBox(
                                                        width: 40.0,
                                                        height: 40.0,
                                                        child:
                                                            CircularProgressIndicator(
                                                          valueColor:
                                                              AlwaysStoppedAnimation<
                                                                  Color>(
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .primary,
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                  List<MonthlyChallengesRecord>
                                                      containerMonthlyChallengesRecordList =
                                                      snapshot.data!;

                                                  return Container(
                                                    decoration: BoxDecoration(),
                                                    child: Builder(
                                                      builder: (context) {
                                                        final filteredMonthlyChallenges =
                                                            containerMonthlyChallengesRecordList
                                                                .where((e) =>
                                                                    e.expiresAt! >
                                                                    getCurrentTimestamp)
                                                                .toList();

                                                        return Column(
                                                          mainAxisSize:
                                                              MainAxisSize.max,
                                                          children: List.generate(
                                                              filteredMonthlyChallenges
                                                                  .length,
                                                              (filteredMonthlyChallengesIndex) {
                                                            final filteredMonthlyChallengesItem =
                                                                filteredMonthlyChallenges[
                                                                    filteredMonthlyChallengesIndex];
                                                            return MonthlyChallengeListItemWidget(
                                                              key: Key(
                                                                  'Keysdl_${filteredMonthlyChallengesIndex}_of_${filteredMonthlyChallenges.length}'),
                                                              monthlyChallenge:
                                                                  filteredMonthlyChallengesItem,
                                                            );
                                                          }),
                                                        );
                                                      },
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                          Padding(
                                            padding:
                                                EdgeInsetsDirectional.fromSTEB(
                                                    0.0, 10.0, 0.0, 0.0),
                                            child: StreamBuilder<
                                                List<WebinarsRecord>>(
                                              stream: queryWebinarsRecord(),
                                              builder: (context, snapshot) {
                                                // Customize what your widget looks like when it's loading.
                                                if (!snapshot.hasData) {
                                                  return Center(
                                                    child: SizedBox(
                                                      width: 40.0,
                                                      height: 40.0,
                                                      child:
                                                          CircularProgressIndicator(
                                                        valueColor:
                                                            AlwaysStoppedAnimation<
                                                                Color>(
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primary,
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                }
                                                List<WebinarsRecord>
                                                    textWebinarsRecordList =
                                                    snapshot.data!;

                                                return Text(
                                                  'Webinars',
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyMedium
                                                      .override(
                                                        font:
                                                            GoogleFonts.poppins(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .alternate,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontStyle,
                                                      ),
                                                );
                                              },
                                            ),
                                          ),
                                          StreamBuilder<List<WebinarsRecord>>(
                                            stream: queryWebinarsRecord(
                                              queryBuilder: (webinarsRecord) =>
                                                  webinarsRecord.where(
                                                'event_time',
                                                isLessThanOrEqualTo:
                                                    getCurrentTimestamp,
                                              ),
                                            ),
                                            builder: (context, snapshot) {
                                              // Customize what your widget looks like when it's loading.
                                              if (!snapshot.hasData) {
                                                return Center(
                                                  child: SizedBox(
                                                    width: 40.0,
                                                    height: 40.0,
                                                    child:
                                                        CircularProgressIndicator(
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                              Color>(
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .primary,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }
                                              List<WebinarsRecord>
                                                  containerWebinarsRecordList =
                                                  snapshot.data!;

                                              return Container(
                                                decoration: BoxDecoration(),
                                                child: Builder(
                                                  builder: (context) {
                                                    final containerVar =
                                                        containerWebinarsRecordList
                                                            .where((e) =>
                                                                e.expiresAt! >
                                                                getCurrentTimestamp)
                                                            .toList();
                                                    if (containerVar.isEmpty) {
                                                      return NoWebinarsComponentWidget();
                                                    }

                                                    return Column(
                                                      mainAxisSize:
                                                          MainAxisSize.max,
                                                      children: List.generate(
                                                          containerVar.length,
                                                          (containerVarIndex) {
                                                        final containerVarItem =
                                                            containerVar[
                                                                containerVarIndex];
                                                        return Container(
                                                          decoration:
                                                              BoxDecoration(
                                                            color: FlutterFlowTheme
                                                                    .of(context)
                                                                .whiteOverlay,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                    valueOrDefault<
                                                                        double>(
                                                              FFAppConstants
                                                                  .borderRadius,
                                                              0.0,
                                                            )),
                                                          ),
                                                          child:
                                                              WebinarListItemWidget(
                                                            key: Key(
                                                                'Keyw6s_${containerVarIndex}_of_${containerVar.length}'),
                                                            webinar:
                                                                containerVarItem,
                                                          ),
                                                        );
                                                      }).divide(SizedBox(
                                                          height: 5.0)),
                                                    );
                                                  },
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional(0.0, 1.0),
                  child: Container(
                    height: 120.0,
                    decoration: BoxDecoration(),
                    child: Visibility(
                      visible: !(isWeb
                          ? MediaQuery.viewInsetsOf(context).bottom > 0
                          : _isKeyboardVisible),
                      child: Builder(
                        builder: (context) => wrapWithModel(
                          model: _model.bottomNavBarComponentModel,
                          updateCallback: () => safeSetState(() {}),
                          child: BottomNavBarComponentWidget(
                            selectedPageIndex: 3,
                            hidden: false,
                            plusButtonVisible: true,
                            plusButtonAction: () async {
                              logFirebaseEvent(
                                  'GROUPS_Container_8in34dc0_CALLBACK');
                              logFirebaseEvent(
                                  'bottomNavBarComponent_alert_dialog');
                              await showDialog(
                                context: context,
                                builder: (dialogContext) {
                                  return Dialog(
                                    elevation: 0,
                                    insetPadding: EdgeInsets.zero,
                                    backgroundColor: Colors.transparent,
                                    alignment: AlignmentDirectional(0.0, 0.0)
                                        .resolve(Directionality.of(context)),
                                    child: GestureDetector(
                                      onTap: () {
                                        FocusScope.of(dialogContext).unfocus();
                                        FocusManager.instance.primaryFocus
                                            ?.unfocus();
                                      },
                                      child: Container(
                                        height:
                                            MediaQuery.sizeOf(context).height *
                                                0.8,
                                        width:
                                            MediaQuery.sizeOf(context).width *
                                                0.9,
                                        child: GroupCreateModalWidget(
                                          isModal: true,
                                          groupCreatedCallback: () async {
                                            logFirebaseEvent('_dismiss_dialog');
                                            Navigator.pop(context);
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                wrapWithModel(
                  model: _model.inAppNotificationComponentModel,
                  updateCallback: () => safeSetState(() {}),
                  child: InAppNotificationComponentWidget(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

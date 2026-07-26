import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/chat_groupwbubbles/chat_members_view_component/chat_members_view_component_widget.dart';
import '/chat_groupwbubbles/chat_thread_component/chat_thread_component_widget.dart';
import '/chat_groupwbubbles/long_press_chat_options/long_press_chat_options_widget.dart';
import '/components/user_icon_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'chat2_details_model.dart';
export 'chat2_details_model.dart';

class Chat2DetailsWidget extends StatefulWidget {
  const Chat2DetailsWidget({
    super.key,
    required this.chatRef,
    this.group,
  });

  final ChatsRecord? chatRef;
  final GroupsRecord? group;

  static String routeName = 'chat_2_Details';
  static String routePath = '/chat2Details';

  @override
  State<Chat2DetailsWidget> createState() => _Chat2DetailsWidgetState();
}

class _Chat2DetailsWidgetState extends State<Chat2DetailsWidget> {
  late Chat2DetailsModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => Chat2DetailsModel());

    logFirebaseEvent('screen_view',
        parameters: {'screen_name': 'chat_2_Details'});
    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      logFirebaseEvent('CHAT_2_DETAILS_chat_2_Details_ON_INIT_ST');
      logFirebaseEvent('chat_2_Details_backend_call');

      await widget!.chatRef!.reference.update({
        ...mapToFirestore(
          {
            'members_online': FieldValue.arrayUnion([currentUserReference]),
          },
        ),
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    // On page dispose action.
    () async {
      logFirebaseEvent('CHAT_2_DETAILS_chat_2_Details_ON_DISPOSE');
      logFirebaseEvent('chat_2_Details_backend_call');

      await widget!.chatRef!.reference.update({
        ...mapToFirestore(
          {
            'members_online': FieldValue.arrayRemove([currentUserReference]),
          },
        ),
      });
    }();

    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
        appBar: AppBar(
          backgroundColor: FlutterFlowTheme.of(context).alternate,
          automaticallyImplyLeading: false,
          leading: FlutterFlowIconButton(
            borderColor: Colors.transparent,
            borderRadius: 30.0,
            borderWidth: 1.0,
            buttonSize: 60.0,
            icon: Icon(
              Icons.chevron_left,
              color: FlutterFlowTheme.of(context).primaryText,
              size: 30.0,
            ),
            onPressed: () async {
              logFirebaseEvent('CHAT_2_DETAILS_chevron_left_ICN_ON_TAP');
              logFirebaseEvent('IconButton_navigate_back');
              context.safePop();
            },
          ),
          title: Builder(
            builder: (context) {
              if (widget!.chatRef?.hasGroup() != true) {
                return StreamBuilder<UsersRecord>(
                  stream: UsersRecord.getDocument(widget!.chatRef!.users
                      .where((e) => e.id != currentUserReference?.id)
                      .toList()
                      .firstOrNull!),
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

                    final rowSingleUserUsersRecord = snapshot.data!;

                    return Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        wrapWithModel(
                          model: _model.userIconModel,
                          updateCallback: () => safeSetState(() {}),
                          child: UserIconWidget(
                            width: 40,
                            height: 40,
                            userDoc: rowSingleUserUsersRecord,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                valueOrDefault<String>(
                                  rowSingleUserUsersRecord.displayName,
                                  'Ghost User',
                                ),
                                style: FlutterFlowTheme.of(context)
                                    .bodyLarge
                                    .override(
                                      font: GoogleFonts.poppins(
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .bodyLarge
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyLarge
                                            .fontStyle,
                                      ),
                                      letterSpacing: 0.0,
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodyLarge
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyLarge
                                          .fontStyle,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              } else {
                return InkWell(
                  splashColor: Colors.transparent,
                  focusColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  onTap: () async {
                    logFirebaseEvent(
                        'CHAT_2_DETAILS_PAGE_Row-groupChat_ON_TAP');
                    logFirebaseEvent('Row-groupChat_bottom_sheet');
                    await showModalBottomSheet(
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      enableDrag: false,
                      context: context,
                      builder: (context) {
                        return GestureDetector(
                          onTap: () {
                            FocusScope.of(context).unfocus();
                            FocusManager.instance.primaryFocus?.unfocus();
                          },
                          child: Padding(
                            padding: MediaQuery.viewInsetsOf(context),
                            child: ChatMembersViewComponentWidget(
                              group: widget!.group!,
                            ),
                          ),
                        );
                      },
                    ).then((value) => safeSetState(() {}));
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              valueOrDefault<String>(
                                widget!.group?.name,
                                'Group Chat',
                              ),
                              style: FlutterFlowTheme.of(context)
                                  .bodyLarge
                                  .override(
                                    font: GoogleFonts.poppins(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodyLarge
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyLarge
                                          .fontStyle,
                                    ),
                                    color:
                                        FlutterFlowTheme.of(context).background,
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .bodyLarge
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyLarge
                                        .fontStyle,
                                  ),
                            ),
                            Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  0.0, 4.0, 0.0, 0.0),
                              child:
                                  FutureBuilder<List<GroupMemberStateRecord>>(
                                future: queryGroupMemberStateRecordOnce(
                                  queryBuilder: (groupMemberStateRecord) =>
                                      groupMemberStateRecord
                                          .where(
                                            'group',
                                            isEqualTo: widget!.group?.reference,
                                          )
                                          .whereIn(
                                              'status',
                                              _model.memberLeaderCreator
                                                  .map((e) => e.serialize())
                                                  .toList()),
                                ),
                                builder: (context, snapshot) {
                                  // Customize what your widget looks like when it's loading.
                                  if (!snapshot.hasData) {
                                    return Center(
                                      child: SizedBox(
                                        width: 40.0,
                                        height: 40.0,
                                        child: CircularProgressIndicator(
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            FlutterFlowTheme.of(context)
                                                .primary,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  List<GroupMemberStateRecord>
                                      textGroupMemberStateRecordList =
                                      snapshot.data!;

                                  return Text(
                                    '${textGroupMemberStateRecordList.unique((e) => e.member!).length.toString()} members, ${valueOrDefault<String>(
                                      widget!.chatRef?.membersOnline?.length
                                          ?.toString(),
                                      '10',
                                    )} online',
                                    style: FlutterFlowTheme.of(context)
                                        .labelSmall
                                        .override(
                                          font: GoogleFonts.poppins(
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .labelSmall
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .labelSmall
                                                    .fontStyle,
                                          ),
                                          color: FlutterFlowTheme.of(context)
                                              .grayDark,
                                          letterSpacing: 0.0,
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .labelSmall
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .labelSmall
                                                  .fontStyle,
                                        ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
          actions: [
            Visibility(
              visible: FFAppState().selectedChatMessage?.id != null &&
                  FFAppState().selectedChatMessage?.id != '',
              child: Builder(
                builder: (context) => Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(0.0, 8.0, 16.0, 8.0),
                  child: FlutterFlowIconButton(
                    borderColor: FlutterFlowTheme.of(context).alternate,
                    borderRadius: 12.0,
                    borderWidth: 2.0,
                    buttonSize: 40.0,
                    fillColor: FlutterFlowTheme.of(context).alternate,
                    icon: Icon(
                      Icons.more_vert,
                      color: FlutterFlowTheme.of(context).primaryText,
                      size: 24.0,
                    ),
                    onPressed: () async {
                      logFirebaseEvent(
                          'CHAT_2_DETAILS_PAGE_more_vert_ICN_ON_TAP');
                      logFirebaseEvent('IconButton_alert_dialog');
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
                                FocusManager.instance.primaryFocus?.unfocus();
                              },
                              child: LongPressChatOptionsWidget(
                                chatMessageRef:
                                    FFAppState().selectedChatMessage!,
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
          ],
          centerTitle: false,
          elevation: 1.0,
        ),
        body: SafeArea(
          top: true,
          child: StreamBuilder<List<GroupMemberStateRecord>>(
            stream: queryGroupMemberStateRecord(
              queryBuilder: (groupMemberStateRecord) => groupMemberStateRecord
                  .where(
                    'group',
                    isEqualTo: widget!.group?.reference,
                  )
                  .where(
                    'member',
                    isEqualTo: currentUserReference,
                  ),
              singleRecord: true,
            ),
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
              List<GroupMemberStateRecord>
                  chatThreadComponentGroupMemberStateRecordList =
                  snapshot.data!;
              // Return an empty Container when the item does not exist.
              if (snapshot.data!.isEmpty) {
                return Container();
              }
              final chatThreadComponentGroupMemberStateRecord =
                  chatThreadComponentGroupMemberStateRecordList.isNotEmpty
                      ? chatThreadComponentGroupMemberStateRecordList.first
                      : null;

              return wrapWithModel(
                model: _model.chatThreadComponentModel,
                updateCallback: () => safeSetState(() {}),
                updateOnChange: true,
                child: ChatThreadComponentWidget(
                  chatRef: widget!.chatRef,
                  group: widget!.group,
                  groupMemberState: chatThreadComponentGroupMemberStateRecord,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

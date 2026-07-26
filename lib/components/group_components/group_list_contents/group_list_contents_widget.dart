import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/push_notifications/push_notifications_util.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/actions/actions.dart' as action_blocks;
import '/index.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'group_list_contents_model.dart';
export 'group_list_contents_model.dart';

class GroupListContentsWidget extends StatefulWidget {
  const GroupListContentsWidget({
    super.key,
    required this.group,
  });

  final GroupsRecord? group;

  @override
  State<GroupListContentsWidget> createState() =>
      _GroupListContentsWidgetState();
}

class _GroupListContentsWidgetState extends State<GroupListContentsWidget> {
  late GroupListContentsModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => GroupListContentsModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 5.0),
      child: StreamBuilder<List<GroupMemberStateRecord>>(
        stream: queryGroupMemberStateRecord(
          queryBuilder: (groupMemberStateRecord) => groupMemberStateRecord
              .where(
                'member',
                isEqualTo: currentUserReference,
              )
              .where(
                'group',
                isEqualTo: widget!.group?.reference,
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
          List<GroupMemberStateRecord> mainContainerGroupMemberStateRecordList =
              snapshot.data!;
          final mainContainerGroupMemberStateRecord =
              mainContainerGroupMemberStateRecordList.isNotEmpty
                  ? mainContainerGroupMemberStateRecordList.first
                  : null;

          return InkWell(
            splashColor: Colors.transparent,
            focusColor: Colors.transparent,
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
            onTap: () async {
              logFirebaseEvent('GROUP_LIST_CONTENTS_MainContainer_ON_TAP');
              var _shouldSetState = false;
              if (((mainContainerGroupMemberStateRecord != null) == true) &&
                  ((mainContainerGroupMemberStateRecord?.status ==
                          GroupMembershipStatus.Member) ||
                      (mainContainerGroupMemberStateRecord?.status ==
                          GroupMembershipStatus.Leader) ||
                      (mainContainerGroupMemberStateRecord?.status ==
                          GroupMembershipStatus.Creator))) {
                logFirebaseEvent('MainContainer_backend_call');
                _model.chatRef =
                    await ChatsRecord.getDocumentOnce(widget!.group!.chat!);
                _shouldSetState = true;
                logFirebaseEvent('MainContainer_navigate_to');
                if (Navigator.of(context).canPop()) {
                  context.pop();
                }
                context.pushNamed(
                  Chat2DetailsWidget.routeName,
                  queryParameters: {
                    'chatRef': serializeParam(
                      _model.chatRef,
                      ParamType.Document,
                    ),
                    'group': serializeParam(
                      widget!.group,
                      ParamType.Document,
                    ),
                  }.withoutNulls,
                  extra: <String, dynamic>{
                    'chatRef': _model.chatRef,
                    'group': widget!.group,
                  },
                );
              } else {
                if (mainContainerGroupMemberStateRecord?.status ==
                    GroupMembershipStatus.Banned) {
                  logFirebaseEvent('MainContainer_alert_dialog');
                  await showDialog(
                    context: context,
                    builder: (alertDialogContext) {
                      return AlertDialog(
                        title: Text('You\'ve been banned from this group.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(alertDialogContext),
                            child: Text('Ok'),
                          ),
                        ],
                      );
                    },
                  );
                  if (_shouldSetState) safeSetState(() {});
                  return;
                } else {
                  if (widget!.group!.needsApprovalToJoin) {
                    logFirebaseEvent('MainContainer_action_block');
                    await action_blocks.userRequestToJoinGroup(
                      context,
                      user: currentUserReference,
                      group: widget!.group?.reference,
                    );
                    logFirebaseEvent('MainContainer_trigger_push_notification');
                    triggerPushNotification(
                      notificationTitle:
                          'Request to join ${widget!.group?.name}',
                      notificationText:
                          '${currentUserDisplayName} wants to join your group.',
                      notificationSound: 'default',
                      userRefs: [widget!.group!.creator!],
                      initialPageName: 'groupsPage',
                      parameterData: {},
                    );
                  } else {
                    logFirebaseEvent('MainContainer_action_block');
                    await action_blocks.userJoinGroup(
                      context,
                      groupRef: widget!.group?.reference,
                      user: currentUserReference,
                    );
                  }
                }
              }

              logFirebaseEvent('MainContainer_firestore_query');
              _model.groupMemberState = await queryGroupMemberStateRecordOnce(
                queryBuilder: (groupMemberStateRecord) => groupMemberStateRecord
                    .where(
                      'member',
                      isEqualTo: currentUserReference,
                    )
                    .where(
                      'group',
                      isEqualTo: widget!.group?.reference,
                    ),
                singleRecord: true,
              ).then((s) => s.firstOrNull);
              _shouldSetState = true;
              logFirebaseEvent('MainContainer_action_block');
              await action_blocks.updateGroupMemberLastActive(
                context,
                groupMemberStateRef:
                    mainContainerGroupMemberStateRecord?.reference,
              );
              if (_shouldSetState) safeSetState(() {});
            },
            onLongPress: () async {
              logFirebaseEvent('GROUP_LIST_CONTENTS_MainContainer_ON_LON');
              if ((mainContainerGroupMemberStateRecord?.status ==
                      GroupMembershipStatus.Leader) ||
                  (mainContainerGroupMemberStateRecord?.status ==
                      GroupMembershipStatus.Member) ||
                  (mainContainerGroupMemberStateRecord?.status ==
                      GroupMembershipStatus.Creator)) {
                logFirebaseEvent('MainContainer_alert_dialog');
                var confirmDialogResponse = await showDialog<bool>(
                      context: context,
                      builder: (alertDialogContext) {
                        return AlertDialog(
                          title: Text('Leave group?'),
                          content: Text('Would you like to leave this group?'),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(alertDialogContext, false),
                              child: Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(alertDialogContext, true),
                              child: Text('Yes'),
                            ),
                          ],
                        );
                      },
                    ) ??
                    false;
                if (confirmDialogResponse) {
                  logFirebaseEvent('MainContainer_firestore_query');
                  _model.chat = await queryChatsRecordOnce(
                    queryBuilder: (chatsRecord) => chatsRecord.where(
                      'group',
                      isEqualTo: widget!.group?.reference,
                    ),
                    singleRecord: true,
                  ).then((s) => s.firstOrNull);
                  logFirebaseEvent('MainContainer_backend_call');

                  await _model.chat!.reference.update({
                    ...mapToFirestore(
                      {
                        'users': FieldValue.arrayRemove([currentUserReference]),
                      },
                    ),
                  });
                  logFirebaseEvent('MainContainer_backend_call');
                  await mainContainerGroupMemberStateRecord!.reference.delete();
                }
              }

              safeSetState(() {});
            },
            child: Container(
              width: double.infinity,
              height: 107.0,
              decoration: BoxDecoration(
                color: () {
                  if (!(mainContainerGroupMemberStateRecord != null)) {
                    return FlutterFlowTheme.of(context).grayLight;
                  } else if ((mainContainerGroupMemberStateRecord?.status ==
                          GroupMembershipStatus.Leader) ||
                      (mainContainerGroupMemberStateRecord?.status ==
                          GroupMembershipStatus.Member) ||
                      (mainContainerGroupMemberStateRecord?.status ==
                          GroupMembershipStatus.Creator)) {
                    return FlutterFlowTheme.of(context).tertiary;
                  } else {
                    return FlutterFlowTheme.of(context).grayLight;
                  }
                }(),
                borderRadius: BorderRadius.circular(valueOrDefault<double>(
                  FFAppConstants.borderRadius,
                  0.0,
                )),
              ),
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(16.0, 16.0, 16.0, 16.0),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional(-1.0, 0.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              valueOrDefault<String>(
                                widget!.group?.name,
                                'name',
                              ),
                              textAlign: TextAlign.start,
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    font: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w500,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                                    color: () {
                                      if (!(mainContainerGroupMemberStateRecord !=
                                          null)) {
                                        return FlutterFlowTheme.of(context)
                                            .alternate;
                                      } else if (mainContainerGroupMemberStateRecord
                                              ?.status ==
                                          GroupMembershipStatus.Member) {
                                        return FlutterFlowTheme.of(context)
                                            .secondary;
                                      } else if (mainContainerGroupMemberStateRecord
                                              ?.status ==
                                          GroupMembershipStatus.Leader) {
                                        return FlutterFlowTheme.of(context)
                                            .secondary;
                                      } else if (mainContainerGroupMemberStateRecord
                                              ?.status ==
                                          GroupMembershipStatus.Creator) {
                                        return FlutterFlowTheme.of(context)
                                            .secondary;
                                      } else {
                                        return FlutterFlowTheme.of(context)
                                            .alternate;
                                      }
                                    }(),
                                    fontSize: 15.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w500,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                            ),
                            StreamBuilder<UsersRecord>(
                              stream: UsersRecord.getDocument(
                                  widget!.group!.creator!),
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
                                          FlutterFlowTheme.of(context).primary,
                                        ),
                                      ),
                                    ),
                                  );
                                }

                                final textUsersRecord = snapshot.data!;

                                return Text(
                                  'Created By: ${textUsersRecord.displayName}',
                                  textAlign: TextAlign.start,
                                  style: FlutterFlowTheme.of(context)
                                      .bodySmall
                                      .override(
                                        font: GoogleFonts.poppins(
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .bodySmall
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodySmall
                                                  .fontStyle,
                                        ),
                                        color: () {
                                          if (!(mainContainerGroupMemberStateRecord !=
                                              null)) {
                                            return FlutterFlowTheme.of(context)
                                                .alternate;
                                          } else if (mainContainerGroupMemberStateRecord
                                                  ?.status ==
                                              GroupMembershipStatus.Member) {
                                            return FlutterFlowTheme.of(context)
                                                .secondary;
                                          } else if (mainContainerGroupMemberStateRecord
                                                  ?.status ==
                                              GroupMembershipStatus.Leader) {
                                            return FlutterFlowTheme.of(context)
                                                .secondary;
                                          } else if (mainContainerGroupMemberStateRecord
                                                  ?.status ==
                                              GroupMembershipStatus.Creator) {
                                            return FlutterFlowTheme.of(context)
                                                .secondary;
                                          } else {
                                            return FlutterFlowTheme.of(context)
                                                .alternate;
                                          }
                                        }(),
                                        fontSize: 12.0,
                                        letterSpacing: 0.0,
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .bodySmall
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodySmall
                                            .fontStyle,
                                      ),
                                );
                              },
                            ),
                            Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  0.0, 4.0, 0.0, 0.0),
                              child: Text(
                                widget!.group!.description,
                                textAlign: TextAlign.start,
                                maxLines: 2,
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      font: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w300,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                      color: () {
                                        if (!(mainContainerGroupMemberStateRecord !=
                                            null)) {
                                          return FlutterFlowTheme.of(context)
                                              .alternate;
                                        } else if (mainContainerGroupMemberStateRecord
                                                ?.status ==
                                            GroupMembershipStatus.Member) {
                                          return FlutterFlowTheme.of(context)
                                              .secondary;
                                        } else if (mainContainerGroupMemberStateRecord
                                                ?.status ==
                                            GroupMembershipStatus.Leader) {
                                          return FlutterFlowTheme.of(context)
                                              .secondary;
                                        } else if (mainContainerGroupMemberStateRecord
                                                ?.status ==
                                            GroupMembershipStatus.Creator) {
                                          return FlutterFlowTheme.of(context)
                                              .secondary;
                                        } else {
                                          return FlutterFlowTheme.of(context)
                                              .alternate;
                                        }
                                      }(),
                                      fontSize: 10.0,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.w300,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
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
                                        _model.memberCreatorLeader
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
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      FlutterFlowTheme.of(context).primary,
                                    ),
                                  ),
                                ),
                              );
                            }
                            List<GroupMemberStateRecord>
                                memberDisplayContainerGroupMemberStateRecordList =
                                snapshot.data!;

                            return Container(
                              decoration: BoxDecoration(),
                              child: Text(
                                'members: ${memberDisplayContainerGroupMemberStateRecordList.unique((e) => e.member!).length.toString()}',
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      font: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                      color: () {
                                        if (!(mainContainerGroupMemberStateRecord !=
                                            null)) {
                                          return FlutterFlowTheme.of(context)
                                              .alternate;
                                        } else if (mainContainerGroupMemberStateRecord
                                                ?.status ==
                                            GroupMembershipStatus.Member) {
                                          return FlutterFlowTheme.of(context)
                                              .secondary;
                                        } else if (mainContainerGroupMemberStateRecord
                                                ?.status ==
                                            GroupMembershipStatus.Leader) {
                                          return FlutterFlowTheme.of(context)
                                              .secondary;
                                        } else if (mainContainerGroupMemberStateRecord
                                                ?.status ==
                                            GroupMembershipStatus.Creator) {
                                          return FlutterFlowTheme.of(context)
                                              .secondary;
                                        } else {
                                          return FlutterFlowTheme.of(context)
                                              .alternate;
                                        }
                                      }(),
                                      fontSize: 10.0,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                              ),
                            );
                          },
                        ),
                        StreamBuilder<ChatsRecord>(
                          stream: ChatsRecord.getDocument(widget!.group!.chat!),
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

                            final textChatsRecord = snapshot.data!;

                            return Text(
                              dateTimeFormat(
                                  "relative", textChatsRecord.lastMessageTime!),
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    font: GoogleFonts.poppins(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                                    color: () {
                                      if (!(mainContainerGroupMemberStateRecord !=
                                          null)) {
                                        return FlutterFlowTheme.of(context)
                                            .alternate;
                                      } else if (mainContainerGroupMemberStateRecord
                                              ?.status ==
                                          GroupMembershipStatus.Member) {
                                        return FlutterFlowTheme.of(context)
                                            .secondary;
                                      } else if (mainContainerGroupMemberStateRecord
                                              ?.status ==
                                          GroupMembershipStatus.Leader) {
                                        return FlutterFlowTheme.of(context)
                                            .secondary;
                                      } else if (mainContainerGroupMemberStateRecord
                                              ?.status ==
                                          GroupMembershipStatus.Creator) {
                                        return FlutterFlowTheme.of(context)
                                            .secondary;
                                      } else {
                                        return FlutterFlowTheme.of(context)
                                            .alternate;
                                      }
                                    }(),
                                    fontSize: 10.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                            );
                          },
                        ),
                        if ((mainContainerGroupMemberStateRecord?.status ==
                                    GroupMembershipStatus.Leader) ||
                                (mainContainerGroupMemberStateRecord?.status ==
                                    GroupMembershipStatus.Member) ||
                                (mainContainerGroupMemberStateRecord?.status ==
                                    GroupMembershipStatus.Creator)
                            ? false
                            : true)
                          FFButtonWidget(
                            onPressed: (true == true)
                                ? null
                                : () {
                                    print('Button pressed ...');
                                  },
                            text: () {
                              if (!(mainContainerGroupMemberStateRecord !=
                                  null)) {
                                return 'Join';
                              } else if (mainContainerGroupMemberStateRecord
                                      ?.status ==
                                  GroupMembershipStatus.Pending) {
                                return 'Pending';
                              } else if (mainContainerGroupMemberStateRecord
                                      ?.status ==
                                  GroupMembershipStatus.Member) {
                                return 'Chat';
                              } else if (mainContainerGroupMemberStateRecord
                                      ?.status ==
                                  GroupMembershipStatus.Leader) {
                                return 'Chat';
                              } else if (mainContainerGroupMemberStateRecord
                                      ?.status ==
                                  GroupMembershipStatus.Creator) {
                                return 'Chat';
                              } else if (mainContainerGroupMemberStateRecord
                                      ?.status ==
                                  GroupMembershipStatus.Banned) {
                                return 'Banned';
                              } else {
                                return 'Join';
                              }
                            }(),
                            options: FFButtonOptions(
                              width: 70.0,
                              height: 20.0,
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  0.0, 0.0, 0.0, 0.0),
                              iconPadding: EdgeInsetsDirectional.fromSTEB(
                                  0.0, 0.0, 0.0, 0.0),
                              color: FlutterFlowTheme.of(context).accent1,
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
                                    color:
                                        FlutterFlowTheme.of(context).secondary,
                                    fontSize: 8.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontStyle,
                                  ),
                              elevation: 0.0,
                              borderSide: BorderSide(
                                color: Colors.transparent,
                              ),
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

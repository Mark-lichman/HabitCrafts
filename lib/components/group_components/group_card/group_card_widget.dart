import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/push_notifications/push_notifications_util.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/actions/actions.dart' as action_blocks;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'group_card_model.dart';
export 'group_card_model.dart';

class GroupCardWidget extends StatefulWidget {
  const GroupCardWidget({
    super.key,
    required this.group,
  });

  final GroupsRecord? group;

  @override
  State<GroupCardWidget> createState() => _GroupCardWidgetState();
}

class _GroupCardWidgetState extends State<GroupCardWidget> {
  late GroupCardModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => GroupCardModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100.0,
      height: 140.0,
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(valueOrDefault<double>(
          FFAppConstants.borderRadius,
          0.0,
        )),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(8.0, 20.0, 8.0, 0.0),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20.0),
              child: Image.network(
                'https://picsum.photos/seed/518/600',
                width: 40.0,
                height: 40.0,
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(0.0, 10.0, 0.0, 0.0),
              child: Text(
                valueOrDefault<String>(
                  widget!.group?.name,
                  'name',
                ),
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      font: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                      ),
                      color: Color(0xFF1D1B20),
                      fontSize: 8.0,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.w500,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                    ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(0.0, 2.0, 0.0, 0.0),
                child: Text(
                  valueOrDefault<String>(
                    widget!.group?.description,
                    'description',
                  ),
                  maxLines: 2,
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        font: GoogleFonts.poppins(
                          fontWeight: FlutterFlowTheme.of(context)
                              .bodyMedium
                              .fontWeight,
                          fontStyle:
                              FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                        ),
                        color: Color(0xFF1D1B20),
                        fontSize: 8.0,
                        letterSpacing: 0.0,
                        fontWeight:
                            FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                      ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 4.0),
              child: InkWell(
                splashColor: Colors.transparent,
                focusColor: Colors.transparent,
                hoverColor: Colors.transparent,
                highlightColor: Colors.transparent,
                onTap: () async {
                  logFirebaseEvent('GROUP_CARD_Container_hnreatnv_ON_TAP');
                  if (widget!.group?.needsApprovalToJoin == true) {
                    logFirebaseEvent('Container_action_block');
                    await action_blocks.userRequestToJoinGroup(
                      context,
                      user: currentUserReference,
                      group: widget!.group?.reference,
                    );
                    logFirebaseEvent('Container_trigger_push_notification');
                    triggerPushNotification(
                      notificationTitle:
                          'New request to join ${widget!.group?.name}',
                      notificationText:
                          '${currentUserDisplayName} wants to join your group.',
                      notificationSound: 'default',
                      userRefs: [widget!.group!.creator!],
                      initialPageName: 'groupsPage',
                      parameterData: {
                        'groupFromPush': widget!.group?.reference,
                      },
                    );
                    logFirebaseEvent('Container_show_snack_bar');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'You\'ve sent a request to join the group!',
                          style: TextStyle(
                            color: FlutterFlowTheme.of(context).alternate,
                          ),
                        ),
                        duration: Duration(milliseconds: 4000),
                        backgroundColor: FlutterFlowTheme.of(context).secondary,
                      ),
                    );
                  } else {
                    logFirebaseEvent('Container_action_block');
                    await action_blocks.userJoinGroup(
                      context,
                      groupRef: widget!.group?.reference,
                      user: currentUserReference,
                    );
                    logFirebaseEvent('Container_show_snack_bar');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'You\'ve goined the group!',
                          style: TextStyle(
                            color: FlutterFlowTheme.of(context).alternate,
                          ),
                        ),
                        duration: Duration(milliseconds: 4000),
                        backgroundColor: FlutterFlowTheme.of(context).secondary,
                      ),
                    );
                  }
                },
                child: Container(
                  height: 20.0,
                  decoration: BoxDecoration(
                    color: Color(0xFFCAD0E1),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: Align(
                    alignment: AlignmentDirectional(0.0, 0.0),
                    child: Padding(
                      padding:
                          EdgeInsetsDirectional.fromSTEB(2.0, 0.0, 2.0, 0.0),
                      child: StreamBuilder<List<GroupMemberStateRecord>>(
                        stream: queryGroupMemberStateRecord(
                          queryBuilder: (groupMemberStateRecord) =>
                              groupMemberStateRecord
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
                              textGroupMemberStateRecordList = snapshot.data!;
                          // Return an empty Container when the item does not exist.
                          if (snapshot.data!.isEmpty) {
                            return Container();
                          }
                          final textGroupMemberStateRecord =
                              textGroupMemberStateRecordList.isNotEmpty
                                  ? textGroupMemberStateRecordList.first
                                  : null;

                          return Text(
                            (textGroupMemberStateRecord?.status ==
                                        GroupMembershipStatus.Leader) ||
                                    (textGroupMemberStateRecord?.status ==
                                        GroupMembershipStatus.Member) ||
                                    (textGroupMemberStateRecord?.status ==
                                        GroupMembershipStatus.Creator)
                                ? 'Chat'
                                : 'Join',
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
                                  fontSize: 8.0,
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
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

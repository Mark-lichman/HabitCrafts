import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/components/group_components/group_accept_decline_list_item/group_accept_decline_list_item_widget.dart';
import '/components/group_components/group_create_modal/group_create_modal_widget.dart';
import '/components/group_components/group_manage_list_item/group_manage_list_item_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'group_management_component_model.dart';
export 'group_management_component_model.dart';

class GroupManagementComponentWidget extends StatefulWidget {
  const GroupManagementComponentWidget({super.key});

  @override
  State<GroupManagementComponentWidget> createState() =>
      _GroupManagementComponentWidgetState();
}

class _GroupManagementComponentWidgetState
    extends State<GroupManagementComponentWidget> {
  late GroupManagementComponentModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => GroupManagementComponentModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GroupMemberStateRecord>>(
      stream: queryGroupMemberStateRecord(
        queryBuilder: (groupMemberStateRecord) => groupMemberStateRecord
            .where(
              'member',
              isEqualTo: currentUserReference,
            )
            .whereIn('status',
                _model.creatorOrLeader.map((e) => e.serialize()).toList())
            .orderBy('last_active'),
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

        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).primary,
          ),
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Align(
                    alignment: AlignmentDirectional(-1.0, 0.0),
                    child: Builder(
                      builder: (context) => FFButtonWidget(
                        onPressed: () async {
                          logFirebaseEvent(
                              'GROUP_MANAGEMENT_COMPONENT_CREATE_A_NEW_');
                          logFirebaseEvent('Button_alert_dialog');
                          await showDialog(
                            context: context,
                            builder: (dialogContext) {
                              return Dialog(
                                elevation: 0,
                                insetPadding: EdgeInsets.zero,
                                backgroundColor: Colors.transparent,
                                alignment: AlignmentDirectional(0.0, 0.0)
                                    .resolve(Directionality.of(context)),
                                child: Container(
                                  height:
                                      MediaQuery.sizeOf(context).height * 0.8,
                                  width: MediaQuery.sizeOf(context).width * 0.9,
                                  child: GroupCreateModalWidget(
                                    isModal: true,
                                    groupCreatedCallback: () async {
                                      logFirebaseEvent('_dismiss_dialog');
                                      Navigator.pop(context);
                                    },
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        text: 'Create a new group',
                        icon: Icon(
                          Icons.groups_2_sharp,
                          size: 20.0,
                        ),
                        options: FFButtonOptions(
                          height: 30.0,
                          padding: EdgeInsetsDirectional.fromSTEB(
                              16.0, 0.0, 16.0, 0.0),
                          iconPadding: EdgeInsetsDirectional.fromSTEB(
                              0.0, 0.0, 0.0, 0.0),
                          iconColor: FlutterFlowTheme.of(context).secondary,
                          color: FlutterFlowTheme.of(context).accent1,
                          textStyle: FlutterFlowTheme.of(context)
                              .titleSmall
                              .override(
                                font: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w500,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .titleSmall
                                      .fontStyle,
                                ),
                                color: FlutterFlowTheme.of(context).secondary,
                                fontSize: 14.0,
                                letterSpacing: 0.0,
                                fontWeight: FontWeight.w500,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .titleSmall
                                    .fontStyle,
                              ),
                          elevation: 0.0,
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                    ),
                  ),
                  Builder(
                    builder: (context) {
                      final groups = mainContainerGroupMemberStateRecordList
                          .unique((e) => e.group!)
                          .toList();

                      return Column(
                        mainAxisSize: MainAxisSize.max,
                        children: List.generate(groups.length, (groupsIndex) {
                          final groupsItem = groups[groupsIndex];
                          return GroupManageListItemWidget(
                            key: Key(
                                'Key6bu_${groupsIndex}_of_${groups.length}'),
                            groupRef: groupsItem.group!,
                          );
                        })
                            .divide(SizedBox(height: 10.0))
                            .around(SizedBox(height: 10.0)),
                      );
                    },
                  ),
                  Padding(
                    padding:
                        EdgeInsetsDirectional.fromSTEB(0.0, 20.0, 0.0, 0.0),
                    child: Container(
                      width: double.infinity,
                      height: 1.0,
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).grayLight,
                      ),
                    ),
                  ),
                  if (true /* Warning: Trying to access variable not yet defined. */)
                    StreamBuilder<List<GroupMemberStateRecord>>(
                      stream: queryGroupMemberStateRecord(
                        queryBuilder: (groupMemberStateRecord) =>
                            groupMemberStateRecord
                                .whereIn(
                                    'group',
                                    mainContainerGroupMemberStateRecordList
                                        .map((e) => e.group)
                                        .withoutNulls
                                        .toList())
                                .where(
                                  'status',
                                  isEqualTo:
                                      GroupMembershipStatus.Pending.serialize(),
                                ),
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
                            pendingContainerGroupMemberStateRecordList =
                            snapshot.data!;

                        return Container(
                          width: double.infinity,
                          decoration: BoxDecoration(),
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Align(
                                alignment: AlignmentDirectional(-1.0, 0.0),
                                child: Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 10.0, 0.0, 0.0),
                                  child: Text(
                                    'NEW member(s) request',
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          font: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                          color: FlutterFlowTheme.of(context)
                                              .alternate,
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.w600,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                  ),
                                ),
                              ),
                              Align(
                                alignment: AlignmentDirectional(-1.0, 0.0),
                                child: Text(
                                  'Accept or decline requests',
                                  style: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        font: GoogleFonts.poppins(
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                        color: FlutterFlowTheme.of(context)
                                            .alternate,
                                        fontSize: 12.0,
                                        letterSpacing: 0.0,
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                ),
                              ),
                              Builder(
                                builder: (context) {
                                  final containerVar =
                                      pendingContainerGroupMemberStateRecordList
                                          .toList();

                                  return Column(
                                    mainAxisSize: MainAxisSize.max,
                                    children: List.generate(containerVar.length,
                                            (containerVarIndex) {
                                      final containerVarItem =
                                          containerVar[containerVarIndex];
                                      return GroupAcceptDeclineListItemWidget(
                                        key: Key(
                                            'Keyr6h_${containerVarIndex}_of_${containerVar.length}'),
                                        groupMemberState: containerVarItem,
                                      );
                                    })
                                        .divide(SizedBox(height: 10.0))
                                        .addToStart(SizedBox(height: 10.0)),
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ].addToEnd(SizedBox(height: 120.0)),
              ),
            ),
          ),
        );
      },
    );
  }
}

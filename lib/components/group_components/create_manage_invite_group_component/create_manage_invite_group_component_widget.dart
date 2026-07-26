import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/components/group_components/create_group_component/create_group_component_widget.dart';
import '/components/group_components/group_invite_component/group_invite_component_widget.dart';
import '/components/group_components/group_management_component/group_management_component_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'create_manage_invite_group_component_model.dart';
export 'create_manage_invite_group_component_model.dart';

/// this is a the component that contains each of the pages for creating,
/// managing, and inviting in groups
class CreateManageInviteGroupComponentWidget extends StatefulWidget {
  const CreateManageInviteGroupComponentWidget({
    super.key,
    required this.groupCreatedCallback,
  });

  final Future Function()? groupCreatedCallback;

  @override
  State<CreateManageInviteGroupComponentWidget> createState() =>
      _CreateManageInviteGroupComponentWidgetState();
}

class _CreateManageInviteGroupComponentWidgetState
    extends State<CreateManageInviteGroupComponentWidget> {
  late CreateManageInviteGroupComponentModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model =
        createModel(context, () => CreateManageInviteGroupComponentModel());

    // On component load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      logFirebaseEvent('CREATE_MANAGE_INVITE_GROUP_COMPONENT_cre');
      logFirebaseEvent('createManageInviteGroupComponent_firesto');
      _model.creatorCount = await queryGroupMemberStateRecordCount(
        queryBuilder: (groupMemberStateRecord) => groupMemberStateRecord
            .where(
              'member',
              isEqualTo: currentUserReference,
            )
            .where(
              'status',
              isEqualTo: GroupMembershipStatus.Creator.serialize(),
            ),
      );
      if (_model.creatorCount! > 0) {
        logFirebaseEvent('createManageInviteGroupComponent_page_vi');
        await _model.pageViewController?.animateToPage(
          1,
          duration: Duration(milliseconds: 500),
          curve: Curves.ease,
        );
        logFirebaseEvent('createManageInviteGroupComponent_update_');

        _model.updatePage(() {});
      }
    });

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
      padding: EdgeInsetsDirectional.fromSTEB(0.0, 10.0, 0.0, 0.0),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FFButtonWidget(
                onPressed: () async {
                  logFirebaseEvent('CREATE_MANAGE_INVITE_GROUP_COMPONENT_CRE');
                  logFirebaseEvent('Button_page_view');
                  await _model.pageViewController?.animateToPage(
                    0,
                    duration: Duration(milliseconds: 500),
                    curve: Curves.ease,
                  );
                  logFirebaseEvent('Button_update_component_state');

                  safeSetState(() {});
                },
                text: 'Creating',
                options: FFButtonOptions(
                  height: 40.0,
                  padding: EdgeInsetsDirectional.fromSTEB(24.0, 0.0, 24.0, 0.0),
                  iconPadding:
                      EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                  color: Colors.transparent,
                  textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                        font: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontStyle:
                              FlutterFlowTheme.of(context).titleSmall.fontStyle,
                        ),
                        color: _model.pageViewCurrentIndex == 0
                            ? FlutterFlowTheme.of(context).accent1
                            : FlutterFlowTheme.of(context).alternate,
                        fontSize: 14.0,
                        letterSpacing: 0.0,
                        fontWeight: FontWeight.w600,
                        fontStyle:
                            FlutterFlowTheme.of(context).titleSmall.fontStyle,
                      ),
                  elevation: 0.0,
                  borderSide: BorderSide(
                    color: Colors.transparent,
                    width: 1.0,
                  ),
                  borderRadius: BorderRadius.circular(8.0),
                  hoverTextColor: FlutterFlowTheme.of(context).accent1,
                ),
              ),
              FFButtonWidget(
                onPressed: () async {
                  logFirebaseEvent('CREATE_MANAGE_INVITE_GROUP_COMPONENT_MAN');
                  logFirebaseEvent('Button_page_view');
                  await _model.pageViewController?.animateToPage(
                    1,
                    duration: Duration(milliseconds: 500),
                    curve: Curves.ease,
                  );
                  logFirebaseEvent('Button_update_component_state');

                  safeSetState(() {});
                },
                text: 'Managing',
                options: FFButtonOptions(
                  height: 40.0,
                  padding: EdgeInsetsDirectional.fromSTEB(24.0, 0.0, 24.0, 0.0),
                  iconPadding:
                      EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                  color: Colors.transparent,
                  textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                        font: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontStyle:
                              FlutterFlowTheme.of(context).titleSmall.fontStyle,
                        ),
                        color: _model.pageViewCurrentIndex == 1
                            ? FlutterFlowTheme.of(context).accent1
                            : FlutterFlowTheme.of(context).alternate,
                        fontSize: 14.0,
                        letterSpacing: 0.0,
                        fontWeight: FontWeight.w600,
                        fontStyle:
                            FlutterFlowTheme.of(context).titleSmall.fontStyle,
                      ),
                  elevation: 0.0,
                  borderSide: BorderSide(
                    color: Colors.transparent,
                    width: 1.0,
                  ),
                  borderRadius: BorderRadius.circular(8.0),
                  hoverTextColor: FlutterFlowTheme.of(context).accent1,
                ),
              ),
              FFButtonWidget(
                onPressed: () async {
                  logFirebaseEvent('CREATE_MANAGE_INVITE_GROUP_COMPONENT_INV');
                  logFirebaseEvent('Button_page_view');
                  await _model.pageViewController?.animateToPage(
                    2,
                    duration: Duration(milliseconds: 500),
                    curve: Curves.ease,
                  );
                  logFirebaseEvent('Button_update_component_state');

                  safeSetState(() {});
                },
                text: 'Invite',
                options: FFButtonOptions(
                  height: 40.0,
                  padding: EdgeInsetsDirectional.fromSTEB(24.0, 0.0, 24.0, 0.0),
                  iconPadding:
                      EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                  color: Colors.transparent,
                  textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                        font: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontStyle:
                              FlutterFlowTheme.of(context).titleSmall.fontStyle,
                        ),
                        color: _model.pageViewCurrentIndex == 2
                            ? FlutterFlowTheme.of(context).accent1
                            : FlutterFlowTheme.of(context).alternate,
                        fontSize: 14.0,
                        letterSpacing: 0.0,
                        fontWeight: FontWeight.w600,
                        fontStyle:
                            FlutterFlowTheme.of(context).titleSmall.fontStyle,
                      ),
                  elevation: 0.0,
                  borderSide: BorderSide(
                    color: Colors.transparent,
                    width: 1.0,
                  ),
                  borderRadius: BorderRadius.circular(8.0),
                  hoverTextColor: FlutterFlowTheme.of(context).accent1,
                ),
              ),
            ],
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              height: double.infinity,
              child: PageView(
                controller: _model.pageViewController ??=
                    PageController(initialPage: 0),
                scrollDirection: Axis.horizontal,
                children: [
                  wrapWithModel(
                    model: _model.createGroupComponentModel,
                    updateCallback: () => safeSetState(() {}),
                    child: CreateGroupComponentWidget(
                      groupCreatedCallback: () async {},
                    ),
                  ),
                  wrapWithModel(
                    model: _model.groupManagementComponentModel,
                    updateCallback: () => safeSetState(() {}),
                    child: GroupManagementComponentWidget(),
                  ),
                  wrapWithModel(
                    model: _model.groupInviteComponentModel,
                    updateCallback: () => safeSetState(() {}),
                    child: GroupInviteComponentWidget(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

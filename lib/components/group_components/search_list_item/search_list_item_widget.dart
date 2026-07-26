import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/components/group_components/group_list_contents/group_list_contents_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/actions/actions.dart' as action_blocks;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'search_list_item_model.dart';
export 'search_list_item_model.dart';

class SearchListItemWidget extends StatefulWidget {
  const SearchListItemWidget({
    super.key,
    required this.userGroupSearch,
  });

  final UserGroupSearchRecord? userGroupSearch;

  @override
  State<SearchListItemWidget> createState() => _SearchListItemWidgetState();
}

class _SearchListItemWidgetState extends State<SearchListItemWidget> {
  late SearchListItemModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => SearchListItemModel());

    // On component load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      logFirebaseEvent('SEARCH_LIST_ITEM_searchListItem_ON_INIT_');
      logFirebaseEvent('searchListItem_update_component_state');
      _model.addToCombinedUsers(currentUserReference!);
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
    return Builder(
      builder: (context) {
        if (widget!.userGroupSearch?.hasUser() ?? false) {
          return StreamBuilder<UsersRecord>(
            stream: UsersRecord.getDocument(widget!.userGroupSearch!.user!),
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

              final containerUsersRecord = snapshot.data!;

              return Container(
                width: double.infinity,
                height: 45.0,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).grayLight,
                  borderRadius: BorderRadius.circular(valueOrDefault<double>(
                    FFAppConstants.borderRadius,
                    0.0,
                  )),
                ),
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(10.0, 0.0, 20.0, 0.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Container(
                        width: 26.0,
                        height: 26.0,
                        decoration: BoxDecoration(
                          color: FlutterFlowTheme.of(context).accent2,
                          shape: BoxShape.circle,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(13.0),
                          child: Image.network(
                            containerUsersRecord.photoUrl != null &&
                                    containerUsersRecord.photoUrl != ''
                                ? containerUsersRecord.photoUrl
                                : 'https://firebasestorage.googleapis.com/v0/b/habitcraft-78a3f.appspot.com/o/images%2Fdefault_person.png?alt=media&token=ad79337b-b569-4948-8b58-5ec4d7f740fc',
                            width: 26.0,
                            height: 26.0,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              6.0, 0.0, 0.0, 0.0),
                          child: Text(
                            containerUsersRecord.displayName,
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  font: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                                  color: FlutterFlowTheme.of(context).alternate,
                                  fontSize: 15.0,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.w600,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontStyle,
                                ),
                          ),
                        ),
                      ),
                      InkWell(
                        splashColor: Colors.transparent,
                        focusColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        onTap: () async {
                          logFirebaseEvent(
                              'SEARCH_LIST_ITEM_Container_z1x2j7q2_ON_T');
                          logFirebaseEvent('Container_action_block');
                          await action_blocks.openChatWithUser(
                            context,
                            userRef: containerUsersRecord.reference,
                          );
                        },
                        child: Container(
                          height: 20.0,
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context).accent1,
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: Align(
                            alignment: AlignmentDirectional(0.0, 0.0),
                            child: Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  8.0, 0.0, 8.0, 0.0),
                              child: Text(
                                'Chat',
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
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        } else {
          return StreamBuilder<GroupsRecord>(
            stream: GroupsRecord.getDocument(widget!.userGroupSearch!.group!),
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

              final containerGroupsRecord = snapshot.data!;

              return Container(
                width: double.infinity,
                height: 107.0,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5.0),
                ),
                child: wrapWithModel(
                  model: _model.groupListContentsModel,
                  updateCallback: () => safeSetState(() {}),
                  child: GroupListContentsWidget(
                    group: containerGroupsRecord,
                  ),
                ),
              );
            },
          );
        }
      },
    );
  }
}

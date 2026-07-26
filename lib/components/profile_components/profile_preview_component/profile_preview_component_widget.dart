import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/profile_components/profile_tag_component/profile_tag_component_widget.dart';
import '/components/user_icon_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/actions/actions.dart' as action_blocks;
import '/flutter_flow/custom_functions.dart' as functions;
import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'profile_preview_component_model.dart';
export 'profile_preview_component_model.dart';

class ProfilePreviewComponentWidget extends StatefulWidget {
  const ProfilePreviewComponentWidget({
    super.key,
    required this.userRef,
  });

  final DocumentReference? userRef;

  @override
  State<ProfilePreviewComponentWidget> createState() =>
      _ProfilePreviewComponentWidgetState();
}

class _ProfilePreviewComponentWidgetState
    extends State<ProfilePreviewComponentWidget> {
  late ProfilePreviewComponentModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ProfilePreviewComponentModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UsersRecord>(
      stream: UsersRecord.getDocument(widget!.userRef!),
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
          height: 272.0,
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).secondaryBackground,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(valueOrDefault<double>(
                FFAppConstants.borderRadius,
                0.0,
              )),
              topRight: Radius.circular(valueOrDefault<double>(
                FFAppConstants.borderRadius,
                0.0,
              )),
            ),
          ),
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(10.0, 10.0, 10.0, 0.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      wrapWithModel(
                        model: _model.userIconModel,
                        updateCallback: () => safeSetState(() {}),
                        child: UserIconWidget(
                          width: 50,
                          height: 50,
                          userDoc: containerUsersRecord,
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              10.0, 0.0, 0.0, 0.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
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
                                      fontSize: 16.0,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                              ),
                              Wrap(
                                spacing: 5.0,
                                runSpacing: 5.0,
                                alignment: WrapAlignment.start,
                                crossAxisAlignment: WrapCrossAlignment.start,
                                direction: Axis.horizontal,
                                runAlignment: WrapAlignment.start,
                                verticalDirection: VerticalDirection.down,
                                clipBehavior: Clip.none,
                                children: [
                                  if (containerUsersRecord.userSexPublic)
                                    wrapWithModel(
                                      model: _model.profileTagComponentModel1,
                                      updateCallback: () => safeSetState(() {}),
                                      child: ProfileTagComponentWidget(
                                        title: containerUsersRecord.userSex,
                                      ),
                                    ),
                                  if (containerUsersRecord.agePublic)
                                    AuthUserStreamWidget(
                                      builder: (context) => wrapWithModel(
                                        model: _model.profileTagComponentModel2,
                                        updateCallback: () =>
                                            safeSetState(() {}),
                                        child: ProfileTagComponentWidget(
                                          title:
                                              'Age: ${functions.ageFromBirthday(currentUserDocument?.birthday).toString()}',
                                        ),
                                      ),
                                    ),
                                  if (containerUsersRecord.heightPublic)
                                    wrapWithModel(
                                      model: _model.profileTagComponentModel3,
                                      updateCallback: () => safeSetState(() {}),
                                      child: ProfileTagComponentWidget(
                                        title:
                                            '${containerUsersRecord.heightFeet} ${containerUsersRecord.heightInch}',
                                      ),
                                    ),
                                  wrapWithModel(
                                    model: _model.profileTagComponentModel4,
                                    updateCallback: () => safeSetState(() {}),
                                    child: ProfileTagComponentWidget(
                                      title: containerUsersRecord.location,
                                    ),
                                  ),
                                  if (containerUsersRecord.weightPublic)
                                    wrapWithModel(
                                      model: _model.profileTagComponentModel5,
                                      updateCallback: () => safeSetState(() {}),
                                      child: ProfileTagComponentWidget(
                                        title:
                                            '${containerUsersRecord.weight.toString()}lbs',
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (widget!.userRef != currentUserReference)
                        FFButtonWidget(
                          onPressed: () async {
                            logFirebaseEvent(
                                'PROFILE_PREVIEW_COMPONENT_CHAT_BTN_ON_TA');
                            logFirebaseEvent('Button_action_block');
                            await action_blocks.openChatWithUser(
                              context,
                              userRef: widget!.userRef,
                            );
                          },
                          text: 'Chat',
                          options: FFButtonOptions(
                            height: 40.0,
                            padding: EdgeInsetsDirectional.fromSTEB(
                                8.0, 0.0, 8.0, 0.0),
                            iconPadding: EdgeInsetsDirectional.fromSTEB(
                                0.0, 0.0, 0.0, 0.0),
                            color: FlutterFlowTheme.of(context).primary,
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
                                  fontSize: 14.0,
                                  letterSpacing: 0.0,
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .titleSmall
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .titleSmall
                                      .fontStyle,
                                ),
                            elevation: 0.0,
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                    ],
                  ),
                  if (containerUsersRecord.habitsPublic)
                    Align(
                      alignment: AlignmentDirectional(-1.0, 0.0),
                      child: Padding(
                        padding:
                            EdgeInsetsDirectional.fromSTEB(0.0, 10.0, 0.0, 5.0),
                        child: Text(
                          'My Habits',
                          style:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    font: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w600,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                        ),
                      ),
                    ),
                  if (containerUsersRecord.habitsPublic)
                    StreamBuilder<List<HabitsRecord>>(
                      stream: queryHabitsRecord(
                        queryBuilder: (habitsRecord) => habitsRecord
                            .where(
                              'user',
                              isEqualTo: widget!.userRef,
                            )
                            .where(
                              'is_finished',
                              isEqualTo: false,
                            )
                            .where(
                              'behavior',
                              isNotEqualTo: '',
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
                        List<HabitsRecord> columnHabitsRecordList =
                            snapshot.data!;

                        return Column(
                          mainAxisSize: MainAxisSize.max,
                          children: List.generate(columnHabitsRecordList.length,
                                  (columnIndex) {
                            final columnHabitsRecord =
                                columnHabitsRecordList[columnIndex];
                            return Row(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8.0),
                                  child: Image.asset(
                                    'assets/images/goal_icon.png',
                                    width: 20.0,
                                    height: 20.0,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        6.0, 0.0, 0.0, 0.0),
                                    child: AutoSizeText(
                                      columnHabitsRecord.behavior,
                                      maxLines: 2,
                                      minFontSize: 8.0,
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
                                            fontSize: 12.0,
                                            letterSpacing: 0.0,
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          })
                              .divide(SizedBox(height: 7.0))
                              .addToEnd(SizedBox(height: 10.0)),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

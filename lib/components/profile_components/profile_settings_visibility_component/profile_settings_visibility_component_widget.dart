import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/flutter_flow/custom_functions.dart' as functions;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'profile_settings_visibility_component_model.dart';
export 'profile_settings_visibility_component_model.dart';

class ProfileSettingsVisibilityComponentWidget extends StatefulWidget {
  const ProfileSettingsVisibilityComponentWidget({super.key});

  @override
  State<ProfileSettingsVisibilityComponentWidget> createState() =>
      _ProfileSettingsVisibilityComponentWidgetState();
}

class _ProfileSettingsVisibilityComponentWidgetState
    extends State<ProfileSettingsVisibilityComponentWidget> {
  late ProfileSettingsVisibilityComponentModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model =
        createModel(context, () => ProfileSettingsVisibilityComponentModel());

    _model.goalSwitchValue =
        valueOrDefault<bool>(currentUserDocument?.goalsPublic, false);
    _model.habitSwitchValue =
        valueOrDefault<bool>(currentUserDocument?.habitsPublic, false);
    _model.profileSwitchValue =
        valueOrDefault<bool>(currentUserDocument?.profilePublic, false);
    _model.ageSwitchValue =
        valueOrDefault<bool>(currentUserDocument?.agePublic, false);
    _model.genderSwitchValue =
        valueOrDefault<bool>(currentUserDocument?.userSexPublic, false);
    _model.switchValue =
        valueOrDefault<bool>(currentUserDocument?.heightPublic, false);
    _model.weightSwitchValue =
        valueOrDefault<bool>(currentUserDocument?.weightPublic, false);
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
      width: double.infinity,
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).primary,
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 0.0),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 34.0,
                    height: 34.0,
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context).tertiary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              10.0, 0.0, 0.0, 0.0),
                          child: Text(
                            'Goals :',
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
                                  fontSize: 14.0,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.w600,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontStyle,
                                ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              2.0, 0.0, 0.0, 0.0),
                          child: Text(
                            _model.goalSwitchValue == true
                                ? 'Public'
                                : 'Private',
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
                                  color: FlutterFlowTheme.of(context).alternate,
                                  fontSize: 14.0,
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
                      ],
                    ),
                  ),
                  AuthUserStreamWidget(
                    builder: (context) => Switch.adaptive(
                      value: _model.goalSwitchValue!,
                      onChanged: (newValue) async {
                        safeSetState(() => _model.goalSwitchValue = newValue!);
                        if (newValue!) {
                          logFirebaseEvent(
                              'PROFILE_SETTINGS_VISIBILITY_COMPONENT_go');
                          logFirebaseEvent('goalSwitch_backend_call');

                          await currentUserReference!
                              .update(createUsersRecordData(
                            goalsPublic: _model.goalSwitchValue,
                          ));
                        } else {
                          logFirebaseEvent(
                              'PROFILE_SETTINGS_VISIBILITY_COMPONENT_go');
                          logFirebaseEvent('goalSwitch_backend_call');

                          await currentUserReference!
                              .update(createUsersRecordData(
                            goalsPublic: _model.goalSwitchValue,
                          ));
                        }
                      },
                      activeColor: FlutterFlowTheme.of(context).alternate,
                      activeTrackColor: FlutterFlowTheme.of(context).accent2,
                      inactiveTrackColor: FlutterFlowTheme.of(context).neutral,
                      inactiveThumbColor:
                          FlutterFlowTheme.of(context).alternate,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 0.0),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 34.0,
                    height: 34.0,
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context).tertiary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              10.0, 0.0, 0.0, 0.0),
                          child: Text(
                            'Habits:',
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
                                  fontSize: 14.0,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.w600,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontStyle,
                                ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              2.0, 0.0, 0.0, 0.0),
                          child: Text(
                            _model.habitSwitchValue == true
                                ? 'Public'
                                : 'Private',
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
                                  color: FlutterFlowTheme.of(context).alternate,
                                  fontSize: 14.0,
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
                      ],
                    ),
                  ),
                  AuthUserStreamWidget(
                    builder: (context) => Switch.adaptive(
                      value: _model.habitSwitchValue!,
                      onChanged: (newValue) async {
                        safeSetState(() => _model.habitSwitchValue = newValue!);
                        if (newValue!) {
                          logFirebaseEvent(
                              'PROFILE_SETTINGS_VISIBILITY_COMPONENT_ha');
                          logFirebaseEvent('habitSwitch_backend_call');

                          await currentUserReference!
                              .update(createUsersRecordData(
                            habitsPublic: _model.habitSwitchValue,
                          ));
                        } else {
                          logFirebaseEvent(
                              'PROFILE_SETTINGS_VISIBILITY_COMPONENT_ha');
                          logFirebaseEvent('habitSwitch_backend_call');

                          await currentUserReference!
                              .update(createUsersRecordData(
                            habitsPublic: _model.habitSwitchValue,
                          ));
                        }
                      },
                      activeColor: FlutterFlowTheme.of(context).alternate,
                      activeTrackColor: FlutterFlowTheme.of(context).accent2,
                      inactiveTrackColor: FlutterFlowTheme.of(context).neutral,
                      inactiveThumbColor:
                          FlutterFlowTheme.of(context).alternate,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 0.0),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 34.0,
                    height: 34.0,
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context).tertiary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              10.0, 0.0, 0.0, 0.0),
                          child: Text(
                            'Profile:',
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
                                  fontSize: 14.0,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.w600,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontStyle,
                                ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              2.0, 0.0, 0.0, 0.0),
                          child: AuthUserStreamWidget(
                            builder: (context) => Text(
                              valueOrDefault<bool>(
                                          currentUserDocument?.profilePublic,
                                          false) ==
                                      true
                                  ? 'Public'
                                  : 'Private',
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
                                    color:
                                        FlutterFlowTheme.of(context).alternate,
                                    fontSize: 14.0,
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
                      ],
                    ),
                  ),
                  AuthUserStreamWidget(
                    builder: (context) => Switch.adaptive(
                      value: _model.profileSwitchValue!,
                      onChanged: (newValue) async {
                        safeSetState(
                            () => _model.profileSwitchValue = newValue!);
                        if (newValue!) {
                          logFirebaseEvent(
                              'PROFILE_SETTINGS_VISIBILITY_COMPONENT_pr');
                          logFirebaseEvent('profileSwitch_backend_call');

                          await currentUserReference!
                              .update(createUsersRecordData(
                            profilePublic: _model.profileSwitchValue,
                          ));
                        } else {
                          logFirebaseEvent(
                              'PROFILE_SETTINGS_VISIBILITY_COMPONENT_pr');
                          logFirebaseEvent('profileSwitch_backend_call');

                          await currentUserReference!
                              .update(createUsersRecordData(
                            profilePublic: _model.profileSwitchValue,
                          ));
                        }
                      },
                      activeColor: FlutterFlowTheme.of(context).alternate,
                      activeTrackColor: FlutterFlowTheme.of(context).accent2,
                      inactiveTrackColor: FlutterFlowTheme.of(context).neutral,
                      inactiveThumbColor:
                          FlutterFlowTheme.of(context).alternate,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 0.0),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 34.0,
                    height: 34.0,
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context).tertiary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              10.0, 0.0, 0.0, 0.0),
                          child: Text(
                            'Age: ',
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
                                  fontSize: 14.0,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.w600,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontStyle,
                                ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              2.0, 0.0, 0.0, 0.0),
                          child: AuthUserStreamWidget(
                            builder: (context) => Text(
                              functions
                                  .ageFromBirthday(
                                      currentUserDocument?.birthday)
                                  .toString(),
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
                                    color:
                                        FlutterFlowTheme.of(context).alternate,
                                    fontSize: 14.0,
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
                      ],
                    ),
                  ),
                  AuthUserStreamWidget(
                    builder: (context) => Switch.adaptive(
                      value: _model.ageSwitchValue!,
                      onChanged: (newValue) async {
                        safeSetState(() => _model.ageSwitchValue = newValue!);
                        if (newValue!) {
                          logFirebaseEvent(
                              'PROFILE_SETTINGS_VISIBILITY_COMPONENT_ag');
                          logFirebaseEvent('ageSwitch_backend_call');

                          await currentUserReference!
                              .update(createUsersRecordData(
                            agePublic: _model.ageSwitchValue,
                          ));
                        } else {
                          logFirebaseEvent(
                              'PROFILE_SETTINGS_VISIBILITY_COMPONENT_ag');
                          logFirebaseEvent('ageSwitch_backend_call');

                          await currentUserReference!
                              .update(createUsersRecordData(
                            agePublic: _model.ageSwitchValue,
                          ));
                        }
                      },
                      activeColor: FlutterFlowTheme.of(context).alternate,
                      activeTrackColor: FlutterFlowTheme.of(context).accent2,
                      inactiveTrackColor: FlutterFlowTheme.of(context).neutral,
                      inactiveThumbColor:
                          FlutterFlowTheme.of(context).alternate,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 0.0),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 34.0,
                    height: 34.0,
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context).tertiary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              10.0, 0.0, 0.0, 0.0),
                          child: Text(
                            'Gender:',
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
                                  fontSize: 14.0,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.w600,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontStyle,
                                ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              2.0, 0.0, 0.0, 0.0),
                          child: AuthUserStreamWidget(
                            builder: (context) => Text(
                              valueOrDefault(currentUserDocument?.userSex, ''),
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
                                    color:
                                        FlutterFlowTheme.of(context).alternate,
                                    fontSize: 14.0,
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
                      ],
                    ),
                  ),
                  AuthUserStreamWidget(
                    builder: (context) => Switch.adaptive(
                      value: _model.genderSwitchValue!,
                      onChanged: (newValue) async {
                        safeSetState(
                            () => _model.genderSwitchValue = newValue!);
                        if (newValue!) {
                          logFirebaseEvent(
                              'PROFILE_SETTINGS_VISIBILITY_COMPONENT_ge');
                          logFirebaseEvent('genderSwitch_backend_call');

                          await currentUserReference!
                              .update(createUsersRecordData(
                            userSexPublic: _model.genderSwitchValue,
                          ));
                        } else {
                          logFirebaseEvent(
                              'PROFILE_SETTINGS_VISIBILITY_COMPONENT_ge');
                          logFirebaseEvent('genderSwitch_backend_call');

                          await currentUserReference!
                              .update(createUsersRecordData(
                            userSexPublic: _model.genderSwitchValue,
                          ));
                        }
                      },
                      activeColor: FlutterFlowTheme.of(context).alternate,
                      activeTrackColor: FlutterFlowTheme.of(context).accent2,
                      inactiveTrackColor: FlutterFlowTheme.of(context).neutral,
                      inactiveThumbColor:
                          FlutterFlowTheme.of(context).alternate,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 0.0),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 34.0,
                    height: 34.0,
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context).tertiary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              10.0, 0.0, 0.0, 0.0),
                          child: Text(
                            'Height:',
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
                                  fontSize: 14.0,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.w600,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontStyle,
                                ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              2.0, 0.0, 0.0, 0.0),
                          child: AuthUserStreamWidget(
                            builder: (context) => Text(
                              valueOrDefault(currentUserDocument?.height, 0)
                                  .toString(),
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
                                    color:
                                        FlutterFlowTheme.of(context).alternate,
                                    fontSize: 14.0,
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
                      ],
                    ),
                  ),
                  AuthUserStreamWidget(
                    builder: (context) => Switch.adaptive(
                      value: _model.switchValue!,
                      onChanged: (newValue) async {
                        safeSetState(() => _model.switchValue = newValue!);
                        if (newValue!) {
                          logFirebaseEvent(
                              'PROFILE_SETTINGS_VISIBILITY_COMPONENT_Sw');
                          logFirebaseEvent('Switch_backend_call');

                          await currentUserReference!
                              .update(createUsersRecordData(
                            heightPublic: _model.switchValue,
                          ));
                        } else {
                          logFirebaseEvent(
                              'PROFILE_SETTINGS_VISIBILITY_COMPONENT_Sw');
                          logFirebaseEvent('Switch_backend_call');

                          await currentUserReference!
                              .update(createUsersRecordData(
                            heightPublic: _model.switchValue,
                          ));
                        }
                      },
                      activeColor: FlutterFlowTheme.of(context).alternate,
                      activeTrackColor: FlutterFlowTheme.of(context).accent2,
                      inactiveTrackColor: FlutterFlowTheme.of(context).neutral,
                      inactiveThumbColor:
                          FlutterFlowTheme.of(context).alternate,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 0.0),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 34.0,
                    height: 34.0,
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context).tertiary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              10.0, 0.0, 0.0, 0.0),
                          child: Text(
                            'Weight:',
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
                                  fontSize: 14.0,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.w600,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontStyle,
                                ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              2.0, 0.0, 0.0, 0.0),
                          child: AuthUserStreamWidget(
                            builder: (context) => Text(
                              valueOrDefault(currentUserDocument?.weight, 0)
                                  .toString(),
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
                                    color:
                                        FlutterFlowTheme.of(context).alternate,
                                    fontSize: 14.0,
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
                      ],
                    ),
                  ),
                  AuthUserStreamWidget(
                    builder: (context) => Switch.adaptive(
                      value: _model.weightSwitchValue!,
                      onChanged: (newValue) async {
                        safeSetState(
                            () => _model.weightSwitchValue = newValue!);
                        if (newValue!) {
                          logFirebaseEvent(
                              'PROFILE_SETTINGS_VISIBILITY_COMPONENT_we');
                          logFirebaseEvent('weightSwitch_backend_call');

                          await currentUserReference!
                              .update(createUsersRecordData(
                            weightPublic: _model.weightSwitchValue,
                          ));
                        } else {
                          logFirebaseEvent(
                              'PROFILE_SETTINGS_VISIBILITY_COMPONENT_we');
                          logFirebaseEvent('weightSwitch_backend_call');

                          await currentUserReference!
                              .update(createUsersRecordData(
                            weightPublic: _model.weightSwitchValue,
                          ));
                        }
                      },
                      activeColor: FlutterFlowTheme.of(context).alternate,
                      activeTrackColor: FlutterFlowTheme.of(context).accent2,
                      inactiveTrackColor: FlutterFlowTheme.of(context).neutral,
                      inactiveThumbColor:
                          FlutterFlowTheme.of(context).alternate,
                    ),
                  ),
                ],
              ),
            ),
          ].divide(SizedBox(height: 10.0)).addToStart(SizedBox(height: 20.0)),
        ),
      ),
    );
  }
}

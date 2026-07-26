import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/instant_timer.dart';
import 'dart:ui';
import '/actions/actions.dart' as action_blocks;
import '/custom_code/actions/index.dart' as actions;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'habit_completed_snack_bar_model.dart';
export 'habit_completed_snack_bar_model.dart';

class HabitCompletedSnackBarWidget extends StatefulWidget {
  const HabitCompletedSnackBarWidget({
    super.key,
    String? title,
    required this.isCompletedType,
    required this.addNotesCallback,
  }) : this.title = title ?? 'title';

  final String title;
  final bool? isCompletedType;
  final Future Function()? addNotesCallback;

  @override
  State<HabitCompletedSnackBarWidget> createState() =>
      _HabitCompletedSnackBarWidgetState();
}

class _HabitCompletedSnackBarWidgetState
    extends State<HabitCompletedSnackBarWidget> {
  late HabitCompletedSnackBarModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => HabitCompletedSnackBarModel());

    // On component load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      logFirebaseEvent('HABIT_COMPLETED_SNACK_BAR_habitCompleted');
      logFirebaseEvent('habitCompletedSnackBar_start_periodic_ac');
      _model.instantTimer = InstantTimer.periodic(
        duration: Duration(milliseconds: 4000),
        callback: (timer) async {
          logFirebaseEvent('habitCompletedSnackBar_action_block');
          await action_blocks.clearTempValues(context);
          logFirebaseEvent('habitCompletedSnackBar_bottom_sheet');
          Navigator.pop(context);
          logFirebaseEvent('habitCompletedSnackBar_stop_periodic_act');
          _model.instantTimer?.cancel();
        },
        startImmediately: false,
      );
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
    context.watch<FFAppState>();

    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(10.0, 10.0, 10.0, 30.0),
      child: Container(
        width: double.infinity,
        height: 70.0,
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).background,
          borderRadius: BorderRadius.circular(valueOrDefault<double>(
            FFAppConstants.borderRadius,
            0.0,
          )),
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(10.0, 0.0, 10.0, 0.0),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Expanded(
                child: Text(
                  widget!.title,
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        font: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontStyle:
                              FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                        ),
                        color: FlutterFlowTheme.of(context).alternate,
                        letterSpacing: 0.0,
                        fontWeight: FontWeight.w600,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                      ),
                ),
              ),
              FFButtonWidget(
                onPressed: () async {
                  logFirebaseEvent('HABIT_COMPLETED_SNACK_BAR_ADD_NOTES_BTN_');
                  logFirebaseEvent('Button_execute_callback');
                  await widget.addNotesCallback?.call();
                  logFirebaseEvent('Button_bottom_sheet');
                  Navigator.pop(context);
                },
                text: 'Add Notes',
                options: FFButtonOptions(
                  height: 40.0,
                  padding: EdgeInsetsDirectional.fromSTEB(8.0, 0.0, 8.0, 0.0),
                  iconPadding:
                      EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                  color: Colors.transparent,
                  textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                        font: GoogleFonts.poppins(
                          fontWeight: FlutterFlowTheme.of(context)
                              .titleSmall
                              .fontWeight,
                          fontStyle:
                              FlutterFlowTheme.of(context).titleSmall.fontStyle,
                        ),
                        color: FlutterFlowTheme.of(context).primary,
                        fontSize: 14.0,
                        letterSpacing: 0.0,
                        fontWeight:
                            FlutterFlowTheme.of(context).titleSmall.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).titleSmall.fontStyle,
                      ),
                  elevation: 0.0,
                  borderSide: BorderSide(
                    color: Colors.transparent,
                    width: 1.0,
                  ),
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              FFButtonWidget(
                onPressed: () async {
                  logFirebaseEvent('HABIT_COMPLETED_SNACK_BAR_UNDO_BTN_ON_TA');
                  logFirebaseEvent('Button_backend_call');
                  _model.habit = await HabitsRecord.getDocumentOnce(
                      FFAppState().tempHabitRef!);
                  if (widget!.isCompletedType == true) {
                    logFirebaseEvent('Button_custom_action');
                    _model.lastTime =
                        await actions.getMostRecentCompletedDateTime(
                      _model.habit!,
                    );
                    logFirebaseEvent('Button_backend_call');

                    await FFAppState().tempHabitRef!.update({
                      ...mapToFirestore(
                        {
                          'complete': FieldValue.arrayRemove([_model.lastTime]),
                        },
                      ),
                    });
                  } else {
                    logFirebaseEvent('Button_backend_call');

                    await FFAppState()
                        .tempHabitRef!
                        .update(createHabitsRecordData(
                          finished: null,
                          isFinished: false,
                        ));
                    logFirebaseEvent('Button_backend_call');

                    var userActivityRecordReference =
                        UserActivityRecord.createDoc(currentUserReference!);
                    await userActivityRecordReference.set({
                      ...createUserActivityRecordData(
                        action: ActivityTypes.AddedNewHabit,
                        habit: FFAppState().tempHabitRef,
                        actionText:
                            'Habit Added Back - ${_model.habit?.behavior}',
                      ),
                      ...mapToFirestore(
                        {
                          'created': FieldValue.serverTimestamp(),
                        },
                      ),
                    });
                    _model.activityCopy =
                        UserActivityRecord.getDocumentFromData({
                      ...createUserActivityRecordData(
                        action: ActivityTypes.AddedNewHabit,
                        habit: FFAppState().tempHabitRef,
                        actionText:
                            'Habit Added Back - ${_model.habit?.behavior}',
                      ),
                      ...mapToFirestore(
                        {
                          'created': DateTime.now(),
                        },
                      ),
                    }, userActivityRecordReference);
                  }

                  logFirebaseEvent('Button_update_app_state');
                  FFAppState().tempHabitRef = null;
                  safeSetState(() {});
                  logFirebaseEvent('Button_bottom_sheet');
                  Navigator.pop(context);

                  safeSetState(() {});
                },
                text: 'Undo',
                options: FFButtonOptions(
                  height: 40.0,
                  padding: EdgeInsetsDirectional.fromSTEB(8.0, 0.0, 8.0, 0.0),
                  iconPadding:
                      EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                  color: Colors.transparent,
                  textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                        font: GoogleFonts.poppins(
                          fontWeight: FlutterFlowTheme.of(context)
                              .titleSmall
                              .fontWeight,
                          fontStyle:
                              FlutterFlowTheme.of(context).titleSmall.fontStyle,
                        ),
                        color: FlutterFlowTheme.of(context).error,
                        fontSize: 14.0,
                        letterSpacing: 0.0,
                        fontWeight:
                            FlutterFlowTheme.of(context).titleSmall.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).titleSmall.fontStyle,
                      ),
                  elevation: 0.0,
                  borderSide: BorderSide(
                    color: Colors.transparent,
                    width: 1.0,
                  ),
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

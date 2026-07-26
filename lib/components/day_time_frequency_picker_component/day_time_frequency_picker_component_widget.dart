import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_choice_chips.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import 'dart:ui';
import '/flutter_flow/custom_functions.dart' as functions;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'day_time_frequency_picker_component_model.dart';
export 'day_time_frequency_picker_component_model.dart';

class DayTimeFrequencyPickerComponentWidget extends StatefulWidget {
  const DayTimeFrequencyPickerComponentWidget({
    super.key,
    this.reminder,
  });

  final RemindersRecord? reminder;

  @override
  State<DayTimeFrequencyPickerComponentWidget> createState() =>
      _DayTimeFrequencyPickerComponentWidgetState();
}

class _DayTimeFrequencyPickerComponentWidgetState
    extends State<DayTimeFrequencyPickerComponentWidget> {
  late DayTimeFrequencyPickerComponentModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => DayTimeFrequencyPickerComponentModel());

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

    return Container(
      width: double.infinity,
      height: 250.0,
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.0),
          topRight: Radius.circular(20.0),
        ),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(20.0, 20.0, 20.0, 0.0),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Expanded(
                  child: FlutterFlowChoiceChips(
                    options: [
                      ChipData('Mon'),
                      ChipData('Tues'),
                      ChipData('Wed'),
                      ChipData('Thurs'),
                      ChipData('Fri'),
                      ChipData('Sat'),
                      ChipData('Sun')
                    ],
                    onChanged: (val) =>
                        safeSetState(() => _model.choiceChipsValues = val),
                    selectedChipStyle: ChipStyle(
                      backgroundColor: FlutterFlowTheme.of(context).secondary,
                      textStyle:
                          FlutterFlowTheme.of(context).bodyMedium.override(
                                font: GoogleFonts.poppins(
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontStyle,
                                ),
                                color: FlutterFlowTheme.of(context).alternate,
                                letterSpacing: 0.0,
                                fontWeight: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .fontWeight,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .fontStyle,
                              ),
                      iconColor: FlutterFlowTheme.of(context).alternate,
                      iconSize: 18.0,
                      elevation: 4.0,
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    unselectedChipStyle: ChipStyle(
                      backgroundColor:
                          FlutterFlowTheme.of(context).messageTextBG,
                      textStyle:
                          FlutterFlowTheme.of(context).bodyMedium.override(
                                font: GoogleFonts.poppins(
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontStyle,
                                ),
                                color: FlutterFlowTheme.of(context).secondary,
                                letterSpacing: 0.0,
                                fontWeight: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .fontWeight,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .fontStyle,
                              ),
                      iconColor: FlutterFlowTheme.of(context).secondary,
                      iconSize: 18.0,
                      elevation: 0.0,
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    chipSpacing: 12.0,
                    rowSpacing: 12.0,
                    multiselect: true,
                    initialized: _model.choiceChipsValues != null,
                    alignment: WrapAlignment.start,
                    controller: _model.choiceChipsValueController ??=
                        FormFieldController<List<String>>(
                      widget!.reminder?.days,
                    ),
                    wrapped: true,
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional(0.0, 0.0),
                  child: Padding(
                    padding:
                        EdgeInsetsDirectional.fromSTEB(10.0, 0.0, 0.0, 0.0),
                    child: FFButtonWidget(
                      onPressed: () async {
                        logFirebaseEvent(
                            'DAY_TIME_FREQUENCY_PICKER_COMPONENT_SELE');
                        if (_model.selectAllisSelected) {
                          logFirebaseEvent('Button_clear_all_select_all');
                          safeSetState(() =>
                              _model.choiceChipsValueController?.value = []);
                        } else {
                          logFirebaseEvent('Button_clear_all_select_all');
                          safeSetState(() => _model.choiceChipsValueController
                                  ?.value = List.from([
                                'Mon',
                                'Tues',
                                'Wed',
                                'Thurs',
                                'Fri',
                                'Sat',
                                'Sun'
                              ]));
                        }

                        logFirebaseEvent('Button_update_component_state');
                        _model.selectAllisSelected =
                            !_model.selectAllisSelected;
                        safeSetState(() {});
                      },
                      text: _model.selectAllisSelected
                          ? 'Unselect All'
                          : 'Select All',
                      options: FFButtonOptions(
                        height: 30.0,
                        padding: EdgeInsetsDirectional.fromSTEB(
                            10.0, 0.0, 10.0, 0.0),
                        iconPadding:
                            EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                        color: _model.selectAllisSelected
                            ? FlutterFlowTheme.of(context).secondary
                            : FlutterFlowTheme.of(context).messageTextBG,
                        textStyle:
                            FlutterFlowTheme.of(context).titleSmall.override(
                                  font: GoogleFonts.poppins(
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontStyle,
                                  ),
                                  color: _model.selectAllisSelected
                                      ? FlutterFlowTheme.of(context).alternate
                                      : FlutterFlowTheme.of(context).secondary,
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
                        borderSide: BorderSide(
                          color: Colors.transparent,
                          width: 1.0,
                        ),
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                      showLoadingIndicator: false,
                    ),
                  ),
                ),
              ],
            ),
            Align(
              alignment: AlignmentDirectional(0.0, 0.0),
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(0.0, 20.0, 0.0, 0.0),
                child: FFButtonWidget(
                  onPressed: () async {
                    logFirebaseEvent(
                        'DAY_TIME_FREQUENCY_PICKER_COMPONENT_BUTT');
                    logFirebaseEvent('Button_date_time_picker');

                    final _datePickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(getCurrentTimestamp),
                      builder: (context, child) {
                        return wrapInMaterialTimePickerTheme(
                          context,
                          child!,
                          headerBackgroundColor:
                              FlutterFlowTheme.of(context).primary,
                          headerForegroundColor:
                              FlutterFlowTheme.of(context).info,
                          headerTextStyle: FlutterFlowTheme.of(context)
                              .headlineLarge
                              .override(
                                font: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .headlineLarge
                                      .fontStyle,
                                ),
                                fontSize: 32.0,
                                letterSpacing: 0.0,
                                fontWeight: FontWeight.w600,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .headlineLarge
                                    .fontStyle,
                              ),
                          pickerBackgroundColor:
                              FlutterFlowTheme.of(context).secondaryBackground,
                          pickerForegroundColor:
                              FlutterFlowTheme.of(context).primaryText,
                          selectedDateTimeBackgroundColor:
                              FlutterFlowTheme.of(context).primary,
                          selectedDateTimeForegroundColor:
                              FlutterFlowTheme.of(context).info,
                          actionButtonForegroundColor:
                              FlutterFlowTheme.of(context).primaryText,
                          iconSize: 24.0,
                        );
                      },
                    );
                    if (_datePickedTime != null) {
                      safeSetState(() {
                        _model.datePicked = DateTime(
                          getCurrentTimestamp.year,
                          getCurrentTimestamp.month,
                          getCurrentTimestamp.day,
                          _datePickedTime.hour,
                          _datePickedTime.minute,
                        );
                      });
                    } else if (_model.datePicked != null) {
                      safeSetState(() {
                        _model.datePicked = getCurrentTimestamp;
                      });
                    }
                  },
                  text: valueOrDefault<String>(
                    () {
                      if (_model.datePicked != null) {
                        return valueOrDefault<String>(
                          dateTimeFormat("jm", _model.datePicked),
                          'Select Time',
                        );
                      } else if ((widget!.reminder != null) == true) {
                        return dateTimeFormat("jm", widget!.reminder?.time);
                      } else {
                        return 'Select Time';
                      }
                    }(),
                    'Select Time',
                  ),
                  options: FFButtonOptions(
                    height: 30.0,
                    padding:
                        EdgeInsetsDirectional.fromSTEB(24.0, 0.0, 24.0, 0.0),
                    iconPadding:
                        EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                    color: Color(0xFFCAD0E1),
                    textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                          font: GoogleFonts.poppins(
                            fontWeight: FlutterFlowTheme.of(context)
                                .titleSmall
                                .fontWeight,
                            fontStyle: FlutterFlowTheme.of(context)
                                .titleSmall
                                .fontStyle,
                          ),
                          color: FlutterFlowTheme.of(context).secondary,
                          fontSize: 16.0,
                          letterSpacing: 0.0,
                          fontWeight: FlutterFlowTheme.of(context)
                              .titleSmall
                              .fontWeight,
                          fontStyle:
                              FlutterFlowTheme.of(context).titleSmall.fontStyle,
                        ),
                    elevation: 0.0,
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
                padding: EdgeInsetsDirectional.fromSTEB(0.0, 10.0, 0.0, 0.0),
                child: FFButtonWidget(
                  onPressed: () async {
                    logFirebaseEvent(
                        'DAY_TIME_FREQUENCY_PICKER_COMPONENT_CONF');
                    if (widget!.reminder != null) {
                      logFirebaseEvent('Button_backend_call');

                      await widget!.reminder!.reference.update({
                        ...createRemindersRecordData(
                          time: functions.localToUTC(_model.datePicked!),
                          user: currentUserReference,
                          hour: functions.localToHour(_model.datePicked!),
                          minute: functions.localToMinute(_model.datePicked!),
                          timezoneOffset:
                              functions.localToUTCOffset(_model.datePicked!),
                          hourLocal: functions.localToHour(_model.datePicked!),
                          minuteLocal:
                              functions.localToMinute(_model.datePicked!),
                        ),
                        ...mapToFirestore(
                          {
                            'days': _model.choiceChipsValues,
                          },
                        ),
                      });
                    } else {
                      logFirebaseEvent('Button_backend_call');

                      var remindersRecordReference =
                          RemindersRecord.collection.doc();
                      await remindersRecordReference.set({
                        ...createRemindersRecordData(
                          time: functions.localToUTC(_model.datePicked!),
                          user: currentUserReference,
                          hour: functions.localToUTCHour(_model.datePicked!),
                          minute: functions.localToMinute(_model.datePicked!),
                          timezoneOffset:
                              functions.localToUTCOffset(_model.datePicked!),
                          hourLocal: functions.localToHour(_model.datePicked!),
                          minuteLocal:
                              functions.localToMinute(_model.datePicked!),
                        ),
                        ...mapToFirestore(
                          {
                            'days': _model.choiceChipsValues,
                          },
                        ),
                      });
                      _model.reminder = RemindersRecord.getDocumentFromData({
                        ...createRemindersRecordData(
                          time: functions.localToUTC(_model.datePicked!),
                          user: currentUserReference,
                          hour: functions.localToUTCHour(_model.datePicked!),
                          minute: functions.localToMinute(_model.datePicked!),
                          timezoneOffset:
                              functions.localToUTCOffset(_model.datePicked!),
                          hourLocal: functions.localToHour(_model.datePicked!),
                          minuteLocal:
                              functions.localToMinute(_model.datePicked!),
                        ),
                        ...mapToFirestore(
                          {
                            'days': _model.choiceChipsValues,
                          },
                        ),
                      }, remindersRecordReference);
                      // Sooooo ugly. Current limitation of the platform that I can't pass back the reminder ref to the main page. This is interim to assign the ref to an app state. blech
                      logFirebaseEvent('Button_update_app_state');
                      FFAppState().tempReminderRef = _model.reminder?.reference;
                    }

                    logFirebaseEvent('Button_bottom_sheet');
                    Navigator.pop(context, FFAppState().tempReminderRef);

                    safeSetState(() {});
                  },
                  text: 'Confirm',
                  options: FFButtonOptions(
                    height: 30.0,
                    padding:
                        EdgeInsetsDirectional.fromSTEB(24.0, 0.0, 24.0, 0.0),
                    iconPadding:
                        EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                    color: FlutterFlowTheme.of(context).secondary,
                    textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                          font: GoogleFonts.poppins(
                            fontWeight: FlutterFlowTheme.of(context)
                                .titleSmall
                                .fontWeight,
                            fontStyle: FlutterFlowTheme.of(context)
                                .titleSmall
                                .fontStyle,
                          ),
                          color: FlutterFlowTheme.of(context).alternate,
                          fontSize: 16.0,
                          letterSpacing: 0.0,
                          fontWeight: FlutterFlowTheme.of(context)
                              .titleSmall
                              .fontWeight,
                          fontStyle:
                              FlutterFlowTheme.of(context).titleSmall.fontStyle,
                        ),
                    elevation: 0.0,
                    borderSide: BorderSide(
                      color: Colors.transparent,
                      width: 1.0,
                    ),
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  showLoadingIndicator: false,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

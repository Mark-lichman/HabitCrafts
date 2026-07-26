import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/day_time_frequency_picker_component/day_time_frequency_picker_component_widget.dart';
import '/components/reminder_text_component_widget.dart';
import '/flutter_flow/flutter_flow_autocomplete_options_list.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'new_habit_component_model.dart';
export 'new_habit_component_model.dart';

class NewHabitComponentWidget extends StatefulWidget {
  const NewHabitComponentWidget({
    super.key,
    required this.type,
    required this.title,
    bool? isPrompt,
    this.autoCompleteOptions,
    bool? isCelebration,
    this.initialText,
    bool? promptRemind,
    bool? isGoal,
    required this.saveCallback,
  })  : this.isPrompt = isPrompt ?? false,
        this.isCelebration = isCelebration ?? false,
        this.promptRemind = promptRemind ?? false,
        this.isGoal = isGoal ?? false;

  final String? type;
  final String? title;
  final bool isPrompt;
  final List<String>? autoCompleteOptions;
  final bool isCelebration;
  final String? initialText;
  final bool promptRemind;
  final bool isGoal;
  final Future Function()? saveCallback;

  @override
  State<NewHabitComponentWidget> createState() =>
      _NewHabitComponentWidgetState();
}

class _NewHabitComponentWidgetState extends State<NewHabitComponentWidget> {
  late NewHabitComponentModel _model;

  bool expandableListenerRegistered = false;
  bool inputFieldFocusListenerRegistered = false;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => NewHabitComponentModel());

    _model.expandableExpandableController =
        ExpandableController(initialExpanded: false)
          ..addListener(() => safeSetState(() {}));
    _model.inputFieldTextController ??= TextEditingController(
        text: widget!.initialText != null && widget!.initialText != ''
            ? widget!.initialText
            : '');

    _model.switchValue = widget!.promptRemind;
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
      decoration: BoxDecoration(
        color: Color(0x00FFFFFF),
      ),
      child: Builder(builder: (_) {
        if (!expandableListenerRegistered) {
          expandableListenerRegistered = true;
          _model.expandableExpandableController.addListener(
            () async {
              logFirebaseEvent('NEW_HABIT_COMPONENT_Expandable_yjqpxoin_');
              logFirebaseEvent('Expandable_update_component_state');

              safeSetState(() {});
            },
          );
        }
        return Container(
          width: double.infinity,
          color: Colors.transparent,
          child: ExpandableNotifier(
            controller: _model.expandableExpandableController,
            child: ExpandablePanel(
              header: Container(
                width: double.infinity,
                height: 65.0,
                decoration: BoxDecoration(
                  color: () {
                    if (_model.expandableExpandableController.expanded!) {
                      return FlutterFlowTheme.of(context).secondary;
                    } else if (_model.inputFieldTextController.text != '') {
                      return FlutterFlowTheme.of(context).accent2;
                    } else {
                      return Color(0x40AAA4A4);
                    }
                  }(),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(valueOrDefault<double>(
                      FFAppConstants.borderRadius,
                      0.0,
                    )),
                    topRight: Radius.circular(valueOrDefault<double>(
                      FFAppConstants.borderRadius,
                      0.0,
                    )),
                    bottomLeft: Radius.circular(valueOrDefault<double>(
                      _model.expandableExpandableController.expanded!
                          ? 0.0
                          : FFAppConstants.borderRadius,
                      0.0,
                    )),
                    bottomRight: Radius.circular(valueOrDefault<double>(
                      _model.expandableExpandableController.expanded!
                          ? 0.0
                          : FFAppConstants.borderRadius,
                      0.0,
                    )),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 10.0, 0.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              10.0, 0.0, 0.0, 0.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                valueOrDefault<String>(
                                  widget!.type,
                                  'type',
                                ),
                                style: FlutterFlowTheme.of(context)
                                    .bodySmall
                                    .override(
                                      font: GoogleFonts.poppins(
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .bodySmall
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodySmall
                                            .fontStyle,
                                      ),
                                      letterSpacing: 0.0,
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodySmall
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodySmall
                                          .fontStyle,
                                    ),
                              ),
                              Text(
                                valueOrDefault<String>(
                                  widget!.initialText != null &&
                                          widget!.initialText != ''
                                      ? widget!.initialText
                                      : widget!.title,
                                  'title',
                                ),
                                maxLines: 1,
                                style: FlutterFlowTheme.of(context)
                                    .bodyLarge
                                    .override(
                                      font: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyLarge
                                            .fontStyle,
                                      ),
                                      color: FlutterFlowTheme.of(context)
                                          .alternate,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyLarge
                                          .fontStyle,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Builder(
                        builder: (context) {
                          if (_model.expandableExpandableController.expanded ??
                              false) {
                            return FlutterFlowIconButton(
                              borderRadius: 8.0,
                              buttonSize: 40.0,
                              icon: Icon(
                                Icons.check,
                                color: FlutterFlowTheme.of(context).alternate,
                                size: 24.0,
                              ),
                              onPressed: () async {
                                logFirebaseEvent(
                                    'NEW_HABIT_COMPONENT_check_ICN_ON_TAP');
                                logFirebaseEvent('IconButton_execute_callback');
                                await widget.saveCallback?.call();
                                logFirebaseEvent(
                                    'IconButton_update_component_state');

                                safeSetState(() {});
                              },
                            );
                          } else {
                            return FlutterFlowIconButton(
                              borderRadius: 8.0,
                              buttonSize: 40.0,
                              icon: Icon(
                                Icons.edit_outlined,
                                color: FlutterFlowTheme.of(context).alternate,
                                size: 24.0,
                              ),
                              onPressed: (true == true)
                                  ? null
                                  : () {
                                      print('IconButton pressed ...');
                                    },
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              collapsed: Container(
                width: MediaQuery.sizeOf(context).width * 1.0,
                height: 0.0,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).secondaryBackground,
                ),
              ),
              expanded: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Container(
                    width: double.infinity,
                    height: widget!.isCelebration ? 142.0 : 117.0,
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context).secondaryBackground,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(valueOrDefault<double>(
                          () {
                            if (widget!.isCelebration) {
                              return 0.0;
                            } else if (widget!.isGoal) {
                              return 0.0;
                            } else {
                              return FFAppConstants.borderRadius;
                            }
                          }(),
                          0.0,
                        )),
                        bottomRight: Radius.circular(valueOrDefault<double>(
                          () {
                            if (widget!.isCelebration) {
                              return 0.0;
                            } else if (widget!.isGoal) {
                              return 0.0;
                            } else {
                              return FFAppConstants.borderRadius;
                            }
                          }(),
                          0.0,
                        )),
                      ),
                    ),
                    child: Padding(
                      padding:
                          EdgeInsetsDirectional.fromSTEB(0.0, 5.0, 0.0, 0.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          if (widget!.isCelebration)
                            Align(
                              alignment: AlignmentDirectional(1.0, 0.0),
                              child: Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    0.0, 3.0, 10.0, 0.0),
                                child: Container(
                                  width: 140.0,
                                  height: 17.0,
                                  decoration: BoxDecoration(
                                    color: FlutterFlowTheme.of(context).accent1,
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            0.0, 0.0, 3.0, 0.0),
                                        child: Icon(
                                          Icons.lightbulb_outline,
                                          color: FlutterFlowTheme.of(context)
                                              .alternate,
                                          size: 8.0,
                                        ),
                                      ),
                                      Text(
                                        'Something that brings you joy!',
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
                                              fontSize: 8.0,
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
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                10.0, 5.0, 10.0, 10.0),
                            child: Container(
                              width: double.infinity,
                              height: 97.0,
                              decoration: BoxDecoration(
                                color: Color(0x7FCED2D9),
                                borderRadius: BorderRadius.circular(5.0),
                              ),
                              child: Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    8.0, 0.0, 8.0, 0.0),
                                child: Autocomplete<String>(
                                  initialValue: TextEditingValue(
                                      text: widget!.initialText != null &&
                                              widget!.initialText != ''
                                          ? widget!.initialText!
                                          : ''),
                                  optionsBuilder: (textEditingValue) {
                                    if (textEditingValue.text == '') {
                                      return const Iterable<String>.empty();
                                    }
                                    return widget!.autoCompleteOptions!
                                        .where((option) {
                                      final lowercaseOption =
                                          option.toLowerCase();
                                      return lowercaseOption.contains(
                                          textEditingValue.text.toLowerCase());
                                    });
                                  },
                                  optionsViewBuilder:
                                      (context, onSelected, options) {
                                    return AutocompleteOptionsList(
                                      textFieldKey: _model.inputFieldKey,
                                      textController:
                                          _model.inputFieldTextController!,
                                      options: options.toList(),
                                      onSelected: onSelected,
                                      textStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            font: GoogleFonts.poppins(
                                              fontWeight: FontWeight.bold,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                            color: Color(0xFF67686D),
                                            fontSize: 16.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.bold,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                      textHighlightStyle: TextStyle(),
                                      elevation: 4.0,
                                      optionBackgroundColor:
                                          FlutterFlowTheme.of(context).tertiary,
                                      optionHighlightColor:
                                          FlutterFlowTheme.of(context).accent2,
                                      maxHeight: 200.0,
                                    );
                                  },
                                  onSelected: (String selection) {
                                    safeSetState(() => _model
                                        .inputFieldSelectedOption = selection);
                                    FocusScope.of(context).unfocus();
                                  },
                                  fieldViewBuilder: (
                                    context,
                                    textEditingController,
                                    focusNode,
                                    onEditingComplete,
                                  ) {
                                    _model.inputFieldFocusNode = focusNode;
                                    if (!inputFieldFocusListenerRegistered) {
                                      inputFieldFocusListenerRegistered = true;
                                      _model.inputFieldFocusNode!.addListener(
                                        () async {
                                          logFirebaseEvent(
                                              'NEW_HABIT_COMPONENT_InputField_ON_FOCUS_');
                                          logFirebaseEvent(
                                              'InputField_update_component_state');

                                          _model.updatePage(() {});
                                        },
                                      );
                                    }
                                    _model.inputFieldTextController =
                                        textEditingController;
                                    return TextFormField(
                                      key: _model.inputFieldKey,
                                      controller: textEditingController,
                                      focusNode: focusNode,
                                      onEditingComplete: onEditingComplete,
                                      onFieldSubmitted: (_) async {
                                        logFirebaseEvent(
                                            'NEW_HABIT_COMPONENT_InputField_ON_TEXTFI');
                                        logFirebaseEvent(
                                            'InputField_custom_action');
                                        await actions.hideKeyboard();
                                      },
                                      autofocus: true,
                                      textInputAction: TextInputAction.done,
                                      obscureText: false,
                                      decoration: InputDecoration(
                                        labelStyle: FlutterFlowTheme.of(context)
                                            .labelMedium
                                            .override(
                                              font: GoogleFonts.poppins(
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .labelMedium
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .labelMedium
                                                        .fontStyle,
                                              ),
                                              letterSpacing: 0.0,
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .fontStyle,
                                            ),
                                        hintStyle: FlutterFlowTheme.of(context)
                                            .labelMedium
                                            .override(
                                              font: GoogleFonts.poppins(
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .labelMedium
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .labelMedium
                                                        .fontStyle,
                                              ),
                                              letterSpacing: 0.0,
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .fontStyle,
                                            ),
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        errorBorder: InputBorder.none,
                                        focusedErrorBorder: InputBorder.none,
                                      ),
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            font: GoogleFonts.poppins(
                                              fontWeight: FontWeight.bold,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                            color: Color(0xFF67686D),
                                            fontSize: 16.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.bold,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                      maxLines: null,
                                      validator: _model
                                          .inputFieldTextControllerValidator
                                          .asValidator(context),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (widget!.isPrompt)
                    Padding(
                      padding:
                          EdgeInsetsDirectional.fromSTEB(0.0, 5.0, 0.0, 0.0),
                      child: Container(
                        width: double.infinity,
                        height: 65.0,
                        decoration: BoxDecoration(
                          color:
                              FlutterFlowTheme.of(context).secondaryBackground,
                          borderRadius: BorderRadius.circular(5.0),
                        ),
                        child: Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              10.0, 0.0, 10.0, 0.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Align(
                                  alignment: AlignmentDirectional(-1.0, 0.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Remind me',
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              font: GoogleFonts.poppins(
                                                fontWeight: FontWeight.normal,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontStyle,
                                              ),
                                              fontSize: 16.0,
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.normal,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                      ),
                                      if (FFAppState().tempReminderRef != null)
                                        wrapWithModel(
                                          model:
                                              _model.reminderTextComponentModel,
                                          updateCallback: () =>
                                              safeSetState(() {}),
                                          child: ReminderTextComponentWidget(
                                            reminderRef:
                                                FFAppState().tempReminderRef!,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Switch.adaptive(
                                    value: _model.switchValue!,
                                    onChanged: (newValue) async {
                                      safeSetState(
                                          () => _model.switchValue = newValue!);
                                    },
                                    activeColor:
                                        FlutterFlowTheme.of(context).alternate,
                                    activeTrackColor:
                                        FlutterFlowTheme.of(context).accent2,
                                    inactiveTrackColor:
                                        FlutterFlowTheme.of(context).neutral,
                                    inactiveThumbColor:
                                        FlutterFlowTheme.of(context)
                                            .secondaryText,
                                  ),
                                  FlutterFlowIconButton(
                                    borderRadius: 20.0,
                                    borderWidth: 1.0,
                                    buttonSize: 40.0,
                                    icon: Icon(
                                      Icons.unfold_more,
                                      color: FlutterFlowTheme.of(context)
                                          .primaryText,
                                      size: 24.0,
                                    ),
                                    onPressed: () async {
                                      logFirebaseEvent(
                                          'NEW_HABIT_COMPONENT_unfold_more_ICN_ON_T');
                                      if (FFAppState().tempReminderRef !=
                                          null) {
                                        logFirebaseEvent(
                                            'IconButton_backend_call');
                                        _model.reminder = await RemindersRecord
                                            .getDocumentOnce(
                                                FFAppState().tempReminderRef!);
                                        logFirebaseEvent(
                                            'IconButton_bottom_sheet');
                                        await showModalBottomSheet(
                                          isScrollControlled: true,
                                          backgroundColor: Colors.transparent,
                                          enableDrag: false,
                                          context: context,
                                          builder: (context) {
                                            return Padding(
                                              padding: MediaQuery.viewInsetsOf(
                                                  context),
                                              child:
                                                  DayTimeFrequencyPickerComponentWidget(
                                                reminder: _model.reminder,
                                              ),
                                            );
                                          },
                                        ).then((value) => safeSetState(() {}));
                                      } else {
                                        logFirebaseEvent(
                                            'IconButton_bottom_sheet');
                                        await showModalBottomSheet(
                                          isScrollControlled: true,
                                          backgroundColor: Colors.transparent,
                                          enableDrag: false,
                                          context: context,
                                          builder: (context) {
                                            return Padding(
                                              padding: MediaQuery.viewInsetsOf(
                                                  context),
                                              child:
                                                  DayTimeFrequencyPickerComponentWidget(),
                                            );
                                          },
                                        ).then((value) => safeSetState(() {}));
                                      }

                                      logFirebaseEvent(
                                          'IconButton_set_form_field');
                                      safeSetState(() {
                                        _model.switchValue = true;
                                      });

                                      safeSetState(() {});
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (widget!.isCelebration)
                    Container(
                      width: double.infinity,
                      height: 90.0,
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).secondaryBackground,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(5.0),
                          bottomRight: Radius.circular(5.0),
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(
                            10.0, 10.0, 10.0, 0.0),
                        child:
                            StreamBuilder<List<CelebrationSuggestionsRecord>>(
                          stream: queryCelebrationSuggestionsRecord(),
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
                            List<CelebrationSuggestionsRecord>
                                wrapCelebrationSuggestionsRecordList =
                                snapshot.data!;

                            return Wrap(
                              spacing: 5.0,
                              runSpacing: 5.0,
                              alignment: WrapAlignment.start,
                              crossAxisAlignment: WrapCrossAlignment.start,
                              direction: Axis.horizontal,
                              runAlignment: WrapAlignment.start,
                              verticalDirection: VerticalDirection.down,
                              clipBehavior: Clip.antiAlias,
                              children: List.generate(
                                  wrapCelebrationSuggestionsRecordList.length,
                                  (wrapIndex) {
                                final wrapCelebrationSuggestionsRecord =
                                    wrapCelebrationSuggestionsRecordList[
                                        wrapIndex];
                                return FFButtonWidget(
                                  onPressed: () async {
                                    logFirebaseEvent(
                                        'NEW_HABIT_COMPONENT_BUTTON_BTN_ON_TAP');
                                    logFirebaseEvent('Button_set_form_field');
                                    safeSetState(() {
                                      _model.inputFieldTextController?.text =
                                          wrapCelebrationSuggestionsRecord.name;
                                    });
                                  },
                                  text: wrapCelebrationSuggestionsRecord.name,
                                  options: FFButtonOptions(
                                    height: 28.0,
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        8.0, 0.0, 8.0, 0.0),
                                    iconPadding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 0.0, 0.0, 0.0),
                                    color: Color(0xFFCAD0E1),
                                    textStyle: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .override(
                                          font: GoogleFonts.poppins(
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .titleSmall
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .titleSmall
                                                    .fontStyle,
                                          ),
                                          color: FlutterFlowTheme.of(context)
                                              .secondary,
                                          fontSize: 12.0,
                                          letterSpacing: 0.0,
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .titleSmall
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .titleSmall
                                                  .fontStyle,
                                        ),
                                    elevation: 0.0,
                                    borderSide: BorderSide(
                                      color: Colors.transparent,
                                      width: 1.0,
                                    ),
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                );
                              }),
                            );
                          },
                        ),
                      ),
                    ),
                  if (valueOrDefault<bool>(
                    widget!.isGoal,
                    false,
                  ))
                    Container(
                      width: double.infinity,
                      height: 80.0,
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).secondaryBackground,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(5.0),
                          bottomRight: Radius.circular(5.0),
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(
                            10.0, 10.0, 10.0, 0.0),
                        child: StreamBuilder<List<GoalsRecord>>(
                          stream: queryGoalsRecord(
                            queryBuilder: (goalsRecord) => goalsRecord
                                .where(
                                  'user',
                                  isEqualTo: currentUserReference,
                                )
                                .orderBy('last_used', descending: true),
                            limit: 3,
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
                            List<GoalsRecord> wrapGoalsRecordList =
                                snapshot.data!;

                            return Wrap(
                              spacing: 5.0,
                              runSpacing: 5.0,
                              alignment: WrapAlignment.start,
                              crossAxisAlignment: WrapCrossAlignment.start,
                              direction: Axis.horizontal,
                              runAlignment: WrapAlignment.start,
                              verticalDirection: VerticalDirection.down,
                              clipBehavior: Clip.antiAlias,
                              children: List.generate(
                                  wrapGoalsRecordList.length, (wrapIndex) {
                                final wrapGoalsRecord =
                                    wrapGoalsRecordList[wrapIndex];
                                return FFButtonWidget(
                                  onPressed: () async {
                                    logFirebaseEvent(
                                        'NEW_HABIT_COMPONENT_BUTTON_BTN_ON_TAP');
                                    logFirebaseEvent('Button_set_form_field');
                                    safeSetState(() {
                                      _model.inputFieldTextController?.text =
                                          wrapGoalsRecord.name;
                                    });
                                  },
                                  text: wrapGoalsRecord.name,
                                  options: FFButtonOptions(
                                    height: 28.0,
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        8.0, 0.0, 8.0, 0.0),
                                    iconPadding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 0.0, 0.0, 0.0),
                                    color: Color(0xFFCAD0E1),
                                    textStyle: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .override(
                                          font: GoogleFonts.poppins(
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .titleSmall
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .titleSmall
                                                    .fontStyle,
                                          ),
                                          color: FlutterFlowTheme.of(context)
                                              .secondary,
                                          fontSize: 12.0,
                                          letterSpacing: 0.0,
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .titleSmall
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .titleSmall
                                                  .fontStyle,
                                        ),
                                    elevation: 0.0,
                                    borderSide: BorderSide(
                                      color: Colors.transparent,
                                      width: 1.0,
                                    ),
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                );
                              }),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
              theme: ExpandableThemeData(
                tapHeaderToExpand: true,
                tapBodyToExpand: false,
                tapBodyToCollapse: false,
                headerAlignment: ExpandablePanelHeaderAlignment.center,
                hasIcon: false,
              ),
            ),
          ),
        );
      }),
    );
  }
}

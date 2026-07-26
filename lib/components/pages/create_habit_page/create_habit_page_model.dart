import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/components/habit_components/new_habit_component/new_habit_component_widget.dart';
import '/components/toolip_component_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/actions/actions.dart' as action_blocks;
import '/index.dart';
import 'create_habit_page_widget.dart' show CreateHabitPageWidget;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class CreateHabitPageModel extends FlutterFlowModel<CreateHabitPageWidget> {
  ///  Local state fields for this page.

  DocumentReference? newHabitRef;

  ///  State fields for stateful widgets in this page.

  // Model for toolipComponent component.
  late ToolipComponentModel toolipComponentModel;
  // Model for exisitingBehaviorComponent.
  late NewHabitComponentModel exisitingBehaviorComponentModel;
  // Model for exisitingPromptComponent.
  late NewHabitComponentModel exisitingPromptComponentModel;
  // Model for exisitingCelebrationComponent.
  late NewHabitComponentModel exisitingCelebrationComponentModel;
  // Model for existingGoalComponent.
  late NewHabitComponentModel existingGoalComponentModel;
  // Model for existingWhyComponent.
  late NewHabitComponentModel existingWhyComponentModel;
  // Model for newBehaviorComponent.
  late NewHabitComponentModel newBehaviorComponentModel;
  // Model for newPromptComponent.
  late NewHabitComponentModel newPromptComponentModel;
  // Model for newCelebrationComponent.
  late NewHabitComponentModel newCelebrationComponentModel;
  // Model for newGoalComponent.
  late NewHabitComponentModel newGoalComponentModel;
  // Model for newWhyComponent.
  late NewHabitComponentModel newWhyComponentModel;
  // Stores action output result for [Firestore Query - Query a collection] action in Button widget.
  List<HabitsRecord>? existinghabits;
  // Stores action output result for [Firestore Query - Query a collection] action in Button widget.
  GoalsRecord? newGoal;
  // Stores action output result for [Backend Call - Create Document] action in Button widget.
  GoalsRecord? createdGoal;
  // Stores action output result for [Firestore Query - Query a collection] action in Button widget.
  GoalsRecord? goalCopy;
  // Stores action output result for [Backend Call - Create Document] action in Button widget.
  HabitsRecord? newHabit;
  // Stores action output result for [Backend Call - Create Document] action in Button widget.
  HabitsRecord? newHabitNoGoal;

  @override
  void initState(BuildContext context) {
    toolipComponentModel = createModel(context, () => ToolipComponentModel());
    exisitingBehaviorComponentModel =
        createModel(context, () => NewHabitComponentModel());
    exisitingPromptComponentModel =
        createModel(context, () => NewHabitComponentModel());
    exisitingCelebrationComponentModel =
        createModel(context, () => NewHabitComponentModel());
    existingGoalComponentModel =
        createModel(context, () => NewHabitComponentModel());
    existingWhyComponentModel =
        createModel(context, () => NewHabitComponentModel());
    newBehaviorComponentModel =
        createModel(context, () => NewHabitComponentModel());
    newPromptComponentModel =
        createModel(context, () => NewHabitComponentModel());
    newCelebrationComponentModel =
        createModel(context, () => NewHabitComponentModel());
    newGoalComponentModel =
        createModel(context, () => NewHabitComponentModel());
    newWhyComponentModel = createModel(context, () => NewHabitComponentModel());
  }

  @override
  void dispose() {
    toolipComponentModel.dispose();
    exisitingBehaviorComponentModel.dispose();
    exisitingPromptComponentModel.dispose();
    exisitingCelebrationComponentModel.dispose();
    existingGoalComponentModel.dispose();
    existingWhyComponentModel.dispose();
    newBehaviorComponentModel.dispose();
    newPromptComponentModel.dispose();
    newCelebrationComponentModel.dispose();
    newGoalComponentModel.dispose();
    newWhyComponentModel.dispose();
  }

  /// Action blocks.
  Future updateHabit(BuildContext context) async {
    GoalsRecord? existingGoal;
    GoalsRecord? createdGoal;

    logFirebaseEvent('updateHabit_firestore_query');
    existingGoal = await queryGoalsRecordOnce(
      queryBuilder: (goalsRecord) => goalsRecord
          .where(
            'name',
            isEqualTo: existingGoalComponentModel.inputFieldTextController.text,
          )
          .where(
            'user',
            isEqualTo: currentUserReference,
          ),
      singleRecord: true,
    ).then((s) => s.firstOrNull);
    if (existingGoal != null) {
      logFirebaseEvent('updateHabit_backend_call');

      await widget!.existingHabit!.reference.update(createHabitsRecordData(
        behavior: exisitingBehaviorComponentModel.inputFieldTextController.text,
        celebration:
            exisitingCelebrationComponentModel.inputFieldTextController.text,
        goal: existingGoal?.reference,
        prompt: exisitingPromptComponentModel.inputFieldTextController.text,
        promptRemind: exisitingPromptComponentModel.switchValue,
        why: existingWhyComponentModel.inputFieldTextController.text,
        reminder: exisitingPromptComponentModel.switchValue!
            ? FFAppState().tempReminderRef
            : null,
      ));
    } else {
      if (existingGoalComponentModel.inputFieldTextController.text == '') {
        logFirebaseEvent('updateHabit_backend_call');

        await widget!.existingHabit!.reference.update(createHabitsRecordData(
          behavior:
              exisitingBehaviorComponentModel.inputFieldTextController.text,
          celebration:
              exisitingCelebrationComponentModel.inputFieldTextController.text,
          prompt: exisitingPromptComponentModel.inputFieldTextController.text,
          promptRemind: exisitingPromptComponentModel.switchValue,
          why: existingWhyComponentModel.inputFieldTextController.text,
        ));
      } else {
        logFirebaseEvent('updateHabit_backend_call');

        var goalsRecordReference = GoalsRecord.collection.doc();
        await goalsRecordReference.set(createGoalsRecordData(
          isPublic: false,
          name: existingGoalComponentModel.inputFieldTextController.text,
          user: currentUserReference,
        ));
        createdGoal = GoalsRecord.getDocumentFromData(
            createGoalsRecordData(
              isPublic: false,
              name: existingGoalComponentModel.inputFieldTextController.text,
              user: currentUserReference,
            ),
            goalsRecordReference);
        logFirebaseEvent('updateHabit_backend_call');

        await widget!.existingHabit!.reference.update(createHabitsRecordData(
          behavior:
              exisitingBehaviorComponentModel.inputFieldTextController.text,
          celebration:
              exisitingCelebrationComponentModel.inputFieldTextController.text,
          goal: createdGoal?.reference,
          prompt: exisitingPromptComponentModel.inputFieldTextController.text,
          promptRemind: exisitingPromptComponentModel.switchValue,
          why: existingWhyComponentModel.inputFieldTextController.text,
        ));
      }
    }

    logFirebaseEvent('updateHabit_action_block');
    await action_blocks.clearTempValues(context);
    logFirebaseEvent('updateHabit_show_snack_bar');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Habit Updated',
          style: FlutterFlowTheme.of(context).titleSmall.override(
                font: GoogleFonts.poppins(
                  fontWeight:
                      FlutterFlowTheme.of(context).titleSmall.fontWeight,
                  fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
                ),
                color: FlutterFlowTheme.of(context).alternate,
                letterSpacing: 0.0,
                fontWeight: FlutterFlowTheme.of(context).titleSmall.fontWeight,
                fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
              ),
        ),
        duration: Duration(milliseconds: 4000),
        backgroundColor: FlutterFlowTheme.of(context).background,
      ),
    );
  }
}

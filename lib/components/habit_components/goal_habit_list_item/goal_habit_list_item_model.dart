import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/index.dart';
import 'goal_habit_list_item_widget.dart' show GoalHabitListItemWidget;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class GoalHabitListItemModel extends FlutterFlowModel<GoalHabitListItemWidget> {
  ///  State fields for stateful widgets in this component.

  // State field(s) for Expandable widget.
  late ExpandableController expandableExpandableController;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    expandableExpandableController.dispose();
  }

  /// Action blocks.
  Future finishHabitActionBlock(
    BuildContext context, {
    HabitsRecord? habit,
  }) async {
    UserActivityRecord? activityCopy;

    logFirebaseEvent('finishHabitActionBlock_backend_call');

    var userActivityRecordReference =
        UserActivityRecord.createDoc(currentUserReference!);
    await userActivityRecordReference.set({
      ...createUserActivityRecordData(
        action: ActivityTypes.FinishedHabit,
        habit: habit?.reference,
        actionText: 'Habit Removed - ${habit?.behavior}',
      ),
      ...mapToFirestore(
        {
          'created': FieldValue.serverTimestamp(),
        },
      ),
    });
    activityCopy = UserActivityRecord.getDocumentFromData({
      ...createUserActivityRecordData(
        action: ActivityTypes.FinishedHabit,
        habit: habit?.reference,
        actionText: 'Habit Removed - ${habit?.behavior}',
      ),
      ...mapToFirestore(
        {
          'created': DateTime.now(),
        },
      ),
    }, userActivityRecordReference);
    if (habit?.hasReminder() == true) {
      logFirebaseEvent('finishHabitActionBlock_backend_call');
      await habit!.reminder!.delete();
    }
    logFirebaseEvent('finishHabitActionBlock_backend_call');

    await habit!.reference.update(createHabitsRecordData(
      isFinished: true,
      finished: getCurrentTimestamp,
      reminder: null,
    ));
    logFirebaseEvent('finishHabitActionBlock_update_app_state');
    FFAppState().tempHabitRef = habit?.reference;
    FFAppState().tempActivityRef = activityCopy?.reference;
  }

  Future editHabitActionBlock(
    BuildContext context, {
    required HabitsRecord? habit,
  }) async {
    logFirebaseEvent('editHabitActionBlock_update_app_state');
    FFAppState().tempReminderRef = habit?.reminder;
    logFirebaseEvent('editHabitActionBlock_navigate_to');

    context.pushNamed(
      CreateHabitPageWidget.routeName,
      queryParameters: {
        'existingHabit': serializeParam(
          habit,
          ParamType.Document,
        ),
      }.withoutNulls,
      extra: <String, dynamic>{
        'existingHabit': habit,
      },
    );
  }

  Future completeHabitActionBlock(
    BuildContext context, {
    required HabitsRecord? habit,
  }) async {
    UserActivityRecord? activity;

    logFirebaseEvent('completeHabitActionBlock_backend_call');

    await habit!.reference.update({
      ...mapToFirestore(
        {
          'complete': FieldValue.arrayUnion([getCurrentTimestamp]),
        },
      ),
    });
    logFirebaseEvent('completeHabitActionBlock_backend_call');

    var userActivityRecordReference =
        UserActivityRecord.createDoc(currentUserReference!);
    await userActivityRecordReference.set({
      ...createUserActivityRecordData(
        action: ActivityTypes.CompletedHabit,
        habit: habit?.reference,
        actionText: 'Habit Completed - ${habit?.behavior}',
      ),
      ...mapToFirestore(
        {
          'created': FieldValue.serverTimestamp(),
        },
      ),
    });
    activity = UserActivityRecord.getDocumentFromData({
      ...createUserActivityRecordData(
        action: ActivityTypes.CompletedHabit,
        habit: habit?.reference,
        actionText: 'Habit Completed - ${habit?.behavior}',
      ),
      ...mapToFirestore(
        {
          'created': DateTime.now(),
        },
      ),
    }, userActivityRecordReference);
    logFirebaseEvent('completeHabitActionBlock_update_app_stat');
    FFAppState().tempHabitRef = habit?.reference;
    FFAppState().tempActivityRef = activity?.reference;
  }
}

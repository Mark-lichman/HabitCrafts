// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/backend/schema/enums/enums.dart';
import '/actions/actions.dart' as action_blocks;
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/components/habit_components/active_habit_list_item/active_habit_list_item_widget.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class SlidingListItemWidget extends StatefulWidget {
  const SlidingListItemWidget({
    super.key,
    this.width,
    this.height,
    this.title,
    this.habit,
    required this.finishAction,
    required this.editAction,
    required this.completeAction,
  });

  final double? width;
  final double? height;
  final String? title;
  final HabitsRecord? habit;
  final Future Function() finishAction;
  final Future Function() editAction;
  final Future Function() completeAction;

  @override
  State<SlidingListItemWidget> createState() => _SlidingListItemWidgetState();
}

class _SlidingListItemWidgetState extends State<SlidingListItemWidget> {
  // final controller = SlidableController();

  @override
  Widget build(BuildContext context) {
    Color textColor = Color(0xFF2A405D);
    return Slidable(
      // Specify a key if the Slidable is dismissible.
      key: const ValueKey(0),
      //controller: controller,
      // The start action pane is the one at the left or the top side.
      startActionPane: ActionPane(
        // A motion is a widget used to control how the pane animates.
        motion: const ScrollMotion(),

        // A pane can dismiss the Slidable.
        dismissible: null, //DismissiblePane(onDismissed: () {}),

        // All actions are defined in the children parameter.
        children: [
          // A SlidableAction can have an icon and/or a label.
          Builder(
            builder: (cont) {
              return Padding(
                padding: EdgeInsets.fromLTRB(0, 0, 5, 0),
                child: SizedBox(
                  height: 80,
                  width: 80,
                  child: ElevatedButton(
                    onPressed: () {
                      widget.finishAction();
                      Slidable.of(cont)!.close();
                    },
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5.0),
                      ),
                      backgroundColor: Color(0xFFF06962),
                      padding: EdgeInsets.all(10),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 25,
                        ),
                        Text("Remove")
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          Builder(
            builder: (cont) {
              return Padding(
                padding: EdgeInsets.fromLTRB(0, 0, 5, 0),
                child: SizedBox(
                  height: 80,
                  width: 80,
                  child: ElevatedButton(
                    onPressed: () {
                      widget.editAction();
                      Slidable.of(cont)!.close();
                    },
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5.0),
                      ),
                      backgroundColor: Color(0xFFA4ADC5),
                      padding: EdgeInsets.all(10),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.edit,
                          color: Colors.white,
                          size: 25,
                        ),
                        Text("Edit")
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),

      // The end action pane is the one at the right or the bottom side.
      endActionPane: ActionPane(
        motion: ScrollMotion(),
        children: [
          Builder(
            builder: (cont) {
              return Padding(
                padding: EdgeInsets.fromLTRB(5, 0, 0, 0),
                child: SizedBox(
                  height: 80,
                  width: 80,
                  child: ElevatedButton(
                    onPressed: () {
                      widget.completeAction();
                      Slidable.of(cont)!.close();
                    },
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5.0),
                      ),
                      backgroundColor: Color(0xFF57D76C),
                      padding: EdgeInsets.all(10),
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 25,
                    ),
                  ),
                ),
              );
            },
          ),
          // SlidableAction(
          //   onPressed: (context) {
          //     widget.completeAction();
          //   },
          //   backgroundColor: Color(0xFF57D76C),
          //   foregroundColor: Colors.white,
          //   icon: Icons.check,
          // ),
        ],
      ),

      // The child of the Slidable is what the user sees when the
      // component is not dragged.
      child: ActiveHabitListItemWidget(habit: widget.habit ?? null),
    );
  }

  void doNothing(BuildContext context) {}
}

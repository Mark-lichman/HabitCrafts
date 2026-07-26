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

import 'package:fl_chart/fl_chart.dart';

class ProgressLineChartWidget extends StatefulWidget {
  const ProgressLineChartWidget({
    super.key,
    this.width,
    this.height,
    required this.habits,
  });

  final double? width;
  final double? height;
  final List<HabitsRecord> habits;

  @override
  State<ProgressLineChartWidget> createState() =>
      _ProgressLineChartWidgetState();
}

class _ProgressLineChartWidgetState extends State<ProgressLineChartWidget> {
  @override
  Widget build(BuildContext context) {
    return Container(
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          color: Color(0x40AAA4A4),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start, // = default, not needed
          children: <Widget>[
            Container(height: 10),
            const Text(
              'Productivity',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.0,
                fontWeight: FontWeight.bold, // Regular
              ),
            ),
            Container(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: Colors.yellow,
                          border: Border.all(
                            color: Colors.yellow,
                          ),
                          borderRadius: BorderRadius.all(Radius.circular(5))),
                    ),
                    Container(width: 5),
                    Text(
                      'Habits In Progress',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.0,
                        fontWeight: FontWeight.w400, // Regular
                      ),
                    )
                  ],
                ),
                Container(width: 20),
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: Colors.green,
                          border: Border.all(
                            color: Colors.green,
                          ),
                          borderRadius: BorderRadius.all(Radius.circular(5))),
                    ),
                    Container(width: 5),
                    Text(
                      'Done for the Day',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.0,
                        fontWeight: FontWeight.w400, // Regular
                      ),
                    )
                  ],
                )
              ],
            ),
            Container(child: chartToRun(), height: 184),
          ],
        ));
  }

  Widget chartToRun() {
    return Padding(
      padding: const EdgeInsets.only(
        left: 10,
        right: 18,
        top: 10,
        bottom: 4,
      ),
      child: LineChart(
        LineChartData(
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: activeHabits(),
              isCurved: false,
              barWidth: 2,
              color: Colors.yellow,
              dotData: const FlDotData(
                show: true,
              ),
            ),
            LineChartBarData(
              spots: finishedPoints(),
              isCurved: false,
              barWidth: 2,
              color: Colors.green,
              dotData: const FlDotData(
                show: true,
              ),
            ),
          ],
          betweenBarsData: [],
          minY: 0,
          borderData: FlBorderData(
            show: false,
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: bottomTitleWidgets,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: leftTitleWidgets,
                interval: 1,
                reservedSize: 36,
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: 1,
            checkToShowVerticalLine: (double value) {
              return true; //value == 1 || value == 6 || value == 4 || value == 5;
            },
            checkToShowHorizontalLine: (double value) {
              return true; //value == 1 || value == 6 || value == 4 || value == 5;
            },
          ),
        ),
      ),
    );
  }

  Widget bottomTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    );
    List<String> lastSixWeekLabels = lastSevenDays();
    String text;
    text = lastSixWeekLabels[value.toInt()];

    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 4,
      child: Text(text, style: style),
    );
  }

  Widget leftTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(
        fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white);

    return SideTitleWidget(
      axisSide: meta.axisSide,
      child: Text(
        '${value.toInt()}',
        style: style,
      ),
    );
  }

  List<FlSpot> activeHabits() {
    // List<FlSpot> array = [];
    // List<DateTime> dates = lastSevenWeeksDates();

    // for (int i = 1; i < dates.length; i++) {
    //   print(dates);
    //   int sum = 0;
    //   for (int j = 0; j < widget.habits.length; j++) {
    //     print(dates[i - 1]);
    //     print(dates[i]);
    //     print(widget.habits);
    //     List<DateTime> completedThatWeek = widget.habits[j].complete
    //         .where((e) => e.isAfter(dates[i - 1]) && e.isBefore(dates[i]))
    //         .toList();
    //     sum += completedThatWeek.length;
    //   }

    //   array.add(FlSpot(i.toDouble(), sum.toDouble()));
    // }

    List<FlSpot> array = [];
    List<DateTime> dates = lastSevenDaysDates();

    for (int i = 1; i < dates.length; i++) {
      int sum = 0;
      for (int j = 0; j < widget.habits.length; j++) {
        if (widget.habits[j].createdTime != null &&
            widget.habits[j].createdTime!.isBefore(dates[i]) &&
            (!widget.habits[j].isFinished ||
                (widget.habits[j].finished != null &&
                    widget.habits[j].finished!.isAfter(dates[i])))) {
          sum++;
        }
      }

      array.add(FlSpot(i.toDouble(), sum.toDouble()));
    }

    return array;
  }

  List<FlSpot> finishedPoints() {
    // List<FlSpot> array = [];
    // List<DateTime> dates = lastSevenWeeksDates();

    // for (int i = 1; i < dates.length; i++) {
    //   int sum = 0;
    //   for (int j = 0; j < widget.habits.length; j++) {
    //     if (widget.habits[j].finished != null &&
    //         widget.habits[j].finished!.isAfter(dates[i - 1]) &&
    //         widget.habits[j].finished!.isBefore(dates[i])) {
    //       sum++;
    //     }
    //   }

    //   array.add(FlSpot(i.toDouble(), sum.toDouble()));
    // }

    List<FlSpot> array = [];
    List<DateTime> dates = lastSevenDaysDates();

    for (int i = 1; i < dates.length; i++) {
      int sum = 0;
      for (int j = 0; j < widget.habits.length; j++) {
        List<DateTime> completedThatDay = widget.habits[j].complete
            .where((e) => e.isAfter(dates[i - 1]) && e.isBefore(dates[i]))
            .toList();
        sum += completedThatDay.length;
      }

      array.add(FlSpot(i.toDouble(), sum.toDouble()));
    }

    return array;
  }
}

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

import 'dart:collection';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

final kToday = DateTime.now();
final kFirstDay = DateTime(kToday.year, kToday.month - 3, kToday.day);
final kLastDay = DateTime(kToday.year, kToday.month + 3, kToday.day);

/// Returns a list of [DateTime] objects from [first] to [last], inclusive.
List<DateTime> daysInRange(DateTime first, DateTime last) {
  final dayCount = last.difference(first).inDays + 1;
  return List.generate(
    dayCount,
    (index) => DateTime.utc(first.year, first.month, first.day + index),
  );
}

int getHashCode(DateTime key) {
  return key.day * 1000000 + key.month * 10000 + key.year;
}

class ProgressCalendarWidget extends StatefulWidget {
  const ProgressCalendarWidget({
    super.key,
    this.width,
    this.height,
    required this.activites,
    required this.displayNotesCallback,
  });

  final double? width;
  final double? height;
  final List<UserActivityRecord> activites;
  final Future Function() displayNotesCallback;

  @override
  State<ProgressCalendarWidget> createState() => _ProgressCalendarWidgetState();
}

class _ProgressCalendarWidgetState extends State<ProgressCalendarWidget> {
  late final ValueNotifier<List<Event>> _selectedEvents;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  AvailableGestures _availableGestures = AvailableGestures.horizontalSwipe;
  ValueNotifier<DateTime> _focusedDay = ValueNotifier(DateTime.now());
  final DateFormat monthFormatter = DateFormat('MMMM yyyy');
  DateTime? _selectedDay;

  RangeSelectionMode _rangeSelectionMode = RangeSelectionMode
      .toggledOff; // Can be toggled on/off by longpressing a date
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  @override
  void initState() {
    super.initState();

    _selectedDay = _focusedDay.value;
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay!));
  }

  @override
  void dispose() {
    _selectedEvents.dispose();
    super.dispose();
  }

  List<Event> _getEventsForDay(DateTime day) {
    // Implementation example
    // return events()[day] ?? [];
    return events()[day] ?? [];
  }

  LinkedHashMap<DateTime, List<Event>> events() {
    return LinkedHashMap<DateTime, List<Event>>(
      equals: isSameDay,
      hashCode: getHashCode,
    )..addAll(eventSource());
  }

  Map<DateTime, List<Event>> eventSource() {
    return Map.fromIterable(widget.activites,
        key: (item) => item
            .created, //DateTime.utc(kFirstDay.year, kFirstDay.month, item * 5),
        value: (item) => List.generate(1, (index) => Event(item)));
  }

  List<Event> _getEventsForRange(DateTime start, DateTime end) {
    // Implementation example
    final days = daysInRange(start, end);

    return [
      for (final d in days) ..._getEventsForDay(d),
    ];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay.value = focusedDay;
        _rangeStart = null; // Important to clean those
        _rangeEnd = null;
        _rangeSelectionMode = RangeSelectionMode.toggledOff;
      });

      _selectedEvents.value = _getEventsForDay(selectedDay);
    }
  }

  void _onRangeSelected(DateTime? start, DateTime? end, DateTime focusedDay) {
    setState(() {
      _selectedDay = null;
      _focusedDay.value = focusedDay;
      _rangeStart = start;
      _rangeEnd = end;
      _rangeSelectionMode = RangeSelectionMode.toggledOn;
    });

    // `start` or `end` could be null
    if (start != null && end != null) {
      _selectedEvents.value = _getEventsForRange(start, end);
    } else if (start != null) {
      _selectedEvents.value = _getEventsForDay(start);
    } else if (end != null) {
      _selectedEvents.value = _getEventsForDay(end);
    }
  }

  Future<String> getFeelingUrl(DocumentReference checkinRef) async {
    //final db = FirebaseFirestore.instance;
    //DocumentSnapshot docSnap = await checkinRef.get();

    //QuerySnapshot snapshot = await db
    //  .collection('feelings')
    // .where('level', isEqualTo: docSnap.get('feeling'))
    // .get();

    //for (var docSnapshot in snapshot.docs) {
    // return docSnapshot.get("imagePath");
    //}
    return Future<String>.value(
        "https://firebasestorage.googleapis.com/v0/b/habitcraft-78a3f.appspot.com/o/icons%2Fwhite_clipboardx2.png?alt=media&token=a1af3fbb-efb3-49a2-a0d3-c2c5a1a9bb2b");
  }

  void openNotesModal(UserActivityRecord activity) {}

  Widget notesRing(UserActivityRecord activity) {
    if (activity.notes != null && activity.notes.length > 0) {
      return Positioned.fill(
        child: Align(
          alignment: Alignment.center,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Color(0xFF7cCf7b), width: 2),
            ),
          ),
        ),
      );
    } else {
      return Positioned.fill(
        child: Align(
          alignment: Alignment.center,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.transparent, width: 2),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        color: Color(0x40AAA4A4),
      ),
      child: Column(
        children: [
          Container(height: 10),
          // const Text(
          //   'Streaks',
          //   style: TextStyle(
          //     color: Colors.white,
          //     fontSize: 12.0,
          //     fontWeight: FontWeight.bold, // Regular
          //   ),
          // ),
          ValueListenableBuilder<DateTime>(
            valueListenable: _focusedDay,
            builder: (context, value, _) => Text(
              'Streaks - ' + DateFormat.yMMMM().format(value),
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.0,
                fontWeight: FontWeight.bold, // Regular
              ),
            ),
          ),
          Container(height: 10),
          TableCalendar<Event>(
            firstDay: kFirstDay,
            lastDay: kLastDay,
            focusedDay: _focusedDay.value,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            rangeStartDay: _rangeStart,
            rangeEndDay: _rangeEnd,
            calendarFormat: _calendarFormat,
            availableGestures: _availableGestures,
            headerVisible: false,
            rangeSelectionMode: _rangeSelectionMode,
            eventLoader: _getEventsForDay,
            startingDayOfWeek: StartingDayOfWeek.monday,
            calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                defaultDecoration: BoxDecoration(
                    shape: BoxShape.circle, color: Color(0x282A405D)),
                defaultTextStyle: TextStyle(color: Colors.white),
                todayDecoration: BoxDecoration(
                    shape: BoxShape.circle, color: Color(0x282A405D)),
                todayTextStyle: TextStyle(color: Colors.transparent),
                weekendDecoration: BoxDecoration(
                    shape: BoxShape.circle, color: Color(0x282A405D)),
                weekendTextStyle: TextStyle(color: Colors.white),
                markerSizeScale: 1,
                markersAnchor: 0,
                markersAutoAligned: true,
                markersMaxCount: 1,
                markerDecoration: BoxDecoration(
                    shape: BoxShape.circle, color: Color(0xFFFFCE51)),
                markerMargin: const EdgeInsets.only(top: 0.0)),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                if (events.length > 0) {
                  if (isSameDay(day, events[0].activity.created)) if (events[0]
                          .activity
                          .action ==
                      ActivityTypes.CompletedCheckin) {
                    return FutureBuilder<String>(
                      future: getFeelingUrl(events[0].activity.checkin!),
                      builder: (BuildContext context,
                          AsyncSnapshot<String> snapshot) {
                        if (snapshot.hasData) {
                          return Stack(children: [
                            Center(
                              child: InkWell(
                                  child: Center(
                                    child: Stack(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            // border color
                                            shape: BoxShape.circle,
                                          ),
                                        ),

                                        Container(
                                          child: Positioned.fill(
                                            child: Align(
                                              alignment: Alignment.center,
                                              child: Text(
                                                DateFormat.d().format(day),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Center(
                                          child: Image.network(
                                              width: 20,
                                              height: 20,
                                              "https://firebasestorage.googleapis.com/v0/b/habitcraft-78a3f.appspot.com/o/icons%2Fwhite_clipboardx2.png?alt=media&token=a1af3fbb-efb3-49a2-a0d3-c2c5a1a9bb2b"),
                                        ),
                                        notesRing(events[0].activity),

                                        // inner content
                                      ],
                                    ),
                                  ),
                                  onTap: () {
                                    FFAppState().tempActivityRef =
                                        events[0].activity.reference;
                                    widget?.displayNotesCallback();
                                  }),
                            ),
                          ]);
                        } else {
                          return Positioned.fill(
                            child: Align(
                                alignment: Alignment.center,
                                child: Text(
                                  DateFormat.d().format(day),
                                )),
                          );
                        }
                      },
                    );
                  } else {
                    return Positioned.fill(
                        child: Align(
                            alignment: Alignment.center,
                            child: InkWell(
                                child: Stack(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color:
                                            Color(0xFFFFCE51), // border color
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    Container(
                                      child: Positioned.fill(
                                        child: Align(
                                          alignment: Alignment.center,
                                          child: Text(
                                            DateFormat.d().format(day),
                                          ),
                                        ),
                                      ),
                                    ),
                                    notesRing(events[0].activity),
                                  ],
                                ),
                                onTap: () {
                                  FFAppState().tempActivityRef =
                                      events[0].activity.reference;
                                  widget?.displayNotesCallback();
                                })));
                  }
                }
              },
              dowBuilder: (context, day) {
                final text = DateFormat.E().format(day);

                return Center(
                  child: Text(
                    allCaps(text),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.0,
                      fontWeight: FontWeight.w500, // Regular
                    ),
                  ),
                );
              },
            ),
            onDaySelected: _onDaySelected,
            onRangeSelected: _onRangeSelected,
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() {
                  _calendarFormat = format;
                });
              }
            },
            onPageChanged: (focusedDay) {
              print('focusedDay');
              print(focusedDay);
              _focusedDay.value = focusedDay;
            },
          ),
          const SizedBox(height: 8.0),
        ],
      ),
    );
  }
}

class _CalendarHeader extends StatelessWidget {
  final DateTime focusedDay;

  const _CalendarHeader({Key? key, required this.focusedDay}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final headerText = DateFormat.yMMM().format(focusedDay);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0.0),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Color(0xE6EEF8),
            ),
            height: 35,
            width: 200,
            child: Center(
              child: Text(
                headerText,
                style: TextStyle(
                  color: Color(0x2A405D),
                  fontSize: 12.0,
                  fontWeight: FontWeight.bold, // Regular
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class Event {
  final UserActivityRecord activity;

  const Event(this.activity);

  @override
  String toString() => activity.action.toString();
}

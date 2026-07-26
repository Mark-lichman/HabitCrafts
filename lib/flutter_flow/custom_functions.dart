import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'lat_lng.dart';
import 'place.dart';
import 'uploaded_file.dart';
import '/backend/backend.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/backend/schema/structs/index.dart';
import '/backend/schema/enums/enums.dart';
import '/auth/firebase_auth/auth_util.dart';

List<String> lastSixWeeks() {
  List<String> dates = [];
  final now = DateTime.now();
  dates.add(DateFormat.Md().format(now));

  dates.add(DateFormat.Md().format(now.subtract(Duration(days: 7))));
  dates.add(DateFormat.Md().format(now.subtract(Duration(days: 14))));
  dates.add(DateFormat.Md().format(now.subtract(Duration(days: 21))));
  dates.add(DateFormat.Md().format(now.subtract(Duration(days: 28))));
  dates.add(DateFormat.Md().format(now.subtract(Duration(days: 35))));
  dates.add(DateFormat.Md().format(now.subtract(Duration(days: 42))));

  return dates.reversed.toList();
}

List<DateTime> lastSevenWeeksDates() {
  List<DateTime> dates = [];
  final now = DateTime.now();
  dates.add(now);

  dates.add(now.subtract(Duration(days: 7)));
  dates.add(now.subtract(Duration(days: 14)));
  dates.add(now.subtract(Duration(days: 21)));
  dates.add(now.subtract(Duration(days: 28)));
  dates.add(now.subtract(Duration(days: 35)));
  dates.add(now.subtract(Duration(days: 42)));

  return dates.reversed.toList();
}

List<int> hours() {
  List<int> hourList = [];
  for (int i = 0; i < 12; i++) {
    hourList.add(i);
  }
  return hourList;
}

List<int> minutes() {
  List<int> minuteList = [];
  for (int i = 0; i < 12; i++) {
    minuteList.add(i * 5);
  }
  return minuteList;
}

DateTime inSevenDaysCopy(DateTime date) {
  final sevenDaysFromNow = date.add(const Duration(days: 7));
  return sevenDaysFromNow;
}

String allCaps(String input) {
  return input.toUpperCase();
}

DateTime twoMonthsAgo(DateTime date) {
  final twoMonthsAgo = date.subtract(const Duration(days: 60));
  return twoMonthsAgo;
}

List<DocumentReference> usersToList(
  DocumentReference user1,
  DocumentReference user2,
) {
  List<DocumentReference> combinedList = [];
  combinedList.add(user1);
  combinedList.add(user2);
  return combinedList;
}

int lastIndex(int numOfItems) {
  return numOfItems - 1;
}

bool isToday(DateTime? date) {
  if (date == null) return false;
  DateTime now = DateTime.now();
  return DateUtils.isSameDay(now, date);
}

int howManyWeeksSinceAccountCreation(
  DateTime createdDate,
  int totalCategories,
) {
  final now = DateTime.now();
//   print('weeks ${now.difference(createdDate).inHours / 24).round() / 7).toInt()}');
  print('totalCategories ${totalCategories}');
  final total =
      ((now.difference(createdDate).inHours / 24).round() / 7).toInt() %
          totalCategories;
  print('total ${total}');
  return total;
}

int localToUTCOffset(DateTime dateTime) {
  print(dateTime.timeZoneOffset.inHours);
  return dateTime.timeZoneOffset.inHours;
}

int localToMinute(DateTime dateTime) {
  return dateTime.minute;
}

List<String> stringToList(String input) {
  return [input];
}

DateTime localToUTC(DateTime localTime) {
  return localTime.toUtc();
}

int localToHour(DateTime dateTime) {
  return dateTime.hour;
}

int localToUTCHour(DateTime dateTime) {
  return dateTime.toUtc().hour;
}

List<String> lastSevenDays() {
  List<String> dates = [];
  final now = DateTime.now();
  dates.add(DateFormat.Md().format(now));

  dates.add(DateFormat.Md().format(now.subtract(Duration(days: 1))));
  dates.add(DateFormat.Md().format(now.subtract(Duration(days: 2))));
  dates.add(DateFormat.Md().format(now.subtract(Duration(days: 3))));
  dates.add(DateFormat.Md().format(now.subtract(Duration(days: 4))));
  dates.add(DateFormat.Md().format(now.subtract(Duration(days: 5))));
  dates.add(DateFormat.Md().format(now.subtract(Duration(days: 6))));

  return dates.reversed.toList();
}

int localToUTCMinute(DateTime dateTime) {
  return dateTime.toUtc().minute;
}

List<DateTime> lastSevenDaysDates() {
  List<DateTime> dates = [];
  final now = DateTime.now();
  dates.add(now);

  dates.add(now.subtract(Duration(days: 1)));
  dates.add(now.subtract(Duration(days: 2)));
  dates.add(now.subtract(Duration(days: 3)));
  dates.add(now.subtract(Duration(days: 4)));
  dates.add(now.subtract(Duration(days: 5)));
  dates.add(now.subtract(Duration(days: 6)));

  return dates.reversed.toList();
}

String listToString(List<String> list) {
  return list.join(', ');
}

bool isWithinWeekOfNow(DateTime date) {
  final now = DateTime.now();
  date = DateTime(date.year, date.month, date.day);
  return (now.difference(date).inHours / 24).round() < 7;
}

DateTime startOfDay() {
  DateTime now = DateTime.now();
  DateTime startOfDay = DateTime(now.year, now.month, now.day);
  return startOfDay;
}

List<GroupMemberStateRecord> filteredCheckinsByToday(
    List<GroupMemberStateRecord> groupMemberStates) {
  final now = DateTime.now();
  List<GroupMemberStateRecord> groupList = [];
  for (GroupMemberStateRecord groupMemberState in groupMemberStates) {
    // now pull the group object and check the checkin date to see if it's today
    // var groupSnapshot = await groupMemberState.group!.get();

    groupMemberState.group!.get().then((groupSnapshot) {
      print(groupSnapshot);
      Map<String, dynamic>? groupDoc =
          groupSnapshot.data() as Map<String, dynamic>?;
      if (groupDoc != null && groupDoc!.containsKey('checkin_time')) {
        final nowDay =
            now.day; //DateFormat(DateFormat.ABBR_WEEKDAY).format(now);
        final checkinDay = groupSnapshot.get('checkin_time');
        if (nowDay == checkinDay.toDate().day) {
          groupList.add(groupMemberState);
        }
      }
    }).catchError((error) {
      print('Error: $error');
    });

    // Map<String, dynamic>? groupDoc =
    //     groupSnapshot.data() as Map<String, dynamic>?;
    // if (groupDoc != null && groupDoc!.containsKey('checkin_time')) {
    //   final nowDay = now.day; //DateFormat(DateFormat.ABBR_WEEKDAY).format(now);
    //   final checkinDay = groupSnapshot.get('checkin_time');
    //   if (nowDay == checkinDay.toDate().day) {
    //     groupList.add(groupMemberState);
    //   }
    // }
  }

  print(groupList);
  return groupList;
}

int? ageFromBirthday(DateTime? birthday) {
  if (birthday != null) {
    final now = DateTime.now();
    int age = now.year - birthday.year;

    if (now.month < birthday.month ||
        (now.month == birthday.month && now.day < birthday.day)) {
      age--;
    }

    return age;
  } else {
    return null;
  }
}

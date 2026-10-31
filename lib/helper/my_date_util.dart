import 'package:flutter/material.dart';

// make time readable
class MyDateUtil{
  static String getFormattedTime({required BuildContext context, required String time}){
    final date = DateTime.fromMillisecondsSinceEpoch(int.tryParse(time) ?? 0);
    return TimeOfDay.fromDateTime(date).format(context);
  }

// get last msg time
  static String getLastMessageTime(
      {required BuildContext context, required String time, bool showYear = false}) {
    final DateTime sent = DateTime.fromMillisecondsSinceEpoch(int.tryParse(time) ?? 0);
    final DateTime now = DateTime.now();

    if (now.day == sent.day && now.month == sent.month && now.year == sent.year) {
      return TimeOfDay.fromDateTime(sent).format(context);
    }
    return now.year == sent.year
        ? '${sent.day} ${_getMonth(sent)}'
        : '${sent.day} ${_getMonth(sent)} ${sent.year}';
  }

  // format active time
  static String getLastActiveTime(
      {required BuildContext context, required String lastActive}) {
    final int i = int.tryParse(lastActive) ?? -1;
    if (i == -1) return 'Last seen recently';

    final DateTime time = DateTime.fromMillisecondsSinceEpoch(i);
    final DateTime now = DateTime.now();

    String formattedTime = TimeOfDay.fromDateTime(time).format(context);
    if (time.day == now.day && time.month == now.month && time.year == now.year) {
      return 'Last seen today at $formattedTime';
    }

    if ((now.difference(time).inHours / 24).round() == 1) {
      return 'Last seen yesterday at $formattedTime';
    }

    String month = _getMonth(time);
    return 'Last seen on ${time.day} $month at $formattedTime';
  }

  // Format joined date (e.g., Oct 2024)
  static String getJoinedDate(String createdAt) {
    final int millis = int.tryParse(createdAt) ?? 0;
    if (millis <= 0) return 'Recent';
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    return '${_getMonth(dt)} ${dt.year}';
  }

  // for showing last chatting month
  static String _getMonth(DateTime date) {
    switch (date.month) {
      case 1:
        return 'Jan';
      case 2:
        return 'Feb';
      case 3:
        return 'Mar';
      case 4:
        return 'Apr';
      case 5:
        return 'May';
      case 6:
        return 'Jun';
      case 7:
        return 'Jul';
      case 8:
        return 'Aug';
      case 9:
        return 'Sept';
      case 10:
        return 'Oct';
      case 11:
        return 'Nov';
      case 12:
        return 'Dec';
    }
    return 'N/A';
  }

  // Get conversational date header for chat timeline
  static String getChatDateHeader(String timeMillis) {
    final int millis = int.tryParse(timeMillis) ?? 0;
    if (millis <= 0) return '';
    final DateTime date = DateTime.fromMillisecondsSinceEpoch(millis);
    final DateTime now = DateTime.now();

    if (now.year == date.year && now.month == date.month && now.day == date.day) {
      return 'Today';
    }

    final DateTime yesterday = now.subtract(const Duration(days: 1));
    if (yesterday.year == date.year &&
        yesterday.month == date.month &&
        yesterday.day == date.day) {
      return 'Yesterday';
    }

    if (now.difference(date).inDays < 7 && now.weekday > date.weekday) {
      return _getWeekday(date.weekday);
    }

    final String month = _getMonth(date);
    if (now.year == date.year) {
      return '${date.day} $month';
    }
    return '${date.day} $month ${date.year}';
  }

  static String _getWeekday(int weekday) {
    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return '';
    }
  }

  // Check if two timestamps fall on different calendar days
  static bool isDifferentDay(String timeA, String timeB) {
    final int a = int.tryParse(timeA) ?? 0;
    final int b = int.tryParse(timeB) ?? 0;
    if (a <= 0 || b <= 0) return true;
    final dtA = DateTime.fromMillisecondsSinceEpoch(a);
    final dtB = DateTime.fromMillisecondsSinceEpoch(b);
    return dtA.year != dtB.year || dtA.month != dtB.month || dtA.day != dtB.day;
  }
}
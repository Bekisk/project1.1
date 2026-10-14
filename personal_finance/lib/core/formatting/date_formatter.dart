import 'package:intl/intl.dart';

class DateFormatter {
  static final DateFormat _dateFormat = DateFormat('MMM d, y');
  static final DateFormat _timeFormat = DateFormat('h:mm a');
  static final DateFormat _dateTimeFormat = DateFormat('MMM d, y • h:mm a');
  static final DateFormat _monthYearFormat = DateFormat('MMMM y');

  static String formatDate(DateTime date) => _dateFormat.format(date);
  static String formatTime(DateTime date) => _timeFormat.format(date);
  static String formatDateTime(DateTime date) => _dateTimeFormat.format(date);
  static String formatMonthYear(DateTime date) => _monthYearFormat.format(date);

  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);

    final differenceInDays = today.difference(targetDate).inDays;

    if (differenceInDays == 0) return 'Today';
    if (differenceInDays == 1) return 'Yesterday';
    if (differenceInDays == -1) return 'Tomorrow';
    if (differenceInDays > 1 && differenceInDays < 7) return '$differenceInDays days ago';

    return formatDate(date);
  }
}

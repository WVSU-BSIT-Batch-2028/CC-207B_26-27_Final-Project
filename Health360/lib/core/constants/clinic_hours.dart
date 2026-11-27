/// When the clinic takes appointments: Monday to Saturday, 8:00 AM to
/// 5:00 PM. The last appointment starts at 4:30 PM so it ends by closing.
///
/// Used by the booking and Edit Appointment screens (to block other times)
/// and by AppointmentService (so the rule holds even if a screen forgets).
/// Change the hours here only.
class ClinicHours {
  ClinicHours._();

  static const int openHour = 8; // 8:00 AM
  static const int lastStartHour = 16; // 4:30 PM is the last start
  static const int lastStartMinute = 30;

  /// Shown under the time field and in error messages.
  static const String description = 'Monday to Saturday, 8:00 AM to 5:00 PM';

  /// True on days the clinic is open (closed on Sundays).
  static bool isOpenDay(DateTime day) => day.weekday != DateTime.sunday;

  /// True when an appointment may start at [time].
  static bool isWithinHours(DateTime time) {
    if (!isOpenDay(time)) return false;
    final minutes = time.hour * 60 + time.minute;
    return minutes >= openHour * 60 &&
        minutes <= lastStartHour * 60 + lastStartMinute;
  }

  /// An error message for [time], or null when it can be booked.
  static String? validate(DateTime time, {DateTime? now}) {
    if (!time.isAfter(now ?? DateTime.now())) {
      return 'Please choose a date and time in the future.';
    }
    if (!isOpenDay(time)) {
      return 'The clinic is closed on Sundays. Clinic hours: $description.';
    }
    if (!isWithinHours(time)) {
      return 'Please choose a time from 8:00 AM to 4:30 PM. Clinic hours: $description.';
    }
    return null;
  }

  /// [day] if the clinic is open then, otherwise the next open day.
  static DateTime nextOpenDay(DateTime day) {
    var date = DateTime(day.year, day.month, day.day);
    while (!isOpenDay(date)) {
      date = DateTime(date.year, date.month, date.day + 1);
    }
    return date;
  }
}

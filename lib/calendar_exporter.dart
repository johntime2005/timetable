import 'package:add_2_calendar/add_2_calendar.dart';

import 'course.dart';

class CalendarExporter {
  const CalendarExporter({DateTime Function()? now}) : _now = now;

  final DateTime Function()? _now;

  Future<void> addCourse(Course course) async {
    await Add2Calendar.addEvent2Cal(buildEvent(course));
  }

  Future<void> addCourses(Iterable<Course> courses) async {
    for (final course in courses) {
      await addCourse(course);
    }
  }

  Event buildEvent(Course course) {
    final date = _nextCourseDate(course);
    final startClock = _slotStartTime(course.startSlot);
    final endClock = _slotStartTime(course.endSlot);
    final start = DateTime(date.year, date.month, date.day, startClock.hour, startClock.minute);
    final rawEnd = DateTime(date.year, date.month, date.day, endClock.hour, endClock.minute)
        .add(const Duration(minutes: 45));
    final end = rawEnd.isAfter(start) ? rawEnd : start.add(const Duration(minutes: 45));

    return Event(
      title: course.name,
      description: '${course.teacher} · ${course.timeText} · ${course.weekText}',
      location: course.room,
      startDate: start,
      endDate: end,
      iosParams: const IOSParams(reminder: Duration(minutes: 15)),
      androidParams: const AndroidParams(emailInvites: <String>[]),
    );
  }

  DateTime _nextCourseDate(Course course) {
    final now = _now?.call() ?? DateTime.now();
    var date = DateTime(now.year, now.month, now.day);
    final daysToAdd = (course.weekday - now.weekday) % DateTime.daysPerWeek;
    date = date.add(Duration(days: daysToAdd));

    final endClock = _slotStartTime(course.endSlot);
    final end = DateTime(date.year, date.month, date.day, endClock.hour, endClock.minute)
        .add(const Duration(minutes: 45));
    if (!end.isAfter(now)) {
      date = date.add(const Duration(days: DateTime.daysPerWeek));
    }
    return date;
  }

  _ClockTime _slotStartTime(int slot) {
    const schedule = <int, _ClockTime>{
      1: _ClockTime(8, 0),
      2: _ClockTime(8, 55),
      3: _ClockTime(10, 10),
      4: _ClockTime(11, 5),
      5: _ClockTime(14, 0),
      6: _ClockTime(14, 55),
      7: _ClockTime(16, 10),
      8: _ClockTime(17, 5),
      9: _ClockTime(19, 0),
      10: _ClockTime(19, 55),
      11: _ClockTime(20, 50),
      12: _ClockTime(21, 45),
    };
    return schedule[slot] ?? const _ClockTime(8, 0);
  }
}

class _ClockTime {
  const _ClockTime(this.hour, this.minute);

  final int hour;
  final int minute;
}

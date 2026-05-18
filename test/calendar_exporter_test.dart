import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetable/calendar_exporter.dart';
import 'package:timetable/course.dart';

void main() {
  const course = Course(
    name: '移动应用开发',
    teacher: '张老师',
    room: 'A202',
    weekday: DateTime.monday,
    startSlot: 1,
    endSlot: 2,
    color: Color(0xFF4F46E5),
  );

  test('keeps start and end on the same date when course is in progress', () {
    final exporter = CalendarExporter(
      now: () => DateTime(2026, 5, 18, 8, 30),
    );

    final event = exporter.buildEvent(course);

    expect(event.startDate, DateTime(2026, 5, 18, 8, 0));
    expect(event.endDate, DateTime(2026, 5, 18, 9, 40));
  });

  test('moves course to next week after it has ended', () {
    final exporter = CalendarExporter(
      now: () => DateTime(2026, 5, 18, 10, 0),
    );

    final event = exporter.buildEvent(course);

    expect(event.startDate, DateTime(2026, 5, 25, 8, 0));
    expect(event.endDate, DateTime(2026, 5, 25, 9, 40));
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timetable/course.dart';
import 'package:timetable/course_storage.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('returns sample courses when storage is empty', () async {
    final storage = CourseStorage();

    final courses = await storage.loadCourses();

    expect(courses, hasLength(sampleCourses.length));
    expect(courses.first.name, sampleCourses.first.name);
  });

  test('saves and reloads edited courses', () async {
    final storage = CourseStorage();
    final courses = <Course>[
      const Course(
        name: '软件工程',
        teacher: '周老师',
        room: 'A305',
        weekday: DateTime.wednesday,
        startSlot: 3,
        endSlot: 4,
        color: Color(0xFF4F46E5),
        weeks: <int>[1, 2, 3, 4],
      ),
    ];

    await storage.saveCourses(courses);

    final restored = await storage.loadCourses();

    expect(restored, hasLength(1));
    expect(restored.single.name, '软件工程');
    expect(restored.single.teacher, '周老师');
    expect(restored.single.room, 'A305');
    expect(restored.single.weekday, DateTime.wednesday);
    expect(restored.single.startSlot, 3);
    expect(restored.single.endSlot, 4);
    expect(restored.single.weeks, <int>[1, 2, 3, 4]);
    expect(restored.single.color, const Color(0xFF4F46E5));
  });
}

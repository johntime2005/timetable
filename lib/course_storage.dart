import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'course.dart';

class CourseStorage {
  static const String storageKey = 'stored_courses';

  Future<List<Course>> loadCourses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) {
      return sampleCourses.toList();
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List<dynamic>) {
      return sampleCourses.toList();
    }

    return decoded
        .map((item) => Map<String, dynamic>.from(item as Map<dynamic, dynamic>))
        .map(Course.fromJson)
        .toList();
  }

  Future<void> saveCourses(List<Course> courses) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      storageKey,
      jsonEncode(courses.map((course) => course.toJson()).toList()),
    );
  }
}

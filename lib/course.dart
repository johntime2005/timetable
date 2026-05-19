import 'package:flutter/material.dart';

class Course {
  const Course({
    required this.name,
    required this.teacher,
    required this.room,
    required this.weekday,
    required this.startSlot,
    required this.endSlot,
    required this.color,
    this.weeks = const <int>[],
  });

  final String name;
  final String teacher;
  final String room;
  final int weekday;
  final int startSlot;
  final int endSlot;
  final Color color;
  final List<int> weeks;

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      name: json['name'] as String? ?? '未命名课程',
      teacher: json['teacher'] as String? ?? '未填写教师',
      room: json['room'] as String? ?? '未填写教室',
      weekday: json['weekday'] as int? ?? DateTime.monday,
      startSlot: json['startSlot'] as int? ?? 1,
      endSlot: json['endSlot'] as int? ?? 1,
      color: Color(json['color'] as int? ?? coursePalette.first.toARGB32()),
      weeks: ((json['weeks'] as List<dynamic>?) ?? const <dynamic>[]).map((item) => item as int).toList(),
    );
  }

  String get timeText => '第$startSlot-$endSlot节';

  String get weekText {
    if (weeks.isEmpty) {
      return '全周';
    }
    if (weeks.length == 1) {
      return '第${weeks.first}周';
    }
    return '第${weeks.first}-${weeks.last}周';
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'teacher': teacher,
      'room': room,
      'weekday': weekday,
      'startSlot': startSlot,
      'endSlot': endSlot,
      'color': color.toARGB32(),
      'weeks': weeks,
    };
  }
}

const List<String> weekdays = <String>['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

const List<Course> sampleCourses = <Course>[
  Course(
    name: '高等数学',
    teacher: '李老师',
    room: 'A101',
    weekday: 1,
    startSlot: 1,
    endSlot: 2,
    color: Color(0xFF4F46E5),
    weeks: <int>[1, 2, 3, 4, 5, 6, 7, 8],
  ),
  Course(
    name: '大学英语',
    teacher: '王老师',
    room: 'B204',
    weekday: 1,
    startSlot: 3,
    endSlot: 4,
    color: Color(0xFF0EA5E9),
    weeks: <int>[1, 2, 3, 4, 5, 6, 7, 8],
  ),
  Course(
    name: '数据结构',
    teacher: '陈老师',
    room: '实验楼 302',
    weekday: 2,
    startSlot: 1,
    endSlot: 2,
    color: Color(0xFF16A34A),
    weeks: <int>[1, 2, 3, 4, 5, 6, 7, 8],
  ),
  Course(
    name: '线性代数',
    teacher: '赵老师',
    room: 'C310',
    weekday: 3,
    startSlot: 5,
    endSlot: 6,
    color: Color(0xFFF97316),
    weeks: <int>[1, 2, 3, 4, 5, 6, 7, 8],
  ),
  Course(
    name: '操作系统',
    teacher: '刘老师',
    room: 'D412',
    weekday: 4,
    startSlot: 3,
    endSlot: 4,
    color: Color(0xFFDB2777),
    weeks: <int>[1, 2, 3, 4, 5, 6, 7, 8],
  ),
  Course(
    name: '体育',
    teacher: '孙老师',
    room: '操场',
    weekday: 5,
    startSlot: 7,
    endSlot: 8,
    color: Color(0xFF7C3AED),
    weeks: <int>[1, 2, 3, 4, 5, 6, 7, 8],
  ),
];

const List<Color> coursePalette = <Color>[
  Color(0xFF4F46E5),
  Color(0xFF0EA5E9),
  Color(0xFF16A34A),
  Color(0xFFF97316),
  Color(0xFFDB2777),
  Color(0xFF7C3AED),
  Color(0xFF0891B2),
  Color(0xFFDC2626),
];

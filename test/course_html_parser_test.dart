import 'package:flutter_test/flutter_test.dart';
import 'package:timetable/course_html_parser.dart';

void main() {
  test('parses courses from table rows', () {
    const html = '''
      <table>
        <tr>
          <th>课程</th><th>时间</th><th>教师</th><th>地点</th><th>周次</th>
        </tr>
        <tr>
          <td>移动应用开发</td><td>周二 第3-4节</td><td>教师: 张老师</td><td>教室: A202</td><td>第1-16周</td>
        </tr>
      </table>
    ''';

    final courses = const CourseHtmlParser().parse(html);

    expect(courses, hasLength(1));
    expect(courses.single.name, '移动应用开发');
    expect(courses.single.weekday, 2);
    expect(courses.single.startSlot, 3);
    expect(courses.single.endSlot, 4);
    expect(courses.single.teacher, '张老师');
    expect(courses.single.room, 'A202');
    expect(courses.single.weeks.first, 1);
    expect(courses.single.weeks.last, 16);
  });

  test('uses default teacher and room when fields are missing', () {
    const html = '<table><tr><td>形势与政策</td><td>周日 第9节</td><td>第2-3周</td></tr></table>';

    final courses = const CourseHtmlParser().parse(html);

    expect(courses, hasLength(1));
    expect(courses.single.weekday, 7);
    expect(courses.single.startSlot, 9);
    expect(courses.single.endSlot, 9);
    expect(courses.single.teacher, '未填写教师');
    expect(courses.single.room, '未填写教室');
  });

  test('returns empty list for html without recognizable courses', () {
    final courses = const CourseHtmlParser().parse('<p>这里只是一段通知，没有课表。</p>');

    expect(courses, isEmpty);
  });
}

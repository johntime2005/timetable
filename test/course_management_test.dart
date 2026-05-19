import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timetable/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first.physicalSize = const Size(1440, 2200);
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first.devicePixelRatio = 1.0;
  });

  testWidgets('can add edit and delete a course', (tester) async {
    await tester.pumpWidget(const TimetableApp(initialWeekday: DateTime.monday));
    await tester.pumpAndSettle();

    await tester.tap(find.text('添加课程'));
    await tester.pumpAndSettle();

    await tester.enterText(find.bySemanticsLabel('课程名称'), '编译原理');
    await tester.enterText(find.bySemanticsLabel('授课教师'), '吴老师');
    await tester.enterText(find.bySemanticsLabel('上课地点'), 'B201');
    await tester.enterText(find.bySemanticsLabel('开始节次'), '9');
    await tester.enterText(find.bySemanticsLabel('结束节次'), '10');
    await tester.enterText(find.bySemanticsLabel('周次'), '1-16');
    await tester.tap(find.text('保存课程'));
    await tester.pumpAndSettle();

    expect(find.text('编译原理'), findsOneWidget);
    expect(find.text('第9-10节'), findsOneWidget);

    await tester.tap(find.byTooltip('课程操作').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑课程').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.bySemanticsLabel('课程名称'), '高级编译原理');
    await tester.tap(find.text('保存课程'));
    await tester.pumpAndSettle();

    expect(find.text('高级编译原理'), findsOneWidget);
    expect(find.text('编译原理'), findsNothing);

    await tester.tap(find.byTooltip('课程操作').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除课程').last);
    await tester.pumpAndSettle();

    expect(find.text('高级编译原理'), findsNothing);
  });

  testWidgets('restores saved courses from shared preferences', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'stored_courses':
          '[{"name":"离散数学","teacher":"何老师","room":"C102","weekday":1,"startSlot":5,"endSlot":6,"color":4283398382,"weeks":[1,2,3,4,5]}]',
    });

    await tester.pumpWidget(const TimetableApp(initialWeekday: DateTime.monday));
    await tester.pumpAndSettle();

    expect(find.text('离散数学'), findsOneWidget);
    expect(find.text('高等数学'), findsNothing);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timetable/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('renders timetable home page', (tester) async {
    await tester.pumpWidget(const TimetableApp(initialWeekday: DateTime.monday));
    await tester.pump();

    expect(find.text('课程表'), findsOneWidget);
    expect(find.text('添加课程'), findsOneWidget);
    expect(find.text('今天 · 周一'), findsOneWidget);
    expect(find.byTooltip('从教务系统网页导入'), findsOneWidget);
    expect(find.byTooltip('个性化背景'), findsOneWidget);
  });

  testWidgets('can switch weekday tab', (tester) async {
    await tester.pumpWidget(const TimetableApp(initialWeekday: DateTime.monday));
    await tester.pump();

    await tester.tap(find.text('周二'));
    await tester.pumpAndSettle();

    expect(find.text('今天 · 周二'), findsOneWidget);
    expect(find.text('周二安排'), findsOneWidget);
    expect(find.text('数据结构'), findsOneWidget);
  });

  testWidgets('opens add course sheet when tapping add course', (tester) async {
    await tester.pumpWidget(const TimetableApp(initialWeekday: DateTime.monday));
    await tester.pump();

    await tester.tap(find.text('添加课程'));
    await tester.pumpAndSettle();

    expect(find.text('新建课程'), findsOneWidget);
    expect(find.text('保存课程'), findsOneWidget);
  });

  testWidgets('can switch theme mode from menu', (tester) async {
    await tester.pumpWidget(const TimetableApp(initialWeekday: DateTime.monday));
    await tester.pump();

    var app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.system);

    await tester.tap(find.byTooltip('主题模式').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('深色模式').last);
    await tester.pumpAndSettle();

    app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });
}

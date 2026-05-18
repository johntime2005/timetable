import 'package:flutter_test/flutter_test.dart';
import 'package:timetable/main.dart';

void main() {
  testWidgets('renders timetable home page', (tester) async {
    await tester.pumpWidget(const TimetableApp(initialWeekday: DateTime.monday));

    expect(find.text('课程表'), findsOneWidget);
    expect(find.text('添加课程'), findsOneWidget);
    expect(find.text('今天 · 周一'), findsOneWidget);
    expect(find.byTooltip('从教务系统网页导入'), findsOneWidget);
    expect(find.byTooltip('个性化背景'), findsOneWidget);
  });

  testWidgets('can switch weekday tab', (tester) async {
    await tester.pumpWidget(const TimetableApp(initialWeekday: DateTime.monday));

    await tester.tap(find.text('周二'));
    await tester.pumpAndSettle();

    expect(find.text('今天 · 周二'), findsOneWidget);
    expect(find.text('周二安排'), findsOneWidget);
    expect(find.text('数据结构'), findsOneWidget);
  });

  testWidgets('shows coming soon message when tapping add course', (tester) async {
    await tester.pumpWidget(const TimetableApp(initialWeekday: DateTime.monday));

    await tester.tap(find.text('添加课程'));
    await tester.pump();

    expect(find.text('下一步可接入添加课程表单和本地保存'), findsOneWidget);
  });
}

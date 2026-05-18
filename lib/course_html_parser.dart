import 'package:html/parser.dart' as html_parser;

import 'course.dart';

class CourseHtmlParser {
  const CourseHtmlParser();

  List<Course> parse(String html) {
    final document = html_parser.parse(html);
    final rows = document.querySelectorAll('tr');
    final courses = <Course>[];

    for (final row in rows) {
      final cells = row.querySelectorAll('td, th');
      if (cells.length < 3) {
        continue;
      }

      final rowText = cells.map((cell) => _clean(cell.text)).join(' ');
      final weekday = _parseWeekday(rowText);
      final slots = _parseSlots(rowText);
      final name = _parseName(cells.map((cell) => _clean(cell.text)).toList());

      if (weekday == null || slots == null || name == null) {
        continue;
      }

      courses.add(
        Course(
          name: name,
          teacher: _parseField(rowText, const <String>['教师', '老师', '任课']) ?? '未填写教师',
          room: _parseField(rowText, const <String>['地点', '教室', '校区']) ?? '未填写教室',
          weekday: weekday,
          startSlot: slots.start,
          endSlot: slots.end,
          color: coursePalette[courses.length % coursePalette.length],
          weeks: _parseWeeks(rowText),
        ),
      );
    }

    if (courses.isNotEmpty) {
      courses.sort((left, right) {
        final weekdayCompare = left.weekday.compareTo(right.weekday);
        if (weekdayCompare != 0) {
          return weekdayCompare;
        }
        return left.startSlot.compareTo(right.startSlot);
      });
      return courses;
    }

    return _parseTextBlocks(document.body?.text ?? document.text ?? '');
  }

  List<Course> _parseTextBlocks(String text) {
    final blocks = text
        .split(RegExp(r'\n{2,}|;|；'))
        .map(_clean)
        .where((block) => block.isNotEmpty)
        .toList();
    final courses = <Course>[];

    for (final block in blocks) {
      final weekday = _parseWeekday(block);
      final slots = _parseSlots(block);
      if (weekday == null || slots == null) {
        continue;
      }

      courses.add(
        Course(
          name: _parseLooseName(block),
          teacher: _parseField(block, const <String>['教师', '老师', '任课']) ?? '未填写教师',
          room: _parseField(block, const <String>['地点', '教室', '校区']) ?? '未填写教室',
          weekday: weekday,
          startSlot: slots.start,
          endSlot: slots.end,
          color: coursePalette[courses.length % coursePalette.length],
          weeks: _parseWeeks(block),
        ),
      );
    }
    return courses;
  }

  String? _parseName(List<String> values) {
    for (final value in values) {
      final normalized = _clean(value);
      if (normalized.length < 2) {
        continue;
      }
      if (_parseWeekday(normalized) != null || _parseSlots(normalized) != null) {
        continue;
      }
      if (RegExp(r'教师|老师|地点|教室|校区|周次|星期|节').hasMatch(normalized)) {
        continue;
      }
      return normalized;
    }
    return null;
  }

  String _parseLooseName(String text) {
    final cleaned = _clean(text)
        .replaceAll(RegExp(r'周[一二三四五六日天]|星期[一二三四五六日天]'), '')
        .replaceAll(RegExp(r'第?\d+\s*[-~至到,，、]\s*\d+节'), '')
        .replaceAll(RegExp(r'(教师|老师|任课|地点|教室|校区|周次)[:：]?\S*'), '')
        .trim();
    return cleaned.isEmpty ? '未命名课程' : cleaned;
  }

  int? _parseWeekday(String text) {
    const mapping = <String, int>{
      '一': 1,
      '二': 2,
      '三': 3,
      '四': 4,
      '五': 5,
      '六': 6,
      '日': 7,
      '天': 7,
    };
    final match = RegExp(r'(?:周|星期)([一二三四五六日天])').firstMatch(text);
    if (match == null) {
      return null;
    }
    return mapping[match.group(1)];
  }

  _SlotRange? _parseSlots(String text) {
    final rangeMatch = RegExp(r'第?\s*(\d{1,2})\s*[-~至到,，、]\s*(\d{1,2})\s*节').firstMatch(text);
    if (rangeMatch != null) {
      return _SlotRange(
        int.parse(rangeMatch.group(1)!),
        int.parse(rangeMatch.group(2)!),
      );
    }

    final singleMatch = RegExp(r'第?\s*(\d{1,2})\s*节').firstMatch(text);
    if (singleMatch != null) {
      final slot = int.parse(singleMatch.group(1)!);
      return _SlotRange(slot, slot);
    }
    return null;
  }

  List<int> _parseWeeks(String text) {
    final match = RegExp(r'第?\s*(\d{1,2})\s*[-~至到]\s*(\d{1,2})\s*周').firstMatch(text);
    if (match == null) {
      return const <int>[];
    }
    final start = int.parse(match.group(1)!);
    final end = int.parse(match.group(2)!);
    if (end < start) {
      return const <int>[];
    }
    return List<int>.generate(end - start + 1, (index) => start + index);
  }

  String? _parseField(String text, List<String> labels) {
    for (final label in labels) {
      final match = RegExp('$label[:：]?\\s*([^\\s，,；;]+)').firstMatch(text);
      if (match != null) {
        return match.group(1);
      }
    }
    return null;
  }

  String _clean(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();
}

class _SlotRange {
  const _SlotRange(this.start, this.end);

  final int start;
  final int end;
}

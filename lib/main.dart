import 'dart:convert';
import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'calendar_exporter.dart';
import 'course.dart';
import 'course_html_parser.dart';
import 'course_storage.dart';
import 'education_web_import_page.dart';

void main() {
  runApp(const TimetableApp());
}

enum AppThemePreference {
  system,
  light,
  dark,
}

class _ThemeSettings {
  const _ThemeSettings({
    required this.preference,
    required this.backgroundImagePath,
    required this.backgroundOpacity,
    required this.hasCustomPalette,
    this.lightScheme,
    this.darkScheme,
  });

  final AppThemePreference preference;
  final String? backgroundImagePath;
  final double backgroundOpacity;
  final bool hasCustomPalette;
  final ColorScheme? lightScheme;
  final ColorScheme? darkScheme;

  ThemeMode get themeMode {
    switch (preference) {
      case AppThemePreference.system:
        return ThemeMode.system;
      case AppThemePreference.light:
        return ThemeMode.light;
      case AppThemePreference.dark:
        return ThemeMode.dark;
    }
  }

  File? get backgroundImageFile {
    final path = backgroundImagePath;
    if (path == null) {
      return null;
    }
    final file = File(path);
    return file.existsSync() ? file : null;
  }

  _ThemeSettings copyWith({
    AppThemePreference? preference,
    String? backgroundImagePath,
    bool clearBackgroundImagePath = false,
    double? backgroundOpacity,
    bool? hasCustomPalette,
    ColorScheme? lightScheme,
    ColorScheme? darkScheme,
    bool clearSchemes = false,
  }) {
    return _ThemeSettings(
      preference: preference ?? this.preference,
      backgroundImagePath: clearBackgroundImagePath
          ? null
          : (backgroundImagePath ?? this.backgroundImagePath),
      backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
      hasCustomPalette: hasCustomPalette ?? this.hasCustomPalette,
      lightScheme: clearSchemes ? null : (lightScheme ?? this.lightScheme),
      darkScheme: clearSchemes ? null : (darkScheme ?? this.darkScheme),
    );
  }
}

class TimetableApp extends StatefulWidget {
  const TimetableApp({
    this.initialWeekday,
    super.key,
  });

  final int? initialWeekday;

  @override
  State<TimetableApp> createState() => _TimetableAppState();
}

class _TimetableAppState extends State<TimetableApp> {
  static const String _themePreferenceKey = 'theme_preference';
  static const String _backgroundImagePathKey = 'background_image_path';
  static const String _backgroundOpacityKey = 'background_opacity';

  _ThemeSettings _settings = const _ThemeSettings(
    preference: AppThemePreference.system,
    backgroundImagePath: null,
    backgroundOpacity: 0.34,
    hasCustomPalette: false,
  );

  @override
  void initState() {
    super.initState();
    _restoreThemeSettings();
  }

  Future<void> _restoreThemeSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPreference = prefs.getInt(_themePreferenceKey);
    final savedPath = prefs.getString(_backgroundImagePathKey);
    final savedOpacity = prefs.getDouble(_backgroundOpacityKey);

    var nextSettings = _settings.copyWith(
      preference: savedPreference != null && savedPreference >= 0 && savedPreference < AppThemePreference.values.length
          ? AppThemePreference.values[savedPreference]
          : AppThemePreference.system,
      backgroundImagePath: savedPath,
      backgroundOpacity: (savedOpacity ?? _settings.backgroundOpacity).clamp(0.12, 0.72),
      hasCustomPalette: false,
      clearSchemes: true,
    );

    final backgroundFile = nextSettings.backgroundImageFile;
    if (backgroundFile != null) {
      final palette = await _deriveSchemesFromImage(backgroundFile);
      if (palette != null) {
        nextSettings = nextSettings.copyWith(
          lightScheme: palette.$1,
          darkScheme: palette.$2,
          hasCustomPalette: true,
        );
      }
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _settings = nextSettings;
    });
  }

  Future<(ColorScheme, ColorScheme)?> _deriveSchemesFromImage(File imageFile) async {
    if (!imageFile.existsSync()) {
      return null;
    }

    final provider = FileImage(imageFile);
    try {
      final results = await Future.wait<ColorScheme>(<Future<ColorScheme>>[
        ColorScheme.fromImageProvider(provider: provider, brightness: Brightness.light),
        ColorScheme.fromImageProvider(provider: provider, brightness: Brightness.dark),
      ]);
      return (results[0], results[1]);
    } catch (_) {
      return null;
    }
  }

  Future<void> _setThemePreference(AppThemePreference preference) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themePreferenceKey, preference.index);
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = _settings.copyWith(preference: preference);
    });
  }

  Future<void> _setBackgroundOpacity(double opacity) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = opacity.clamp(0.12, 0.72);
    await prefs.setDouble(_backgroundOpacityKey, normalized);
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = _settings.copyWith(backgroundOpacity: normalized);
    });
  }

  Future<bool> _pickBackgroundImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    final file = result?.files.single;
    if (file == null) {
      return false;
    }

    final directory = await getApplicationDocumentsDirectory();
    final extension = file.extension?.trim();
    final savedFile = File(
      '${directory.path}${Platform.pathSeparator}timetable_background${extension == null || extension.isEmpty ? '.png' : '.${extension.toLowerCase()}'}',
    );

    final bytes = file.bytes;
    if (bytes != null) {
      await savedFile.writeAsBytes(bytes, flush: true);
    } else if (file.path != null) {
      await File(file.path!).copy(savedFile.path);
    } else {
      return false;
    }

    final palette = await _deriveSchemesFromImage(savedFile);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_backgroundImagePathKey, savedFile.path);

    if (!mounted) {
      return false;
    }

    setState(() {
      _settings = _settings.copyWith(
        backgroundImagePath: savedFile.path,
        lightScheme: palette?.$1,
        darkScheme: palette?.$2,
        hasCustomPalette: palette != null,
      );
    });
    return true;
  }

  Future<void> _clearBackgroundImage() async {
    final existing = _settings.backgroundImageFile;
    if (existing != null && existing.existsSync()) {
      await existing.delete();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_backgroundImagePathKey);

    if (!mounted) {
      return;
    }
    setState(() {
      _settings = _settings.copyWith(
        clearBackgroundImagePath: true,
        hasCustomPalette: false,
        clearSchemes: true,
      );
    });
  }

  ThemeData _buildTheme({
    required Brightness brightness,
    required ColorScheme scheme,
  }) {
    final isDark = brightness == Brightness.dark;
    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
    );

    final cardColor = isDark ? const Color(0xCC101826) : Colors.white.withValues(alpha: 0.82);
    final outlineColor = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xD7D9E7F4);

    return baseTheme.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : const Color(0xFFF8FAFC),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        margin: EdgeInsets.zero,
      ),
      chipTheme: baseTheme.chipTheme.copyWith(
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      dividerColor: outlineColor,
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        extendedPadding: const EdgeInsets.symmetric(horizontal: 20),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF08111F) : const Color(0xFF0F172A),
        contentTextStyle: baseTheme.textTheme.bodyMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? const Color(0xFF091321) : const Color(0xFFF8FAFC),
        modalBackgroundColor: isDark ? const Color(0xFF091321) : const Color(0xFFF8FAFC),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
      sliderTheme: baseTheme.sliderTheme.copyWith(
        activeTrackColor: scheme.primary,
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.12),
      ),
    );
  }

  ColorScheme _fallbackScheme(Brightness brightness) {
    return ColorScheme.fromSeed(
      seedColor: const Color(0xFF2563EB),
      brightness: brightness,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final lightScheme = _settings.lightScheme ??
            (lightDynamic != null
                ? ColorScheme.fromSeed(seedColor: lightDynamic.primary, brightness: Brightness.light)
                : _fallbackScheme(Brightness.light));
        final darkScheme = _settings.darkScheme ??
            (darkDynamic != null
                ? ColorScheme.fromSeed(seedColor: darkDynamic.primary, brightness: Brightness.dark)
                : _fallbackScheme(Brightness.dark));

        return MaterialApp(
          title: '课程表',
          debugShowCheckedModeBanner: false,
          themeMode: _settings.themeMode,
          theme: _buildTheme(brightness: Brightness.light, scheme: lightScheme),
          darkTheme: _buildTheme(brightness: Brightness.dark, scheme: darkScheme),
          home: TimetableHomePage(
            initialWeekday: widget.initialWeekday,
            themePreference: _settings.preference,
            backgroundImage: _settings.backgroundImageFile,
            backgroundOpacity: _settings.backgroundOpacity,
            onThemePreferenceSelected: _setThemePreference,
            onPickBackgroundImage: _pickBackgroundImage,
            onClearBackgroundImage: _clearBackgroundImage,
            onBackgroundOpacityChanged: _setBackgroundOpacity,
            hasCustomPalette: _settings.hasCustomPalette,
          ),
        );
      },
    );
  }
}

class TimetableHomePage extends StatefulWidget {
  const TimetableHomePage({
    required this.themePreference,
    required this.backgroundImage,
    required this.backgroundOpacity,
    required this.onThemePreferenceSelected,
    required this.onPickBackgroundImage,
    required this.onClearBackgroundImage,
    required this.onBackgroundOpacityChanged,
    required this.hasCustomPalette,
    this.initialWeekday,
    super.key,
  });

  final int? initialWeekday;
  final AppThemePreference themePreference;
  final File? backgroundImage;
  final double backgroundOpacity;
  final ValueChanged<AppThemePreference> onThemePreferenceSelected;
  final Future<bool> Function() onPickBackgroundImage;
  final Future<void> Function() onClearBackgroundImage;
  final Future<void> Function(double opacity) onBackgroundOpacityChanged;
  final bool hasCustomPalette;

  @override
  State<TimetableHomePage> createState() => _TimetableHomePageState();
}

class _TimetableHomePageState extends State<TimetableHomePage> {
  late int selectedWeekday = _normalizeWeekday(widget.initialWeekday ?? _currentSchoolWeekday());
  final CourseHtmlParser _htmlParser = const CourseHtmlParser();
  final CalendarExporter _calendarExporter = const CalendarExporter();
  final CourseStorage _courseStorage = CourseStorage();
  List<Course> courses = sampleCourses.toList();

  @override
  void initState() {
    super.initState();
    _restoreCourses();
  }

  List<Course> get selectedCourses {
    final visibleCourses = courses.where((course) => course.weekday == selectedWeekday).toList()
      ..sort((left, right) => left.startSlot.compareTo(right.startSlot));
    return visibleCourses;
  }

  Future<void> _restoreCourses() async {
    final restoredCourses = await _courseStorage.loadCourses();
    if (!mounted) {
      return;
    }

    setState(() {
      courses = restoredCourses;
      if (restoredCourses.isNotEmpty) {
        selectedWeekday = _normalizeWeekday(restoredCourses.first.weekday);
      }
    });
  }

  Future<void> _persistCourses() async {
    await _courseStorage.saveCourses(courses);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final compactLayout = MediaQuery.sizeOf(context).height < 760;
    final weekdayLabel = weekdays[selectedWeekday - 1];
    final bodyColor = colorScheme.onSurface;
    final outline = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFD9E4F5);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '课程表',
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              widget.hasCustomPalette ? '已根据你的背景图自动取色' : '切换日期、导入课表、导出今日提醒',
              style: theme.textTheme.labelMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.74),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: <Widget>[
                _ThemeModeMenuButton(
                  preference: widget.themePreference,
                  onSelected: widget.onThemePreferenceSelected,
                ),
                const SizedBox(width: 8),
                _TopActionButton(
                  tooltip: '个性化背景',
                  icon: Icons.wallpaper_rounded,
                  onPressed: _openAppearanceSheet,
                ),
                const SizedBox(width: 8),
                _TopActionButton(
                  tooltip: '导入 HTML 课程表',
                  icon: Icons.upload_file_rounded,
                  onPressed: _importFromHtml,
                ),
                const SizedBox(width: 8),
                _TopActionButton(
                  tooltip: '从教务系统网页导入',
                  icon: Icons.language_rounded,
                  onPressed: _importFromEducationWeb,
                ),
                const SizedBox(width: 8),
                _TopActionButton(
                  tooltip: '逐个保存当天课程到系统日程',
                  icon: Icons.event_available_rounded,
                  onPressed: selectedCourses.isEmpty ? null : _exportSelectedCourses,
                ),
                const SizedBox(width: 8),
                _TopActionButton(
                  tooltip: '本周',
                  icon: Icons.today_rounded,
                  onPressed: () {
                    setState(() => selectedWeekday = _currentSchoolWeekday());
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _AdaptiveBackdrop(
            imageFile: widget.backgroundImage,
            overlayOpacity: widget.backgroundOpacity,
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, compactLayout ? 8 : 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(height: compactLayout ? 16 : 48),
                  _HeroPanel(
                    weekdayLabel: weekdayLabel,
                    courseCount: selectedCourses.length,
                    onSurface: bodyColor,
                  ),
                  SizedBox(height: compactLayout ? 12 : 18),
                  _WeekdaySelector(
                    selectedWeekday: selectedWeekday,
                    onSelected: (weekday) => setState(() => selectedWeekday = weekday),
                  ),
                  SizedBox(height: compactLayout ? 12 : 18),
                  _TodaySummary(
                    weekday: selectedWeekday,
                    courseCount: selectedCourses.length,
                  ),
                  SizedBox(height: compactLayout ? 12 : 18),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.035) : Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: outline),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        child: _CourseList(
                          courses: selectedCourses,
                          onEdit: _editCourse,
                          onDelete: _deleteCourse,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createCourse,
        icon: const Icon(Icons.add_rounded),
        label: const Text('添加课程', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Future<void> _createCourse() async {
    await _openCourseEditor();
  }

  Future<void> _editCourse(Course course) async {
    final index = courses.indexOf(course);
    if (index < 0) {
      return;
    }
    await _openCourseEditor(course: course, index: index);
  }

  Future<void> _deleteCourse(Course course) async {
    setState(() {
      courses = courses.where((item) => item != course).toList();
    });
    await _persistCourses();
    _showMessage('已删除 ${course.name}');
  }

  Future<void> _openCourseEditor({Course? course, int? index}) async {
    final result = await showModalBottomSheet<Course>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CourseEditorSheet(initialCourse: course),
    );
    if (result == null) {
      return;
    }

    final nextCourses = courses.toList();
    if (index == null) {
      nextCourses.add(result);
    } else {
      nextCourses[index] = result;
    }
    nextCourses.sort((left, right) {
      final weekdayCompare = left.weekday.compareTo(right.weekday);
      if (weekdayCompare != 0) {
        return weekdayCompare;
      }
      return left.startSlot.compareTo(right.startSlot);
    });

    setState(() {
      courses = nextCourses;
      selectedWeekday = result.weekday;
    });
    await _persistCourses();
    _showMessage(index == null ? '已添加 ${result.name}' : '已更新 ${result.name}');
  }

  Future<void> _openAppearanceSheet() async {
    final theme = Theme.of(context);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            var localOpacity = widget.backgroundOpacity;

            Future<void> updateOpacity(double value) async {
              setSheetState(() => localOpacity = value);
              await widget.onBackgroundOpacityChanged(value);
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).padding.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.palette_rounded, color: theme.colorScheme.primary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('个性化外观', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 4),
                            Text(
                              '支持自定义背景图、类似 Monet 的主色联动，以及透明度调节。',
                              style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _SheetActionTile(
                    icon: Icons.image_outlined,
                    title: '上传背景图',
                    subtitle: '从本地图片生成背景，并自动提取主色。',
                    onTap: () async {
                      final navigator = Navigator.of(context);
                      final success = await widget.onPickBackgroundImage();
                      if (!mounted) {
                        return;
                      }
                      if (success) {
                        navigator.pop();
                        _showMessage('背景图已更新，并已自动生成配套主题色。');
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  _SheetActionTile(
                    icon: Icons.hide_image_outlined,
                    title: '移除背景图',
                    subtitle: '恢复纯色氛围背景，但保留主题模式选择。',
                    enabled: widget.backgroundImage != null,
                    onTap: () async {
                      final navigator = Navigator.of(context);
                      await widget.onClearBackgroundImage();
                      if (!mounted) {
                        return;
                      }
                      navigator.pop();
                      _showMessage('已移除背景图，恢复默认背景。');
                    },
                  ),
                  const SizedBox(height: 22),
                  Text('背景透明度', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(
                    '数值越高，背景图片越明显；数值越低，信息内容更突出。',
                    style: theme.textTheme.bodySmall,
                  ),
                  Slider(
                    value: localOpacity,
                    min: 0.12,
                    max: 0.72,
                    divisions: 12,
                    label: '${(localOpacity * 100).round()}%',
                    onChanged: updateOpacity,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _importFromHtml() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const <String>['html', 'htm'],
        withData: true,
      );
      final file = result?.files.single;
      final bytes = file?.bytes;
      if (bytes == null) {
        return;
      }

      final importedCourses = _htmlParser.parse(utf8.decode(bytes, allowMalformed: true));
      if (importedCourses.isEmpty) {
        _showMessage('没有从 HTML 中识别到课程，请检查是否包含课程名、星期和节次。');
        return;
      }

      setState(() {
        courses = importedCourses;
        selectedWeekday = _normalizeWeekday(importedCourses.first.weekday);
      });
      await _persistCourses();
      _showMessage('已导入 ${importedCourses.length} 门课程');
    } on Exception catch (error) {
      _showMessage('导入失败：$error');
    }
  }

  Future<void> _importFromEducationWeb() async {
    final url = await _askEducationSystemUrl();
    if (url == null || !mounted) {
      return;
    }

    final html = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => EducationWebImportPage(initialUrl: url),
      ),
    );
    if (html == null) {
      return;
    }

    final importedCourses = _htmlParser.parse(html);
    if (importedCourses.isEmpty) {
      _showMessage('当前网页未识别到课程，请确认已经进入课表页面。');
      return;
    }

    setState(() {
      courses = importedCourses;
      selectedWeekday = _normalizeWeekday(importedCourses.first.weekday);
    });
    await _persistCourses();
    _showMessage('已从教务系统导入 ${importedCourses.length} 门课程');
  }

  Future<Uri?> _askEducationSystemUrl() async {
    final controller = TextEditingController(text: 'https://');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('教务系统网址'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.url,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '登录页或课表页 URL',
            hintText: 'https://jw.example.edu.cn',
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('打开'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) {
      return null;
    }

    final value = result.trim();
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      _showMessage('请输入完整的网址，例如 https://jw.example.edu.cn');
      return null;
    }
    return uri;
  }

  Future<void> _exportSelectedCourses() async {
    try {
      _showMessage('将逐个打开系统日历保存界面，请按提示确认每门课程。');
      await _calendarExporter.addCourses(selectedCourses);
      _showMessage('已打开系统日程，按提示保存后即可收到系统提醒。');
    } on Exception catch (error) {
      _showMessage('写入系统日程失败：$error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

int _currentSchoolWeekday() {
  return _normalizeWeekday(DateTime.now().weekday);
}

int _normalizeWeekday(int weekday) {
  if (weekday < DateTime.monday) {
    return DateTime.monday;
  }
  if (weekday > DateTime.sunday) {
    return DateTime.sunday;
  }
  return weekday;
}

class _AdaptiveBackdrop extends StatelessWidget {
  const _AdaptiveBackdrop({
    required this.imageFile,
    required this.overlayOpacity,
  });

  final File? imageFile;
  final double overlayOpacity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? <Color>[
                  const Color(0xFF040B16),
                  theme.colorScheme.primary.withValues(alpha: 0.42),
                  const Color(0xFF0D1728),
                  const Color(0xFF050A14),
                ]
              : <Color>[
                  const Color(0xFFEFF4FF),
                  theme.colorScheme.primary.withValues(alpha: 0.18),
                  const Color(0xFFF9FBFF),
                  const Color(0xFFE7ECF8),
                ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (imageFile != null)
            Opacity(
              opacity: overlayOpacity,
              child: Image.file(imageFile!, fit: BoxFit.cover),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? <Color>[
                        const Color(0xBB02060D),
                        const Color(0x9A08111F),
                        const Color(0xED07111D),
                      ]
                    : <Color>[
                        Colors.white.withValues(alpha: 0.28),
                        const Color(0xCCF5F8FF),
                        const Color(0xEEF8FAFD),
                      ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.weekdayLabel,
    required this.courseCount,
    required this.onSurface,
  });

  final String weekdayLabel;
  final int courseCount;
  final Color onSurface;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            theme.colorScheme.primary.withValues(alpha: isDark ? 0.52 : 0.88),
            theme.colorScheme.secondary.withValues(alpha: isDark ? 0.44 : 0.82),
            theme.colorScheme.tertiary.withValues(alpha: isDark ? 0.34 : 0.74),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.28)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.18 : 0.20),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                ),
                child: Text(
                  '今天 · $weekdayLabel',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            courseCount == 0 ? '今天课表很轻，可以安排自己的节奏。' : '共有 $courseCount 门课程，重点信息已经整理好了。',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              height: 1.18,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _HeroMetricPill(label: '状态', value: courseCount == 0 ? '轻松日' : '学习中'),
              _HeroMetricPill(label: '课程数', value: courseCount.toString().padLeft(2, '0')),
              const _HeroMetricPill(label: '风格', value: 'Monet 联动'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetricPill extends StatelessWidget {
  const _HeroMetricPill({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: RichText(
        text: TextSpan(
          style: theme.textTheme.labelMedium?.copyWith(color: Colors.white),
          children: <InlineSpan>[
            TextSpan(text: '$label  ', style: const TextStyle(fontWeight: FontWeight.w500)),
            TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _ThemeModeMenuButton extends StatelessWidget {
  const _ThemeModeMenuButton({
    required this.preference,
    required this.onSelected,
  });

  final AppThemePreference preference;
  final ValueChanged<AppThemePreference> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<AppThemePreference>(
      tooltip: '主题模式',
      onSelected: onSelected,
      itemBuilder: (context) => <PopupMenuEntry<AppThemePreference>>[
        CheckedPopupMenuItem<AppThemePreference>(
          value: AppThemePreference.system,
          checked: preference == AppThemePreference.system,
          child: const Text('跟随系统'),
        ),
        CheckedPopupMenuItem<AppThemePreference>(
          value: AppThemePreference.light,
          checked: preference == AppThemePreference.light,
          child: const Text('浅色模式'),
        ),
        CheckedPopupMenuItem<AppThemePreference>(
          value: AppThemePreference.dark,
          checked: preference == AppThemePreference.dark,
          child: const Text('深色模式'),
        ),
      ],
      child: const _TopActionButton(
        tooltip: '主题模式',
        icon: Icons.palette_outlined,
      ),
    );
  }
}

class _TopActionButton extends StatelessWidget {
  const _TopActionButton({
    required this.tooltip,
    required this.icon,
    this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: enabled
            ? Colors.white.withValues(alpha: isDark ? 0.10 : 0.14)
            : Colors.white.withValues(alpha: isDark ? 0.04 : 0.08),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: enabled
                    ? Colors.white.withValues(alpha: isDark ? 0.10 : 0.20)
                    : Colors.white.withValues(alpha: 0.06),
              ),
            ),
            child: Icon(
              icon,
              size: 20,
              color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.38),
            ),
          ),
        ),
      ),
    );
  }
}

class _WeekdaySelector extends StatelessWidget {
  const _WeekdaySelector({
    required this.selectedWeekday,
    required this.onSelected,
  });

  final int selectedWeekday;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: weekdays.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final weekday = index + 1;
          final selected = selectedWeekday == weekday;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: selected
                  ? LinearGradient(
                      colors: <Color>[
                        theme.colorScheme.primary,
                        theme.colorScheme.tertiary,
                      ],
                    )
                  : null,
              color: selected
                  ? null
                  : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.82)),
              border: Border.all(
                color: selected
                    ? Colors.white.withValues(alpha: 0.16)
                    : (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFD9E4F5)),
              ),
              boxShadow: selected
                  ? <BoxShadow>[
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.22),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: ChoiceChip(
              label: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(weekdays[index]),
              ),
              selected: selected,
              onSelected: (_) => onSelected(weekday),
              showCheckmark: false,
              labelStyle: theme.textTheme.labelLarge?.copyWith(
                color: selected ? Colors.white : theme.colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
              selectedColor: Colors.transparent,
              backgroundColor: Colors.transparent,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          );
        },
      ),
    );
  }
}

class _TodaySummary extends StatelessWidget {
  const _TodaySummary({
    required this.weekday,
    required this.courseCount,
  });

  final int weekday;
  final int courseCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            theme.colorScheme.surface.withValues(alpha: 0.78),
            theme.colorScheme.primaryContainer.withValues(alpha: 0.74),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.dividerColor),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.wb_sunny_outlined, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${weekdays[weekday - 1]}安排',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      courseCount == 0 ? '轻松一点，今天可以把时间留给自己。' : '课程已经按时间顺序排好，出门前看一眼就够。',
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Row(
              children: <Widget>[
                Text(
                  courseCount.toString().padLeft(2, '0'),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    courseCount == 1 ? '今天只需要处理 1 门课程。' : '今天共有 $courseCount 门课程。',
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseList extends StatelessWidget {
  const _CourseList({
    required this.courses,
    required this.onEdit,
    required this.onDelete,
  });

  final List<Course> courses;
  final ValueChanged<Course> onEdit;
  final ValueChanged<Course> onDelete;

  @override
  Widget build(BuildContext context) {
    if (courses.isEmpty) {
      return const _EmptyState();
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      itemCount: courses.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) => _CourseCard(
        course: courses[index],
        onEdit: () => onEdit(courses[index]),
        onDelete: () => onDelete(courses[index]),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.course,
    required this.onEdit,
    required this.onDelete,
  });

  final Course course;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xBF0C1522) : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.dividerColor),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: course.color.withValues(alpha: isDark ? 0.14 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 64,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  course.color.withValues(alpha: 0.98),
                  course.color.withValues(alpha: 0.72),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.schedule_rounded, color: Colors.white, size: 18),
                const SizedBox(height: 8),
                Text(
                  course.timeText.replaceAll('第', '').replaceAll('节', ''),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        course.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    PopupMenuButton<_CourseAction>(
                      tooltip: '课程操作',
                      onSelected: (action) {
                        switch (action) {
                          case _CourseAction.edit:
                            onEdit();
                          case _CourseAction.delete:
                            onDelete();
                        }
                      },
                      itemBuilder: (context) => const <PopupMenuEntry<_CourseAction>>[
                        PopupMenuItem<_CourseAction>(
                          value: _CourseAction.edit,
                          child: Text('编辑课程'),
                        ),
                        PopupMenuItem<_CourseAction>(
                          value: _CourseAction.delete,
                          child: Text('删除课程'),
                        ),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: course.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '课程',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: course.color,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '教室、周次和授课教师都整理在下方，适合出门前快速确认。',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    _InfoPill(icon: Icons.schedule_rounded, text: course.timeText, tint: course.color),
                    _InfoPill(icon: Icons.date_range_rounded, text: course.weekText, tint: course.color),
                    _InfoPill(icon: Icons.location_on_rounded, text: course.room, tint: course.color),
                    _InfoPill(icon: Icons.person_rounded, text: course.teacher, tint: course.color),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _CourseAction { edit, delete }

class _CourseEditorSheet extends StatefulWidget {
  const _CourseEditorSheet({this.initialCourse});

  final Course? initialCourse;

  @override
  State<_CourseEditorSheet> createState() => _CourseEditorSheetState();
}

class _CourseEditorSheetState extends State<_CourseEditorSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _teacherController;
  late final TextEditingController _roomController;
  late final TextEditingController _startSlotController;
  late final TextEditingController _endSlotController;
  late final TextEditingController _weeksController;
  late int _weekday;

  @override
  void initState() {
    super.initState();
    final course = widget.initialCourse;
    _nameController = TextEditingController(text: course?.name ?? '');
    _teacherController = TextEditingController(text: course?.teacher ?? '');
    _roomController = TextEditingController(text: course?.room ?? '');
    _startSlotController = TextEditingController(text: '${course?.startSlot ?? 1}');
    _endSlotController = TextEditingController(text: '${course?.endSlot ?? 2}');
    _weeksController = TextEditingController(text: _formatWeeks(course?.weeks ?? const <int>[]));
    _weekday = course?.weekday ?? DateTime.monday;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _teacherController.dispose();
    _roomController.dispose();
    _startSlotController.dispose();
    _endSlotController.dispose();
    _weeksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                widget.initialCourse == null ? '新建课程' : '编辑课程',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '课程名称'),
                validator: (value) => _required(value, '课程名称'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _teacherController,
                decoration: const InputDecoration(labelText: '授课教师'),
                validator: (value) => _required(value, '授课教师'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _roomController,
                decoration: const InputDecoration(labelText: '上课地点'),
                validator: (value) => _required(value, '上课地点'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _weekday,
                decoration: const InputDecoration(labelText: '星期'),
                items: List<DropdownMenuItem<int>>.generate(
                  weekdays.length,
                  (index) => DropdownMenuItem<int>(
                    value: index + 1,
                    child: Text(weekdays[index]),
                  ),
                ),
                onChanged: (value) {
                  if (value != null) {
                    _weekday = value;
                  }
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextFormField(
                      controller: _startSlotController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '开始节次'),
                      validator: (value) => _slot(value, '开始节次'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _endSlotController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '结束节次'),
                      validator: (value) => _slot(value, '结束节次'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _weeksController,
                decoration: const InputDecoration(labelText: '周次', hintText: '例如 1-16'),
                validator: (value) => _parseWeeks(value).isEmpty ? '请输入有效周次，例如 1-16' : null,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  child: const Text('保存课程'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '请输入$label';
    }
    return null;
  }

  String? _slot(String? value, String label) {
    final parsed = int.tryParse((value ?? '').trim());
    if (parsed == null || parsed < 1 || parsed > 12) {
      return '$label需为 1-12';
    }
    return null;
  }

  List<int> _parseWeeks(String? input) {
    final trimmed = (input ?? '').trim();
    final range = RegExp(r'^(\d{1,2})\s*[-~至到]\s*(\d{1,2})$').firstMatch(trimmed);
    if (range != null) {
      final start = int.parse(range.group(1)!);
      final end = int.parse(range.group(2)!);
      if (end < start) {
        return const <int>[];
      }
      return List<int>.generate(end - start + 1, (index) => start + index);
    }
    final single = int.tryParse(trimmed);
    return single == null ? const <int>[] : <int>[single];
  }

  String _formatWeeks(List<int> weeks) {
    if (weeks.isEmpty) {
      return '1-16';
    }
    if (weeks.length == 1) {
      return '${weeks.first}';
    }
    return '${weeks.first}-${weeks.last}';
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final startSlot = int.parse(_startSlotController.text.trim());
    final endSlot = int.parse(_endSlotController.text.trim());
    if (endSlot < startSlot) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('结束节次不能早于开始节次')),
      );
      return;
    }

    final color = widget.initialCourse?.color ?? coursePalette[(_weekday + startSlot + endSlot) % coursePalette.length];
    Navigator.of(context).pop(
      Course(
        name: _nameController.text.trim(),
        teacher: _teacherController.text.trim(),
        room: _roomController.text.trim(),
        weekday: _weekday,
        startSlot: startSlot,
        endSlot: endSlot,
        color: color,
        weeks: _parseWeeks(_weeksController.text),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.text,
    required this.tint,
  });

  final IconData icon;
  final String text;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 14, color: tint),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xB20B1422) : Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    theme.colorScheme.primary.withValues(alpha: 0.20),
                    theme.colorScheme.secondary.withValues(alpha: 0.30),
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(
                Icons.event_available_rounded,
                size: 40,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '这一天还没有课程',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '你可以切换到其他日期，或者点击右上角自定义背景，让课程表更像你自己的桌面。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetActionTile extends StatelessWidget {
  const _SheetActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Future<void> Function() onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: InkWell(
        onTap: enabled ? () => onTap() : null,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(height: 1.35)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

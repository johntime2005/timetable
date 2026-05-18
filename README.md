# Timetable

一个用 Flutter 编写的课程表应用原型，目标是把“导入课表、查看当天安排、把课程写入系统日历”这条链路先跑通。

## 当前能力

- 按工作日切换课程视图
- 展示当天课程摘要与课程卡片
- 支持从本地 HTML 文件导入课程表
- 支持在内置网页中登录教务系统后，一键读取当前课表页 HTML 并导入
- 支持将当天课程逐个导出到系统日历
- 包含空状态与后续“添加课程”扩展入口

## 技术栈

- Flutter
- Dart
- `file_picker`：选择本地 HTML 文件
- `html`：解析课表 HTML
- `webview_flutter`：承载教务系统网页导入流程
- `add_2_calendar`：导出课程到系统日历

## 项目结构

```text
lib/
  main.dart                     # 主界面与交互入口
  course.dart                   # 课程数据模型
  course_html_parser.dart       # HTML 课程表解析器
  education_web_import_page.dart# 教务系统网页导入页
  calendar_exporter.dart        # 日历导出逻辑

test/
  course_html_parser_test.dart
  calendar_exporter_test.dart
  widget_test.dart
```

## 使用流程

### 1. 从 HTML 文件导入

点击右上角“导入 HTML 课程表”按钮，选择 `.html` 或 `.htm` 文件。解析器当前优先识别以下信息：

- 课程名，例如 `移动应用开发`
- 星期，例如 `周二` / `星期二`
- 节次，例如 `第3-4节`
- 教师，例如 `教师: 张老师`
- 教室，例如 `教室: A202`
- 周次，例如 `第1-16周`

示例：

```html
<table>
  <tr>
    <td>移动应用开发</td>
    <td>周二 第3-4节</td>
    <td>教师: 张老师</td>
    <td>教室: A202</td>
    <td>第1-16周</td>
  </tr>
</table>
```

### 2. 从教务系统网页导入

点击“从教务系统网页导入”后输入登录页或课表页 URL，应用会打开内置网页：

1. 用户手动完成登录、验证码、二次认证等步骤
2. 手动进入“我的课表 / 学生课表”等实际课表页面
3. 点击右上角“一键导入”
4. 应用读取当前页面 HTML，并复用 HTML 解析器导入课程

这种做法避免应用直接处理教务系统账号、密码或登录接口，适配成本更低。若目标系统限制内嵌网页、脚本读取，或依赖校内 VPN，可以先在浏览器中打开课表页并另存为 HTML，再回到应用中用文件导入。

### 3. 导出到系统日历

点击“导出当天课程到系统日程”后，应用会通过 `add_2_calendar` 逐个调起系统日历保存界面。当前策略是：

- 导出每门课的下一次上课时间
- 用户在系统日历界面逐项确认保存
- iOS 默认附带 15 分钟前提醒
- Android 的提醒策略取决于系统日历应用自身行为

## 兼容性边界

- 当前 HTML 解析器优先支持“同一行内同时出现课程名、星期、节次”的表格或文本块
- 如果教务系统课表使用网格布局、iframe、Shadow DOM、canvas 或异步接口渲染，通常需要拿真实 HTML 样本继续扩展解析规则
- `webview_flutter` 主要面向 Android / iOS / macOS 等原生平台；Flutter Web 端不适合复用同样的内嵌导入流程，因此 Web 端建议优先使用 HTML 文件导入

## 本地运行

安装 Flutter SDK 后，在项目根目录执行：

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

如果需要补齐 Android、iOS、Web 等平台目录，可执行：

```bash
flutter create --platforms=android,ios,web .
```

## 日历相关平台配置

后续如果补齐 Android / iOS 平台目录，需要按插件文档补充配置。

Android `android/app/src/main/AndroidManifest.xml`：

```xml
<queries>
  <intent>
    <action android:name="android.intent.action.INSERT" />
    <data android:mimeType="vnd.android.cursor.item/event" />
  </intent>
</queries>
```

iOS `ios/Runner/Info.plist`：

```xml
<key>NSCalendarsUsageDescription</key>
<string>用于将课程添加到系统日历并触发提醒</string>
<key>NSContactsUsageDescription</key>
<string>系统日历保存界面可能需要通讯录权限</string>
```

## 当前状态

这是一个可继续扩展的原型版本，已经覆盖：课表导入、课程查看、日历导出三条主路径。后续可以继续往下面扩展：

- 本地持久化课程数据
- 手动新增 / 编辑课程
- 更复杂的教务系统课表适配
- 批量或重复日程导出

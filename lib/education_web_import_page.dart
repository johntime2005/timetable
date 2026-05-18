import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class EducationWebImportPage extends StatefulWidget {
  const EducationWebImportPage({
    required this.initialUrl,
    super.key,
  });

  final Uri initialUrl;

  @override
  State<EducationWebImportPage> createState() => _EducationWebImportPageState();
}

class _EducationWebImportPageState extends State<EducationWebImportPage> {
  late final WebViewController _controller;
  var _isLoading = true;
  String? _currentUrl;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.initialUrl.toString();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() {
              _isLoading = true;
              _currentUrl = url;
            });
          },
          onPageFinished: (url) {
            setState(() {
              _isLoading = false;
              _currentUrl = url;
            });
          },
        ),
      )
      ..loadRequest(widget.initialUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('教务系统导入'),
        actions: <Widget>[
          IconButton(
            tooltip: '刷新页面',
            onPressed: () => _controller.reload(),
            icon: const Icon(Icons.refresh_rounded),
          ),
          FilledButton.icon(
            onPressed: _isLoading ? null : _importCurrentPage,
            icon: const Icon(Icons.download_done_rounded),
            label: const Text('一键导入'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: <Widget>[
          _ImportHint(currentUrl: _safeDisplayUrl(_currentUrl), isLoading: _isLoading),
          if (_isLoading) const LinearProgressIndicator(minHeight: 2),
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
    );
  }

  Future<void> _importCurrentPage() async {
    try {
      final result = await _controller.runJavaScriptReturningResult(
        'document.documentElement.outerHTML',
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(_normalizeJavaScriptString(result));
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('读取当前页面失败：$error')),
      );
    }
  }

  String _normalizeJavaScriptString(Object result) {
    final raw = result.toString();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is String) {
        return decoded;
      }
    } on FormatException {
      return raw;
    }
    return raw;
  }

  String? _safeDisplayUrl(String? url) {
    if (url == null) {
      return null;
    }
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) {
      return null;
    }
    return uri.replace(query: '', fragment: '').toString();
  }
}

class _ImportHint extends StatelessWidget {
  const _ImportHint({
    required this.currentUrl,
    required this.isLoading,
  });

  final String? currentUrl;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            isLoading ? '页面加载中…' : '登录并进入课表页后，点击右上角“一键导入”。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (currentUrl != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              currentUrl!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

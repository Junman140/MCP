import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../services/lms_api_client.dart';

/// Convert a video/resource URL into an embeddable form (YouTube, Vimeo, etc.).
/// Links are the primary path; HLS/file streams remain an alternative handled
/// separately by the player when a direct media URL is supplied.
String? toEmbedUrl(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final u = Uri.parse(raw);
    final host = u.host.replaceAll(RegExp(r'^www\.'), '');
    if (host == 'youtube.com' || host == 'm.youtube.com') {
      final id = u.queryParameters['v'];
      if (id != null && id.isNotEmpty) return 'https://www.youtube.com/embed/$id';
    } else if (host == 'youtu.be') {
      final id = u.pathSegments.where((s) => s.isNotEmpty).firstOrNull;
      if (id != null) return 'https://www.youtube.com/embed/$id';
    } else if (host == 'vimeo.com') {
      final id = u.pathSegments.where((s) => s.isNotEmpty).firstOrNull;
      if (id != null) return 'https://player.vimeo.com/video/$id';
    }
    return raw;
  } catch (_) {
    return raw;
  }
}

class LmsCourseViewerScreen extends StatefulWidget {
  final String courseId;
  final String courseName;
  const LmsCourseViewerScreen({super.key, required this.courseId, required this.courseName});

  @override
  State<LmsCourseViewerScreen> createState() => _LmsCourseViewerScreenState();
}

class _LmsCourseViewerScreenState extends State<LmsCourseViewerScreen> {
  List<dynamic> _modules = [];
  Map<String, List<dynamic>> _items = {};
  String? _selectedModule;
  Map<String, dynamic>? _selectedItem;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadModules();
  }

  Future<void> _loadModules() async {
    try {
      final res = await LmsApiClient.get('/courses/${widget.courseId}/modules');
      setState(() { _modules = (res.data as List<dynamic>?) ?? []; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _loadItems(String moduleId) async {
    try {
      final res = await LmsApiClient.get('/modules/$moduleId/items');
      setState(() { _items[moduleId] = (res.data as List<dynamic>?) ?? []; });
      await LmsApiClient.post('/student/progress/${widget.courseId}', data: {
        'moduleId': moduleId,
        'completionPercent': 0,
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return Scaffold(appBar: AppBar(title: Text(widget.courseName)), body: const Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: Text(widget.courseName)),
      body: Column(children: [
        LinearProgressIndicator(value: _modules.isNotEmpty ? _modules.where((m) => (_items[m['id']]?.any((i) => true) ?? false)).length / _modules.length : 0),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 140,
              child: ListView(
                children: _modules.map((m) => ListTile(
                  title: Text(m['title'] as String? ?? '', style: const TextStyle(fontSize: 13)),
                  selected: _selectedModule == m['id'],
                  selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
                  onTap: () { setState(() => _selectedModule = m['id'] as String?); _loadItems(m['id'] as String); },
                  dense: true,
                )).toList(),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: _selectedModule == null
                ? const Center(child: Text('Select a module'))
                : ListView(
                    children: (_items[_selectedModule] ?? []).map((i) {
                      final item = i as Map<String, dynamic>;
                      final isVideo = item['type'] == 'video';
                      return ListTile(
                        leading: Icon(isVideo ? Icons.play_circle : Icons.article, color: Theme.of(context).colorScheme.primary),
                        title: Text(item['title'] as String? ?? '', style: TextStyle(fontWeight: _selectedItem?['id'] == item['id'] ? FontWeight.bold : FontWeight.normal)),
                        subtitle: isVideo && item['duration'] != null ? Text('${item['duration']}s') : null,
                        selected: _selectedItem?['id'] == item['id'],
                        onTap: () => setState(() => _selectedItem = item),
                      );
                    }).toList(),
                  ),
            ),
          ]),
        ),
        if (_selectedItem != null) Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_selectedItem!['title'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text((_selectedItem!['type'] as String? ?? '').toUpperCase(),
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 12),
            _ItemContent(item: _selectedItem!),
            const SizedBox(height: 8),
            FilledButton.tonal(onPressed: () async {
              await LmsApiClient.post('/student/progress/${widget.courseId}', data: {
                'moduleId': _selectedModule,
                'completionPercent': 100,
              });
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Module completed!')));
            }, child: const Text('Mark Complete')),
          ]),
        ),
      ]),
    );
  }
}

/// Renders a course content item. Links (YouTube, Vimeo, etc.) are embedded
/// via WebView as the primary path; text bodies render inline.
class _ItemContent extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ItemContent({required this.item});

  @override
  Widget build(BuildContext context) {
    final type = (item['type'] as String? ?? '').toLowerCase();
    final url = item['url'] as String?;

    if ((type == 'video' || type == 'link' || type == 'url') && url != null && url.isNotEmpty) {
      final embed = toEmbedUrl(url);
      if (embed != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 220,
            child: WebViewWidget(
              controller: WebViewController()
                ..setJavaScriptMode(JavaScriptMode.unrestricted)
                ..loadRequest(Uri.parse(embed)),
            ),
          ),
        );
      }
    }

    if (type == 'text') {
      final text = (item['body'] as String?) ?? (item['description'] as String?) ?? '';
      if (text.isNotEmpty) return Text(text);
    }

    if (url != null && url.isNotEmpty) {
      return SelectableText(url, style: const TextStyle(color: Colors.blue));
    }

    return const Text('No preview available for this item.', style: TextStyle(color: Colors.grey));
  }
}

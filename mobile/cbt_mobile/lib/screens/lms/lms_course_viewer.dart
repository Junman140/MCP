import 'package:flutter/material.dart';
import '../../services/lms_api_client.dart';

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
          child: Row(children: [
            Expanded(child: Text(_selectedItem!['title'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
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

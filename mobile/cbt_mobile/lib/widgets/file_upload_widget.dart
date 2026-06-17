import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class FileUploadWidget extends StatefulWidget {
  final int maxFiles;
  final List<String>? allowedMimeTypes;
  final int maxBytes;
  final List<String>? initialPaths;
  final ValueChanged<List<String>> onFilesChanged;

  const FileUploadWidget({
    super.key,
    required this.maxFiles,
    this.allowedMimeTypes,
    this.maxBytes = 0,
    this.initialPaths,
    required this.onFilesChanged,
  });

  @override
  State<FileUploadWidget> createState() => _FileUploadWidgetState();
}

class _FileUploadWidgetState extends State<FileUploadWidget> {
  final List<String> _paths = [];
  String? _warning;

  @override
  void initState() {
    super.initState();
    if (widget.initialPaths != null) {
      _paths.addAll(widget.initialPaths!);
    }
  }

  Future<void> _pick() async {
    final allowed = widget.allowedMimeTypes;
    final extensions = allowed != null && allowed.isNotEmpty
        ? allowed.map((m) {
            if (m == 'image/*') return 'jpg,png,gif,bmp,webp';
            if (m == 'application/pdf') return 'pdf';
            return null;
          }).whereType<String>().join(',')
        : null;

    final res = await FilePicker.platform.pickFiles(
      allowMultiple: widget.maxFiles > 1,
      type: extensions != null ? FileType.custom : FileType.any,
      allowedExtensions: extensions?.split(','),
    );
    if (res == null) return;

    for (final f in res.files) {
      if (f.path == null) continue;

      // Check size constraint
      if (widget.maxBytes > 0 && f.size > widget.maxBytes) {
        final maxMB = (widget.maxBytes / (1024 * 1024)).toStringAsFixed(1);
        setState(() => _warning = 'File "${f.name}" exceeds ${maxMB}MB limit.');
        continue;
      }

      if (_paths.length >= widget.maxFiles) break;
      if (!_paths.contains(f.path!)) {
        _paths.add(f.path!);
      }
    }

    setState(() {});
    widget.onFilesChanged(List<String>.from(_paths));
  }

  @override
  Widget build(BuildContext context) {
    final maxFiles = widget.maxFiles <= 0 ? 1 : widget.maxFiles;
    final info = <String>[];
    if (widget.allowedMimeTypes != null && widget.allowedMimeTypes!.isNotEmpty) {
      info.add('Types: ${widget.allowedMimeTypes!.join(", ")}');
    }
    if (widget.maxBytes > 0) {
      info.add('Max: ${(widget.maxBytes / (1024 * 1024)).toStringAsFixed(1)} MB');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ElevatedButton(
              onPressed: _paths.length < maxFiles ? _pick : null,
              child: Text(maxFiles > 1 ? "Select files" : "Select file"),
            ),
            const SizedBox(width: 12),
            Text(
              "${_paths.length}/$maxFiles selected",
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        if (info.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(info.join(' · '), style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          ),
        if (_warning != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_warning!, style: const TextStyle(color: Colors.orange, fontSize: 13)),
          ),
        const SizedBox(height: 8),
        if (_paths.isEmpty)
          Text("No file selected.", style: TextStyle(color: Colors.grey[600]))
        else
          ..._paths.map((p) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(p.split(Platform.pathSeparator).last),
                subtitle: Text(p, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _paths.remove(p);
                      _warning = null;
                    });
                    widget.onFilesChanged(List<String>.from(_paths));
                  },
                ),
              )),
      ],
    );
  }
}

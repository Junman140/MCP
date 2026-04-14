import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class FileUploadWidget extends StatefulWidget {
  final int maxFiles;
  final List<File>? initialFiles;
  final ValueChanged<List<File>> onFilesChanged;

  const FileUploadWidget({
    super.key,
    required this.maxFiles,
    this.initialFiles,
    required this.onFilesChanged,
  });

  @override
  State<FileUploadWidget> createState() => _FileUploadWidgetState();
}

class _FileUploadWidgetState extends State<FileUploadWidget> {
  final List<File> _files = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialFiles != null) {
      _files.addAll(widget.initialFiles!);
    }
  }

  @override
  void didUpdateWidget(FileUploadWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Usually handled by parent using unique Key per question, but let's sync just in case
    if (widget.initialFiles != null && oldWidget.initialFiles != widget.initialFiles) {
      _files.clear();
      _files.addAll(widget.initialFiles!);
    }
  }

  Future<void> _pick() async {
    final res = await FilePicker.platform.pickFiles(allowMultiple: widget.maxFiles > 1);
    if (res == null) return;
    final picked = res.files
        .where((f) => f.path != null)
        .map((f) => File(f.path!))
        .toList();

    setState(() {
      _files.clear();
      _files.addAll(picked.take(widget.maxFiles <= 0 ? 1 : widget.maxFiles));
    });
    widget.onFilesChanged(List<File>.from(_files));
  }

  @override
  Widget build(BuildContext context) {
    final maxFiles = widget.maxFiles <= 0 ? 1 : widget.maxFiles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ElevatedButton(
              onPressed: _pick,
              child: Text(maxFiles > 1 ? "Select files" : "Select file"),
            ),
            const SizedBox(width: 12),
            Text(
              "Max: $maxFiles",
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_files.isEmpty)
          Text("No file selected.", style: TextStyle(color: Colors.grey[600]))
        else
          ..._files.map((f) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(f.path.split(Platform.pathSeparator).last),
                subtitle: Text(f.path),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() => _files.remove(f));
                    widget.onFilesChanged(List<File>.from(_files));
                  },
                ),
              )),
      ],
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../models/exam.dart';
import 'essay_widget.dart';
import 'file_upload_widget.dart';

class QuestionWidget extends StatelessWidget {
  final Question question;
  final String examDirPath;
  final String? selectedOptionId;
  final String? essayText;
  final ValueChanged<String>? onOptionSelected;
  final ValueChanged<String>? onEssayChanged;
  final ValueChanged<String>? onEssayEditingComplete;
  final List<String>? filePaths;
  final ValueChanged<List<String>>? onFilesChanged;

  const QuestionWidget({
    super.key,
    required this.question,
    required this.examDirPath,
    this.selectedOptionId,
    this.essayText,
    this.onOptionSelected,
    this.onEssayChanged,
    this.onEssayEditingComplete,
    this.filePaths,
    this.onFilesChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRichText(question.content),
        const SizedBox(height: 16),

        if (question.media.isNotEmpty)
          ...question.media.map(
            (path) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Image.file(File('$examDirPath/$path')),
            ),
          ),

        if (question.type == "mcq" || question.type == "multiple_choice") ...[
          ...question.options.map(
            (option) => RadioListTile<String>(
              title: _buildRichText(option.text),
              value: option.id,
              groupValue: selectedOptionId,
              onChanged: onOptionSelected == null ? null : (val) => onOptionSelected!(val!),
            ),
          ),
        ] else if (question.type == "essay") ...[
          EssayWidget(
            initialValue: essayText,
            wordLimit: question.wordLimit,
            onChanged: (txt) => onEssayChanged?.call(txt),
            onEditingComplete: (txt) => onEssayEditingComplete?.call(txt),
          ),
        ] else if (question.type == "file_upload") ...[
          FileUploadWidget(
            maxFiles: question.fileUpload?.maxFiles ?? 1,
            allowedMimeTypes: question.fileUpload?.allowedMimeTypes,
            maxBytes: question.fileUpload?.maxBytes ?? 0,
            initialPaths: filePaths,
            onFilesChanged: (paths) => onFilesChanged?.call(paths),
          ),
        ] else ...[
          Text(
            "Unsupported question type: ${question.type}",
            style: TextStyle(color: Colors.red[600]),
          ),
        ],
      ],
    );
  }

  Widget _buildRichText(String text) {
    final regex = RegExp(r'\$\$(.*?)\$\$');
    final matches = regex.allMatches(text);
    if (matches.isEmpty) return MarkdownBody(data: text);

    List<Widget> children = [];
    int lastEnd = 0;
    for (var match in matches) {
      if (match.start > lastEnd) {
        children.add(MarkdownBody(data: text.substring(lastEnd, match.start)));
      }
      children.add(Math.tex(match.group(1)!, mathStyle: MathStyle.display));
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      children.add(MarkdownBody(data: text.substring(lastEnd)));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}

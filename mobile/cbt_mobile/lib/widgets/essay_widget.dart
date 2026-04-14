import 'package:flutter/material.dart';

class EssayWidget extends StatefulWidget {
  final String? initialValue;
  final int wordLimit;
  final ValueChanged<String> onChanged;

  const EssayWidget({
    super.key,
    this.initialValue,
    required this.wordLimit,
    required this.onChanged,
  });

  @override
  State<EssayWidget> createState() => _EssayWidgetState();
}

class _EssayWidgetState extends State<EssayWidget> {
  late TextEditingController _controller;
  int _wordCount = 0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? "");
    _wordCount = _countWords(_controller.text);
    _controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(EssayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != null && widget.initialValue != _controller.text && oldWidget.initialValue != widget.initialValue) {
      _controller.text = widget.initialValue!;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final count = _countWords(_controller.text);
    if (count != _wordCount) {
      setState(() => _wordCount = count);
    }
  }

  int _countWords(String s) {
    final trimmed = s.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).length;
  }

  @override
  Widget build(BuildContext context) {
    final over = widget.wordLimit > 0 && _wordCount > widget.wordLimit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          maxLines: 8,
          decoration: InputDecoration(
            labelText: "Your answer",
            helperText: widget.wordLimit > 0 ? "Word limit: ${widget.wordLimit}" : null,
            border: const OutlineInputBorder(),
          ),
          onChanged: widget.onChanged,
        ),
        const SizedBox(height: 8),
        Text(
          "Words: $_wordCount${widget.wordLimit > 0 ? " / ${widget.wordLimit}" : ""}",
          style: TextStyle(color: over ? Colors.red : Colors.grey[600]),
        ),
      ],
    );
  }
}

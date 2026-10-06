import 'package:flutter/material.dart';
import '../config.dart';
import '../services/exam_service.dart';

class ResultsScreen extends StatefulWidget {
  final String examId;
  final String studentId;
  final String authToken;
  final String examTitle;

  const ResultsScreen({
    super.key,
    required this.examId,
    required this.studentId,
    required this.authToken,
    this.examTitle = '',
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  late final ExamService _examService;
  bool _loading = true;
  String? _error;
  List<dynamic> _results = [];

  @override
  void initState() {
    super.initState();
    _examService = ExamService(
      baseUrl: AppConfig.apiBaseUrl,
      authToken: widget.authToken,
      encryptionKey: '',
    );
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _examService.fetchStudentResults(
        examId: widget.examId,
        studentId: widget.studentId,
      );
      setState(() {
        _results = res;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load results: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.examTitle.isNotEmpty ? widget.examTitle : 'Exam Results';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, style: const TextStyle(color: Colors.red)),
        ),
      );
    }
    if (_results.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No submission found yet. If you just submitted, it may still be syncing.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final r = _results[i] as Map<String, dynamic>;
        final status = r['status'] ?? '';
        final grade = r['grade'] as Map<String, dynamic>?;
        final maxScore = r['max_score'] ?? 0;
        final examTitle = r['exam_title'] ?? '';
        final perQ = grade?['per_question'] as Map<String, dynamic>? ?? {};
        final feedback = grade?['feedback'] as String?;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (examTitle.isNotEmpty)
                  Text(examTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Chip(
                      label: Text((status as String).toUpperCase()),
                      backgroundColor: status == 'graded'
                          ? Colors.green.shade100
                          : Colors.blue.shade100,
                    ),
                    const Spacer(),
                    if (grade != null)
                      Text(
                        '${grade['total_score']} / $maxScore',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      )
                    else
                      const Text('Pending grading',
                          style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600)),
                  ],
                ),
                if (feedback != null && feedback.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Feedback', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(feedback),
                ],
                if (perQ.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Per-question', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  ...perQ.entries.map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Expanded(child: Text(e.key, style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
                            Text('${e.value} pts', style: const TextStyle(fontWeight: FontWeight.w500)),
                          ],
                        ),
                      )),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

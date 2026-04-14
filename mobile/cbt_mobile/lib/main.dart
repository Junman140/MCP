import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'models/exam.dart';
import 'services/exam_service.dart';
import 'services/sync_service.dart';
import 'services/snitch_protocol.dart';
import 'widgets/question_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final syncService = SyncService();
  await syncService.initialize();
  
  runApp(CBTApp(syncService: syncService));
}

class CBTApp extends StatelessWidget {
  final SyncService syncService;

  const CBTApp({super.key, required this.syncService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MCP Mobile CBT',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: ExamStartScreen(syncService: syncService),
    );
  }
}

class ExamStartScreen extends StatefulWidget {
  final SyncService syncService;

  const ExamStartScreen({super.key, required this.syncService});

  @override
  State<ExamStartScreen> createState() => _ExamStartScreenState();
}

class _ExamStartScreenState extends State<ExamStartScreen> {
  final _examIdController = TextEditingController(text: "test-exam-id");

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("MCP CBT Platform")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _examIdController,
              decoration: const InputDecoration(
                labelText: "Exam / Assessment ID",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                final examId = _examIdController.text.trim();
                if (examId.isEmpty) return;
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => ExamScreen(
                    examId: examId,
                    authToken: "dummy-token",
                    syncService: widget.syncService,
                  ),
                ));
              },
              child: const Text("Start Exam"),
            ),
          ],
        ),
      ),
    );
  }
}

class ExamScreen extends StatefulWidget {
  final String examId;
  final String authToken;
  final SyncService syncService;

  const ExamScreen({
    super.key,
    required this.examId,
    required this.authToken,
    required this.syncService,
  });

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> with WidgetsBindingObserver, SnitchProtocol {
  final ExamService _examService = ExamService();
  Exam? _exam;
  String _examDirPath = "";
  bool _isLoading = true;
  String? _errorMessage;
  int _currentIndex = 0;

  // State maps for answers
  final Map<String, String> _optionAnswers = {};
  final Map<String, String> _essayAnswers = {};
  final Map<String, List<File>> _fileAnswers = {};

  @override
  bool get snitchEnabled => _exam?.rules.isProctored ?? true;

  @override
  void initState() {
    super.initState();
    _loadExam();
  }

  Future<void> _loadExam() async {
    try {
      final exam = await _examService.downloadAndDecryptExam(widget.examId, widget.authToken);
      final appDocDir = await getApplicationDocumentsDirectory();
      
      setState(() {
        _exam = exam;
        _examDirPath = '${appDocDir.path}/exams/${widget.examId}';
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading exam: $e");
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void onViolationDetected(String reason, int totalViolations) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Warning: $reason")),
    );
  }

  void _submitOption(String questionId, String optionId) {
    setState(() => _optionAnswers[questionId] = optionId);
    widget.syncService.queueAnswer(widget.examId, questionId, optionId);
  }

  void _submitEssay(String questionId, String text) {
    setState(() => _essayAnswers[questionId] = text);
    widget.syncService.queueEssay(widget.examId, questionId, text);
  }

  void _submitFiles(String questionId, List<File> files) {
    setState(() => _fileAnswers[questionId] = files);
    widget.syncService.queueFileUpload(widget.examId, questionId, files);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Error")),
        body: Center(child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text("Error loading exam:\n$_errorMessage"),
        )),
      );
    }
    if (_exam == null) return const Scaffold(body: Center(child: Text("Exam not found.")));

    final questions = _exam!.questions;
    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(_exam!.metadata.title)),
        body: const Center(child: Text("No questions in this assessment.")),
      );
    }

    final question = questions[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(_exam!.metadata.title),
        actions: [
          Center(child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text("Q: ${_currentIndex + 1}/${questions.length}"),
          )),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: QuestionWidget(
          key: ValueKey(question.id), // Ensures state resets for essay/file widgets
          question: question,
          examDirPath: _examDirPath,
          selectedOptionId: _optionAnswers[question.id],
          initialEssayText: _essayAnswers[question.id],
          initialFiles: _fileAnswers[question.id],
          onOptionSelected: (optId) => _submitOption(question.id, optId),
          onEssayChanged: (text) => _submitEssay(question.id, text),
          onFilesChanged: (files) => _submitFiles(question.id, files),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_currentIndex > 0)
              TextButton(onPressed: () => setState(() => _currentIndex--), child: const Text("Previous")),
            const Spacer(),
            if (_currentIndex < questions.length - 1)
              ElevatedButton(onPressed: () => setState(() => _currentIndex++), child: const Text("Next"))
            else
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Exam submitted successfully!")),
                  );
                }, 
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                child: const Text("Finish Exam"),
              ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'models/exam.dart';
import 'services/exam_service.dart';
import 'services/sync_service.dart';
import 'services/randomization_engine.dart';
import 'services/snitch_protocol.dart';
import 'services/lms_auth_service.dart';
import 'widgets/question_widget.dart';
import 'config.dart';
import 'screens/lms/lms_login_screen.dart';
import 'screens/lms/lms_dashboard.dart';

final syncService = SyncService();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  syncService.initialize();
  runApp(const CBTApp());
}

// ─── App Root ─────────────────────────────────────
class CBTApp extends StatelessWidget {
  const CBTApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MCP CBT Platform',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      home: const ModeSelectScreen(),
    );
  }
}

class ModeSelectScreen extends StatefulWidget {
  const ModeSelectScreen({super.key});

  @override
  State<ModeSelectScreen> createState() => _ModeSelectScreenState();
}

class _ModeSelectScreenState extends State<ModeSelectScreen> {
  bool _checking = true;
  bool _lmsLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLmsSession();
  }

  Future<void> _checkLmsSession() async {
    final loggedIn = await LmsAuthService.isLoggedIn();
    if (mounted) setState(() { _checking = false; _lmsLoggedIn = loggedIn; });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.school, size: 72, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 8),
          Text('MCP Platform', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          SizedBox(width: 240, height: 56, child: FilledButton.icon(
            icon: const Icon(Icons.assignment),
            label: const Text('Take Exam (CBT)'),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
          )),
          const SizedBox(height: 12),
          SizedBox(width: 240, height: 56, child: FilledButton.tonalIcon(
            icon: const Icon(Icons.menu_book),
            label: const Text('Student Portal (LMS)'),
            onPressed: () {
              if (_lmsLoggedIn) {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => LmsDashboardScreen(
                    onLogout: () async {
                      await LmsAuthService.logout();
                      Navigator.popUntil(context, (r) => r.isFirst);
                    },
                    onGoToCbt: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                  ),
                ));
              } else {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => LmsLoginScreen(onLogin: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => LmsDashboardScreen(
                        onLogout: () async {
                          await LmsAuthService.logout();
                          Navigator.popUntil(context, (r) => r.isFirst);
                        },
                        onGoToCbt: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                      ),
                    ));
                  }),
                ));
              }
            },
          )),
          if (_lmsLoggedIn)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton(onPressed: () async { await LmsAuthService.logout(); setState(() => _lmsLoggedIn = false); }, child: const Text('Sign out of LMS')),
            ),
        ]),
      ),
    );
  }
}

// ─── Login Screen ─────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _studentIdCtrl = TextEditingController();
  final _examIdCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _verify() async {
    final studentId = _studentIdCtrl.text.trim();
    final examId = _examIdCtrl.text.trim();
    if (studentId.isEmpty || examId.isEmpty) {
      setState(() => _error = 'Enter both Student ID and Exam ID.');
      return;
    }
    setState(() { _loading = true; _error = null; });

    try {
      final dio = ExamService.createDio(null);
      final resp = await dio.post(
        '${AppConfig.apiBaseUrl}/api/v1/auth/verify',
        data: {'student_id': studentId, 'exam_id': examId},
      );
      final data = resp.data as Map<String, dynamic>;
      if (data['status'] != 'verified' || data['auth_token'] == null) {
        setState(() => _error = 'Verification failed. Check your credentials.');
        return;
      }
      final token = data['auth_token'] as String;
      final student = data['student'] as Map<String, dynamic>? ?? {};
      final name = student['full_name'] as String? ?? studentId;

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ExamScreen(
            examId: examId,
            authToken: token,
            studentId: studentId,
            studentName: name,
          ),
        ),
      );
    } catch (e) {
      setState(() => _error = 'Connection failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _studentIdCtrl.dispose();
    _examIdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.school, size: 64, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text('MCP CBT Platform', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Enter your credentials to start the exam', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
              const SizedBox(height: 32),
              TextField(
                controller: _studentIdCtrl,
                decoration: const InputDecoration(
                  labelText: 'Student ID / Matric Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _examIdCtrl,
                decoration: const InputDecoration(
                  labelText: 'Exam ID',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.assignment),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _verify(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _loading ? null : _verify,
                  child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Verify & Start Exam'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Exam Screen ──────────────────────────────────
class ExamScreen extends StatefulWidget {
  final String examId;
  final String authToken;
  final String studentId;
  final String studentName;

  const ExamScreen({
    super.key,
    required this.examId,
    required this.authToken,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> with SnitchProtocol {
  int _currentIdx = 0;
  Exam? _exam;
  bool _loading = true;
  String? _error;
  bool _finished = false;

  final _optionAnswers = <String, String>{};
  final _essayAnswers = <String, String>{};
  final _fileAnswers = <String, List<String>>{};

  late final ExamService _examService;
  late final RandomizationEngine _randomizer;
  List<Question> _questions = [];
  Timer? _timer;
  Duration _remaining = Duration.zero;
  String _examDirPath = '';

  @override
  bool get snitchEnabled => _exam?.rules.isProctored ?? true;

  @override
  void onViolationDetected(String reason, int totalViolations) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Proctoring alert: $reason'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _examService = ExamService(baseUrl: AppConfig.apiBaseUrl, authToken: widget.authToken, encryptionKey: AppConfig.encryptionKey);
    _randomizer = RandomizationEngine(widget.examId.hashCode);
    _loadExam();
  }

  Future<void> _loadExam() async {
    try {
      final exam = await _examService.downloadAndDecryptExam(widget.examId);
      final examDir = await _examService.getExamDir(widget.examId);
      _questions = exam.questions;
      if (exam.metadata.shuffleQuestions) {
        _questions = _randomizer.randomizeQuestions(_questions);
      }
      setState(() {
        _exam = exam;
        _examDirPath = examDir;
        _loading = false;
        _remaining = Duration(minutes: exam.metadata.durationMinutes > 0 ? exam.metadata.durationMinutes : 120);
      });
      _startTimer();
    } catch (e) {
      setState(() { _error = 'Failed to load exam: $e'; _loading = false; });
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_remaining.inSeconds > 0) {
          _remaining -= const Duration(seconds: 1);
        } else {
          _timer?.cancel();
          _submitExam(autoSubmit: true);
        }
      });
    });
  }

  String get _timeString {
    final h = _remaining.inHours;
    final m = _remaining.inMinutes.remainder(60);
    final s = _remaining.inSeconds.remainder(60);
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _submitExam({bool autoSubmit = false}) async {
    if (_finished) return;
    setState(() { _finished = true; _loading = true; });
    _timer?.cancel();

    try {
      await syncService.syncPendingSubmissions(widget.authToken);
    } catch (_) {}

    if (!mounted) return;
    final msg = autoSubmit ? 'Time expired. Exam auto-submitted.' : 'Exam submitted successfully.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
    Navigator.pop(context);
  }

  Future<bool> _onWillPop() async {
    if (_finished) return true;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finish Exam?'),
        content: const Text('Are you sure you want to submit and finish?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit')),
        ],
      ),
    );
    if (confirm == true) {
      _submitExam();
      return false;
    }
    return false;
  }

  void _onOptionSelected(String questionId, String? optionId) {
    if (optionId == null) return;
    _optionAnswers[questionId] = optionId;
    syncService.queueAnswer(
      examId: widget.examId,
      questionId: questionId,
      selectedOptionId: optionId,
      studentId: widget.studentId,
      authToken: widget.authToken,
    );
  }

  void _onEssayChanged(String questionId, String text) {
    _essayAnswers[questionId] = text;
  }

  void _onEssayCommitted(String questionId, String text) {
    syncService.queueEssay(
      examId: widget.examId,
      questionId: questionId,
      essayText: text,
      studentId: widget.studentId,
      authToken: widget.authToken,
    );
  }

  void _onFilesChanged(String questionId, List<String> paths) {
    _fileAnswers[questionId] = paths;
    syncService.queueFileUpload(
      examId: widget.examId,
      questionId: questionId,
      filePaths: paths,
      studentId: widget.studentId,
      authToken: widget.authToken,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onWillPop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_exam?.metadata.title ?? 'Exam'),
          actions: [
            if (!_loading && _exam != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Chip(
                  avatar: Icon(Icons.timer, size: 16, color: _remaining.inMinutes < 5 ? Colors.red : null),
                  label: Text(_timeString, style: TextStyle(fontWeight: FontWeight.bold, color: _remaining.inMinutes < 5 ? Colors.red : null)),
                ),
              ),
            if (!_loading)
              TextButton.icon(
                onPressed: _finished ? null : () => _onWillPop(),
                icon: const Icon(Icons.done_all),
                label: const Text('Finish'),
              ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    if (_exam == null || _questions.isEmpty) return const Center(child: Text('No questions found.'));

    final question = _questions[_currentIdx];
    final options = _exam!.metadata.shuffleOptions && question.options.isNotEmpty
        ? _randomizer.randomizeOptions(question.options)
        : question.options;

    return Column(
      children: [
        LinearProgressIndicator(value: (_currentIdx + 1) / _questions.length),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Question ${_currentIdx + 1} of ${_questions.length}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(question.type.toUpperCase(),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: QuestionWidget(
              key: ValueKey(question.id),
              question: question.copyWith(options: options),
              examDirPath: _examDirPath,
              selectedOptionId: _optionAnswers[question.id],
              onOptionSelected: (optId) => _onOptionSelected(question.id, optId),
              essayText: _essayAnswers[question.id],
              onEssayChanged: (text) => _onEssayChanged(question.id, text),
              onEssayEditingComplete: (text) => _onEssayCommitted(question.id, text),
              filePaths: _fileAnswers[question.id],
              onFilesChanged: (paths) => _onFilesChanged(question.id, paths),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (_currentIdx > 0)
                  OutlinedButton(
                    onPressed: () => setState(() => _currentIdx--),
                    child: const Text('Previous'),
                  ),
                const Spacer(),
                if (_currentIdx < _questions.length - 1)
                  FilledButton(
                    onPressed: () => setState(() => _currentIdx++),
                    child: const Text('Next'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

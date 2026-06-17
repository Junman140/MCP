class ExamMetadata {
  final String title;
  final int durationMinutes;
  final bool shuffleQuestions;
  final bool shuffleOptions;

  ExamMetadata({
    required this.title,
    required this.durationMinutes,
    required this.shuffleQuestions,
    required this.shuffleOptions,
  });

  factory ExamMetadata.fromJson(Map<String, dynamic> json) {
    return ExamMetadata(
      title: json['title'],
      durationMinutes: json['duration_minutes'],
      shuffleQuestions: json['shuffle_questions'],
      shuffleOptions: json['shuffle_options'],
    );
  }
}

class AssessmentRules {
  final bool isProctored;
  final int maxAttempts;

  AssessmentRules({required this.isProctored, required this.maxAttempts});

  factory AssessmentRules.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return AssessmentRules(isProctored: true, maxAttempts: 1);
    }
    return AssessmentRules(
      isProctored: json['is_proctored'] ?? true,
      maxAttempts: json['max_attempts'] ?? 1,
    );
  }
}

class Option {
  final String id;
  final String text;

  Option({required this.id, required this.text});

  factory Option.fromJson(Map<String, dynamic> json) {
    return Option(id: json['opt_id'], text: json['text']);
  }
}

class FileUploadConstraints {
  final List<String> allowedMimeTypes;
  final int maxBytes;
  final int maxFiles;

  FileUploadConstraints({
    required this.allowedMimeTypes,
    required this.maxBytes,
    required this.maxFiles,
  });

  factory FileUploadConstraints.fromJson(Map<String, dynamic> json) {
    return FileUploadConstraints(
      allowedMimeTypes: List<String>.from(json['allowed_mime_types'] ?? const <String>[]),
      maxBytes: (json['max_bytes'] ?? 0) is int ? (json['max_bytes'] ?? 0) : int.tryParse('${json['max_bytes']}') ?? 0,
      maxFiles: json['max_files'] ?? 1,
    );
  }
}

class Question {
  final String id;
  final String type;
  final String content;
  final List<String> media;
  final List<Option> options;
  final int points;
  final int wordLimit;
  final FileUploadConstraints? fileUpload;

  Question({
    required this.id,
    required this.type,
    required this.content,
    required this.media,
    required this.options,
    this.points = 0,
    this.wordLimit = 0,
    this.fileUpload,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['q_id'],
      type: json['type'],
      content: json['content'],
      media: List<String>.from(json['media'] ?? []),
      options: (json['options'] as List)
          .map((o) => Option.fromJson(o))
          .toList(),
      points: json['points'] ?? 0,
      wordLimit: json['word_limit'] ?? 0,
      fileUpload: json['file_upload'] == null ? null : FileUploadConstraints.fromJson(json['file_upload']),
    );
  }

  Question copyWith({List<Option>? options}) {
    return Question(
      id: id,
      type: type,
      content: content,
      media: media,
      options: options ?? this.options,
      points: points,
      wordLimit: wordLimit,
      fileUpload: fileUpload,
    );
  }
}

class Exam {
  final String id;
  final String type; // "exam" | "test" | "assignment"
  final AssessmentRules rules;
  final ExamMetadata metadata;
  final List<Question> questions;

  Exam({
    required this.id,
    required this.type,
    required this.rules,
    required this.metadata,
    required this.questions,
  });

  factory Exam.fromJson(Map<String, dynamic> json) {
    return Exam(
      id: json['id'] ?? json['exam_id'] ?? '',
      type: json['type'] ?? 'exam',
      rules: AssessmentRules.fromJson(json['rules']),
      metadata: ExamMetadata.fromJson(json['metadata']),
      questions: (json['questions'] as List)
          .map((q) => Question.fromJson(q))
          .toList(),
    );
  }
}

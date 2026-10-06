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

class Section {
  final String id;
  final String title;
  final String description;
  final int durationMinutes;
  final bool shuffleQuestions;
  final int order;
  final List<Question> questions;

  Section({
    required this.id,
    required this.title,
    this.description = '',
    this.durationMinutes = 0,
    this.shuffleQuestions = false,
    this.order = 0,
    required this.questions,
  });

  factory Section.fromJson(Map<String, dynamic> json) {
    return Section(
      id: json['sec_id'] ?? '',
      title: json['title'] ?? 'Section',
      description: json['description'] ?? '',
      durationMinutes: json['duration_minutes'] ?? 0,
      shuffleQuestions: json['shuffle_questions'] ?? false,
      order: json['order'] ?? 0,
      questions: (json['questions'] as List? ?? [])
          .map((q) => Question.fromJson(q))
          .toList(),
    );
  }
}

class Stream {
  final String id;
  final String name;
  final List<Section> sections;

  Stream({
    required this.id,
    required this.name,
    required this.sections,
  });

  factory Stream.fromJson(Map<String, dynamic> json) {
    return Stream(
      id: json['str_id'] ?? '',
      name: json['name'] ?? 'Stream',
      sections: (json['sections'] as List? ?? [])
          .map((s) => Section.fromJson(s))
          .toList(),
    );
  }
}

class Exam {
  final String id;
  final String type; // "exam" | "test" | "assignment"
  final AssessmentRules rules;
  final ExamMetadata metadata;
  final List<Question> questions;
  final List<Section> sections;
  final List<Stream> streams;
  final String hmacSecret;

  Exam({
    required this.id,
    required this.type,
    required this.rules,
    required this.metadata,
    this.questions = const [],
    this.sections = const [],
    this.streams = const [],
    this.hmacSecret = '',
  });

  factory Exam.fromJson(Map<String, dynamic> json) {
    return Exam(
      id: json['id'] ?? json['exam_id'] ?? '',
      type: json['type'] ?? 'exam',
      rules: AssessmentRules.fromJson(json['rules']),
      metadata: ExamMetadata.fromJson(json['metadata']),
      questions: json['questions'] != null
          ? (json['questions'] as List).map((q) => Question.fromJson(q)).toList()
          : const [],
      sections: json['sections'] != null
          ? (json['sections'] as List).map((s) => Section.fromJson(s)).toList()
          : const [],
      streams: json['streams'] != null
          ? (json['streams'] as List).map((s) => Stream.fromJson(s)).toList()
          : const [],
      hmacSecret: json['hmac_secret'] ?? '',
    );
  }

  // The sections to display: prefer the assigned stream's sections, then exam
  // sections, then a synthetic section wrapping the legacy flat question list.
  List<Section> get displaySections {
    if (streams.isNotEmpty) return streams.first.sections;
    if (sections.isNotEmpty) return sections;
    return [
      Section(
        id: '',
        title: metadata.title,
        shuffleQuestions: metadata.shuffleQuestions,
        questions: questions,
      )
    ];
  }
}

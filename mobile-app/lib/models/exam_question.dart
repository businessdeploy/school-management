class ExamQuestion {
  final String id;
  final String questionId;
  final String onlineexamId;
  final String? sessionId;
  final String marks;
  final String negMarks;
  final String isActive;
  final String createdAt;
  final String updatedAt;
  final String subjectId;
  final String question;
  final String optA;
  final String optB;
  final String optC;
  final String optD;
  final String optE;
  final String correct;
  final String questionType;

  ExamQuestion({
    required this.id,
    required this.questionId,
    required this.onlineexamId,
    this.sessionId,
    required this.marks,
    required this.negMarks,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.subjectId,
    required this.question,
    required this.optA,
    required this.optB,
    required this.optC,
    required this.optD,
    required this.optE,
    required this.correct,
    required this.questionType,
  });

  factory ExamQuestion.fromJson(Map<String, dynamic> json) {
    return ExamQuestion(
      id: json['id']?.toString() ?? '',
      questionId: json['question_id']?.toString() ?? '',
      onlineexamId: json['onlineexam_id']?.toString() ?? '',
      sessionId: json['session_id']?.toString(),
      marks: json['marks']?.toString() ?? '',
      negMarks: json['neg_marks']?.toString() ?? '',
      isActive: json['is_active']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
      subjectId: json['subject_id']?.toString() ?? '',
      question: json['question']?.toString() ?? '',
      optA: json['opt_a']?.toString() ?? '',
      optB: json['opt_b']?.toString() ?? '',
      optC: json['opt_c']?.toString() ?? '',
      optD: json['opt_d']?.toString() ?? '',
      optE: json['opt_e']?.toString() ?? '',
      correct: json['correct']?.toString() ?? '',
      questionType: json['question_type']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question_id': questionId,
      'onlineexam_id': onlineexamId,
      'session_id': sessionId,
      'marks': marks,
      'neg_marks': negMarks,
      'is_active': isActive,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'subject_id': subjectId,
      'question': question,
      'opt_a': optA,
      'opt_b': optB,
      'opt_c': optC,
      'opt_d': optD,
      'opt_e': optE,
      'correct': correct,
      'question_type': questionType,
    };
  }

  List<String> get options {
    List<String> options = [];
    if (optA.isNotEmpty) options.add(optA);
    if (optB.isNotEmpty) options.add(optB);
    if (optC.isNotEmpty) options.add(optC);
    if (optD.isNotEmpty) options.add(optD);
    if (optE.isNotEmpty && optE != 'na') options.add(optE);
    return options;
  }

  String get cleanQuestion {
    // Remove HTML tags from question
    return question
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .trim();
  }

  String get cleanOptionA {
    return optA
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .trim();
  }

  String get cleanOptionB {
    return optB
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .trim();
  }

  String get cleanOptionC {
    return optC
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .trim();
  }

  String get cleanOptionD {
    return optD
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .trim();
  }

  String get cleanOptionE {
    return optE
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .trim();
  }
}

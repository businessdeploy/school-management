class ExamResult {
  final String id;
  final String questionId;
  final String onlineexamId;
  final String? sessionId;
  final String marks;
  final String negMarks;
  final String isActive;
  final String createdAt;
  final String updatedAt;
  final String subjectName;
  final String subjectsCode;
  final String onlineexamStudentResultId;
  final String question;
  final String questionType;
  final String scoreMarks;
  final String optA;
  final String optB;
  final String optC;
  final String optD;
  final String optE;
  final String correct;
  final String selectOption;
  final String remark;

  ExamResult({
    required this.id,
    required this.questionId,
    required this.onlineexamId,
    this.sessionId,
    required this.marks,
    required this.negMarks,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.subjectName,
    required this.subjectsCode,
    required this.onlineexamStudentResultId,
    required this.question,
    required this.questionType,
    required this.scoreMarks,
    required this.optA,
    required this.optB,
    required this.optC,
    required this.optD,
    required this.optE,
    required this.correct,
    required this.selectOption,
    required this.remark,
  });

  factory ExamResult.fromJson(Map<String, dynamic> json) {
    return ExamResult(
      id: json['id']?.toString() ?? '',
      questionId: json['question_id']?.toString() ?? '',
      onlineexamId: json['onlineexam_id']?.toString() ?? '',
      sessionId: json['session_id']?.toString(),
      marks: json['marks']?.toString() ?? '',
      negMarks: json['neg_marks']?.toString() ?? '',
      isActive: json['is_active']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
      subjectName: json['subject_name']?.toString() ?? '',
      subjectsCode: json['subjects_code']?.toString() ?? '',
      onlineexamStudentResultId: json['onlineexam_student_result_id']?.toString() ?? '',
      question: json['question']?.toString() ?? '',
      questionType: json['question_type']?.toString() ?? '',
      scoreMarks: json['score_marks']?.toString() ?? '',
      optA: json['opt_a']?.toString() ?? '',
      optB: json['opt_b']?.toString() ?? '',
      optC: json['opt_c']?.toString() ?? '',
      optD: json['opt_d']?.toString() ?? '',
      optE: json['opt_e']?.toString() ?? '',
      correct: json['correct']?.toString() ?? '',
      selectOption: json['select_option']?.toString() ?? '',
      remark: json['remark']?.toString() ?? '',
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
      'subject_name': subjectName,
      'subjects_code': subjectsCode,
      'onlineexam_student_result_id': onlineexamStudentResultId,
      'question': question,
      'question_type': questionType,
      'score_marks': scoreMarks,
      'opt_a': optA,
      'opt_b': optB,
      'opt_c': optC,
      'opt_d': optD,
      'opt_e': optE,
      'correct': correct,
      'select_option': selectOption,
      'remark': remark,
    };
  }

  bool get isCorrect {
    return selectOption == correct;
  }

  String get cleanQuestion {
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

class ExamResultSummary {
  final String id;
  final String sessionId;
  final String exam;
  final String attempt;
  final String examFrom;
  final String examTo;
  final String isQuiz;
  final String? autoPublishDate;
  final String? timeFrom;
  final String? timeTo;
  final String duration;
  final String passingPercentage;
  final String description;
  final String publishResult;
  final String answerWordCount;
  final String isActive;
  final String isMarksDisplay;
  final String isNegMarking;
  final String isRandomQuestion;
  final String isRankGenerated;
  final String publishExamNotification;
  final String publishResultNotification;
  final String createdAt;
  final String updatedAt;
  final String rank;
  final int correctAns;
  final int wrongAns;
  final int notAttempted;
  final int totalQuestion;
  final int totalDescriptive;
  final int examTotalMarks;
  final int examTotalNegMarks;
  final int examTotalScored;
  final String score;

  ExamResultSummary({
    required this.id,
    required this.sessionId,
    required this.exam,
    required this.attempt,
    required this.examFrom,
    required this.examTo,
    required this.isQuiz,
    this.autoPublishDate,
    this.timeFrom,
    this.timeTo,
    required this.duration,
    required this.passingPercentage,
    required this.description,
    required this.publishResult,
    required this.answerWordCount,
    required this.isActive,
    required this.isMarksDisplay,
    required this.isNegMarking,
    required this.isRandomQuestion,
    required this.isRankGenerated,
    required this.publishExamNotification,
    required this.publishResultNotification,
    required this.createdAt,
    required this.updatedAt,
    required this.rank,
    required this.correctAns,
    required this.wrongAns,
    required this.notAttempted,
    required this.totalQuestion,
    required this.totalDescriptive,
    required this.examTotalMarks,
    required this.examTotalNegMarks,
    required this.examTotalScored,
    required this.score,
  });

  factory ExamResultSummary.fromJson(Map<String, dynamic> json) {
    return ExamResultSummary(
      id: json['id']?.toString() ?? '',
      sessionId: json['session_id']?.toString() ?? '',
      exam: json['exam']?.toString() ?? '',
      attempt: json['attempt']?.toString() ?? '',
      examFrom: json['exam_from']?.toString() ?? '',
      examTo: json['exam_to']?.toString() ?? '',
      isQuiz: json['is_quiz']?.toString() ?? '',
      autoPublishDate: json['auto_publish_date']?.toString(),
      timeFrom: json['time_from']?.toString(),
      timeTo: json['time_to']?.toString(),
      duration: json['duration']?.toString() ?? '',
      passingPercentage: json['passing_percentage']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      publishResult: json['publish_result']?.toString() ?? '',
      answerWordCount: json['answer_word_count']?.toString() ?? '',
      isActive: json['is_active']?.toString() ?? '',
      isMarksDisplay: json['is_marks_display']?.toString() ?? '',
      isNegMarking: json['is_neg_marking']?.toString() ?? '',
      isRandomQuestion: json['is_random_question']?.toString() ?? '',
      isRankGenerated: json['is_rank_generated']?.toString() ?? '',
      publishExamNotification: json['publish_exam_notification']?.toString() ?? '',
      publishResultNotification: json['publish_result_notification']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
      rank: json['rank']?.toString() ?? '',
      correctAns: int.tryParse(json['correct_ans']?.toString() ?? '0') ?? 0,
      wrongAns: int.tryParse(json['wrong_ans']?.toString() ?? '0') ?? 0,
      notAttempted: int.tryParse(json['not_attempted']?.toString() ?? '0') ?? 0,
      totalQuestion: int.tryParse(json['total_question']?.toString() ?? '0') ?? 0,
      totalDescriptive: int.tryParse(json['total_descriptive']?.toString() ?? '0') ?? 0,
      examTotalMarks: int.tryParse(json['exam_total_marks']?.toString() ?? '0') ?? 0,
      examTotalNegMarks: int.tryParse(json['exam_total_neg_marks']?.toString() ?? '0') ?? 0,
      examTotalScored: int.tryParse(json['exam_total_scored']?.toString() ?? '0') ?? 0,
      score: json['score']?.toString() ?? '0.00',
    );
  }

  double get percentage {
    if (examTotalMarks == 0) return 0.0;
    return (examTotalScored / examTotalMarks) * 100;
  }

  bool get isPassed {
    final passingPercent = double.tryParse(passingPercentage) ?? 0.0;
    return percentage >= passingPercent;
  }
}

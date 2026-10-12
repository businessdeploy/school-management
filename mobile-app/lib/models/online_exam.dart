class OnlineExam {
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
  final String onlineexamStudentId;
  final String isAttempted;
  final String counter;
  final String totalQuestion;
  final String totalDescriptive;
  final Map<String, dynamic> rawExam;

  OnlineExam({
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
    required this.onlineexamStudentId,
    required this.isAttempted,
    required this.counter,
    required this.totalQuestion,
    required this.totalDescriptive,
    this.rawExam = const {},
  });

  factory OnlineExam.fromJson(Map<String, dynamic> json) {
    return OnlineExam(
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
      onlineexamStudentId: json['onlineexam_student_id']?.toString() ?? '',
      isAttempted: json['is_attempted']?.toString() ?? '',
      counter: json['counter']?.toString() ?? '',
      totalQuestion: json['total_question']?.toString() ?? '',
      totalDescriptive: json['total_descriptive']?.toString() ?? '',
      rawExam: json,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (rawExam.isNotEmpty) ...rawExam,
      'id': id,
      'session_id': sessionId,
      'exam': exam,
      'attempt': attempt,
      'exam_from': examFrom,
      'exam_to': examTo,
      'is_quiz': isQuiz,
      'auto_publish_date': autoPublishDate,
      'time_from': timeFrom,
      'time_to': timeTo,
      'duration': duration,
      'passing_percentage': passingPercentage,
      'description': description,
      'publish_result': publishResult,
      'answer_word_count': answerWordCount,
      'is_active': isActive,
      'is_marks_display': isMarksDisplay,
      'is_neg_marking': isNegMarking,
      'is_random_question': isRandomQuestion,
      'is_rank_generated': isRankGenerated,
      'publish_exam_notification': publishExamNotification,
      'publish_result_notification': publishResultNotification,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'onlineexam_student_id': onlineexamStudentId,
      'is_attempted': isAttempted,
      'counter': counter,
      'total_question': totalQuestion,
      'total_descriptive': totalDescriptive,
    };
  }

  String get formattedExamFrom {
    try {
      final date = DateTime.parse(examFrom);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}';
    } catch (e) {
      return examFrom;
    }
  }

  String get formattedExamTo {
    try {
      final date = DateTime.parse(examTo);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}';
    } catch (e) {
      return examTo;
    }
  }

  String get formattedDuration {
    try {
      final parts = duration.split(':');
      if (parts.length >= 2) {
        final hours = int.parse(parts[0]);
        final minutes = int.parse(parts[1]);
        return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:00';
      }
      return duration;
    } catch (e) {
      return duration;
    }
  }

  bool get isSubmitted => isAttempted == '1' || isAttempted.toLowerCase() == 'yes';

  bool get hasReachedMaxAttempts {
    final allowed = int.tryParse(attempt) ?? 0;
    final attemptedCount = int.tryParse(counter) ?? 0;
    return allowed > 0 && attemptedCount >= allowed;
  }

  bool get isAvailable {
    final now = DateTime.now();
    try {
      final startDate = DateTime.parse(examFrom);
      final endDate = DateTime.parse(examTo);
      return (now.isAfter(startDate) || now.isAtSameMomentAs(startDate)) && 
             (now.isBefore(endDate) || now.isAtSameMomentAs(endDate));
    } catch (e) {
      return false;
    }
  }

  bool canStartExam(DateTime now) {
    if (isSubmitted) return false;
    if (hasReachedMaxAttempts) return false;
    return isAvailable;
  }

  String get status {
    if (isSubmitted) {
      return 'Completed';
    } else if (hasReachedMaxAttempts) {
      return 'Max Attempts Reached';
    } else if (isAvailable) {
      return 'Available';
    } else {
      final now = DateTime.now();
      try {
        final startDate = DateTime.parse(examFrom);
        if (now.isBefore(startDate)) return 'Upcoming';
      } catch (_) {}
      return 'Closed';
    }
  }
}

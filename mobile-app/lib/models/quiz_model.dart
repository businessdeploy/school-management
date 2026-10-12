class Quiz {
  final String quizId;
  final String quizTitle;
  final String sectionName;
  final String courseId;
  final DateTime? createdAt;
  final bool isAttempted;
  final int? totalQuestions;
  final double? totalMarks;
  final double? obtainedMarks;
  final String? status; // 'pending', 'completed', 'expired'

  Quiz({
    required this.quizId,
    required this.quizTitle,
    required this.sectionName,
    required this.courseId,
    this.createdAt,
    this.isAttempted = false,
    this.totalQuestions,
    this.totalMarks,
    this.obtainedMarks,
    this.status,
  });

  factory Quiz.fromJson(Map<String, dynamic> json) {
    return Quiz(
      quizId: json['quiz_id']?.toString() ?? 
              json['quizid']?.toString() ?? 
              json['id']?.toString() ?? '',
      quizTitle: json['quiz_title']?.toString() ?? 
                 json['quiz_title']?.toString() ?? 
                 json['title']?.toString() ?? 'Untitled Quiz',
      sectionName: json['section_name']?.toString() ?? 'Unknown Section',
      courseId: json['course_id']?.toString() ?? '',
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at']) 
          : null,
      isAttempted: json['is_attempted'] ?? false,
      totalQuestions: int.tryParse(json['total_questions']?.toString() ?? '0'),
      totalMarks: double.tryParse(json['total_marks']?.toString() ?? '0'),
      obtainedMarks: double.tryParse(json['obtained_marks']?.toString() ?? '0'),
      status: json['status']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'quiz_id': quizId,
      'quiz_title': quizTitle,
      'section_name': sectionName,
      'course_id': courseId,
      'created_at': createdAt?.toIso8601String(),
      'is_attempted': isAttempted,
      'total_questions': totalQuestions,
      'total_marks': totalMarks,
      'obtained_marks': obtainedMarks,
      'status': status,
    };
  }

  Quiz copyWith({
    String? quizId,
    String? quizTitle,
    String? sectionName,
    String? courseId,
    DateTime? createdAt,
    bool? isAttempted,
    int? totalQuestions,
    double? totalMarks,
    double? obtainedMarks,
    String? status,
  }) {
    return Quiz(
      quizId: quizId ?? this.quizId,
      quizTitle: quizTitle ?? this.quizTitle,
      sectionName: sectionName ?? this.sectionName,
      courseId: courseId ?? this.courseId,
      createdAt: createdAt ?? this.createdAt,
      isAttempted: isAttempted ?? this.isAttempted,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      totalMarks: totalMarks ?? this.totalMarks,
      obtainedMarks: obtainedMarks ?? this.obtainedMarks,
      status: status ?? this.status,
    );
  }
}

class QuizQuestion {
  final String questionId;
  final String questionText;
  final String questionType; // 'multiple_choice', 'true_false', 'short_answer', 'essay'
  final List<String> options;
  final String correctAnswer;
  final double marks;
  final String quizId;
  final String? selectedAnswer;
  final bool isCorrect;
  final String? explanation;

  QuizQuestion({
    required this.questionId,
    required this.questionText,
    required this.questionType,
    required this.options,
    required this.correctAnswer,
    required this.marks,
    required this.quizId,
    this.selectedAnswer,
    this.isCorrect = false,
    this.explanation,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      questionId: json['question_id']?.toString() ?? '',
      questionText: json['question_text']?.toString() ?? '',
      questionType: json['question_type']?.toString() ?? 'multiple_choice',
      options: (json['options'] as List?)?.map((e) => e.toString()).toList() ?? [],
      correctAnswer: json['correct_answer']?.toString() ?? '',
      marks: double.tryParse(json['marks']?.toString() ?? '0') ?? 0.0,
      quizId: json['quiz_id']?.toString() ?? '',
      selectedAnswer: json['selected_answer']?.toString(),
      isCorrect: json['is_correct'] ?? false,
      explanation: json['explanation']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question_id': questionId,
      'question_text': questionText,
      'question_type': questionType,
      'options': options,
      'correct_answer': correctAnswer,
      'marks': marks,
      'quiz_id': quizId,
      'selected_answer': selectedAnswer,
      'is_correct': isCorrect,
      'explanation': explanation,
    };
  }

  QuizQuestion copyWith({
    String? questionId,
    String? questionText,
    String? questionType,
    List<String>? options,
    String? correctAnswer,
    double? marks,
    String? quizId,
    String? selectedAnswer,
    bool? isCorrect,
    String? explanation,
  }) {
    return QuizQuestion(
      questionId: questionId ?? this.questionId,
      questionText: questionText ?? this.questionText,
      questionType: questionType ?? this.questionType,
      options: options ?? this.options,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      marks: marks ?? this.marks,
      quizId: quizId ?? this.quizId,
      selectedAnswer: selectedAnswer ?? this.selectedAnswer,
      isCorrect: isCorrect ?? this.isCorrect,
      explanation: explanation ?? this.explanation,
    );
  }

  // Check if the selected answer is correct
  bool checkAnswer(String? answer) {
    if (answer == null || answer.isEmpty) return false;
    return answer.toLowerCase().trim() == correctAnswer.toLowerCase().trim();
  }
}

class QuizAttempt {
  final String attemptId;
  final String quizId;
  final String studentId;
  final DateTime startTime;
  final DateTime? endTime;
  final List<QuizQuestion> questions;
  final List<String> answers;
  final double totalMarks;
  double obtainedMarks;
  double percentage;
  final String status; // 'in_progress', 'completed', 'submitted'
  final int? durationMinutes;
  final int? timeSpentSeconds;

  QuizAttempt({
    required this.attemptId,
    required this.quizId,
    required this.studentId,
    required this.startTime,
    this.endTime,
    required this.questions,
    required this.answers,
    required this.totalMarks,
    required this.obtainedMarks,
    required this.percentage,
    required this.status,
    this.durationMinutes,
    this.timeSpentSeconds,
  });

  factory QuizAttempt.fromJson(Map<String, dynamic> json) {
    return QuizAttempt(
      attemptId: json['attempt_id']?.toString() ?? '',
      quizId: json['quiz_id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      startTime: DateTime.parse(json['start_time']?.toString() ?? DateTime.now().toIso8601String()),
      endTime: json['end_time'] != null ? DateTime.parse(json['end_time']) : null,
      questions: (json['questions'] as List?)
          ?.map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>))
          .toList() ?? [],
      answers: (json['answers'] as List?)?.map((a) => a.toString()).toList() ?? [],
      totalMarks: double.tryParse(json['total_marks']?.toString() ?? '0') ?? 0.0,
      obtainedMarks: double.tryParse(json['obtained_marks']?.toString() ?? '0') ?? 0.0,
      percentage: double.tryParse(json['percentage']?.toString() ?? '0') ?? 0.0,
      status: json['status']?.toString() ?? 'in_progress',
      durationMinutes: int.tryParse(json['duration_minutes']?.toString() ?? '0'),
      timeSpentSeconds: int.tryParse(json['time_spent_seconds']?.toString() ?? '0'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'attempt_id': attemptId,
      'quiz_id': quizId,
      'student_id': studentId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'questions': questions.map((q) => q.toJson()).toList(),
      'answers': answers,
      'total_marks': totalMarks,
      'obtained_marks': obtainedMarks,
      'percentage': percentage,
      'status': status,
      'duration_minutes': durationMinutes,
      'time_spent_seconds': timeSpentSeconds,
    };
  }

  // Calculate results based on answers
  void calculateResults() {
    double marks = 0.0;
    List<QuizQuestion> updatedQuestions = [];

    for (int i = 0; i < questions.length && i < answers.length; i++) {
      final question = questions[i];
      final answer = answers[i];
      
      final isCorrect = question.checkAnswer(answer);
      if (isCorrect) {
        marks += question.marks;
      }

      updatedQuestions.add(question.copyWith(
        selectedAnswer: answer,
        isCorrect: isCorrect,
      ));
    }

    obtainedMarks = marks;
    percentage = totalMarks > 0 ? (marks / totalMarks) * 100 : 0.0;
    questions.clear();
    questions.addAll(updatedQuestions);
  }

  // Get time remaining in seconds
  int getTimeRemaining() {
    if (durationMinutes == null) return 0;
    
    final totalSeconds = durationMinutes! * 60;
    final elapsed = DateTime.now().difference(startTime).inSeconds;
    return (totalSeconds - elapsed).clamp(0, totalSeconds);
  }

  // Check if time is up
  bool isTimeUp() {
    return getTimeRemaining() <= 0;
  }
}

class QuizResult {
  final String resultId;
  final String quizId;
  final String studentId;
  final double totalMarks;
  final double obtainedMarks;
  final double percentage;
  final String grade;
  final String status; // 'pass', 'fail'
  final DateTime submittedAt;
  final int? timeSpentSeconds;
  final List<QuizQuestion> questionResults;

  QuizResult({
    required this.resultId,
    required this.quizId,
    required this.studentId,
    required this.totalMarks,
    required this.obtainedMarks,
    required this.percentage,
    required this.grade,
    required this.status,
    required this.submittedAt,
    this.timeSpentSeconds,
    required this.questionResults,
  });

  factory QuizResult.fromJson(Map<String, dynamic> json) {
    return QuizResult(
      resultId: json['result_id']?.toString() ?? '',
      quizId: json['quiz_id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      totalMarks: double.tryParse(json['total_marks']?.toString() ?? '0') ?? 0.0,
      obtainedMarks: double.tryParse(json['obtained_marks']?.toString() ?? '0') ?? 0.0,
      percentage: double.tryParse(json['percentage']?.toString() ?? '0') ?? 0.0,
      grade: json['grade']?.toString() ?? 'N/A',
      status: json['status']?.toString() ?? 'fail',
      submittedAt: DateTime.parse(json['submitted_at']?.toString() ?? DateTime.now().toIso8601String()),
      timeSpentSeconds: int.tryParse(json['time_spent_seconds']?.toString() ?? '0'),
      questionResults: (json['question_results'] as List?)
          ?.map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'result_id': resultId,
      'quiz_id': quizId,
      'student_id': studentId,
      'total_marks': totalMarks,
      'obtained_marks': obtainedMarks,
      'percentage': percentage,
      'grade': grade,
      'status': status,
      'submitted_at': submittedAt.toIso8601String(),
      'time_spent_seconds': timeSpentSeconds,
      'question_results': questionResults.map((q) => q.toJson()).toList(),
    };
  }
}

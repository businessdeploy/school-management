class Exam {
  final String id;
  final String title;
  final String description;
  final String subject;
  final String className;
  final String section;
  final String examDate;
  final String startTime;
  final String endTime;
  final String duration;
  final String totalMarks;
  final String passingMarks;
  final String status; // created, started, completed, closed
  final String isActive;
  final String createdAt;
  final String updatedAt;
  final String studentId;
  final String studentStatus; // not_started, in_progress, completed
  final String studentMarks;
  final String studentStartTime;
  final String studentEndTime;

  Exam({
    required this.id,
    required this.title,
    required this.description,
    required this.subject,
    required this.className,
    required this.section,
    required this.examDate,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.totalMarks,
    required this.passingMarks,
    required this.status,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.studentId,
    required this.studentStatus,
    required this.studentMarks,
    required this.studentStartTime,
    required this.studentEndTime,
  });

  factory Exam.fromJson(Map<String, dynamic> json) {
    return Exam(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? json['exam_title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      subject: json['subject']?.toString() ?? json['subject_name']?.toString() ?? '',
      className: json['class']?.toString() ?? json['class_name']?.toString() ?? '',
      section: json['section']?.toString() ?? '',
      examDate: json['exam_date']?.toString() ?? json['date']?.toString() ?? '',
      startTime: json['start_time']?.toString() ?? '',
      endTime: json['end_time']?.toString() ?? '',
      duration: json['duration']?.toString() ?? '',
      totalMarks: json['total_marks']?.toString() ?? json['max_marks']?.toString() ?? '',
      passingMarks: json['passing_marks']?.toString() ?? '',
      status: json['status']?.toString() ?? 'created',
      isActive: json['is_active']?.toString() ?? '1',
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      studentStatus: json['student_status']?.toString() ?? 'not_started',
      studentMarks: json['student_marks']?.toString() ?? '',
      studentStartTime: json['student_start_time']?.toString() ?? '',
      studentEndTime: json['student_end_time']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'subject': subject,
      'class': className,
      'section': section,
      'exam_date': examDate,
      'start_time': startTime,
      'end_time': endTime,
      'duration': duration,
      'total_marks': totalMarks,
      'passing_marks': passingMarks,
      'status': status,
      'is_active': isActive,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'student_id': studentId,
      'student_status': studentStatus,
      'student_marks': studentMarks,
      'student_start_time': studentStartTime,
      'student_end_time': studentEndTime,
    };
  }
}

class CBSEExam {
  final String id;
  final String cbseExamId;
  final String studentSessionId;
  final String? staffId;
  final String? rollNo;
  final String? remark;
  final String totalPresentDays;
  final String deleteStudentId;
  final String createdAt;
  final String cbseExamAssessmentId;
  final String cbseTermId;
  final String name;
  final String useExamRollNo;
  final String isActive;
  final String isPublish;
  final String cbseExamGradeId;
  final String totalWorkingDays;
  final List<CBSEExamSubject> subjects;
  final List<CBSEExamGrade> grades;
  final List<CBSEExamAssessment> examAssessments;
  final CBSEExamData? examData;
  final String examTotalMarks;
  final String examObtainMarks;
  final String examPercentage;
  final String examGrade;
  final String examRank;

  CBSEExam({
    required this.id,
    required this.cbseExamId,
    required this.studentSessionId,
    this.staffId,
    this.rollNo,
    this.remark,
    required this.totalPresentDays,
    required this.deleteStudentId,
    required this.createdAt,
    required this.cbseExamAssessmentId,
    required this.cbseTermId,
    required this.name,
    required this.useExamRollNo,
    required this.isActive,
    required this.isPublish,
    required this.cbseExamGradeId,
    required this.totalWorkingDays,
    required this.subjects,
    required this.grades,
    required this.examAssessments,
    this.examData,
    required this.examTotalMarks,
    required this.examObtainMarks,
    required this.examPercentage,
    required this.examGrade,
    required this.examRank,
  });

  factory CBSEExam.fromJson(Map<String, dynamic> json) {
    return CBSEExam(
      id: json['id']?.toString() ?? '',
      cbseExamId: json['cbse_exam_id']?.toString() ?? '',
      studentSessionId: json['student_session_id']?.toString() ?? '',
      staffId: json['staff_id']?.toString(),
      rollNo: json['roll_no']?.toString(),
      remark: json['remark']?.toString(),
      totalPresentDays: json['total_present_days']?.toString() ?? '',
      deleteStudentId: json['delete_student_id']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      cbseExamAssessmentId: json['cbse_exam_assessment_id']?.toString() ?? '',
      cbseTermId: json['cbse_term_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      useExamRollNo: json['use_exam_roll_no']?.toString() ?? '',
      isActive: json['is_active']?.toString() ?? '',
      isPublish: json['is_publish']?.toString() ?? '',
      cbseExamGradeId: json['cbse_exam_grade_id']?.toString() ?? '',
      totalWorkingDays: json['total_working_days']?.toString() ?? '',
      subjects: ((json['subjects'] ?? json['timetables'] ?? json['time_table']) as List<dynamic>? ?? [])
          .map((item) => CBSEExamSubject.fromJson(item as Map<String, dynamic>))
          .toList(),
      grades: (json['grades'] as List<dynamic>? ?? [])
          .map((item) => CBSEExamGrade.fromJson(item as Map<String, dynamic>))
          .toList(),
      examAssessments: (json['exam_assessments'] as List<dynamic>? ?? [])
          .map((item) => CBSEExamAssessment.fromJson(item as Map<String, dynamic>))
          .toList(),
      examData: json['exam_data'] != null 
          ? CBSEExamData.fromJson(json['exam_data'] as Map<String, dynamic>)
          : null,
      examTotalMarks: json['exam_total_marks']?.toString() ?? '0',
      examObtainMarks: json['exam_obtain_marks']?.toString() ?? '0',
      examPercentage: json['exam_percentage']?.toString() ?? '0',
      examGrade: json['exam_grade']?.toString() ?? '',
      examRank: json['exam_rank']?.toString() ?? '',
    );
  }
}

class CBSEExamSubject {
  final String id;
  final String cbseExamId;
  final String subjectId;
  final String date;
  final String timeFrom;
  final String timeTo;
  final String duration;
  final String roomNo;
  final String isWritten;
  final String writtenMaximumMarks;
  final String isPractical;
  final String? practicalMaximumMark;
  final String? createdBy;
  final String createdAt;
  final String subjectName;
  final String subjectCode;
  final List<CBSEExamSubjectAssessment> subjectAssessments;
  final Map<String, dynamic> raw;

  CBSEExamSubject({
    required this.id,
    required this.cbseExamId,
    required this.subjectId,
    required this.date,
    required this.timeFrom,
    required this.timeTo,
    required this.duration,
    required this.roomNo,
    required this.isWritten,
    required this.writtenMaximumMarks,
    required this.isPractical,
    this.practicalMaximumMark,
    this.createdBy,
    required this.createdAt,
    required this.subjectName,
    required this.subjectCode,
    required this.subjectAssessments,
    required this.raw,
  });

  factory CBSEExamSubject.fromJson(Map<String, dynamic> json) {
    return CBSEExamSubject(
      id: json['id']?.toString() ?? '',
      cbseExamId: json['cbse_exam_id']?.toString() ?? '',
      subjectId: json['subject_id']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      timeFrom: json['time_from']?.toString() ?? '',
      timeTo: json['time_to']?.toString() ?? '',
      duration: json['duration']?.toString() ?? '',
      roomNo: json['room_no']?.toString() ?? '',
      isWritten: json['is_written']?.toString() ?? '',
      writtenMaximumMarks: json['written_maximum_marks']?.toString() ?? '',
      isPractical: json['is_practical']?.toString() ?? '',
      practicalMaximumMark: json['practical_maximum_mark']?.toString(),
      createdBy: json['created_by']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
      subjectName: json['subject_name']?.toString() ?? '',
      subjectCode: json['subject_code']?.toString() ?? '',
      subjectAssessments: (json['subject_assessments'] as List<dynamic>? ?? [])
          .map((item) => CBSEExamSubjectAssessment.fromJson(item as Map<String, dynamic>))
          .toList(),
      raw: Map<String, dynamic>.from(json),
    );
  }

  String get formattedDate {
    try {
      final parsedDate = DateTime.parse(date);
      return '${parsedDate.month.toString().padLeft(2, '0')}/${parsedDate.day.toString().padLeft(2, '0')}/${parsedDate.year}';
    } catch (e) {
      return date;
    }
  }
}

class CBSEExamSubjectAssessment {
  final String id;
  final String cbseExamTimetableId;
  final String cbseExamAssessmentTypeId;
  final String createdAt;

  CBSEExamSubjectAssessment({
    required this.id,
    required this.cbseExamTimetableId,
    required this.cbseExamAssessmentTypeId,
    required this.createdAt,
  });

  factory CBSEExamSubjectAssessment.fromJson(Map<String, dynamic> json) {
    return CBSEExamSubjectAssessment(
      id: json['id']?.toString() ?? '',
      cbseExamTimetableId: json['cbse_exam_timetable_id']?.toString() ?? '',
      cbseExamAssessmentTypeId: json['cbse_exam_assessment_type_id']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

class CBSEExamGrade {
  final String id;
  final String cbseExamGradeId;
  final String name;
  final String minimumPercentage;
  final String maximumPercentage;
  final String description;
  final String createdBy;
  final String createdAt;

  CBSEExamGrade({
    required this.id,
    required this.cbseExamGradeId,
    required this.name,
    required this.minimumPercentage,
    required this.maximumPercentage,
    required this.description,
    required this.createdBy,
    required this.createdAt,
  });

  factory CBSEExamGrade.fromJson(Map<String, dynamic> json) {
    return CBSEExamGrade(
      id: json['id']?.toString() ?? '',
      cbseExamGradeId: json['cbse_exam_grade_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      minimumPercentage: json['minimum_percentage']?.toString() ?? '',
      maximumPercentage: json['maximum_percentage']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      createdBy: json['created_by']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

class CBSEExamAssessment {
  final String id;
  final String cbseExamAssessmentId;
  final String name;
  final String code;
  final String maximumMarks;
  final String passPercentage;
  final String description;
  final String createdBy;
  final String createdAt;

  CBSEExamAssessment({
    required this.id,
    required this.cbseExamAssessmentId,
    required this.name,
    required this.code,
    required this.maximumMarks,
    required this.passPercentage,
    required this.description,
    required this.createdBy,
    required this.createdAt,
  });

  factory CBSEExamAssessment.fromJson(Map<String, dynamic> json) {
    return CBSEExamAssessment(
      id: json['id']?.toString() ?? '',
      cbseExamAssessmentId: json['cbse_exam_assessment_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      maximumMarks: json['maximum_marks']?.toString() ?? '',
      passPercentage: json['pass_percentage']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      createdBy: json['created_by']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

class CBSEExamData {
  final List<CBSEExamDataSubject> subjects;

  CBSEExamData({
    required this.subjects,
  });

  factory CBSEExamData.fromJson(Map<String, dynamic> json) {
    return CBSEExamData(
      subjects: (json['subjects'] as List<dynamic>? ?? [])
          .map((item) => CBSEExamDataSubject.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CBSEExamDataSubject {
  final String subjectId;
  final String subjectName;
  final String subjectCode;
  final Map<String, CBSEExamDataAssessment> examAssessments;

  CBSEExamDataSubject({
    required this.subjectId,
    required this.subjectName,
    required this.subjectCode,
    required this.examAssessments,
  });

  factory CBSEExamDataSubject.fromJson(Map<String, dynamic> json) {
    Map<String, CBSEExamDataAssessment> assessments = {};
    if (json['exam_assessments'] != null) {
      (json['exam_assessments'] as Map<String, dynamic>).forEach((key, value) {
        assessments[key] = CBSEExamDataAssessment.fromJson(value as Map<String, dynamic>);
      });
    }
    
    return CBSEExamDataSubject(
      subjectId: json['subject_id']?.toString() ?? '',
      subjectName: json['subject_name']?.toString() ?? '',
      subjectCode: json['subject_code']?.toString() ?? '',
      examAssessments: assessments,
    );
  }
}

class CBSEExamDataAssessment {
  final String cbseExamAssessmentTypeName;
  final String cbseExamAssessmentTypeId;
  final String cbseExamAssessmentTypeCode;
  final String maximumMarks;
  final String? cbseStudentSubjectMarksId;
  final String marks;
  final String note;
  final String isAbsent;

  CBSEExamDataAssessment({
    required this.cbseExamAssessmentTypeName,
    required this.cbseExamAssessmentTypeId,
    required this.cbseExamAssessmentTypeCode,
    required this.maximumMarks,
    this.cbseStudentSubjectMarksId,
    required this.marks,
    required this.note,
    required this.isAbsent,
  });

  factory CBSEExamDataAssessment.fromJson(Map<String, dynamic> json) {
    return CBSEExamDataAssessment(
      cbseExamAssessmentTypeName: json['cbse_exam_assessment_type_name']?.toString() ?? '',
      cbseExamAssessmentTypeId: json['cbse_exam_assessment_type_id']?.toString() ?? '',
      cbseExamAssessmentTypeCode: json['cbse_exam_assessment_type_code']?.toString() ?? '',
      maximumMarks: json['maximum_marks']?.toString() ?? '',
      cbseStudentSubjectMarksId: json['cbse_student_subject_marks_id']?.toString(),
      marks: json['marks']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      isAbsent: json['is_absent']?.toString() ?? '',
    );
  }
}

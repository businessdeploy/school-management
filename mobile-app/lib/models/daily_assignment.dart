class DailyAssignment {
  final String id;
  final String subjectName;
  final String subjectCode;
  final String title;
  final String description;
  final String remark;
  final String date;
  final String evaluationDate;
  final String status;
  final String createdAt;
  final String updatedAt;
  final String attachment;
  final String evaluatedBy;
  final String studentSessionId;
  final String subjectGroupSubjectId;
  final String attachmentDir;

  DailyAssignment({
    required this.id,
    required this.subjectName,
    required this.subjectCode,
    required this.title,
    required this.description,
    required this.remark,
    required this.date,
    required this.evaluationDate,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.attachment,
    required this.evaluatedBy,
    required this.studentSessionId,
    required this.subjectGroupSubjectId,
    required this.attachmentDir,
  });

  factory DailyAssignment.fromJson(Map<String, dynamic> json) {
    final resolvedId = _pickFirstNonEmpty(json, [
      'id',
      'assignment_id',
      'assignmentId',
      'daily_assignment_id',
      'dailyAssignmentId',
      'dailyassignment_id',
      'dailyassignmentId',
    ]);

    final resolvedStudentSessionId = _pickFirstNonEmpty(json, [
      'student_session_id',
      'studentSessionId',
      'student_sessionId',
      'session_id',
    ]);

    final resolvedSubjectGroupSubjectId = _pickFirstNonEmpty(json, [
      'subject_group_subject_id',
      'subjectGroupSubjectId',
      'subject_group_id',
      'subjectGroupId',
      'subject_id',
    ]);

    final resolvedAttachment = _pickFirstNonEmpty(json, [
      'attachment',
      'attachments',
      'document',
      'doc',
      'file',
      'file_path',
    ]);

    final resolvedAttachmentDir = _pickFirstNonEmpty(json, [
      'attachment_path',
      'attachment_dir',
      'dir_path',
      'document_path',
      'document_dir',
      'upload_path',
    ]);

    final resolvedRemark = _pickFirstNonEmpty(json, [
      'remark',
      'remarks',
      'comment',
      'comments',
      'feedback',
      'teacher_remark',
      'evaluation_remark',
    ]);

    final resolvedEvaluationDate = _pickFirstNonEmpty(json, [
      'evaluation_date',
      'evaluationDate',
      'evaluated_at',
      'evaluatedAt',
      'evaluation_on',
    ]);

    return DailyAssignment(
      id: resolvedId,
      subjectName: json['subject_name']?.toString() ?? '',
      subjectCode: json['subject_code']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      remark: resolvedRemark,
      date: json['date']?.toString() ?? '',
      evaluationDate: resolvedEvaluationDate,
      status: json['status']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
      attachment: resolvedAttachment,
      evaluatedBy: json['evaluated_by']?.toString() ?? '',
      studentSessionId: resolvedStudentSessionId,
      subjectGroupSubjectId: resolvedSubjectGroupSubjectId,
      attachmentDir: resolvedAttachmentDir,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject_name': subjectName,
      'subject_code': subjectCode,
      'title': title,
      'description': description,
      'remark': remark,
      'date': date,
      'evaluation_date': evaluationDate,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'attachment': attachment,
      'attachment_dir': attachmentDir,
      'evaluated_by': evaluatedBy,
      'student_session_id': studentSessionId,
      'subject_group_subject_id': subjectGroupSubjectId,
    };
  }

  // Helper method to get formatted date
  String get formattedDate {
    if (date.isEmpty) return '';
    try {
      final dateTime = DateTime.parse(date);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return date;
    }
  }

  // Helper method to get formatted evaluation date
  String get formattedEvaluationDate {
    if (evaluationDate.isEmpty) return '';
    try {
      final dateTime = DateTime.parse(evaluationDate);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}'; // Match basic formattedDate
    } catch (e) {
      return evaluationDate;
    }
  }

  // Helper method to get formatted creation date
  String get formattedCreatedAt {
    if (createdAt.isEmpty) return '';
    try {
      final dateTime = DateTime.parse(createdAt);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return createdAt;
    }
  }
}

String _pickFirstNonEmpty(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    if (!json.containsKey(key)) continue;
    final value = json[key];
    final cleaned = _cleanJsonValue(value);
    if (cleaned.isNotEmpty) {
      return cleaned;
    }
  }
  return '';
}

String _cleanJsonValue(dynamic value) {
  if (value == null) return '';
  final stringValue = value.toString().trim();
  if (stringValue.isEmpty || stringValue.toLowerCase() == 'null') {
    return '';
  }
  return stringValue;
}

class LessonPlan {
  final String id;
  final String subjectId;
  final String subjectName;
  final String subjectCode;
  final String topicName;
  final String lessonName;
  final String description;
  final String date;
  final String timeFrom;
  final String timeTo;
  final String className;
  final String section;
  final String teacherName;
  final String isActive;
  final String createdAt;
  final String updatedAt;
  final String? day; // Add day field for weekly grouping
  final String attachment; // Added attachment field
  final String presentation; // Added presentation field
  final String video; // Added video field

  LessonPlan({
    required this.id,
    required this.subjectId,
    required this.subjectName,
    required this.subjectCode,
    required this.topicName,
    required this.lessonName,
    required this.description,
    required this.date,
    required this.timeFrom,
    required this.timeTo,
    required this.className,
    required this.section,
    required this.teacherName,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.day,
    required this.attachment,
    required this.presentation,
    required this.video,
  });

  factory LessonPlan.fromJson(Map<String, dynamic> json) {
    // Extract subject_syllabus_id (dynamic from API) - this is critical for comments
    final subjectSyllabusId = _pickFirstNonEmpty(json, [
      'subject_syllabus_id',
      'subject_syllabusid',
      'subjectSyllabusId',
      'subject_group_subject_id',
      'subject_group_class_sections_id',
      'subject_id',
      'subjectId',
      'lesson_plan_forum_id',
      'lesson_plan_id',
      'id',
    ]);


    // Capture subject_syllabus_id if present directly (common in getlessonplan)
    String finalSubjectSyllabusId = subjectSyllabusId;
    if (finalSubjectSyllabusId.isEmpty || finalSubjectSyllabusId == '0') {
       finalSubjectSyllabusId = (json['subject_syllabus_id'] ?? json['subject_syllabusid'] ?? '').toString();
    }

    // Extract attachment - check multiple possible keys and nested structures
    String attachment = '';
    
    // First, try direct keys
    final directKeys = [
      'attachment',
      'document',
      'file',
      'file_name',
      'upload_file',
      'attached_file',
      'material',
      'syllabus_attachment',
      'lesson_attachment',
      'lesson_plan_attachment',
      'attached_document',
      'document_file',
      'file_path',
      'file_url',
      'uploaded_file',
      'uploaded_file_url',
      'file_url_path',
      'document_path',
      'attachment_path',
      'lesson_file',
      'syllabus_file',
    ];
    
    attachment = _pickFirstNonEmpty(json, directKeys);
    
    // If not found, check nested structures
    if (attachment.isEmpty) {
      // Check if attachment is in a nested object
      if (json['attachment_data'] is Map) {
        final attachmentData = json['attachment_data'] as Map<String, dynamic>;
        attachment = _pickFirstNonEmpty(attachmentData, directKeys);
      }
      
      // Check if attachment is in file_info
      if (attachment.isEmpty && json['file_info'] is Map) {
        final fileInfo = json['file_info'] as Map<String, dynamic>;
        attachment = _pickFirstNonEmpty(fileInfo, directKeys);
      }
      
      // Check if attachment is in document_info
      if (attachment.isEmpty && json['document_info'] is Map) {
        final docInfo = json['document_info'] as Map<String, dynamic>;
        attachment = _pickFirstNonEmpty(docInfo, directKeys);
      }
    }
    
    // Debug logging

    // Extract presentation
    final presentation = _pickFirstNonEmpty(json, [
      'presentation',
      'presentation_file',
      'ppt',
    ]);

    // Extract video
    final video = _pickFirstNonEmpty(json, [
      'video',
      'video_url',
      'youtube_url',
      'youtube_video',
      'url',
      'lecture_video',
    ]);

    return LessonPlan(
      id: json['id']?.toString() ?? '',
      subjectId: finalSubjectSyllabusId.isNotEmpty ? finalSubjectSyllabusId : subjectSyllabusId, 
      subjectName:
          json['name']?.toString() ?? json['subject_name']?.toString() ?? '',
      subjectCode:
          json['code']?.toString() ?? json['subject_code']?.toString() ?? '',
      topicName: json['topic_name']?.toString() ?? '',
      lessonName: json['lesson_name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      timeFrom: json['time_from']?.toString() ?? '',
      timeTo: json['time_to']?.toString() ?? '',
      className:
          json['class']?.toString() ?? json['class_name']?.toString() ?? '',
      section: json['section']?.toString() ?? '',
      teacherName: _pickFirstNonEmpty(json, [
        'teacher_name',
        'staff_name',
        'created_by_name',
        'teacher',
        'staffname',
        'name', // sometimes the teacher name is simply in 'name'
      ]),
      isActive: json['is_active']?.toString() ?? '1',
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
      day: json['day']?.toString(),
      attachment: attachment,
      presentation: presentation,
      video: video,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject_syllabus_id': subjectId,
      'name': subjectName,
      'code': subjectCode,
      'topic_name': topicName,
      'lesson_name': lessonName,
      'description': description,
      'date': date,
      'time_from': timeFrom,
      'time_to': timeTo,
      'class': className,
      'section': section,
      'teacher_name': teacherName,
      'is_active': isActive,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'day': day,
      'attachment': attachment,
      'presentation': presentation,
      'video': video,
    };
  }
}

String _pickFirstNonEmpty(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    if (!json.containsKey(key)) continue;
    final value = json[key];
    if (value == null) continue;
    final stringValue = value.toString().trim();
    if (stringValue.isNotEmpty && stringValue.toLowerCase() != 'null') {
      return stringValue;
    }
  }
  return '';
}

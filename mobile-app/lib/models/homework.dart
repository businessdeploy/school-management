class Homework {
  final String id;
  final String homeworkId;
  final String title;
  final String description;
  final String subject;
  final String className;
  final String section;
  final String homeworkDate;
  final String submissionDate;
  final String createdBy;
  final String evaluatedBy;
  final String evaluationDate;
  final String maxMarks;
  final String marksObtained;
  final String note;
  final String status;
  final String studentId;
  final String studentSubmission;
  final String studentLogo;
  final String studentDescription;
  final String submittedAt;
  final String subjectName;
  final String subjectCode;
  final String createdByName;
  final String createdBySurname;
  final String createdByStaffId;
  final String attachedDocument;
  final String uploadedFileUrl;
  final Map<String, dynamic> raw; // Added for debugging

  Homework({
    required this.id,
    required this.homeworkId,
    required this.title,
    required this.description,
    required this.subject,
    required this.className,
    required this.section,
    required this.homeworkDate,
    required this.submissionDate,
    required this.createdBy,
    required this.evaluatedBy,
    required this.evaluationDate,
    required this.maxMarks,
    required this.marksObtained,
    required this.note,
    required this.status,
    required this.studentId,
    required this.studentSubmission,
    required this.studentLogo,
    required this.studentDescription,
    required this.submittedAt,
    required this.subjectName,
    required this.subjectCode,
    required this.createdByName,
    required this.createdBySurname,
    required this.createdByStaffId,
    required this.attachedDocument,
    required this.uploadedFileUrl,
    required this.raw,
  });

  factory Homework.fromJson(Map<String, dynamic> json) {
    // Clean HTML from description to create title
    String cleanDescription = json['description']?.toString() ?? '';
    String title = cleanDescription
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'\r?\n'), ' ')
        .trim();
    if (title.isEmpty) {
      title = '${json['subject_name'] ?? ''} Homework';
    }

    final resolvedCreatedByName = _pickFirstNonEmpty(json, [
      'created_by_name',
      'staff_name',
      'name',
      'teacher_name',
      'createdByName',
      'staffName',
      'teacherName',
      'created_by', // Might be name or ID, handled in display logic
    ]);
    final resolvedCreatedBySurname = _pickFirstNonEmpty(json, [
      'created_by_surname',
      'staff_surname',
      'surname',
      'teacher_surname',
      'createdBySurname',
      'staffSurname',
      'teacherSurname',
    ]);

    String displayCreatedByName = [
      resolvedCreatedByName,
      resolvedCreatedBySurname,
    ].where((part) => part.isNotEmpty).join(' ');

    if (displayCreatedByName.isEmpty) {
      displayCreatedByName = _pickFirstNonEmpty(json, [
        'created_by',
        'createdBy',
        'staff_name',
        'name',
        'teacher_name',
      ]);
    }

    if (displayCreatedByName.isEmpty) {
      displayCreatedByName = 'Staff';
    }

    // Determine staff id from multiple possible backend keys.
    // Align priority with Notice Board so the same staff ID is shown everywhere.
    final String resolvedStaffId = _pickFirstNonEmpty(json, [
      'employee_no',                 // Notice Board primary
      'staff_no',
      'staff_number',
      'created_by_employee_id',      // Primary: Employee ID from creation
      'staff_employee_id',            // Alternative
      'employee_id',                 // Generic
      'employeeId',
      'evaluation_staff_id',         // Legacy
      'staff_id',
      'staffId',
      'user_id',
      'userId',
    ]);

    // Extract homework ID - prefer explicit homework identifiers and fall back cautiously
    final String resolvedHomeworkId = _pickFirstNonEmpty(json, [
      'homework_id',
      'homeworkId',
      'homeworkID',
      'homeworkid',
      'id',
      'ID',
      'homework_unique_id',
      'homework_ref_id',
      'student_homework_id',
      'created_by_employee_id',
    ]);

    final String resolvedStudentSubmissionId = _pickFirstNonEmpty(json, [
      'student_homework_id',
      'studentHomeworkId',
      'student_homeworkID',
      'student_submission_id',
      'studentSubmissionId',
      'student_submission',
    ]);

    // CRITICAL: Extract student submission message/text
    // Check multiple possible field names from API, including nested structures
    // We prioritize student-specific keys to avoid picking up the teacher's homework description
    String resolvedStudentDescription = _pickFirstNonEmpty(json, [
      'student_message',
      'studentMessage',
      'student_description',
      'studentDescription',
      'student_note',
      'studentNote',
      'student_comment',
      'studentComment',
      'submission_message',
      'submissionMessage',
      'submission_note',
      'homework_message',
      'homeworkMessage',
      'student_answer',
      'studentAnswer',
      'answer',
      'user_message',
      'userNote',
      'userComment',
      'reply',
      'comment',
      'msg',
      'student_homework_message',
      'student_homework_description',
      'student_homework_note',
      'submission_description',
      'evaluation_note',
      'teacher_note',
      'teacher_message',
    ]);
    
    // If not found at top level, check nested structures
    // Submission data is often inside student_homework, submission, or data
    if (resolvedStudentDescription.isEmpty) {
      // Helper to extract from a dynamic object (Map or List)
      String extractFromNested(dynamic nested) {
        if (nested == null) return '';
        if (nested is Map) {
          return _pickFirstNonEmpty(
            Map<String, dynamic>.from(nested),
            [
              'message', 
              'student_message', 
              'description', 
              'student_description', 
              'student_comment', 
              'student_note',
              'answer', 
              'note', 
              'comment', 
              'reply',
              'msg'
            ],
          );
        } else if (nested is List && nested.isNotEmpty) {
          return extractFromNested(nested.first);
        }
        return '';
      }

      // Check in all possible nested submission objects
      final submissionParentKeys = [
        'student_homework', 
        'submission', 
        'student', 
        'student_submission', 
        'student_homework_data',
        'data',
        'submission_data'
      ];
      
      for (final key in submissionParentKeys) {
        if (json[key] != null) {
          final found = extractFromNested(json[key]);
          if (found.isNotEmpty) {
            // Filter out obvious status messages even in nested objects
            final lower = found.toLowerCase();
            if (lower != 'success' && lower != '1' && lower != 'true' && lower != 'ok') {
              resolvedStudentDescription = found;
              break;
            }
          }
        }
      }
    }
    
    // Final fallback: check 'message' and 'note' at root but filter strictly
    // DO NOT include 'description' here as that is the teacher's homework description
    if (resolvedStudentDescription.isEmpty) {
      final potentialMessage = _pickFirstNonEmpty(json, ['message', 'note']);
      if (potentialMessage.isNotEmpty) {
        final lower = potentialMessage.toLowerCase();
        // Skip common API status messages and common teacher descriptions
        if (lower != 'success' && lower != '1' && lower != 'true' && lower != 'ok') {
           resolvedStudentDescription = potentialMessage;
        }
      }
    }
    
    // Clean HTML from student description if any
    if (resolvedStudentDescription.contains('<') && resolvedStudentDescription.contains('>')) {
       resolvedStudentDescription = resolvedStudentDescription
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .replaceAll('&nbsp;', ' ')
          .replaceAll('&amp;', '&')
          .trim();
    }

    // Final check for redundant status messages
    if (resolvedStudentDescription.toLowerCase() == 'success' || resolvedStudentDescription == '1') {
      resolvedStudentDescription = '';
    }

    // CRITICAL: Extract student submission document/attachment
    // Check ALL possible field names from getHomework API response
    // Priority: document (from API) > student_document > other variations
    String resolvedStudentDocument = _resolveDocumentPath(
      json,
      [
        // PRIMARY: Check "document" field first (most common in getHomework API)
        'student_document', // Alternative primary field
        'studentDocument',
        'student_doc',
        'student_file',
        'student_upload',
        'student_logo',
        'student_attachment',
        'submission_document',
        'submission_file',
        'submission_doc',
        'submission_attachment',
        'submission_upload',
        'student_homework_file',
        'student_homework_document',
        'homework_file',
        'student_homework_attachment',
        'student_homework_upload',
        'uploaded_file',
        'uploaded_document',
        'uploaded_attachment',
        'file_path',
        'filepath',
        'document_path',
        'file',
        'doc',
        // Additional fields that might contain submission attachment
        'attachment',
        'attachment_file',
        'attachment_document',
        'submitted_file',
        'submitted_document',
        'submitted_attachment',
        'homework_submission_file',
        'homework_submission_document',
        // Fields from submission API response
        'file_url',
        'fileUrl',
        'attachment_url',
        'attachmentUrl',
        'student_file_url',
        'submission_file_url',
      ],
      nestedParents: [
        'student_homework',
        'student_submission',
        'student',
        'submission',
        'homework',
        'attachment',
        'file_info',
        'attachment_data',
        'submission_data',
      ],
    );
    
    // If not found, check nested structures explicitly
    if (resolvedStudentDocument.isEmpty) {
      // Check in student_homework nested object
      if (json['student_homework'] is Map) {
        resolvedStudentDocument = _resolveDocumentPath(
          json['student_homework'] as Map<String, dynamic>,
          ['document', 'student_document', 'file', 'attachment'],
        );
      }
      // Check in submission nested object
      if (resolvedStudentDocument.isEmpty && json['submission'] is Map) {
        resolvedStudentDocument = _resolveDocumentPath(
          json['submission'] as Map<String, dynamic>,
          ['document', 'student_document', 'file', 'attachment'],
        );
      }
    }

    final String resolvedHomeworkDocument = _resolveDocumentPath(
      json,
      [
        'attached_document',
        'attachment',
        'document',
        'document_file',
        'documentFile',
        'homework_doc',
        'homework_document',
        'upload_document',
        'file',
        'files',
        'docs',
        'file_path',
        'filepath',
        'homework_attachment',
        'homework_upload',
      ],
      nestedParents: [
        'homework',
        'document',
        'attachment',
      ],
    );

    // CRITICAL: submissionDate should be the DUE DATE (when homework should be submitted)
    final String resolvedSubmissionDueDate = _pickFirstNonEmpty(json, [
      'homework_due_date',
      'due_date',
      'dueDate',
      'submit_date',
      'submission_date',
      'submissionDate',
      's_d',
    ]);

    // CRITICAL: submittedAt should be the ACTUAL SUBMISSION DATE (when student submitted)
    // For submitted homework, this should show today's date or the date from API
    String resolvedSubmittedAt = _pickFirstNonEmpty(json, [
      'submitted_at', // Primary field for actual submission timestamp
      'submitted_date', // Alternative field name
      'submittedDate',
      'submission_datetime',
      'submissionTime',
      'submission_created_at', // When submission was created
      'submission_created_date',
      'created_at', // Fallback to created_at
      'createdAt',
      'created_on',
      'createdOn',
      // Only use submission_date if submitted_at is not available
      // (submission_date might be the due date, not actual submission date)
    ]);
    
    // If not found at top level, check nested structures
    if (resolvedSubmittedAt.isEmpty) {
      // Check in student_homework nested object
      if (json['student_homework'] is Map) {
        resolvedSubmittedAt = _pickFirstNonEmpty(
          json['student_homework'] as Map<String, dynamic>,
          ['submitted_at', 'submitted_date', 'created_at'],
        );
      }
      // Check in submission nested object
      if (resolvedSubmittedAt.isEmpty && json['submission'] is Map) {
        resolvedSubmittedAt = _pickFirstNonEmpty(
          json['submission'] as Map<String, dynamic>,
          ['submitted_at', 'submitted_date', 'created_at'],
        );
      }
    }
    
    // CRITICAL: If status is "submitted" but no submission date found, use today's date
    final status = (json['status']?.toString() ?? '').toLowerCase();
    if (status == 'submitted' && resolvedSubmittedAt.isEmpty) {
      final now = DateTime.now();
      resolvedSubmittedAt = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    }
    final String resolvedUploadedFileUrl = _pickFirstNonEmpty(
      json,
      [
        'uploaded_file_url',
        'uploadedFileUrl',
        'file_url',
        'document_url',
        'student_homework_file',
        'student_homework_attachment',
        'submission_document',
        'submission_file',
        'uploadedFile',
      ],
    );

    final homework = Homework(
      id: resolvedHomeworkId,
      homeworkId: resolvedHomeworkId,
      title: title,
      description: cleanDescription,
      subject: json['subject_name']?.toString() ?? '',
      className: json['class']?.toString() ?? '',
      section: json['section']?.toString() ?? '',
      homeworkDate: json['homework_date']?.toString() ?? '',
      submissionDate: resolvedSubmissionDueDate, // This is the DUE DATE
      createdBy: displayCreatedByName,
      evaluatedBy: () {
        // Robust evaluated by extraction
        final fName = _pickFirstNonEmpty(json, [
          'evaluated_by_name',
          'evaluator_name',
        ]);
        final lName = _pickFirstNonEmpty(json, [
          'evaluated_by_surname',
          'evaluator_surname',
        ]);
        
        String name = [fName, lName].where((s) => s.isNotEmpty).join(' ');
        
        if (name.isEmpty) {
          name = _pickFirstNonEmpty(json, ['evaluated_by']);
        }
        
        final id = _pickFirstNonEmpty(json, [
          'evaluated_by_employee_id',
          'evaluation_employee_id',
          'evaluation_staff_id',
          'staff_employee_id',
          'employee_id',
          'evaluated_by_id',
          'evaluator_id',
          'evaluated_by_staff_id',
        ]);

        if (name.isEmpty && id.isNotEmpty) {
           name = 'Staff'; 
        }

        if (name.isNotEmpty) {
          if (id.isNotEmpty && id != 'null') {
             return '$name (ID: $id)';
          }
          return name;
        }
        return '';
      }(),
      evaluationDate: json['evaluation_date']?.toString() ?? '',
      maxMarks: json['marks']?.toString() ?? '',
      marksObtained: json['evaluation_marks']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      studentId: json['student_id']?.toString() ?? '',
      studentSubmission: resolvedStudentSubmissionId,
      studentLogo: resolvedStudentDocument,
      studentDescription: resolvedStudentDescription,
      submittedAt: resolvedSubmittedAt,
      subjectName: json['subject_name']?.toString() ?? '',
      subjectCode: json['subject_code']?.toString() ?? '',
      createdByName: resolvedCreatedByName,
      createdBySurname: resolvedCreatedBySurname,
      createdByStaffId: resolvedStaffId,
      attachedDocument: resolvedHomeworkDocument,
      uploadedFileUrl: resolvedUploadedFileUrl,
      raw: json, // Store raw JSON
    );

    return homework;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'homework_id': homeworkId,
      'title': title,
      'description': description,
      'subject': subject,
      'class': className,
      'section': section,
      'homework_date': homeworkDate,
      'submission_date': submissionDate,
      'created_by': createdBy,
      'evaluated_by': evaluatedBy,
      'evaluation_date': evaluationDate,
      'max_marks': maxMarks,
      'marks_obtained': marksObtained,
      'note': note,
      'status': status,
      'student_id': studentId,
      'student_submission': studentSubmission,
      'student_logo': studentLogo,
      'student_document': studentLogo,
      'student_description': studentDescription,
      'submitted_at': submittedAt,
      'subject_name': subjectName,
      'subject_code': subjectCode,
      'created_by_name': createdByName,
      'created_by_surname': createdBySurname,
      'created_by_staff_id': createdByStaffId,
      'attached_document': attachedDocument,
      'uploaded_file_url': uploadedFileUrl,
      'raw': raw,
    };
  }

  // Format date for display (DD/MM/YYYY format)
  String formatDateForDisplay(String dateString) {
    if (dateString.isEmpty) return '';

    try {
      // Handle different date formats
      DateTime? date;

      // Try YYYY-MM-DD format first
      if (dateString.contains('-') && dateString.length >= 10) {
        date = DateTime.tryParse(dateString.substring(0, 10));
      }
      // Try DD/MM/YYYY format
      else if (dateString.contains('/')) {
        final parts = dateString.split('/');
        if (parts.length == 3) {
          final day = int.tryParse(parts[0]) ?? 1;
          final month = int.tryParse(parts[1]) ?? 1;
          final year = int.tryParse(parts[2]) ?? 2025;
          date = DateTime(year, month, day);
        }
      }
      // Try MM/DD/YYYY format (American format)
      else if (dateString.contains('/')) {
        final parts = dateString.split('/');
        if (parts.length == 3) {
          final month = int.tryParse(parts[0]) ?? 1;
          final day = int.tryParse(parts[1]) ?? 1;
          final year = int.tryParse(parts[2]) ?? 2025;
          date = DateTime(year, month, day);
        }
      }

      if (date != null) {
        return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      }
    } catch (e) {
      print('Error formatting date: $e');
    }

    return dateString; // Return original if formatting fails
  }

  // Validate and fix date order if needed
  String get validatedHomeworkDate {
    final homework = formatDateForDisplay(homeworkDate);
    final submission = formatDateForDisplay(submissionDate);

    // If homework date is after submission date, swap them
    if (homework.isNotEmpty && submission.isNotEmpty) {
      try {
        final homeworkParts = homework.split('/');
        final submissionParts = submission.split('/');

        if (homeworkParts.length == 3 && submissionParts.length == 3) {
          final homeworkDate = DateTime(
            int.parse(homeworkParts[2]), // year
            int.parse(homeworkParts[1]), // month
            int.parse(homeworkParts[0]), // day
          );
          final submissionDate = DateTime(
            int.parse(submissionParts[2]), // year
            int.parse(submissionParts[1]), // month
            int.parse(submissionParts[0]), // day
          );

          // If homework date is after submission date, use submission date as homework date
          if (homeworkDate.isAfter(submissionDate)) {
            print(
              '⚠️ Homework date ($homework) is after submission date ($submission). Using submission date as homework date.',
            );
            return submission;
          }
        }
      } catch (e) {
        print('Error validating date order: $e');
      }
    }

    return homework;
  }

  String get validatedSubmissionDate {
    final homework = formatDateForDisplay(homeworkDate);
    final submission = formatDateForDisplay(submissionDate);

    // If homework date is after submission date, make submission date 7 days after homework date
    if (homework.isNotEmpty && submission.isNotEmpty) {
      try {
        final homeworkParts = homework.split('/');
        final submissionParts = submission.split('/');

        if (homeworkParts.length == 3 && submissionParts.length == 3) {
          final homeworkDate = DateTime(
            int.parse(homeworkParts[2]), // year
            int.parse(homeworkParts[1]), // month
            int.parse(homeworkParts[0]), // day
          );
          final submissionDate = DateTime(
            int.parse(submissionParts[2]), // year
            int.parse(submissionParts[1]), // month
            int.parse(submissionParts[0]), // day
          );

          // If homework date is after submission date, set submission date to 7 days after homework date
          if (homeworkDate.isAfter(submissionDate)) {
            final correctedSubmissionDate = homeworkDate.add(
              const Duration(days: 7),
            );
            print(
              '⚠️ Homework date ($homework) is after submission date ($submission). Setting submission date to 7 days after homework date.',
            );
            return '${correctedSubmissionDate.day.toString().padLeft(2, '0')}/${correctedSubmissionDate.month.toString().padLeft(2, '0')}/${correctedSubmissionDate.year}';
          }
        }
      } catch (e) {
        print('Error validating date order: $e');
      }
    }

    return submission;
  }

  // Get formatted homework date
  String get formattedHomeworkDate => formatDateForDisplay(homeworkDate);

  // Get formatted submission date
  String get formattedSubmissionDate => formatDateForDisplay(submissionDate);

  // Get created by with staff ID (not homework ID)
  String get createdByWithStaffId {
    // Build full name from first name and surname
    String fullName = createdBy;
    
    // If we have separate name and surname, construct full name
    if (createdByName.isNotEmpty || createdBySurname.isNotEmpty) {
      final nameParts = [
        createdByName,
        createdBySurname,
      ].where((part) => part.isNotEmpty).toList();
      
      if (nameParts.isNotEmpty) {
        fullName = nameParts.join(' ');
      }
    }
    
    // If full name is still empty, use the createdBy field
    if (fullName.isEmpty) {
      fullName = createdBy.isNotEmpty ? createdBy : 'Staff';
    }
    
    // Check if fullName is actually just the ID (common API issue)
    // If fullName is same as staff ID, or if fullName is numeric, treat it as ID only
    final isNumeric = double.tryParse(fullName) != null;
    if (fullName == createdByStaffId || isNumeric) {
      if (createdByName.isNotEmpty || createdBySurname.isNotEmpty) {
          // If we have parts, use them
      } else {
          // Fallback to generic "Staff" if name is purely numeric/ID
          fullName = 'Staff';
      }
    }
    
    // Add staff ID if available
    if (createdByStaffId.isNotEmpty && createdByStaffId != 'null') {
      return '$fullName (ID: $createdByStaffId)';
    }
    
    // Return just the name if no staff ID is available
    return fullName;
  }

  // Get evaluated by with ID
  String get evaluatedByWithId {
    if (evaluatedBy.isEmpty || evaluatedBy == 'null') {
      return '';
    }
    
    // If evaluatedBy contains the ID already (e.g. "Name (9000)"), return as is
    if (evaluatedBy.contains('(') && evaluatedBy.contains(')')) {
      return evaluatedBy;
    }
    
    // If we have an ID, append it
    // Note: Assuming evaluatedBy is the name. If the API returns ID in evaluatedBy, 
    // we might need extra logic similar to createdByWithStaffId
    
    return evaluatedBy;
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

String _resolveDocumentPath(
  Map<String, dynamic> json,
  List<String> keys, {
  List<String> nestedParents = const [],
}) {
  final direct = _pickFirstNonEmpty(json, keys);
  if (direct.isNotEmpty) return direct;

  for (final parentKey in nestedParents) {
    final nested = json[parentKey];
    if (nested == null) continue;

    if (nested is Map<String, dynamic>) {
      final resolved = _pickFirstNonEmpty(nested, keys);
      if (resolved.isNotEmpty) {
        return resolved;
      }
    } else if (nested is List) {
      for (final item in nested) {
        if (item is Map<String, dynamic>) {
          final resolved = _pickFirstNonEmpty(item, keys);
          if (resolved.isNotEmpty) {
            return resolved;
          }
        }
      }
    } else if (nested is String) {
      final trimmed = nested.trim();
      if (trimmed.isNotEmpty && trimmed.toLowerCase() != 'null') {
        return trimmed;
      }
    }
  }

  return '';
}

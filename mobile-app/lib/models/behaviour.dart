class BehaviourRecord {
  final String id;
  final String title;
  final String point;
  final String description;
  final String createdAt;
  final String studentId;
  final String firstname;
  final String? middlename;
  final String lastname;
  final String admissionNo;
  final String session;
  final String staffName;
  final String staffSurname;
  final String staffEmployeeId;
  final String roleName;
  final String roleId;
  final int commentCount;

  BehaviourRecord({
    required this.id,
    required this.title,
    required this.point,
    required this.description,
    required this.createdAt,
    required this.studentId,
    required this.firstname,
    this.middlename,
    required this.lastname,
    required this.admissionNo,
    required this.session,
    required this.staffName,
    required this.staffSurname,
    required this.staffEmployeeId,
    required this.roleName,
    required this.roleId,
    required this.commentCount,
  });

  factory BehaviourRecord.fromJson(Map<String, dynamic> json) {
    return BehaviourRecord(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      point: json['points']?.toString() ?? json['point']?.toString() ?? '0',
      description: json['description']?.toString() ?? '',
      createdAt: json['incident_date']?.toString() ?? json['created_at']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      firstname: json['firstname']?.toString() ?? '',
      middlename: json['middlename']?.toString(),
      lastname: json['lastname']?.toString() ?? '',
      admissionNo: json['admission_no']?.toString() ?? '',
      session: json['session']?.toString() ?? '',
      staffName: json['teacher_name']?.toString().split(' ')[0] ?? json['staff_name']?.toString() ?? '',
      staffSurname: (json['teacher_name']?.toString().split(' ').length ?? 0) > 1 ? json['teacher_name'].toString().split(' ')[1] : json['staff_surname']?.toString() ?? '',
      staffEmployeeId: (json['teacher_name']?.toString().split('(').length ?? 0) > 1 ? json['teacher_name'].toString().split('(')[1].replaceAll(')', '') : json['staff_employee_id']?.toString() ?? '',
      roleName: json['role_name']?.toString() ?? 'Teacher',
      roleId: json['role_id']?.toString() ?? '',
      commentCount: int.tryParse(json['comment_count']?.toString() ?? '0') ?? 0,
    );
  }

  String get formattedDate {
    try {
      final parsedDate = DateTime.parse(createdAt);
      return '${parsedDate.day.toString().padLeft(2, '0')}/${parsedDate.month.toString().padLeft(2, '0')}/${parsedDate.year}';
    } catch (e) {
      return createdAt;
    }
  }

  String get assignedBy {
    return '$staffName $staffSurname ($staffEmployeeId)';
  }

  bool get isPositive {
    return !point.startsWith('-');
  }

  int get pointValue {
    return int.tryParse(point) ?? 0;
  }
}

class BehaviourComment {
  final String id;
  final String comment;
  final String type;
  final String createdDate;
  final String staffName;
  final String staffSurname;
  final String staffEmployeeId;
  final String? staffImage;
  final String gender;
  final String firstname;
  final String middlename;
  final String lastname;
  final String admissionNo;
  final String? studentImage;
  final String staffId;
  final String studentId;
  final String roleName;
  final String? studGender;
  final String studentIncidentCommentId;
  final String incidentCommentId;

  BehaviourComment({
    required this.id,
    required this.comment,
    required this.type,
    required this.createdDate,
    required this.staffName,
    required this.staffSurname,
    required this.staffEmployeeId,
    this.staffImage,
    required this.gender,
    required this.firstname,
    required this.middlename,
    required this.lastname,
    required this.admissionNo,
    this.studentImage,
    required this.staffId,
    required this.studentId,
    required this.roleName,
    this.studGender,
    required this.studentIncidentCommentId,
    required this.incidentCommentId,
  });

  factory BehaviourComment.fromJson(Map<String, dynamic> json) {
    return BehaviourComment(
      id: json['id']?.toString() ?? '',
      comment: json['comment']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      createdDate: json['created_date']?.toString() ?? '',
      staffName: json['staff_name']?.toString() ?? '',
      staffSurname: json['staff_surname']?.toString() ?? '',
      staffEmployeeId: json['staff_employee_id']?.toString() ?? '',
      staffImage: _extractFirstNonEmpty(json, ['staff_image', 'image', 'staff_photo', 'photo', 'teacher_image']),
      gender: json['gender']?.toString() ?? '',
      firstname: json['firstname']?.toString() ?? '',
      middlename: json['middlename']?.toString() ?? '',
      lastname: json['lastname']?.toString() ?? '',
      admissionNo: json['admission_no']?.toString() ?? '',
      studentImage: _extractFirstNonEmpty(json, ['student_image', 'image', 'student_photo', 'photo']),
      staffId: json['staff_id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      roleName: json['role_name']?.toString() ?? '',
      studGender: json['stud_gender']?.toString(),
      studentIncidentCommentId: _extractFirstNonEmpty(
        json,
        [
          'student_incident_comment_id',
          'student_comment_id',
          'studentIncidentCommentId',
          'studentCommentId',
          'studentincidentcommentid',
        ],
      ),
      incidentCommentId: _extractFirstNonEmpty(
        json,
        [
          'incident_comment_id',
          'incidentCommentId',
          'incidentcommentid',
          'comment_id',
          'id',
        ],
      ),
    );
  }

  String get formattedDate {
    try {
      final parsedDate = DateTime.parse(createdDate);
      return '${parsedDate.day.toString().padLeft(2, '0')}/${parsedDate.month.toString().padLeft(2, '0')}/${parsedDate.year} ${parsedDate.hour.toString().padLeft(2, '0')}:${parsedDate.minute.toString().padLeft(2, '0')} ${parsedDate.hour >= 12 ? 'PM' : 'AM'}';
    } catch (e) {
      return createdDate;
    }
  }

  String get commenterName {
    if (type == 'staff') {
      return '$staffName $staffSurname';
    } else {
      return '$firstname $lastname';
    }
  }

  String get commenterId {
    if (type == 'staff') {
      return staffEmployeeId;
    } else {
      return admissionNo;
    }
  }

  String get commenterRole {
    if (type == 'staff') {
      return roleName;
    } else {
      return 'Student';
    }
  }

  String get deleteCommentId {
    if (studentIncidentCommentId.isNotEmpty) {
      return studentIncidentCommentId;
    }
    if (incidentCommentId.isNotEmpty) {
      return incidentCommentId;
    }
    return id;
  }
}

String _extractFirstNonEmpty(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    if (!json.containsKey(key)) continue;
    final value = json[key];
    if (value == null) continue;
    final normalized = value.toString().trim();
    if (normalized.isNotEmpty && normalized.toLowerCase() != 'null') {
      return normalized;
    }
  }
  return '';
}

class GmeetClass {
  final String id;
  final String className;
  final String subject;
  final String topic;
  final String teacherName;
  final String teacherId;
  final String meetingCode;
  final String password;
  final String startTime;
  final String endTime;
  final String status;
  final String joinUrl;
  final String classCode;
  final int maxParticipants;
  final int classDuration;
  final String dateTime;
  final String description;

  GmeetClass({
    required this.id,
    required this.className,
    required this.subject,
    required this.topic,
    required this.teacherName,
    required this.teacherId,
    required this.meetingCode,
    required this.password,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.joinUrl,
    required this.classCode,
    required this.maxParticipants,
    required this.classDuration,
    required this.dateTime,
    required this.description,
  });

  factory GmeetClass.fromJson(Map<String, dynamic> json) {
    return GmeetClass(
      id: json['id']?.toString() ?? '',
      className: json['title'] ?? json['class_name'] ?? json['name'] ?? '',
      subject: json['subject'] ?? '',
      topic: json['topic'] ?? '',
      teacherName: '${json['staff_name'] ?? ''} ${json['staff_surname'] ?? ''}',
      teacherId: json['staff_id']?.toString() ?? '',
      meetingCode: json['meeting_code'] ?? '',
      password: json['password'] ?? '',
      startTime: json['start_time'] ?? '',
      endTime: json['end_time'] ?? '',
      status: json['status'] == '0' ? 'Live' : 'Completed',
      joinUrl: json['url'] ?? json['join_url'] ?? '',
      classCode: '${json['class'] ?? ''} ${json['section'] ?? ''}',
      maxParticipants:
          int.tryParse(json['max_participants']?.toString() ?? '0') ?? 0,
      classDuration: int.tryParse(json['duration']?.toString() ?? '0') ?? 0,
      dateTime: json['date'] ?? json['date_time'] ?? '',
      description: json['description'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'class_name': className,
      'subject': subject,
      'topic': topic,
      'teacher_name': teacherName,
      'teacher_id': teacherId,
      'meeting_code': meetingCode,
      'password': password,
      'start_time': startTime,
      'end_time': endTime,
      'status': status,
      'join_url': joinUrl,
      'class_code': classCode,
      'max_participants': maxParticipants,
      'class_duration': classDuration,
      'date_time': dateTime,
      'description': description,
    };
  }
}

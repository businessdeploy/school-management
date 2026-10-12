class Timeline {
  final String id;
  final String studentId;
  final String title;
  final String timelineDate;
  final String description;
  final String document;
  final String status;
  final String createdStudentId;
  final String date;
  final String createdAt;
  final String updatedAt;

  Timeline({
    required this.id,
    required this.studentId,
    required this.title,
    required this.timelineDate,
    required this.description,
    required this.document,
    required this.status,
    required this.createdStudentId,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Timeline.fromJson(Map<String, dynamic> json) {
    return Timeline(
      id: json['id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      timelineDate: json['timeline_date']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      document: json['document']?.toString() ?? json['timeline_doc']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      createdStudentId: json['created_student_id']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'title': title,
      'timeline_date': timelineDate,
      'description': description,
      'document': document,
      'status': status,
      'created_student_id': createdStudentId,
      'date': date,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  String get formattedDate {
    try {
      // Format as MM/DD/YYYY for iOS app (as per user requirement)
      final date = DateTime.parse(timelineDate);
      return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      // If parsing fails, try to handle common date formats
      final trimmed = timelineDate.trim();
      
      // Handle DD/MM/YYYY format and convert to MM/DD/YYYY
      if (trimmed.contains('/')) {
        final parts = trimmed.split('/');
        if (parts.length == 3) {
          try {
            final day = int.parse(parts[0]);
            final month = int.parse(parts[1]);
            final year = int.parse(parts[2]);
            return '${month.toString().padLeft(2, '0')}/${day.toString().padLeft(2, '0')}/$year';
          } catch (_) {
            // If conversion fails, return as-is
          }
        }
      }
      
      // Handle YYYY-MM-DD format
      if (trimmed.contains('-')) {
        final parts = trimmed.split('-');
        if (parts.length == 3) {
          try {
            final year = int.parse(parts[0]);
            final month = int.parse(parts[1]);
            final day = int.parse(parts[2]);
            return '${month.toString().padLeft(2, '0')}/${day.toString().padLeft(2, '0')}/$year';
          } catch (_) {
            // If conversion fails, return as-is
          }
        }
      }
      
      return timelineDate;
    }
  }
}

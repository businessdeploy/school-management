class Document {
  final String id;
  final String studentId;
  final String title;
  final String doc;
  final String createdAt;
  final String updatedAt;

  Document({
    required this.id,
    required this.studentId,
    required this.title,
    required this.doc,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      id: json['id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      doc: json['doc']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'title': title,
      'doc': doc,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

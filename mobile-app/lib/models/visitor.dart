class Visitor {
  final String id;
  final String? staffId;
  final String studentSessionId;
  final String? source;
  final String purpose;
  final String name;
  final String? email;
  final String contact;
  final String idProof;
  final String noOfPeople;
  final String date;
  final String inTime;
  final String outTime;
  final String note;
  final String image;
  final String meetingWith;
  final String createdAt;
  final String updatedAt;

  Visitor({
    required this.id,
    this.staffId,
    required this.studentSessionId,
    this.source,
    required this.purpose,
    required this.name,
    this.email,
    required this.contact,
    required this.idProof,
    required this.noOfPeople,
    required this.date,
    required this.inTime,
    required this.outTime,
    required this.note,
    required this.image,
    required this.meetingWith,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Visitor.fromJson(Map<String, dynamic> json) {
    return Visitor(
      id: json['id']?.toString() ?? '',
      staffId: json['staff_id']?.toString(),
      studentSessionId: json['student_session_id']?.toString() ?? '',
      source: json['source']?.toString(),
      purpose: json['purpose']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString(),
      contact: json['contact']?.toString() ?? '',
      idProof: json['id_proof']?.toString() ?? '',
      noOfPeople: json['no_of_people']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      inTime: json['in_time']?.toString() ?? '',
      outTime: json['out_time']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      image: json['image']?.toString() ?? '',
      meetingWith: json['meeting_with']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'staff_id': staffId,
      'student_session_id': studentSessionId,
      'source': source,
      'purpose': purpose,
      'name': name,
      'email': email,
      'contact': contact,
      'id_proof': idProof,
      'no_of_people': noOfPeople,
      'date': date,
      'in_time': inTime,
      'out_time': outTime,
      'note': note,
      'image': image,
      'meeting_with': meetingWith,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

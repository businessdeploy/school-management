class ParentChild {
  final String studentId;
  final String className;
  final String section;
  final String classId;
  final String sectionId;
  final String name;
  final String? image;
  final String studentSessionId;
  final String admissionNo;

  ParentChild({
    required this.studentId,
    required this.className,
    required this.section,
    required this.classId,
    required this.sectionId,
    required this.name,
    this.image,
    required this.studentSessionId,
    required this.admissionNo,
  });

  factory ParentChild.fromJson(Map<String, dynamic> json) {
    return ParentChild(
      studentId: json['student_id']?.toString() ?? '',
      className: json['class']?.toString() ?? '',
      section: json['section']?.toString() ?? '',
      classId: json['class_id']?.toString() ?? '',
      sectionId: json['section_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      image: json['image'],
      studentSessionId: json['student_session_id']?.toString() ?? '',
      admissionNo: json['admission_no']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'student_id': studentId,
      'class': className,
      'section': section,
      'class_id': classId,
      'section_id': sectionId,
      'name': name,
      'image': image,
      'student_session_id': studentSessionId,
      'admission_no': admissionNo,
    };
  }
}

class Student {
  final String id;
  final String parentId;
  final String admissionNo;
  final String rollNo;
  final String admissionDate;
  final String firstname;
  final String? middlename;
  final String lastname;
  final String rte;
  final String? image;
  final String mobileno;
  final String email;
  final String? state;
  final String? city;
  final String? pincode;
  final String religion;
  final String cast;
  final String dob;
  final String gender;
  final String currentAddress;
  final String permanentAddress;
  final String categoryId;
  final String schoolHouseId;
  final String bloodGroup;
  final String hostelRoomId;
  final String adharNo;
  final String samagraId;
  final String bankAccountNo;
  final String bankName;
  final String ifscCode;
  final String guardianIs;
  final String fatherName;
  final String fatherPhone;
  final String fatherOccupation;
  final String motherName;
  final String motherPhone;
  final String motherOccupation;
  final String guardianName;
  final String guardianRelation;
  final String guardianPhone;
  final String guardianOccupation;
  final String guardianAddress;
  final String guardianEmail;
  final String fatherPic;
  final String motherPic;
  final String guardianPic;
  final String isActive;
  final String previousSchool;
  final String height;
  final String weight;
  final String measurementDate;
  final String disReason;
  final String note;
  final String disNote;
  final String? about;
  final String? designation;
  final String? appKey;
  final String parentAppKey;
  final String createdBy;
  final String? disableAt;
  final String createdAt;
  final String updatedAt;
  final String classId;
  final String className;
  final String sectionId;
  final String section;
  final String studentSessionId;
  final List<ParentChild>? parentChilds;

  Student({
    required this.id,
    required this.parentId,
    required this.admissionNo,
    required this.rollNo,
    required this.admissionDate,
    required this.firstname,
    this.middlename,
    required this.lastname,
    required this.rte,
    this.image,
    required this.mobileno,
    required this.email,
    this.state,
    this.city,
    this.pincode,
    required this.religion,
    required this.cast,
    required this.dob,
    required this.gender,
    required this.currentAddress,
    required this.permanentAddress,
    required this.categoryId,
    required this.schoolHouseId,
    required this.bloodGroup,
    required this.hostelRoomId,
    required this.adharNo,
    required this.samagraId,
    required this.bankAccountNo,
    required this.bankName,
    required this.ifscCode,
    required this.guardianIs,
    required this.fatherName,
    required this.fatherPhone,
    required this.fatherOccupation,
    required this.motherName,
    required this.motherPhone,
    required this.motherOccupation,
    required this.guardianName,
    required this.guardianRelation,
    required this.guardianPhone,
    required this.guardianOccupation,
    required this.guardianAddress,
    required this.guardianEmail,
    required this.fatherPic,
    required this.motherPic,
    required this.guardianPic,
    required this.isActive,
    required this.previousSchool,
    required this.height,
    required this.weight,
    required this.measurementDate,
    required this.disReason,
    required this.note,
    required this.disNote,
    this.about,
    this.designation,
    this.appKey,
    required this.parentAppKey,
    required this.createdBy,
    this.disableAt,
    required this.createdAt,
    required this.updatedAt,
    required this.classId,
    required this.className,
    required this.sectionId,
    required this.section,
    required this.studentSessionId,
    this.parentChilds,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    List<ParentChild>? children;
    if (json['parent_childs'] != null) {
      children = (json['parent_childs'] as List)
          .map((c) => ParentChild.fromJson(c))
          .toList();
    }

    return Student(
      id: (json['id'] ?? json['student_id'])?.toString() ?? '',
      parentId: json['parent_id']?.toString() ?? '',
      admissionNo: json['admission_no']?.toString() ?? '',
      rollNo: json['roll_no']?.toString() ?? '',
      admissionDate: json['admission_date']?.toString() ?? '',
      firstname: (json['firstname'] ?? json['name'])?.toString() ?? '',
      middlename: json['middlename'],
      lastname: json['lastname']?.toString() ?? '',
      rte: json['rte']?.toString() ?? '',
      image: json['image'],
      mobileno: json['mobileno']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      state: json['state'],
      city: json['city'],
      pincode: json['pincode'],
      religion: json['religion']?.toString() ?? '',
      cast: json['cast']?.toString() ?? '',
      dob: json['dob']?.toString() ?? '',
      gender: json['gender']?.toString() ?? '',
      currentAddress: json['current_address']?.toString() ?? '',
      permanentAddress: json['permanent_address']?.toString() ?? '',
      categoryId: json['category_id']?.toString() ?? '',
      schoolHouseId: json['school_house_id']?.toString() ?? '',
      bloodGroup: json['blood_group']?.toString() ?? '',
      hostelRoomId: json['hostel_room_id']?.toString() ?? '',
      adharNo: json['adhar_no']?.toString() ?? '',
      samagraId: json['samagra_id']?.toString() ?? '',
      bankAccountNo: json['bank_account_no']?.toString() ?? '',
      bankName: json['bank_name']?.toString() ?? '',
      ifscCode: json['ifsc_code']?.toString() ?? '',
      guardianIs: json['guardian_is']?.toString() ?? '',
      fatherName: json['father_name']?.toString() ?? '',
      fatherPhone: json['father_phone']?.toString() ?? '',
      fatherOccupation: json['father_occupation']?.toString() ?? '',
      motherName: json['mother_name']?.toString() ?? '',
      motherPhone: json['mother_phone']?.toString() ?? '',
      motherOccupation: json['mother_occupation']?.toString() ?? '',
      guardianName: json['guardian_name']?.toString() ?? '',
      guardianRelation: json['guardian_relation']?.toString() ?? '',
      guardianPhone: json['guardian_phone']?.toString() ?? '',
      guardianOccupation: json['guardian_occupation']?.toString() ?? '',
      guardianAddress: json['guardian_address']?.toString() ?? '',
      guardianEmail: json['guardian_email']?.toString() ?? '',
      fatherPic: json['father_pic']?.toString() ?? '',
      motherPic: json['mother_pic']?.toString() ?? '',
      guardianPic: json['guardian_pic']?.toString() ?? '',
      isActive: json['is_active']?.toString() ?? '',
      previousSchool: json['previous_school']?.toString() ?? '',
      height: json['height']?.toString() ?? '',
      weight: json['weight']?.toString() ?? '',
      measurementDate: json['measurement_date']?.toString() ?? '',
      disReason: json['dis_reason']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      disNote: json['dis_note']?.toString() ?? '',
      about: json['about'],
      designation: json['designation'],
      appKey: json['app_key'],
      parentAppKey: json['parent_app_key']?.toString() ?? '',
      createdBy: json['created_by']?.toString() ?? '',
      disableAt: json['disable_at'],
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
      classId: json['class_id']?.toString() ?? '',
      className: json['class']?.toString() ?? '',
      sectionId: json['section_id']?.toString() ?? '',
      section: json['section']?.toString() ?? '',
      studentSessionId: json['student_session_id']?.toString() ?? '',
      parentChilds: children,
    );
  }

  String get fullName => '$firstname $lastname'.trim();
  String get classSection => '$className ($section)';
}

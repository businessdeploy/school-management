import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api/teacher_api.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/translated_text.dart';

class TeacherReviewPage extends StatefulWidget {
  const TeacherReviewPage({super.key});

  @override
  State<TeacherReviewPage> createState() => _TeacherReviewPageState();
}

class _TeacherReviewPageState extends State<TeacherReviewPage> {
  List<Map<String, dynamic>> teachers = [];
  bool isLoading = true;
  String? error;
  bool showAddRatingModal = false;
  bool showSubjectDetailsModal = false;
  Map<String, dynamic>? selectedTeacher;

  // Form controllers
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _commentsController = TextEditingController();
  int selectedRating = 0;

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  @override
  void dispose() {
    _commentsController.dispose();
    super.dispose();
  }

  Future<void> _loadTeachers() async {

    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final studentId = await AuthService.getStudentId();
      

      final teachersData = await TeacherApi.getTeachersForReview(studentId);
      
      
      
      
      

      if (!mounted) return;

      final List<dynamic> rawTeachers =
          teachersData['teachers'] as List<dynamic>? ?? <dynamic>[];
      final List<Map<String, dynamic>> teachersList = rawTeachers
          .map<Map<String, dynamic>>(
            (item) => Map<String, dynamic>.from(item as Map<String, dynamic>),
          )
          .toList();

      
      if (teachersList.isNotEmpty) {
        
        // Log all keys to help identify comment field
        
      }

      // Deduplicate teachers and merge subjects if they are provided in-line
      final Map<String, Map<String, dynamic>> dedupedMap = {};
      for (var teacher in teachersList) {
        final id = teacher['staff_id']?.toString() ?? 
                   teacher['employee_id']?.toString() ?? 
                   teacher['id']?.toString() ?? 
                   'unknown';
        
        if (dedupedMap.containsKey(id)) {
          // If we find the same teacher again, merge their subjects if they exist
          final existing = dedupedMap[id]!;
          
          // Helper to merge lists
          void mergeLists(String key) {
            final List<dynamic> oldList = existing[key] is List ? List.from(existing[key] as List) : [];
            final List<dynamic> newList = teacher[key] is List ? teacher[key] as List : [];
            for (var item in newList) {
              if (!oldList.contains(item)) {
                oldList.add(item);
              }
            }
            if (oldList.isNotEmpty) {
              existing[key] = oldList;
            }
          }

          mergeLists('subjects');
          mergeLists('subject_list');
          mergeLists('timetable');
          
          // If the new entry has a subject description but the old one doesn't, or if we want to combine them
          final String oldSub = existing['subject']?.toString() ?? '';
          final String newSub = teacher['subject']?.toString() ?? '';
          if (newSub.isNotEmpty && !oldSub.contains(newSub)) {
            existing['subject'] = oldSub.isEmpty ? newSub : '$oldSub, $newSub';
          }
        } else {
          dedupedMap[id] = teacher;
        }
      }

      final List<Map<String, dynamic>> finalTeachersList = dedupedMap.values.toList();

      setState(() {
        teachers = finalTeachersList;
        isLoading = false;
        if (finalTeachersList.isEmpty && teachersData['status'] != 1) {
          error = teachersData['message'] ?? 'No teachers found';
        }
      });

      
    } catch (e) {
      
      if (!mounted) return;
      setState(() {
        isLoading = false;
        error = e.toString();
      });
    }
  }

  void _showAddRatingModal(Map<String, dynamic> teacher) {
    setState(() {
      showAddRatingModal = true;
      selectedTeacher = teacher;
      _commentsController.clear();
      selectedRating = 0;
    });
  }

  void _showSubjectDetailsModal(Map<String, dynamic> teacher) {
    setState(() {
      showSubjectDetailsModal = true;
      selectedTeacher = teacher;
    });
  }

  void _hideModals() {
    setState(() {
      showAddRatingModal = false;
      showSubjectDetailsModal = false;
      selectedTeacher = null;
    });
  }

  Future<void> _submitRating() async {
    final bool isFormValid = _formKey.currentState?.validate() ?? false;
    
    if (selectedRating == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(
        content: TranslatedText('Please select a rating'),
        backgroundColor: Colors.orange,
      ));
      if (!isFormValid) return; // Still show form errors
      return;
    }

    if (!isFormValid) {
      return;
    }

    if (selectedTeacher == null) return;

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final userId = await AuthService.getUserId();
      if (userId == null || userId.isEmpty) {
        throw Exception('No user ID found. Please login again.');
      }

      final staffId =
          selectedTeacher!['employee_no']?.toString() ??
          selectedTeacher!['staff_no']?.toString() ??
          selectedTeacher!['employee_id']?.toString() ??
          selectedTeacher!['staff_id']?.toString() ??
          selectedTeacher!['id']?.toString() ??
          selectedTeacher!['teacher_id']?.toString() ??
          '';

      if (staffId.isEmpty) {
        throw Exception('No staff ID found for this teacher');
      }

      // API requires role to be "student" as per specification
      const role = 'student';

      
      
      
      
      
      

      final result = await TeacherApi.addStaffRating(
        selectedRating.toString(),
        _commentsController.text,
        role,
        staffId,
        userId,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (result['status'] == 1 || result['status'] == '1') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: TranslatedText('Rating submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _hideModals();
        // Reload teachers to show updated rating
        await _loadTeachers();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: TranslatedText(result['message'] ?? 'Failed to submit rating'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog if still open
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: TranslatedText('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const TranslatedText(
          'Teachers Reviews',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.grey[800],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Header section
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.blueGrey[50], // Professional slate-grey background
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      // Text Section
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TranslatedText(
                              'Your Teachers Reviews is here!',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            TranslatedText(
                              'Share your feedback and rate your teachers\' performance.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Teacher illustration
                      SizedBox(
                        width: 100,
                        height: 80,
                        child: Image.asset(
                          "assets/images/teacher review.png",
                          width: 100,
                          height: 80,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildTeacherIllustration();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Content section
              Expanded(
                child: Container(
                  color: Colors.grey[100],
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              TranslatedText(
                                'Error loading teachers: $error',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadTeachers,
                                child: const TranslatedText('Retry'),
                              ),
                            ],
                          ),
                        )
                      : teachers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              const TranslatedText(
                                'No teachers available',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        )
                      : _buildTeachersList(),
                ),
              ),
            ],
          ),
          // Modals
          if (showAddRatingModal) _buildAddRatingModal(),
          if (showSubjectDetailsModal) _buildSubjectDetailsModal(),
        ],
      ),
    );
  }

  Widget _buildTeacherIllustration() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          // Teacher figure
          Positioned(
            bottom: 10,
            right: 10,
            child: Container(
              width: 40,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.orange[300],
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          // Whiteboard
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              width: 60,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey[400]!, width: 2),
              ),
              child: Stack(
                children: [
                  // Chart/Graph
                  Positioned(
                    top: 5,
                    left: 5,
                    child: Container(
                      width: 20,
                      height: 15,
                      decoration: BoxDecoration(
                        color: Colors.blue[200],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Triangle
                  Positioned(
                    top: 8,
                    left: 30,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.green[400],
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                  // Formula
                  Positioned(
                    bottom: 5,
                    left: 5,
                    child: Container(
                      width: 15,
                      height: 2,
                      decoration: BoxDecoration(
                        color: Colors.grey[600],
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Books
          Positioned(
            bottom: 5,
            left: 5,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.red[300],
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(height: 1),
                Container(
                  width: 12,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.orange[300],
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(height: 1),
                Container(
                  width: 12,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.blue[300],
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeachersList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: teachers.length,
      itemBuilder: (context, index) {
        final teacher = teachers[index];
        return _buildTeacherCard(teacher);
      },
    );
  }

  Widget _buildTeacherCard(Map<String, dynamic> teacher) {
    // API returns 'rate' as string or number, 'comment' as string
    final rateValue = teacher['rate'];
    bool hasRating = false;
    int rating = 0;

    if (rateValue != null && rateValue != '' && rateValue != '0') {
      if (rateValue is num) {
        rating = rateValue.toInt();
        hasRating = rating > 0;
      } else {
        final parsed = int.tryParse(rateValue.toString());
        if (parsed != null) {
          rating = parsed;
          hasRating = rating > 0;
        }
      }
    }

    // Get teacher name from API response (staff_name, staff_surname)
    final teacherName =
        '${teacher['staff_name'] ?? ''} ${teacher['staff_surname'] ?? ''}'
            .trim();
    
    // Try to find the visible staff ID/Employee ID first
    // Do not fall back to internal IDs (id, staff_id) as they are not user-friendly
    final teacherId =
        teacher['employee_no']?.toString() ??
        teacher['staff_no']?.toString() ??
        teacher['employee_code']?.toString() ??
        teacher['employee_id']?.toString() ??
        '';
        
    final phone =
        teacher['contact_no']?.toString() ?? teacher['phone']?.toString() ?? '';
    final email = teacher['email']?.toString() ?? '';
    
    // extensive check for comment keys
    final comment =
        teacher['comment']?.toString() ?? 
        teacher['comments']?.toString() ?? 
        teacher['review']?.toString() ??
        teacher['remarks']?.toString() ??
        teacher['description']?.toString() ??
        '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with teacher info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                // Teacher icon / Image
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: Builder(
                      builder: (context) {
                        final imageUrl = teacher['image']?.toString() ?? 
                                       teacher['staff_image']?.toString() ?? 
                                       teacher['photo']?.toString() ?? '';
                                       
                        if (imageUrl.isNotEmpty && !imageUrl.contains('no_image')) {
                          return FutureBuilder<String>(
                            future: ApiService.getImageUrl(imageUrl),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                return CachedNetworkImage(
                                  imageUrl: snapshot.data!,
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const Center(
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  errorWidget: (context, url, error) => 
                                    Icon(Icons.person, color: Colors.blue[400], size: 28),
                                );
                              }
                              return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                            },
                          );
                        }
                        return Icon(Icons.person, color: Colors.blue[400], size: 28);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Teacher name and ID
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: TranslatedText(
                                teacherName.isNotEmpty ? teacherName : 'Teacher Name',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (teacherId.isNotEmpty && teacherId != '0')
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: Text(
                                  '($teacherId)',
                                  style: TextStyle(
                                    fontSize: 13, 
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      // Add Subject/Department Display
                       Builder(
                        builder: (context) {
                          final subject = _extractSubjectField(teacher, ['subject', 'subject_name', 'subjectName', 'department', 'designation', 'role']);
                          if (subject.isNotEmpty) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 2.0),
                              child: Text(
                                subject,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.blueGrey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        }, 
                      ),
                    ],
                  ),
                ),
                // Class Teacher badge - Only show if it's actually a class teacher
                Builder(
                  builder: (context) {
                    final classTeacherValue = 
                        teacher['class_teacher']?.toString().toLowerCase() ?? 
                        teacher['is_class_teacher']?.toString().toLowerCase() ?? 
                        '';
                    
                    final designation = teacher['designation']?.toString().toLowerCase() ?? '';
                    
                    final bool isClassTeacher = 
                        classTeacherValue == 'yes' || 
                        classTeacherValue == '1' || 
                        classTeacherValue == 'true' ||
                        designation.contains('class teacher');
                    
                    if (isClassTeacher) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green[600],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const TranslatedText(
                          'Class Teacher',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
          // Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Phone and email
                Row(
                  children: [
                    Icon(Icons.phone, color: Colors.grey[600], size: 16),
                    const SizedBox(width: 8),
                    TranslatedText(
                      phone.isNotEmpty ? phone : 'Phone Number',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const Spacer(),
                    if (!hasRating)
                      GestureDetector(
                        onTap: () => _showAddRatingModal(teacher),
                        child: Row(
                          children: [
                            Icon(Icons.list, color: Colors.blue[600], size: 16),
                            const SizedBox(width: 4),
                            const TranslatedText(
                              'Add Rating',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.email, color: Colors.grey[600], size: 16),
                    const SizedBox(width: 8),
                    TranslatedText(
                      email.isNotEmpty ? email : 'Email Address',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const Spacer(),
                    if (hasRating)
                      Row(
                        children: List.generate(5, (index) {
                          return Icon(
                            index < rating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 16,
                          );
                        }),
                      ),
                  ],
                ),
                if (hasRating) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const TranslatedText(
                        'Comments',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TranslatedText(
                          comment.isNotEmpty ? comment : 'No comments',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                // View option - always visible
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () => _showSubjectDetailsModal(teacher),
                      child: Row(
                        children: [
                          const TranslatedText(
                            'View',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward,
                            color: Colors.blue[600],
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddRatingModal() {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.list, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Add Rating',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _hideModals,
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              // Form
              Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const Text(
                        'Add Rating',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Star rating
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedRating = index + 1;
                              });
                            },
                            child: Icon(
                              index < selectedRating
                                  ? Icons.star
                                  : Icons.star_border,
                              color: Colors.amber,
                              size: 32,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 16),
                      // Comments field
                      TextFormField(
                        controller: _commentsController,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: InputDecoration(
                          labelText: 'Comments *',
                          hintText: 'Enter your feedback here',
                          border: const OutlineInputBorder(),
                          errorStyle: const TextStyle(color: Colors.red),
                          labelStyle: TextStyle(color: Colors.grey[700]),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Comments are required';
                          }
                          if (value.trim().length < 3) {
                            return 'Comment is too short';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                             if (_formKey.currentState != null && _formKey.currentState!.validate()) {
                               _submitRating();
                             }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[800],
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'SUBMIT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectDetailsModal() {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.95,
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.list, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Subject Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _hideModals,
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildSubjectRow('Time', 'Day', 'Subject', 'Room'),
                        const SizedBox(height: 8),
                        // Use actual subject data from API if available
                        if (selectedTeacher != null && _hasSubjectData(selectedTeacher!))
                          ..._buildSubjectRowsFromData(selectedTeacher!)
                        else
                          _buildNoSubjectDataMessage(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Check if teacher has subject data
  bool _hasSubjectData(Map<String, dynamic> teacher) {
    // Check for various possible keys that might contain subject information
    final subjectKeys = [
      'subjects',
      'subject_list',
      'subject_details',
      'timetable',
      'schedule',
      'classes',
    ];
    
    for (final key in subjectKeys) {
      if (teacher[key] != null) {
        if (teacher[key] is List && (teacher[key] as List).isNotEmpty) {
          return true;
        }
        if (teacher[key] is Map && (teacher[key] as Map).isNotEmpty) {
          return true;
        }
      }
    }
    
    // Check for subject name field
    if (teacher['subject'] != null || 
        teacher['subject_name'] != null || 
        teacher['subjectName'] != null) {
      return true;
    }
    
    return false;
  }

  // Build subject rows from actual API data
  List<Widget> _buildSubjectRowsFromData(Map<String, dynamic> teacher) {
    List<Widget> rows = [];
    
    // Try to extract subject data from various possible structures
    List<dynamic>? subjectsList;
    
    // Check if subjects is a list
    if (teacher['subjects'] != null && teacher['subjects'] is List) {
      subjectsList = teacher['subjects'] as List;
    } else if (teacher['subject_list'] != null && teacher['subject_list'] is List) {
      subjectsList = teacher['subject_list'] as List;
    } else if (teacher['timetable'] != null && teacher['timetable'] is List) {
      subjectsList = teacher['timetable'] as List;
    } else if (teacher['schedule'] != null && teacher['schedule'] is List) {
      subjectsList = teacher['schedule'] as List;
    }
    
    if (subjectsList != null && subjectsList.isNotEmpty) {
      for (final subject in subjectsList) {
        if (subject is Map) {
          final subjectMap = Map<String, dynamic>.from(subject);
          final time = _extractSubjectField(subjectMap, ['time', 'time_from', 'time_to', 'start_time', 'end_time', 'duration']);
          final day = _extractSubjectField(subjectMap, ['day', 'day_name', 'weekday']);
          final subjectName = _extractSubjectField(subjectMap, ['subject', 'subject_name', 'subjectName', 'name', 'title']);
          final room = _extractSubjectField(subjectMap, ['room', 'room_no', 'room_number', 'roomNumber', 'class_room']);
          
          if (subjectName.isNotEmpty) {
            rows.add(_buildSubjectRow(
              time.isNotEmpty ? time : 'N/A',
              day.isNotEmpty ? day : 'N/A',
              subjectName,
              room.isNotEmpty ? room : 'N/A',
            ));
            rows.add(const SizedBox(height: 4));
          }
        }
      }
    } else {
      // If no list, try to get single subject information
      final subjectName = _extractSubjectField(teacher, ['subject', 'subject_name', 'subjectName', 'name']);
      if (subjectName.isNotEmpty) {
        rows.add(_buildSubjectRow(
          'N/A',
          'N/A',
          subjectName,
          _extractSubjectField(teacher, ['room', 'room_no', 'room_number']),
        ));
      }
    }
    
    return rows.isEmpty ? [_buildNoSubjectDataMessage()] : rows;
  }

  // Extract field value from map using multiple possible keys
  String _extractSubjectField(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value != null) {
        final str = value.toString().trim();
        if (str.isNotEmpty && str.toLowerCase() != 'null') {
          return str;
        }
      }
    }
    return '';
  }

  Widget _buildNoSubjectDataMessage() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Text(
        'Subject details not available',
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[600],
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildSubjectRow(
    String time,
    String day,
    String subject,
    String room,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              time,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              day,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              subject,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              room,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

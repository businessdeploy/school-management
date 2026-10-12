import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../models/daily_assignment.dart';
import '../services/api_service.dart';
import 'package:provider/provider.dart';
import '../providers/app_config_provider.dart';
import '../services/auth_service.dart';
import '../services/api/homework_api.dart';
import '../services/api/lesson_api.dart';
import '../config/app_config.dart';
import '../widgets/translated_text.dart';

class AddEditDailyAssignmentPage extends StatefulWidget {
  final DailyAssignment? assignment;

  const AddEditDailyAssignmentPage({super.key, this.assignment});

  @override
  State<AddEditDailyAssignmentPage> createState() =>
      _AddEditDailyAssignmentPageState();
}

class _AddEditDailyAssignmentPageState
    extends State<AddEditDailyAssignmentPage> {
  static final Map<String, List<Map<String, dynamic>>> _subjectsCache = {};
  static final Map<String, DateTime> _subjectsCacheUpdatedAt = {};
  static const Duration _subjectsCacheTTL = Duration(minutes: 10);

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dueDateController = TextEditingController();

  String? _selectedSubject;
  String? _selectedFile;
  bool _isLoading = false;
  bool _isLoadingSubjects = true;
  List<Map<String, dynamic>> _subjects = [];
  String? _subjectsError;
  Color? _secondaryColor;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
    _loadSecondaryColor();
    if (widget.assignment != null) {
      _titleController.text = widget.assignment!.title;
      _descriptionController.text = widget.assignment!.description;
    }
  }

  Future<void> _loadSecondaryColor() async {
    try {
      final colorString = await AppConfig.getSecondaryColor();
      

      if (colorString.isNotEmpty && colorString.trim().isNotEmpty) {
        final parsedColor = _parseColor(colorString);
        
        if (mounted) {
          setState(() {
            _secondaryColor = parsedColor;
          });
        }
      } else {
        
        if (mounted) {
          setState(() {
            _secondaryColor = Colors.teal[400];
          });
        }
      }
    } catch (e) {
      
      if (mounted) {
        setState(() {
          _secondaryColor = Colors.teal[400];
        });
      }
    }
  }

  Color _parseColor(String colorString) {
    try {
      // Remove any whitespace
      String cleaned = colorString.trim();

      // Handle hex colors with or without #
      if (cleaned.startsWith('#')) {
        cleaned = cleaned.substring(1);
      }

      // Handle 6-digit hex (RRGGBB)
      if (cleaned.length == 6) {
        return Color(int.parse('FF$cleaned', radix: 16));
      }

      // Handle 8-digit hex (AARRGGBB)
      if (cleaned.length == 8) {
        return Color(int.parse(cleaned, radix: 16));
      }

      // Handle 3-digit hex (RGB)
      if (cleaned.length == 3) {
        final r = cleaned[0];
        final g = cleaned[1];
        final b = cleaned[2];
        return Color(int.parse('FF$r$r$g$g$b$b', radix: 16));
      }

      // Try parsing as integer
      final intValue = int.tryParse(cleaned);
      if (intValue != null) {
        return Color(intValue);
      }

      // Fallback to teal if parsing fails
      
      return Colors.teal[400]!;
    } catch (e) {
      
      return Colors.teal[400]!;
    }
  }

  Future<void> _loadSubjects() async {
    try {
      setState(() {
        _isLoadingSubjects = true;
        _subjectsError = null;
      });

      final studentId = await AuthService.getStudentId();
      if (studentId.isEmpty) {
        setState(() {
          _subjectsError = 'Student ID not found';
          _isLoadingSubjects = false;
        });
        return;
      }

      

      final cachedSubjects = _subjectsCache[studentId];
      final cacheTime = _subjectsCacheUpdatedAt[studentId];
      final Duration? cacheAge = cacheTime != null
          ? DateTime.now().difference(cacheTime)
          : null;

      if (cachedSubjects != null &&
          cacheAge != null &&
          cacheAge < _subjectsCacheTTL) {
        
        if (!mounted) return;
        setState(() {
          _subjects = cachedSubjects
              .map((s) => Map<String, dynamic>.from(s))
              .toList();
          _isLoadingSubjects = false;
        });

        if (widget.assignment != null) {
          _selectedSubject = _findSubjectIdByName(
            widget.assignment!.subjectName,
          );
        }
        return;
      }

      

      final List<Map<String, dynamic>> subjectsList = [];

      // Run multiple API calls in parallel
      final results = await Future.wait([
        HomeworkApi.getSubjectList(studentId),
        LessonApi.getSyllabusSubjects(studentId),
        ApiService.getDailyAssignments(studentId).catchError((e) => {'dailyassignment': []}),
      ]);

      final homeworkResult = results[0];
      final syllabusResult = results[1];
      final assignmentsResult = results[2];

      // 1. Process getSubjectList (Primary source)
      if (homeworkResult['status'] == 1 && homeworkResult['subjects'] != null && (homeworkResult['subjects'] as List).isNotEmpty) {
        subjectsList.addAll(List<Map<String, dynamic>>.from(homeworkResult['subjects']));
        
      }

      // 2. Process syllabus subjects (Secondary source)
      if (syllabusResult['status'] == 1 && syllabusResult['subjects'] != null && (syllabusResult['subjects'] as List).isNotEmpty) {
        final syllabusSubjects = List<Map<String, dynamic>>.from(syllabusResult['subjects']);
        // Add only unique subjects if primary source already provided some
        for (var sub in syllabusSubjects) {
          final subName = sub['subject_name']?.toString() ?? '';
          if (!subjectsList.any((s) => (s['subject_name']?.toString() ?? '') == subName)) {
            subjectsList.add(sub);
          }
        }
        
      }

      // 3. Process existing assignments (Fallback source)
      if (subjectsList.isEmpty && assignmentsResult['dailyassignment'] != null) {
        final assignments = List<Map<String, dynamic>>.from(assignmentsResult['dailyassignment']);
        final Set<String> seenSubjects = {};

        for (var assignment in assignments) {
          final subjectName = assignment['subject_name']?.toString() ?? '';
          final subjectCode = assignment['subject_code']?.toString() ?? '';
          final subjectGroupId = assignment['subject_group_subject_id']?.toString() ?? '';

          if (subjectName.isNotEmpty) {
            final key = '$subjectName|$subjectCode|$subjectGroupId';
            if (!seenSubjects.contains(key)) {
              seenSubjects.add(key);
              subjectsList.add({
                'subject_name': subjectName,
                'subject_code': subjectCode,
                'subject_group_subject_id': subjectGroupId,
              });
            }
          }
        }
        
      }

      if (subjectsList.isNotEmpty) {
        _subjectsCache[studentId] = subjectsList
            .map((s) => Map<String, dynamic>.from(s))
            .toList();
        _subjectsCacheUpdatedAt[studentId] = DateTime.now();

        setState(() {
          _subjects = subjectsList;
          _isLoadingSubjects = false;
        });

        // If editing, find and select the matching subject
        if (widget.assignment != null) {
          _selectedSubject = _findSubjectIdByName(
            widget.assignment!.subjectName,
          );
        }
      } else {
        
        setState(() {
          _subjectsError = 'No subjects found. Please contact your school.';
          _isLoadingSubjects = false;
        });
      }
    } catch (e) {
      
      setState(() {
        _subjectsError = 'Failed to load subjects: $e';
        _isLoadingSubjects = false;
      });
    }
  }

  String? _findSubjectIdByName(String subjectName) {
    // Extract the subject name part (before the code)
    final namePart = subjectName.split(' (')[0];

    // Find matching subject in our list - try to match by name
    for (final subject in _subjects) {
      final subName =
          subject['subject_name']?.toString() ??
          subject['name']?.toString() ??
          '';
      if (subName == namePart) {
        // Return subject_group_subject_id if available, else subject_id, else code
        return subject['subject_group_subject_id']?.toString() ??
            subject['subject_id']?.toString() ??
            subject['id']?.toString() ??
            subject['code']?.toString();
      }
    }

    // If no match found, return null (will show "Select" hint)
    return null;
  }

  // Get the value to send to API (subject_group_subject_id is preferred)
  String? _getSubjectValueToSend(String? selectedValue) {
    if (selectedValue == null) return null;

    // Find the subject by the selected value
    for (final subject in _subjects) {
      final value =
          subject['subject_group_subject_id']?.toString() ??
          subject['subject_id']?.toString() ??
          subject['id']?.toString() ??
          subject['code']?.toString();

      if (value == selectedValue) {
        // Return subject_group_subject_id if available (preferred for API)
        return subject['subject_group_subject_id']?.toString() ??
            subject['subject_id']?.toString() ??
            value;
      }
    }

    return selectedValue; // Fallback to what was selected
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _dueDateController.dispose();
    super.dispose();
  }

  Future<void> _pickFile({ImageSource? source}) async {
    try {
      // If source is provided, pick image directly
      if (source != null) {
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: source,
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 85,
        );

        if (image != null) {
          setState(() {
            _selectedFile = image.path;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: TranslatedText(
                  source == ImageSource.camera
                      ? 'Photo captured successfully'
                      : 'Image selected: ${image.name}',
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
        return;
      }

      // If source is not provided, show options dialog
      await showModalBottomSheet(
        context: context,
        builder:
            (context) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.photo_library),
                    title: const TranslatedText('Image from Gallery'),
                    onTap: () {
                      Navigator.pop(context);
                      _pickFile(source: ImageSource.gallery);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.camera_alt),
                    title: const TranslatedText('Take Photo'),
                    onTap: () {
                      Navigator.pop(context);
                      _pickFile(source: ImageSource.camera);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.description),
                    title: const TranslatedText('Upload Document'),
                    subtitle: const Text('PDF, DOC, DOCX, TXT'),
                    onTap: () {
                      Navigator.pop(context);
                      _pickDocument();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.cancel),
                    title: const TranslatedText('Cancel'),
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking file: $e')));
      }
    }
  }

  Future<void> _pickDocument() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = result.files.single.path;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: TranslatedText(
                'File selected: ${result.files.single.name}',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking document: $e')));
      }
    }
  }

  Future<void> _takePhoto() async {
    await _pickFile(source: ImageSource.camera);
  }

  Future<void> _chooseFile() async {
    // Show options instead of defaulting to gallery
    await _pickFile();
  }

  Future<void> _submitAssignment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSubject == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: TranslatedText('Please select a subject')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get dynamic student ID from authentication service
      final studentId = await AuthService.getStudentId();

      if (studentId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: TranslatedText('Student ID not found. Please login again.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Get the correct subject value to send (prefer subject_group_subject_id)
      final subjectValue = _getSubjectValueToSend(_selectedSubject);

      if (subjectValue == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a valid subject'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Find the subject name for debugging
      String? subjectName;
      for (final subject in _subjects) {
        final value =
            subject['subject_group_subject_id']?.toString() ??
            subject['subject_id']?.toString() ??
            subject['id']?.toString() ??
            subject['code']?.toString();
        if (value == _selectedSubject) {
          subjectName =
              subject['subject_name']?.toString() ??
              subject['name']?.toString() ??
              '';
          break;
        }
      }

      
      
      
      
      
      
      
      
      

      final result = await ApiService.addEditDailyAssignment(
        widget.assignment?.id,
        studentId,
        _titleController.text.trim(),
        _descriptionController.text.trim(),
        _dueDateController.text.trim(),
        _selectedFile,
        subjectId: subjectValue, // Send subject_group_subject_id or subject_id
      );

      
      
      
      

      final dynamic status = result['status'];
      final bool isSuccess = status == '1' || status == 1 || status == true;

      if (isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: TranslatedText(result['msg'] ?? 'Assignment saved successfully'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        final errorMsg = result['msg'] ?? 'Failed to save assignment';
        
        
        
        

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e, stackTrace) {
      
      

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.assignment != null;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true, // Allow keyboard to resize view
      appBar: AppBar(
        title: TranslatedText(
          isEditing ? 'Edit Daily Assignment' : 'Add Daily Assignment',
          style: const TextStyle(color: Colors.black),
        ),
        backgroundColor: const Color(0xFFE6F7FF),
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Main white card - Scrollable to prevent keyboard overlap
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white, // ✅ changed to white
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header section
                      Row(
                        children: [
                          Expanded(
                            child: TranslatedText(
                              isEditing
                                  ? 'Edit Daily Assignment!'
                                  : 'Add Daily Assignment!',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black, // ✅ font black
                              ),
                            ),
                          ),
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Image.asset(
                              "assets/images/timelinepage.jpg",
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[200],
                                  child: const Icon(
                                    Icons.timeline,
                                    size: 32,
                                    color: Colors.grey,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),

                      // Subject
                      const TranslatedText(
                        'Subject',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        height: 56, // Fixed height for consistency
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[400]!),
                        ),
                        child: _isLoadingSubjects
                            ? const Center(
                                child: SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : _subjectsError != null
                            ? Center(
                                child: Text(
                                  _subjectsError!,
                                  style: TextStyle(
                                    color: Colors.red[700],
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            : _subjects.isEmpty
                            ? const Center(
                                child: Text(
                                  'No subjects available',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                ),
                              )
                            : DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedSubject,
                                  hint: const TranslatedText(
                                    'Select Subject',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                  isExpanded: true,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 16,
                                  ),
                                  items: _subjects.map((subject) {
                                    // Get subject name and code
                                    final name =
                                        subject['subject_name']?.toString() ??
                                        subject['name']?.toString() ??
                                        'Unknown';
                                    final code =
                                        subject['subject_code']?.toString() ??
                                        subject['code']?.toString() ??
                                        '';

                                    // Store subject_group_subject_id as value (preferred), or fallback to subject_id/id
                                    final value =
                                        subject['subject_group_subject_id']
                                            ?.toString() ??
                                        subject['subject_id']?.toString() ??
                                        subject['id']?.toString() ??
                                        code;

                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(
                                        code.isNotEmpty
                                            ? '$name ($code)'
                                            : name,
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontSize: 16,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedSubject = value;
                                    });
                                  },
                                ),
                              ),
                      ),

                      const SizedBox(height: 20),

                      // Title
                      const TranslatedText(
                        'Title',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 48, // Reduced height
                        child: TextFormField(
                          controller: _titleController,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Enter assignment title',
                            hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[400]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[400]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.blue[600]!,
                                width: 2,
                              ),
                            ),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Please enter a title'
                              : null,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Description
                      const TranslatedText(
                        'Description',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 80, // Reduced height
                        child: TextFormField(
                          controller: _descriptionController,
                          style: const TextStyle(fontSize: 14),
                          maxLines: null, // Allow scrolling within fixed height
                          expands: true, // Fill the available height
                          textAlignVertical: TextAlignVertical.top,
                          decoration: InputDecoration(
                            hintText: 'Enter assignment description',
                            hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                            contentPadding: const EdgeInsets.all(12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[400]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[400]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.blue[600]!,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // File upload - compacted
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const TranslatedText(
                                  'Attach File',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _chooseFile,
                                        icon: const Icon(Icons.attach_file, size: 20),
                                        label: const Text('File', style: TextStyle(fontSize: 13)),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          side: BorderSide(color: Colors.grey[400]!),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _takePhoto,
                                        icon: const Icon(Icons.camera_alt_outlined, size: 20),
                                        label: const Text('Camera', style: TextStyle(fontSize: 13)),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          side: BorderSide(color: Colors.grey[400]!),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_selectedFile != null) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.check_circle, size: 16, color: Colors.green[700]),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _selectedFile!.split('/').last,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.green[800],
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        InkWell(
                                          onTap: () {
                                            setState(() {
                                              _selectedFile = null;
                                            });
                                          },
                                          child: Icon(Icons.close, size: 18, color: Colors.green[700]),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Submit button - Compact
            SafeArea(
              top: false,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitAssignment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Provider.of<AppConfigProvider>(context).primaryColorObj,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const TranslatedText(
                          'SUBMIT',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

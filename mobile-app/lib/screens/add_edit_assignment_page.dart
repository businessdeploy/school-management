import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class AddEditAssignmentPage extends StatefulWidget {
  final Map<String, dynamic>? assignment;

  const AddEditAssignmentPage({super.key, this.assignment});

  @override
  State<AddEditAssignmentPage> createState() => _AddEditAssignmentPageState();
}

class _AddEditAssignmentPageState extends State<AddEditAssignmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dueDateController = TextEditingController();

  String? _selectedSubject;
  String? _selectedFilePath;
  bool _isLoading = false;
  bool _isSubjectsLoading = false;
  List<dynamic> _subjects = [];

  @override
  void initState() {
    super.initState();
    _fetchSubjects();
    if (widget.assignment != null) {
      _titleController.text = widget.assignment!['title'] ?? '';
      _descriptionController.text = widget.assignment!['description'] ?? '';
      _dueDateController.text = widget.assignment!['due_date'] ?? '';
      _selectedSubject = widget.assignment!['subject_group_subject_id']?.toString();
    }
  }

  Future<void> _fetchSubjects() async {
    setState(() {
      _isSubjectsLoading = true;
    });

    try {
      final studentId = await AuthService.getStudentId();
      final result = await ApiService.getSubjectList(studentId);
      
      if (mounted) {
        setState(() {
          _subjects = result['subjects'] ?? [];
          _isSubjectsLoading = false;
        });
      }
    } catch (e) {
      
      if (mounted) {
        setState(() {
          _isSubjectsLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _dueDateController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFilePath = result.files.single.path;
        });
      }
    } catch (e) {
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e')),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    DateTime initialDate = DateTime.now();
    if (_dueDateController.text.isNotEmpty) {
      try {
        initialDate = DateFormat('yyyy-MM-dd').parse(_dueDateController.text);
      } catch (e) {
        initialDate = DateTime.now();
      }
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _dueDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _saveAssignment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSubject == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a subject')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get dynamic student ID from authentication service
      final studentId = await AuthService.getStudentId();

      final result = await ApiService.addEditDailyAssignment(
        widget.assignment?['id'],
        studentId,
        _titleController.text.trim(),
        _descriptionController.text.trim(),
        _dueDateController.text.trim(),
        _selectedFilePath,
        subjectId: _selectedSubject,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        final dynamic status = result['status'];
        final bool isSuccess = status == '1' || status == 1 || status == true;
        if (isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.assignment != null
                    ? 'Assignment updated successfully!'
                    : 'Assignment added successfully!',
              ),
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['msg'] ?? 'Operation failed')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.assignment != null
              ? 'Edit Daily Assignment'
              : 'Add Daily Assignment',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFFB3E6B5), // Light green color
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                _buildForm(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.assignment != null
                  ? 'Edit Daily Assignment!'
                  : 'Add Daily Assignment!',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Image.asset(
              "assets/images/timelinepage.jpg",
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.blue[100],
                  child: const Icon(
                    Icons.timeline,
                    size: 40,
                    color: Colors.blue,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subject Selection
          const Text(
            'Subject',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonFormField<String>(
              initialValue: _selectedSubject,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: _isSubjectsLoading ? 'Loading subjects...' : 'Select',
              ),
              items: _subjects.map((subject) {
                // The API usually returns subject_group_subject_id or id
                // and name or subject_name
                final id = subject['subject_group_subject_id']?.toString() ?? subject['id']?.toString() ?? '';
                final name = subject['name'] ?? subject['subject_name'] ?? 'Unknown Subject';
                return DropdownMenuItem(
                  value: id,
                  child: Text(name),
                );
              }).toList(),
              onChanged: _isSubjectsLoading ? null : (value) {
                setState(() {
                  _selectedSubject = value;
                });
              },
            ),
          ),
          const SizedBox(height: 16),

          // Title
          const Text(
            'Title',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _titleController,
            decoration: InputDecoration(
              hintText: 'Title',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a title';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Description
          const Text(
            'Description',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(
              hintText: 'Description',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            maxLines: 3,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a description';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Due Date
          const Text(
            'Due Date',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _dueDateController,
            readOnly: true,
            onTap: _selectDate,
            decoration: InputDecoration(
              hintText: 'Due Date (YYYY-MM-DD)',
              suffixIcon: const Icon(Icons.calendar_today),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a due date';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // File Upload Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.file_upload,
                    size: 40,
                    color: Colors.blue[700],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Select File to Upload',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _pickFile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'Choose File',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                if (_selectedFilePath != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Selected: ${_selectedFilePath!.split('/').last}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Submit Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveAssignment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[800],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
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
    );
  }
}


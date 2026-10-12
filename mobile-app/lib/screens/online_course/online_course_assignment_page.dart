import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_html/flutter_html.dart';
import '../../services/api/course_api.dart';
import '../../widgets/translated_text.dart';

class OnlineCourseAssignmentPage extends StatefulWidget {
  final Map<String, dynamic> assignment;
  final String studentId;

  const OnlineCourseAssignmentPage({
    super.key,
    required this.assignment,
    required this.studentId,
  });

  @override
  State<OnlineCourseAssignmentPage> createState() => _OnlineCourseAssignmentPageState();
}

class _OnlineCourseAssignmentPageState extends State<OnlineCourseAssignmentPage> {
  final _messageController = TextEditingController();
  File? _selectedFile;
  bool _isSubmitting = false;
  final _picker = ImagePicker();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const TranslatedText('Take Photo'),
              onTap: () async {
                Navigator.pop(context);
                final picked = await _picker.pickImage(source: ImageSource.camera);
                if (picked != null) {
                  setState(() => _selectedFile = File(picked.path));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const TranslatedText('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(context);
                final picked = await _picker.pickImage(source: ImageSource.gallery);
                if (picked != null) {
                  setState(() => _selectedFile = File(picked.path));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: const TranslatedText('Choose Document'),
              onTap: () async {
                Navigator.pop(context);
                final result = await FilePicker.platform.pickFiles();
                if (result != null && result.files.single.path != null) {
                  setState(() => _selectedFile = File(result.files.single.path!));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitAssignment() async {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: TranslatedText('Please enter a message')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final assignmentId = widget.assignment['course_assignment_id']?.toString() ?? 
                         widget.assignment['assignment_id']?.toString() ?? '';
      
      final response = await CourseApi.addCourseAssignmentSubmission(
        studentId: widget.studentId,
        assignmentId: assignmentId,
        message: _messageController.text.trim(),
        filePath: _selectedFile?.path,
      );

      if (mounted) {
        if (response['status'] == 1 || response['status'] == '1') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: TranslatedText('Assignment submitted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message']?.toString() ?? 'Failed to submit assignment'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final assignment = widget.assignment;
    final title = assignment['assignment_title'] ?? assignment['title'] ?? 'Assignment';
    final description = assignment['description'] ?? '';
    final assignmentDate = assignment['assignment_date'] ?? '';
    final submissionDate = assignment['submission_date'] ?? '';
    final evaluationDate = assignment['evaluation_date'] ?? '';
    final createdBy = assignment['created_by_name'] ?? assignment['staff_name'] ?? '';
    final evaluatedBy = assignment['evaluated_by_name'] ?? '';
    final status = assignment['status'] ?? 'Pending';

    return Scaffold(
      appBar: AppBar(
        title: const TranslatedText('Assignment'),
        backgroundColor: Colors.indigo[800],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Assignment Title & Description
            Text(
              'Assignment:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'Description:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]),
            ),
            const SizedBox(height: 4),
            Html(
              data: description,
              style: {
                "body": Style(
                  margin: Margins.zero,
                  padding: HtmlPaddings.zero,
                  fontSize: FontSize(14),
                ),
              },
            ),
            const SizedBox(height: 24),

            // Summary Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Summary',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  _buildSummaryRow(Icons.calendar_today, 'Assignment Date:', assignmentDate),
                  _buildSummaryRow(Icons.calendar_today, 'Submission Date:', submissionDate),
                  _buildSummaryRow(Icons.event_available, 'Evaluation Date:', evaluationDate),
                  const SizedBox(height: 8),
                  _buildTextRow('Created By:', createdBy),
                  _buildTextRow('Evaluated By:', evaluatedBy),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Status: ', style: TextStyle(fontWeight: FontWeight.w500)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: status.toLowerCase() == 'pending' ? Colors.red : Colors.green,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Submission Form
            const Text(
              'Message *',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Type your message here...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Attach Document',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickFile,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[50],
                ),
                child: Column(
                  children: [
                    Icon(Icons.cloud_upload, size: 32, color: Colors.indigo[600]),
                    const SizedBox(height: 8),
                    Text(
                      _selectedFile == null 
                          ? 'Click to upload document or image' 
                          : _selectedFile!.path.split('/').last,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitAssignment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo[800],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const TranslatedText('Submit'),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(' $value'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(' $value'),
        ],
      ),
    );
  }
}

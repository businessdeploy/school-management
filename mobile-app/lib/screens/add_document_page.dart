import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'my_documents_page.dart';
import '../widgets/translated_text.dart';

class AddDocumentPage extends StatefulWidget {
  const AddDocumentPage({super.key});

  @override
  State<AddDocumentPage> createState() => _AddDocumentPageState();
}

class _AddDocumentPageState extends State<AddDocumentPage> {
  final _titleController = TextEditingController();

  final _imagePicker = ImagePicker();
  String? _selectedFilePath;
  String? _selectedFileName;
  bool _isUploading = false;

  @override
  void dispose() {
    _titleController.dispose();

    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFilePath = result.files.single.path;
          _selectedFileName = result.files.single.name;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: TranslatedText('File selected: ${result.files.single.name}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: TranslatedText('File selection cancelled')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: TranslatedText('Error picking file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickPhotoFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedFilePath = image.path;
          _selectedFileName = image.name;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: TranslatedText('Photo selected: ${image.name}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: TranslatedText('Photo selection cancelled')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: TranslatedText('Error picking photo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedFilePath = image.path;
          _selectedFileName = image.name;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: TranslatedText('Photo taken: ${image.name}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: TranslatedText('Photo capture cancelled')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: TranslatedText('Error taking photo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _uploadDocument() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: TranslatedText('Please enter a title'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: TranslatedText('Please select a file'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate file exists
    final file = File(_selectedFilePath!);
    if (!await file.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: TranslatedText('Selected file does not exist. Please select again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final studentId = await AuthService.getStudentId();
      if (studentId.isEmpty) {
        throw Exception('Student ID not found. Please login again.');
      }

      
      
      
      

      final response = await ApiService.uploadDocument(
        studentId,
        _titleController.text.trim(),
        null,
        _selectedFilePath!,
      );

      

      // More lenient success detection (similar to DocumentApi)
      final status = response['status'];
      final statusStr = status?.toString().trim() ?? '0';
      final statusNum = status is int ? status : (status is String ? int.tryParse(statusStr) : null);
      
      final msg = response['msg']?.toString().toLowerCase() ?? '';
      final message = response['message']?.toString().toLowerCase() ?? '';
      
      bool isSuccess = false;
      
      // Check status field
      if (statusStr == '1' || statusNum == 1) {
        isSuccess = true;
        
      }
      // Check success field
      else if (response['success'] == true || response['success'] == 1 || 
               response['success'] == '1' || response['success'] == 'true') {
        isSuccess = true;
        
      }
      // Check message content for success keywords
      else if (msg.contains('success') || msg.contains('uploaded') || msg.contains('saved') || 
               message.contains('success') || message.contains('uploaded') || message.contains('saved')) {
        isSuccess = true;
        
      }
      // If status is not explicitly 0 or false, and no error message, consider it success
      else if (statusStr != '0' && statusNum != 0 && status != false && 
               !msg.contains('error') && !msg.contains('fail') &&
               !message.contains('error') && !message.contains('fail')) {
        isSuccess = true;
        
      }

      if (isSuccess) {
        // Clear form
        _titleController.clear();

        setState(() {
          _selectedFilePath = null;
          _selectedFileName = null;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: TranslatedText('Document uploaded successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Navigate back to My Documents page
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const MyDocumentsPage()),
            (route) => false,
          );
        }
      } else {
        // Show error message with detailed API response
        final errorMsg = response['msg'] ?? 
                        response['message'] ?? 
                        response['error'] ??
                        (response['data'] is Map ? response['data']['msg'] ?? response['data']['message'] : null) ??
                        'Upload failed. Please try again.';
        
        
        
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: TranslatedText('Upload failed: $errorMsg'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Details',
              textColor: Colors.white,
              onPressed: () {
                
              },
            ),
          ),
        );
      }
    } catch (e) {
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: TranslatedText('Error uploading document: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const TranslatedText(
          'Upload Documents',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.grey[800],
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Main white card
          Expanded(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header section with title and illustration
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Title
                        Expanded(
                          child: const TranslatedText(
                            'Upload Document from Here!',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),

                      ],
                    ),
                  ),

                  // Form content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title input field
                          TextField(
                            controller: _titleController,
                            decoration: InputDecoration(
                              labelText: 'Title',
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
                                borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Documents section
                          const TranslatedText(
                            'Documents',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // File upload section
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Upload illustration and title
                                Row(
                                  children: [
                                    SizedBox(
                                      width: 50,
                                      height: 35,
                                      child: _buildFileUploadIllustration(),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          TranslatedText(
                                            'Select File to Upload',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey[800],
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          const TranslatedText(
                                            'Choose from files, gallery, or camera',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                
                                // Action buttons
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: _pickFile,
                                        icon: const Icon(Icons.insert_drive_file, size: 18),
                                        label: const TranslatedText('Choose File', style: TextStyle(fontSize: 13)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.grey[700],
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: _pickPhotoFromGallery,
                                        icon: const Icon(Icons.photo_library, size: 18),
                                        label: const TranslatedText('Browse Photo', style: TextStyle(fontSize: 13)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.purple[600],
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _takePhoto,
                                    icon: const Icon(Icons.camera_alt, size: 18),
                                    label: const TranslatedText('Take Photo', style: TextStyle(fontSize: 13)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue[600],
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                  ),
                                ),
                                
                                // Selected file indicator
                                if (_selectedFileName != null) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.green[200]!),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const TranslatedText(
                                                'File Selected',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.green,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _selectedFileName!,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[700],
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
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
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isUploading ? null : _uploadDocument,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[800],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isUploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const TranslatedText(
                    'SUBMIT',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ),
    );
  }



  Widget _buildFileUploadIllustration() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          // Person
          Positioned(
            top: 5,
            left: 10,
            child: Container(
              width: 15,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.blue[300],
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          // Document window
          Positioned(
            top: 8,
            right: 5,
            child: Container(
              width: 25,
              height: 15,
              decoration: BoxDecoration(
                color: Colors.blue[100],
                border: Border.all(color: Colors.blue[300]!),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Column(
                children: [
                  Container(
                    width: 20,
                    height: 2,
                    margin: const EdgeInsets.only(top: 2),
                    color: Colors.blue[300],
                  ),
                  Container(
                    width: 15,
                    height: 1,
                    margin: const EdgeInsets.only(top: 1),
                    color: Colors.blue[300],
                  ),
                  Container(
                    width: 18,
                    height: 1,
                    margin: const EdgeInsets.only(top: 1),
                    color: Colors.blue[300],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

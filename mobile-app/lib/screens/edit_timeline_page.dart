import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../models/timeline.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/url_manager.dart';
import '../widgets/translated_text.dart';

class EditTimelinePage extends StatefulWidget {
  final Timeline timeline;

  const EditTimelinePage({super.key, required this.timeline});

  @override
  State<EditTimelinePage> createState() => _EditTimelinePageState();
}

class _EditTimelinePageState extends State<EditTimelinePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dateController = TextEditingController();
  String? _selectedFile;
  String? _existingDocumentUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize with existing timeline data
    _titleController.text = widget.timeline.title;
    _descriptionController.text = widget.timeline.description;
    _dateController.text = widget.timeline.formattedDate;
    _selectedFile = widget.timeline.document.isNotEmpty
        ? widget.timeline.document
        : null;
    if (_selectedFile != null && _selectedFile!.trim().isNotEmpty) {
      _prepareExistingDocumentPreview();
    }
  }

  Future<void> _prepareExistingDocumentPreview() async {
    final docPath = _selectedFile;
    if (docPath == null || docPath.trim().isEmpty) return;

    if (docPath.startsWith('http')) {
      setState(() {
        _existingDocumentUrl = docPath;
      });
      return;
    }

    final baseUrl = await UrlManager.getBaseUrl();
    if (baseUrl.isEmpty) return;

    final sanitized = docPath.startsWith('/') ? docPath.substring(1) : docPath;
    setState(() {
      _existingDocumentUrl = '$baseUrl/$sanitized';
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _selectDate() async {
    DateTime initialDate = DateTime.now();
    try {
      initialDate = DateTime.parse(widget.timeline.timelineDate);
    } catch (_) {
      final parts = _dateController.text.split('/');
      if (parts.length == 3) {
        initialDate = DateTime(
          int.parse(parts[2]),
          int.parse(parts[1]),
          int.parse(parts[0]),
        );
      }
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _dateController.text = _formatDate(picked);
      });
    }
  }

  Future<void> _selectFile() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const TranslatedText(
                  'Select Document Source',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: Colors.blue),
                  title: const TranslatedText('Take Photo'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromCamera();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library, color: Colors.green),
                  title: const TranslatedText('Choose from Gallery'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromGallery();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.attach_file, color: Colors.orange),
                  title: const TranslatedText('Choose Document'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickDocument();
                  },
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedFile = image.path;
          _existingDocumentUrl = null;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: TranslatedText('Photo captured: ${image.name}')),
          );
        }
      }
    } catch (e) {
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: TranslatedText('Error taking photo: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedFile = image.path;
          _existingDocumentUrl = null;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: TranslatedText('Image selected: ${image.name}')),
          );
        }
      }
    } catch (e) {
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: TranslatedText('Error selecting image: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _pickDocument() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = result.files.first.path;
          _existingDocumentUrl = null;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: TranslatedText('File selected: ${result.files.first.name}')),
          );
        }
      }
    } catch (e) {
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: TranslatedText('Error selecting file: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final studentId = await AuthService.getStudentId();
      if (studentId.isEmpty) {
        throw Exception('Student ID not found. Please login again.');
      }

      // Convert date format from DD/MM/YYYY to YYYY-MM-DD
      final dateParts = _dateController.text.split('/');
      if (dateParts.length != 3) {
        throw Exception('Invalid date format. Please select the date again.');
      }
      final formattedDate =
          '${dateParts[2]}-${dateParts[1].padLeft(2, '0')}-${dateParts[0].padLeft(2, '0')}';

      final result = await ApiService.addEditTimeline(
        widget.timeline.id,
        _titleController.text,
        _descriptionController.text,
        formattedDate,
        studentId,
        _selectedFile,
      );

      if (mounted) {
        // Check API response for success
        final status = result['status'];
        final isSuccess = status == 1 || 
                         status == '1' || 
                         status == true ||
                         result['success'] == true ||
                         (result['message']?.toString().toLowerCase().contains('success') ?? false);

        if (isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: TranslatedText('Timeline updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true);
        } else {
          final errorMsg = result['message']?.toString() ?? 
                          result['msg']?.toString() ?? 
                          'Failed to update timeline';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: TranslatedText(errorMsg),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: TranslatedText('Failed to update timeline: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
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
          'Student Timeline',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.grey[800],
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Section
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
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
                          const TranslatedText(
                            'Edit Timeline\nfrom here!',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const TranslatedText(
                            'Update your timeline entry',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Illustration
                    SizedBox(
                      width: 120,
                      height: 100,
                      child: _buildEditIllustration(),
                    ),
                  ],
                ),
              ),
            ),
            // Form Section
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title Field
                        const Text(
                          'Title',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
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
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.blue[400]!),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a title';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        // Date Field
                        const Text(
                          'Date',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _dateController,
                          readOnly: true,
                          onTap: _selectDate,
                          decoration: InputDecoration(
                            hintText: 'Date',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.blue[400]!),
                            ),
                            suffixIcon: const Icon(Icons.calendar_today),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a date';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        // Description Field
                        const TranslatedText(
                          'Description',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: TextFormField(
                            controller: _descriptionController,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText: 'Enter description',
                              contentPadding: const EdgeInsets.all(16),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                            validator: (value) {
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        // File Upload Section
                        const TranslatedText(
                          'Documents',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.attach_file,
                                    color: Colors.grey[600],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _selectedFile != null && _selectedFile!.isNotEmpty
                                          ? _selectedFile!.split('/').last
                                          : 'No file selected',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _selectedFile != null && _selectedFile!.isNotEmpty
                                            ? Colors.black87
                                            : Colors.grey,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: _selectFile,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey[800],
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      minimumSize: const Size(0, 36),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const TranslatedText(
                                      'Choose File',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (_existingDocumentUrl != null)
                                _buildExistingFilePreview()
                              else if (_selectedFile != null && _selectedFile!.isNotEmpty)
                                _buildLocalFileEntry(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submitForm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[800],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
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
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditIllustration() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          // Large clock
          Positioned(
            top: 10,
            left: 20,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.blue[400]!, width: 3),
              ),
              child: Center(
                child: Text(
                  '2:50',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
              ),
            ),
          ),
          // Small stopwatch
          Positioned(
            top: 5,
            right: 15,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.pink[300],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.timer, color: Colors.white, size: 12),
            ),
          ),
          // Person
          Positioned(
            bottom: 15,
            left: 10,
            child: Container(
              width: 25,
              height: 35,
              decoration: BoxDecoration(
                color: Colors.blue[200],
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          // Calendar
          Positioned(
            bottom: 20,
            right: 10,
            child: Icon(
              Icons.calendar_today,
              color: Colors.blue[600],
              size: 16,
            ),
          ),
          // Envelope
          Positioned(
            top: 30,
            left: 5,
            child: Icon(Icons.mail, color: Colors.green[600], size: 12),
          ),
          // Gear
          Positioned(
            bottom: 5,
            right: 5,
            child: Icon(Icons.settings, color: Colors.grey[600], size: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildExistingFilePreview() {
    final url = _existingDocumentUrl;
    if (url == null) return const SizedBox();
    final fileName = _selectedFile?.split('/').last ?? 'document';
    final isImage = _isImageFile(url);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isImage)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              url,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, _, __) {
                return _buildDocumentTile(fileName);
              },
            ),
          )
        else
          _buildDocumentTile(fileName),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              setState(() {
                _selectedFile = null;
                _existingDocumentUrl = null;
              });
            },
            child: const TranslatedText('Remove current file'),
          ),
        ),
      ],
    );
  }

  Widget _buildLocalFileEntry() {
    final fileName = _selectedFile ?? 'selected_file';
    return Row(
      children: [
        const Icon(Icons.insert_drive_file, color: Colors.blueGrey, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            fileName,
            style: const TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton(
          onPressed: () {
            setState(() {
              _selectedFile = null;
            });
          },
          child: const TranslatedText('Remove'),
        ),
      ],
    );
  }

  Widget _buildDocumentTile(String fileName) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file, size: 18, color: Colors.blueGrey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              fileName,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

bool _isImageFile(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.png') ||
      lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.gif') ||
      lower.endsWith('.bmp') ||
      lower.endsWith('.webp');
}

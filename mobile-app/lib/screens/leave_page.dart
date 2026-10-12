import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../config/app_config.dart';
import '../utils/url_manager.dart';
import '../widgets/translated_text.dart';
import 'pdf_viewer_page.dart';
import 'document_viewer_page.dart';

class LeavePage extends StatefulWidget {
  final Map<String, dynamic>? leaveData;
  
  const LeavePage({super.key, this.leaveData});

  @override
  State<LeavePage> createState() => _LeavePageState();
}

class _LeavePageState extends State<LeavePage> {
  String schoolName = '';
  String schoolLogo = '';
  bool isLoading = false;
  String? error;
  String? success;
  bool isEditing = false;
  String? _pickedAttachmentPath;
  String? _pickedAttachmentName;
  String? _existingAttachmentUrl;
  String? _existingAttachmentName;
  bool _shouldRemoveAttachment = false;
  bool _isDetailLoading = false;

  final _formKey = GlobalKey<FormState>();
  final _fromDateController = TextEditingController();
  final _toDateController = TextEditingController();
  final _applyDateController = TextEditingController();
  final _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadSchoolInfo();
    isEditing = widget.leaveData != null;
    if (isEditing && widget.leaveData != null) {
      _setInitialFormValues(widget.leaveData!).then((_) {
        if (mounted) {
          setState(() {});
        }
      });
      _loadLeaveDetail();
    } else {
      _setDefaultDates();
    }
  }

  Future<void> loadSchoolInfo() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // Use AppConfig.getAppLogo() to get dynamic logo URL with base URL
    final logoUrl = await AppConfig.getAppLogo();
    setState(() {
      schoolName = prefs.getString('site_url') ?? 'Prime School';
      schoolLogo = logoUrl; // Now uses dynamic URL with base URL
    });
  }

  void _setDefaultDates() {
    final now = DateTime.now();
    _applyDateController.text = _formatDate(now);
    _fromDateController.text = _formatDate(now.add(const Duration(days: 1)));
    _toDateController.text = _formatDate(now.add(const Duration(days: 1)));
  }

  Future<void> _setInitialFormValues(Map<String, dynamic> leave) async {
    
    
    
    
    
    
    _fromDateController.text = _parseDateForForm(
      _extractStringField(leave, [
        'from_date',
        'leave_from_date',
        'start_date',
        'leave_from',
        'from',
      ]),
    );
    _toDateController.text = _parseDateForForm(
      _extractStringField(leave, [
        'to_date',
        'leave_to_date',
        'end_date',
        'leave_to',
        'to',
      ]),
    );
    _applyDateController.text = _parseDateForForm(
      _extractStringField(leave, [
        'apply_date',
        'applied_date',
        'created_at',
        'created_date',
      ]),
    );
    _reasonController.text = _extractStringField(
      leave,
      ['reason', 'leave_reason', 'description', 'comment'],
    );

    // Resolve attachment info with comprehensive logging
    
    final attachmentInfo = await _resolveAttachmentInfo(leave);
    _existingAttachmentUrl = attachmentInfo['url'];
    _existingAttachmentName = attachmentInfo['name'];
    
    
    
    
    
    
    
    // If we have a URL but no name, extract filename from URL
    if (_existingAttachmentUrl != null && _existingAttachmentUrl!.isNotEmpty) {
      if (_existingAttachmentName == null || _existingAttachmentName!.isEmpty) {
        _existingAttachmentName =
            _existingAttachmentUrl!.split('/').last.split('?').first;
        
      }
    }
    
    // If we have a name but no URL, try to construct it
    if (_existingAttachmentName != null && 
        _existingAttachmentName!.isNotEmpty && 
        (_existingAttachmentUrl == null || _existingAttachmentUrl!.isEmpty)) {
      
      // Try to get URL from leave data again
      final urlKeys = [
        'docs', 'docs_url', 'attachment_url', 'attachment', 'attachmentLink', 'leave_attachment',
        'file_url', 'file', 'document', 'document_url', 'leave_attachment_url',
        'attachmentPath', 'doc', 'doc_url',
      ];
      for (final key in urlKeys) {
        final value = leave[key];
        if (value != null) {
          final trimmed = value.toString().trim();
          if (trimmed.isNotEmpty && trimmed.toLowerCase() != 'null') {
            _existingAttachmentUrl = await _resolveAttachmentUrl(trimmed);
            
            break;
          }
        }
      }
      
      // If still no URL, construct from filename using the correct path
      if ((_existingAttachmentUrl == null || _existingAttachmentUrl!.isEmpty) && 
          _existingAttachmentName != null && _existingAttachmentName!.isNotEmpty) {
        final baseUrl = await UrlManager.getBaseUrl();
        if (baseUrl.isNotEmpty) {
          final fileName = _existingAttachmentName!.split('/').last.split('?').first;
          _existingAttachmentUrl = '$baseUrl/uploads/student_leavedocuments/$fileName';
          
        }
      }
    }
    
    _shouldRemoveAttachment = false;
    
    
    
    
    
    
    // Force UI update to show attachment
    if (mounted) {
      setState(() {});
    }
  }

  String _extractStringField(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];
      if (value != null) {
        final trimmed = value.toString().trim();
        if (trimmed.isNotEmpty && trimmed.toLowerCase() != 'null') {
          return trimmed;
        }
      }
    }
    return '';
  }

  String _extractLeaveId(Map<String, dynamic> data) {
    return _extractStringField(
      data,
      [
        'leave_id',
        'id',
        'leaveId',
      ],
    );
  }

  Future<void> _loadLeaveDetail() async {
    if (widget.leaveData == null) return;
    final leaveId = _extractLeaveId(widget.leaveData!);
    if (leaveId.isEmpty) return;
    setState(() {
      _isDetailLoading = true;
    });
    try {
      final studentId = await AuthService.getStudentId();
      if (studentId.isEmpty) return;
      final response = await ApiService.getLeaveList(studentId);
      final leaves = _extractLeavesFromResponse(response);
      Map<String, dynamic>? matched;
      for (final leave in leaves) {
        if (_extractLeaveId(leave) == leaveId) {
          matched = leave;
          break;
        }
      }
      if (matched != null && matched.isNotEmpty) {
        await _setInitialFormValues(matched);
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      
    } finally {
      if (mounted) {
        setState(() {
          _isDetailLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _extractLeavesFromResponse(
    dynamic responseData,
  ) {
    final result = <Map<String, dynamic>>[];
    if (responseData is List) {
      for (final item in responseData) {
        if (item is Map<String, dynamic>) {
          result.add(Map<String, dynamic>.from(item));
        }
      }
    } else if (responseData is Map<String, dynamic>) {
      for (final key in [
        'result_array',
        'leaves',
        'leave_list',
        'data',
        'leave_requests',
        'list',
        'items',
      ]) {
        final value = responseData[key];
        if (value is List) {
          for (final item in value) {
            if (item is Map<String, dynamic>) {
              result.add(Map<String, dynamic>.from(item));
            }
          }
        }
      }
    }
    return result;
  }

  Future<Map<String, String?>> _resolveAttachmentInfo(Map<String, dynamic> leave) async {
    
    
    
    
    
    final urlKeys = [
      'docs', 'docs_url',
      'attachment_url',
      'attachment',
      'attachmentLink',
      'leave_attachment',
      'file_url',
      'file',
      'document',
      'document_url',
      'leave_attachment_url',
      'attachmentPath',
      'doc',
      'doc_url',
      'userfile',
      'document_file',
      'leave_doc',
      'student_leave_document',
      'leave_document',
    ];
    final nameKeys = [
      'attachment_name',
      'file_name',
      'document_name',
      'leave_attachment_name',
      'name',
      'student_leave_document_name',
    ];
    
    String? url;
    for (final key in urlKeys) {
      final value = leave[key];
      if (value != null) {
        final trimmed = value.toString().trim();
        if (trimmed.isNotEmpty && trimmed.toLowerCase() != 'null') {
          url = trimmed;
          
          break;
        }
      }
    }
    
    String? name;
    for (final key in nameKeys) {
      final value = leave[key];
      if (value != null) {
        final trimmed = value.toString().trim();
        if (trimmed.isNotEmpty && trimmed.toLowerCase() != 'null') {
          name = trimmed;
          
          break;
        }
      }
    }
    
    // If no URL found, check all values for file-like strings
    if (url == null || url.isEmpty) {
      
      for (final entry in leave.entries) {
        final value = entry.value?.toString().trim() ?? '';
        if (value.isNotEmpty && 
            value.toLowerCase() != 'null' &&
            (value.contains('.pdf') || 
             value.contains('.jpg') || 
             value.contains('.jpeg') || 
             value.contains('.png') ||
             value.contains('document') ||
             value.contains('attachment') ||
             value.contains('file'))) {
          url = value;
          
          break;
        }
      }
    }
    
    // Resolve the URL to a full URL if it's just a path
    if (url != null && url.isNotEmpty) {
      url = await _resolveAttachmentUrl(url);
      
    }
    
    // If we have name but no URL, construct URL from name
    if ((url == null || url.isEmpty) && name != null && name.isNotEmpty) {
      final baseUrl = await UrlManager.getBaseUrl();
      if (baseUrl.isNotEmpty) {
        final fileName = name.split('/').last.split('?').first;
        url = '$baseUrl/uploads/student_leavedocuments/$fileName';
        
      }
    }
    
    
    
    return {'url': url, 'name': name};
  }

  Future<String> _resolveAttachmentUrl(String attachmentPath) async {
    // If it's already a full URL, return as is
    if (attachmentPath.startsWith('http://') || attachmentPath.startsWith('https://')) {
      
      return attachmentPath;
    }

    final baseUrl = await UrlManager.getBaseUrl();
    if (baseUrl.isEmpty) {
      
      return attachmentPath; // Return original path if no base URL
    }

    // Clean the base URL
    String cleanBaseUrl = baseUrl;
    if (cleanBaseUrl.endsWith('/')) {
      cleanBaseUrl = cleanBaseUrl.substring(0, cleanBaseUrl.length - 1);
    }

    // Clean the attachment path
    String cleanPath = attachmentPath.trim();
    if (cleanPath.startsWith('/')) {
      cleanPath = cleanPath.substring(1);
    }

    // Extract filename from path (get the last part after /)
    final pathParts = cleanPath.split('/');
    final fileName = pathParts.isNotEmpty ? pathParts.last : cleanPath;

    
    

    // Use the correct path: uploads/student_leavedocuments/{filename}
    // As per user specification: /uploads/student_leavedocuments
    final forcedPath = 'uploads/student_leavedocuments/$fileName';
    final fullUrl = '$cleanBaseUrl/$forcedPath';
    
    
    
    
    return fullUrl;
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _convertToApiDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      // Convert from DD/MM/YYYY to YYYY-MM-DD
      if (RegExp(r'^\d{2}/\d{2}/\d{4}').hasMatch(dateStr)) {
        final parts = dateStr.split('/');
        if (parts.length == 3) {
          return '${parts[2]}-${parts[1]}-${parts[0]}';
        }
      }
      // Already in YYYY-MM-DD
      if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(dateStr)) {
        return dateStr;
      }
    } catch (e) {
      
    }
    return dateStr;
  }

  // Parse date from API/Input to DD/MM/YYYY format for display
  String _parseDateForForm(String dateStr) {
    if (dateStr.isEmpty || dateStr == 'N/A' || dateStr == 'null' || dateStr == 'NULL') {
      return '';
    }
    
    try {
      // Already in DD/MM/YYYY
      if (RegExp(r'^\d{2}/\d{2}/\d{4}').hasMatch(dateStr)) {
        return dateStr;
      }
      // Convert from YYYY-MM-DD to DD/MM/YYYY
      else if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(dateStr)) {
        final parts = dateStr.split(' ')[0].split('-');
        if (parts.length == 3) {
          return '${parts[2]}/${parts[1]}/${parts[0]}';
        }
      }
      // Convert from DD-MM-YYYY to DD/MM/YYYY
      else if (RegExp(r'^\d{2}-\d{2}-\d{4}').hasMatch(dateStr)) {
        return dateStr.replaceAll('-', '/');
      }
      // Try DateTime.parse
      else {
        final parsed = DateTime.parse(dateStr.split(' ')[0]);
        return _formatDate(parsed);
      }
    } catch (e) {
      
    }
    
    return dateStr; // Fallback
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      controller.text = _formatDate(picked);
    }
  }

  Future<void> _pickAttachment() async {
    try {
      // Use ImagePicker to open gallery
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      
      if (image == null) {
        
        return;
      }

      
      

      setState(() {
        _pickedAttachmentPath = image.path;
        _pickedAttachmentName = image.name;
        _existingAttachmentUrl = null;
        _existingAttachmentName = null;
        _shouldRemoveAttachment = false;
      });
    } catch (e) {
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: TranslatedText('Error opening gallery: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removeAttachment() {
    setState(() {
      _pickedAttachmentPath = null;
      _pickedAttachmentName = null;
      if (_existingAttachmentUrl != null || _existingAttachmentName != null) {
        _existingAttachmentUrl = null;
        _existingAttachmentName = null;
        _shouldRemoveAttachment = true;
      } else {
        _shouldRemoveAttachment = false;
      }
    });
  }

  Future<void> _viewExistingAttachment() async {
    if (_existingAttachmentUrl == null) return;
    
    final url = _existingAttachmentUrl!;
    final name = _existingAttachmentName ?? 'Attachment';
    
    if (url.toLowerCase().endsWith('.pdf')) {
       Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PDFViewerPage(
            documentUrl: url,
            documentTitle: name,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DocumentViewerPage(
            documentUrl: url,
            documentTitle: name,
          ),
        ),
      );
    }
  }


  InputDecoration _buildInputDecoration(String label,
      {String? hint, Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 15, color: Colors.black87),
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFF1976D2)),
      ),
    );
  }

  Future<void> _submitLeaveApplication() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      isLoading = true;
      error = null;
      success = null;
    });

    final attachmentPath = _pickedAttachmentPath?.trim();
    final shouldRemoveAttachment =
        _shouldRemoveAttachment && (attachmentPath == null || attachmentPath.isEmpty);

    try {
      Map<String, dynamic> response;
      
      if (isEditing && widget.leaveData != null) {
        // Update existing leave
        final leaveId = widget.leaveData!['id']?.toString() ?? '';
        if (leaveId.isEmpty) {
          throw Exception('Invalid leave ID');
        }
        
        response = await ApiService.updateLeave(
          leaveId,
          _convertToApiDate(_fromDateController.text),
          _convertToApiDate(_toDateController.text),
          _convertToApiDate(_applyDateController.text),
          _reasonController.text,
          filePath: attachmentPath,
          removeAttachment: shouldRemoveAttachment,
        );
        
        if (!mounted) return;
        
        if (response['status'] == 1 || response['status'] == '1') {
          setState(() {
            isLoading = false;
            success = 'Leave application updated successfully!';
          });
          
          // Return true to indicate success
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              Navigator.pop(context, true);
            }
          });
        } else {
          setState(() {
            isLoading = false;
            error = response['message'] ?? 'Failed to update leave application';
          });
        }
      } else {
        // Add new leave
        final studentId = await AuthService.getStudentId();

        response = await ApiService.addLeave(
          studentId,
          _convertToApiDate(_fromDateController.text),
          _convertToApiDate(_toDateController.text),
          _convertToApiDate(_applyDateController.text),
          _reasonController.text,
          attachmentPath,
        );
        
        if (!mounted) return;
        
        if (response['status'] == 1 || response['status'] == '1') {
          setState(() {
            isLoading = false;
            success = 'Leave application submitted successfully!';
          });

          // Return true to indicate success and refresh the list
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              Navigator.pop(context, true);
            }
          });
        } else {
          setState(() {
            isLoading = false;
            error = response['message'] ?? 'Failed to submit leave application';
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        error = e.toString();
      });
    }
  }

  Widget _buildAttachmentSection() {
    final hasNewFile = _pickedAttachmentName != null;
    // Show existing file if we have URL (name can be extracted from URL if missing)
    final hasExistingFile = _existingAttachmentUrl != null && _existingAttachmentUrl!.isNotEmpty;

    
    
    
    
    
    
    
    
    

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TranslatedText(
          'Attachment (PDF, JPG, PNG)',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickAttachment,
                icon: const Icon(Icons.attach_file, size: 18),
                label: TranslatedText(hasNewFile ? 'Change File' : 'Choose File'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: Colors.blue.shade700),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            if ((hasNewFile || hasExistingFile))
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: TextButton(
                  onPressed: _removeAttachment,
                  child: const TranslatedText('Remove'),
                ),
              ),
          ],
        ),
        // Show new file selection
        if (hasNewFile) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Selected: $_pickedAttachmentName',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        // Show existing attachment (when editing leave)
        if (hasExistingFile && _pickedAttachmentName == null) ...[
          const SizedBox(height: 12),
          _buildUploadedFilePreview(
            _existingAttachmentName ?? _existingAttachmentUrl!.split('/').last.split('?').first,
            _existingAttachmentUrl!,
          ),
        ],
      ],
    );
  }

  Widget _buildUploadedFilePreview(String fileName, String fileUrl) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: InkWell(
        onTap: () => _viewExistingAttachment(),
        child: Row(
          children: [
            const Icon(Icons.attach_file, color: Colors.blue, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TranslatedText(
                    'Attached File:',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    fileName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _viewExistingAttachment(),
              icon: const Icon(Icons.download, color: Colors.blue, size: 22),
              tooltip: 'Download Attachment',
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fromDateController.dispose();
    _toDateController.dispose();
    _applyDateController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const TranslatedText(
          'Leave List',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Section
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const TranslatedText(
                                    'Leave List',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  TranslatedText(
                                    isEditing
                                        ? 'Edit Leave Application'
                                        : 'Submit your leave application',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 56,
                                height: 56,
                                child: Image.asset(
                                  'assets/images/leavepage.jpg',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isDetailLoading)
                        const SizedBox(
                          width: double.infinity,
                          height: 4,
                          child: LinearProgressIndicator(),
                        ),
                      const SizedBox(height: 24),

                      // Error/Success Messages
                      if (error != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error, color: Colors.red.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  error!,
                                  style: TextStyle(color: Colors.red.shade700),
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (success != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  success!,
                                  style: TextStyle(color: Colors.green.shade700),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Leave Details Section
                      const TranslatedText(
                        'Leave Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Apply Date
    TextFormField(
      controller: _applyDateController,
      decoration: _buildInputDecoration(
        'Apply Date',
        suffixIcon: const Icon(Icons.calendar_today),
      ),
                        readOnly: true,
                        onTap: () => _selectDate(context, _applyDateController),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select apply date';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // From Date and To Date Row
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _fromDateController,
      decoration: _buildInputDecoration(
        'From Date',
        suffixIcon: const Icon(Icons.calendar_today),
      ),
                              readOnly: true,
                              onTap: () => _selectDate(context, _fromDateController),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select from date';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _toDateController,
      decoration: _buildInputDecoration(
        'To Date',
        suffixIcon: const Icon(Icons.calendar_today),
      ),
                              readOnly: true,
                              onTap: () => _selectDate(context, _toDateController),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select to date';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Reason
                      TextFormField(
                        controller: _reasonController,
                        decoration: _buildInputDecoration(
                          'Reason for Leave',
                          hint: 'Enter the reason for your leave application',
                        ),
                        maxLines: 4,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter reason for leave';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildAttachmentSection(),
                      const SizedBox(height: 24),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _submitLeaveApplication,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : TranslatedText(
                                  isEditing ? 'Update Leave Application' : 'Submit Leave Application',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
} 


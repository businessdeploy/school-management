import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../services/api_service.dart';
import '../utils/url_manager.dart';
import '../widgets/translated_text.dart';

class ExamSchedulePage extends StatefulWidget {
  final String examId;
  final String examName;
  final String? downloadUrl;

  const ExamSchedulePage({
    super.key,
    required this.examId,
    required this.examName,
    this.downloadUrl,
  });

  @override
  State<ExamSchedulePage> createState() => _ExamSchedulePageState();
}

class _ExamSchedulePageState extends State<ExamSchedulePage> {
  List<Map<String, dynamic>> examSubjects = [];
  bool isLoading = true;
  String? error;
  String? scheduleDownloadUrl;

  @override
  void initState() {
    super.initState();
    // Initialize with passed URL if available
    scheduleDownloadUrl = widget.downloadUrl;
    _loadExamSchedule();
  }

  Future<void> _loadExamSchedule() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final response = await ApiService.getExamSchedule(widget.examId);
      
      if (!mounted) return;
      
      // Check for exam_subjects first (as per API spec), then data
      List<Map<String, dynamic>> subjectsList = [];
      if (response['exam_subjects'] != null && response['exam_subjects'] is List) {
        subjectsList = List<Map<String, dynamic>>.from(response['exam_subjects']);
        
      } else if (response['data'] != null && response['data'] is List) {
        subjectsList = List<Map<String, dynamic>>.from(response['data']);
        
      }
      
      setState(() {
        examSubjects = subjectsList;
        isLoading = false;
        if (subjectsList.isEmpty && response['status'] != 1) {
          error = response['message'] ?? 'Failed to load exam schedule';
        }
        
        // Extract schedule download URL from full response
        if (response.containsKey('full_response')) {
          final fullData = response['full_response'];
          if (fullData is Map) {
             final fetchedUrl = _extractScheduleUrl(fullData);
             if (fetchedUrl != null && fetchedUrl.isNotEmpty) {
               scheduleDownloadUrl = fetchedUrl;
             }
          }
        }
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const TranslatedText(
          'Exam Schedule',
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
      body: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: const TranslatedText(
                            'Your Exam Schedule is here!',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              height: 1.2,
                            ),
                          ),
                        ),
                        if (scheduleDownloadUrl != null && scheduleDownloadUrl!.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            child: ElevatedButton.icon(
                              onPressed: () => _downloadFullSchedule(),
                              icon: const Icon(Icons.download, size: 18),
                              label: const TranslatedText('Download'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[600],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 120,
                          height: 100,
                          child: _buildScheduleIllustration(),
                        ),
                      ],
                    ),
                  ),

                  // Exam Schedule List
                  Expanded(
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
                                      color: Colors.red[300],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Failed to load exam schedule',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.red[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      error!,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.red[400],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: _loadExamSchedule,
                                      child: const TranslatedText('Retry'),
                                    ),
                                  ],
                                ),
                              )
                            : examSubjects.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.schedule_outlined,
                                          size: 64,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(height: 16),
                                        TranslatedText(
                                          'No schedule found',
                                          style: TextStyle(
                                            fontSize: 18,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        TranslatedText(
                                          'Schedule details will be available soon',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : SingleChildScrollView(
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    child: Column(
                                      children: examSubjects.map((subject) => _buildSubjectCard(subject)).toList(),
                                    ),
                                  ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectCard(Map<String, dynamic> subject) {
    final subjectName = subject['subject_name'] ?? 'Unknown Subject';
    final subjectCode = subject['subject_code'] ?? '';
    final examDate = subject['exam_date'] ?? subject['date_from'] ?? '';
    final startTime = subject['start_time'] ?? subject['time_from'] ?? '';
    final duration = subject['duration'] ?? '';
    final roomNumber = subject['room_number'] ?? subject['room_no'] ?? '';
    final maxMarks = subject['max_marks'] ?? '';
    final minMarks = subject['min_marks'] ?? '';
    final creditHours = subject['credit_hours'] ?? '';
    final scheduleDocPath = _getScheduleDocumentPath(subject);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subject Header - Light grey background like in image
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$subjectName ($subjectCode)',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                if (scheduleDocPath.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: () => _downloadExamSchedule(scheduleDocPath),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[500],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(
                      Icons.download,
                      size: 18,
                    ),
                    label: const TranslatedText(
                      'Download',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Subject Details - Exact match to image
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildDetailRow('Date', _formatDate(examDate)),
                _buildDetailRow('Room No.', roomNumber),
                _buildDetailRow('Start Time', startTime),
                _buildDetailRow('Duration', duration),
                _buildDetailRow('Max Marks', maxMarks),
                _buildDetailRow('Min Marks', minMarks),
                _buildDetailRow('Credit Hours', creditHours),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Row(
              children: [
                Expanded(
                  child: TranslatedText(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const Text(
                  ':',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    if (dateString.isEmpty) return 'TBD';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildScheduleIllustration() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          // Desk
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 20,
              decoration: BoxDecoration(
                color: Colors.brown[300],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
            ),
          ),
          // Person
          Positioned(
            bottom: 20,
            left: 20,
            child: Container(
              width: 30,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.orange[200],
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
          // Head
          Positioned(
            bottom: 55,
            left: 25,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.orange[300],
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Books
          Positioned(
            bottom: 25,
            right: 15,
            child: Container(
              width: 25,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.blue[200],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          // Laptop
          Positioned(
            bottom: 30,
            right: 45,
            child: Container(
              width: 30,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          // Globe
          Positioned(
            top: 10,
            right: 20,
            child: Icon(
              Icons.public,
              color: Colors.blue[600],
              size: 20,
            ),
          ),
          // Exam document
          Positioned(
            top: 15,
            left: 10,
            child: Container(
              width: 20,
              height: 15,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Center(
                child: Text(
                  'EXAM',
                  style: TextStyle(
                    fontSize: 6,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Extract possible schedule document path from subject data
  String _getScheduleDocumentPath(Map<String, dynamic> subject) {
    const possibleKeys = [
      'document',
      'document_file',
      'file',
      'file_name',
      'schedule_file',
      'schedule',
      'attachment',
      'exam_schedule',
      'exam_schedule_file',
    ];

    for (final key in possibleKeys) {
      final value = subject[key];
      if (value != null) {
        final str = value.toString().trim();
        if (str.isNotEmpty && str.toLowerCase() != 'null') {
          return str;
        }
      }
    }

    return '';
  }

  Future<void> _downloadExamSchedule(String rawPath) async {
    try {
      if (!mounted) return;

      // Show short loading indication
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: TranslatedText('Preparing exam schedule...'),
          duration: Duration(seconds: 2),
        ),
      );

      final urlString = await _resolveScheduleUrl(rawPath);
      if (urlString.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: TranslatedText(
              'Exam schedule document not available. Please contact school admin.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final uri = Uri.tryParse(urlString);
      if (uri == null || !uri.hasScheme || !uri.scheme.startsWith('http')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: TranslatedText('Invalid exam schedule URL: $urlString'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final launched = await launchUrlString(
        urlString,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: TranslatedText('Could not open exam schedule. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening exam schedule: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String> _resolveScheduleUrl(String path) async {
    try {
      var trimmed = path.trim();
      if (trimmed.isEmpty) return '';

      // If already a full URL, return as is
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        return trimmed;
      }

      final baseUrl = await UrlManager.getBaseUrl();
      if (baseUrl.isEmpty) {
        
        return '';
      }

      trimmed = trimmed.replaceAll('\\', '/');
      if (trimmed.startsWith('/')) {
        trimmed = trimmed.substring(1);
      }

      // If not already under uploads/, prepend uploads/
      if (!trimmed.startsWith('uploads/')) {
        trimmed = 'uploads/$trimmed';
      }

      final fullUrl = '$baseUrl/$trimmed';
      
      return fullUrl;

    } catch (e) {
      
      return '';
    }
  }

  /// Extract schedule file URL from full API response
  String? _extractScheduleUrl(Map<dynamic, dynamic> data) {
    const keys = ['attachment', 'file', 'exam_schedule_url', 'schedule_file', 'document', 'pdf_url'];
    
    // Check root keys
    for (final key in keys) {
      if (data[key] != null && data[key].toString().isNotEmpty && data[key].toString().toLowerCase() != 'null') {
        return data[key].toString();
      }
    }
    
    // Check nested keys if any (e.g. inside another 'exam' object)
    if (data['exam'] != null && data['exam'] is Map) {
      final examMap = data['exam'];
      for (final key in keys) {
        if (examMap[key] != null && examMap[key].toString().isNotEmpty && examMap[key].toString().toLowerCase() != 'null') {
          return examMap[key].toString();
        }
      }
    }
    
    return null;
  }
  
  Future<void> _downloadFullSchedule() async {
     if (scheduleDownloadUrl == null || scheduleDownloadUrl!.isEmpty) return;
     await _downloadExamSchedule(scheduleDownloadUrl!);
  }
}
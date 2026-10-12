import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../models/lesson_plan.dart';
import 'lesson_detail_page.dart';
import '../services/api/lesson_api.dart';
import '../services/auth_service.dart';
import '../utils/url_manager.dart';
import '../config/app_config.dart';
import '../widgets/translated_text.dart';
import 'package:provider/provider.dart';
import '../providers/app_config_provider.dart';
import '../widgets/enterprise_ui_components.dart';

class LessonPlanDetailPage extends StatefulWidget {
  final LessonPlan lessonPlan;

  const LessonPlanDetailPage({super.key, required this.lessonPlan});

  @override
  State<LessonPlanDetailPage> createState() => _LessonPlanDetailPageState();
}

class _LessonPlanDetailPageState extends State<LessonPlanDetailPage> {
  bool _isLoadingDetails = false;
  Map<String, dynamic> _syllabusDetails = {};
  String _displayTeacherName = '';
  
  // Comment related state
  final TextEditingController _commentController = TextEditingController();
  bool _isSavingComment = false;
  bool _isLoadingComments = false;
  bool _usingLocalStorage = false;
  List<Map<String, dynamic>> _comments = [];
  String _currentStudentId = '';
  String _currentAdmissionNo = '';
  YoutubePlayerController? _ytController;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _loadUserInfo();
    _loadSyllabusDetails();
    _loadComments();
  }

  Future<void> _loadUserInfo() async {
    try {
      final profile = await AuthService.getUserProfile();
      if (mounted) {
        setState(() {
          _currentStudentId = profile['student_id'] ?? '';
          _currentAdmissionNo = profile['admission_no'] ?? '';
        });
      }
    } catch (e) {
      
    }
  }
  Future<void> _loadSyllabusDetails() async {
    if (_forumSubjectId.isEmpty) return;
    
    if (mounted) {
      setState(() {
        _isLoadingDetails = true;
      });
    }

    try {
      final response = await LessonApi.getSyllabus(_forumSubjectId);
      if (mounted) {
        setState(() {
          _isLoadingDetails = false;
          if (response['status'] == 1 && response['data'] != null) {
            _syllabusDetails = Map<String, dynamic>.from(response['data']);
            
            // Extract attachment if not already set (check common keys in syllabus response)
            final syllabusAttachment = _syllabusDetails['attachment']?.toString() ?? 
                                      _syllabusDetails['file']?.toString() ?? 
                                      _syllabusDetails['document']?.toString() ?? '';
            
            if (syllabusAttachment.isNotEmpty && syllabusAttachment.toLowerCase() != 'null') {
              
            }

            // Sync teacher name if missing in lessonPlan but present in syllabus
            final syllabusTeacher = _syllabusDetails['staff_name']?.toString() ?? 
                                   _syllabusDetails['teacher_name']?.toString() ?? '';
            
            if (_displayTeacherName.isEmpty && syllabusTeacher.isNotEmpty) {
              _displayTeacherName = syllabusTeacher;
            }
            
            // Merge description if missing in details but present in lessonPlan
            if ((_syllabusDetails['description'] == null || _syllabusDetails['description'].isEmpty) && 
                widget.lessonPlan.description.isNotEmpty) {
               _syllabusDetails['description'] = widget.lessonPlan.description;
            }

            // INITIALIZE VIDEO PLAYER IF DISCOVERED
            _initVideoPlayer();
          }
        });
      }
    } catch (e) {
      
      if (mounted) {
        setState(() {
          _isLoadingDetails = false;
        });
      }
    }
  }

  void _initVideoPlayer() {
    final video = _getFinalVideoUrl();
    if (video.isNotEmpty) {
      String? videoId = YoutubePlayer.convertUrlToId(video);
      // Fallback for direct IDs
      if (videoId == null && video.length == 11) {
        videoId = video;
      }

      if (videoId != null && videoId.isNotEmpty) {
         _ytController = YoutubePlayerController(
            initialVideoId: videoId,
            flags: const YoutubePlayerFlags(
              autoPlay: false,
              mute: false,
              disableDragSeek: false,
              loop: false,
              isLive: false,
              forceHD: false,
              enableCaption: true,
            ),
          );
          
      }
    }
  }

  String _getFinalVideoUrl() {
    const keys = [
      'lacture_youtube_url',
      'lecture_youtube_url',
      'youtube_url',
      'video_url',
      'video_id',
      'youtube_id',
      'lecture_video',
      'video',
      'url',
    ];

    // Check list data first
    if (widget.lessonPlan.video.isNotEmpty) {
       return widget.lessonPlan.video;
    }

    // Check detailed data
    for (var key in keys) {
      final val = _syllabusDetails[key]?.toString() ?? '';
      if (val.isNotEmpty && val.toLowerCase() != 'null') {
        return val;
      }
    }
    return '';
  }

  String get _forumSubjectId {
    if (widget.lessonPlan.subjectId.isNotEmpty) {
      return widget.lessonPlan.subjectId;
    }
    if (widget.lessonPlan.id.isNotEmpty) {
      return widget.lessonPlan.id;
    }
    return '';
  }

  String get _localStorageKey {
    final identifier = _forumSubjectId.isNotEmpty
        ? _forumSubjectId
        : (widget.lessonPlan.subjectName.isNotEmpty
              ? widget.lessonPlan.subjectName
              : (widget.lessonPlan.lessonName.isNotEmpty
                    ? widget.lessonPlan.lessonName
                    : 'lesson_plan'));
    return 'lesson_plan_comments_$identifier';
  }

  Future<String> _resolveDocumentUrl(String documentPath) async {
    if (documentPath.isEmpty) return '';

    // Prefer full URLs as-is
    if (documentPath.startsWith('http://') || documentPath.startsWith('https://')) {
      
      return documentPath;
    }

    String baseUrl = await UrlManager.getBaseUrl();
    if (baseUrl.isEmpty) {
      baseUrl = await AppConfig.getBaseUrl();
    }

    if (baseUrl.isEmpty) {
      
      return '';
    }

    // Normalize base URL
    baseUrl = baseUrl.trim();
    if (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }

    // Clean path
    String path = documentPath.trim().replaceAll('\\', '/');
    if (path.startsWith('/')) {
      path = path.substring(1);
    }

    

    // Extract filename from path
    final pathParts = path.split('/');
    final fileName = pathParts.isNotEmpty ? pathParts.last : path;

    

    // Check if path already contains uploads/ with a specific folder
    if (path.toLowerCase().contains('uploads/syllabus_attachment') ||
        path.toLowerCase().contains('uploads/lesson_plan') ||
        path.toLowerCase().contains('uploads/lesson_plan_attachment')) {
      // Path already has the correct structure, use it as-is
      final fullUrl = '$baseUrl/$path';
      
      return fullUrl;
    }

    // If path already starts with uploads/ but not lesson plan specific, extract filename and use lesson plan path
    if (path.startsWith('uploads/')) {
      // Extract filename and use lesson plan-specific path
      final forcedPath = 'uploads/syllabus_attachment/$fileName';
      final fullUrl = '$baseUrl/$forcedPath';
      
      return fullUrl;
    }

    // Default: Use syllabus_attachment folder path
    // Try multiple possible lesson plan attachment paths
    final possiblePaths = [
      'uploads/syllabus_attachment/$fileName',
      'uploads/lesson_plan/$fileName',
      'uploads/lesson_plan_attachment/$fileName',
      'uploads/attachment/$fileName',
      'uploads/$fileName',
    ];

    // Use the first path (syllabus_attachment as default)
    final forcedPath = possiblePaths[0];
    final fullUrl = '$baseUrl/$forcedPath';
    
    
    
    
    return fullUrl;
  }

  Future<void> _openDocument(String documentPath) async {
    if (documentPath.isEmpty) return;

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: TranslatedText('Opening document...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      final url = await _resolveDocumentUrl(documentPath);
      if (url.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: TranslatedText('Invalid document URL'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final uri = Uri.parse(url);
      

      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (!await launchUrl(uri, mode: LaunchMode.platformDefault)) {
           throw 'Could not launch $url';
        }
      }
    } catch (e) {
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: TranslatedText('Could not open document: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildAttachmentRow(String fileName) {
    if (fileName.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(
            width: 80,
            child: const TranslatedText(
              "Attachment",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: () => _openDocument(fileName),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.attachment, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fileName.split('/').last, // Show only filename
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          decoration: TextDecoration.underline,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.download_rounded, size: 16, color: Colors.blue),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    if (dateString.isEmpty) return '';
    
    try {
      // Clean string
      String cleanDate = dateString.trim().split(' ').first;
      
      DateTime? parsedDate;
      if (cleanDate.contains('/')) {
        final parts = cleanDate.split('/');
        if (parts.length == 3) {
          // Assuming formatted as DD/MM/YYYY or YYYY/MM/DD logic needed?
          // Usually API returns YYYY-MM-DD. Let's handle DD/MM/YYYY input
          parsedDate = DateTime(
            int.parse(parts[2]), 
            int.parse(parts[1]), 
            int.parse(parts[0])
          );
        }
      } else if (cleanDate.contains('-')) {
        parsedDate = DateTime.tryParse(cleanDate);
      }
      
      if (parsedDate != null) {
        // Requested format: 28 Jul 2025 (dd MMM yyyy)
        return DateFormat('dd MMM yyyy').format(parsedDate);
      }
      
      return cleanDate;
    } catch (e) {
      return dateString;
    }
  }

  String _extractImageUrl(Map<String, dynamic> item, List<String> priorityKeys) {
    for (String key in priorityKeys) {
      final value = item[key]?.toString() ?? '';
      if (value.isNotEmpty && value.toLowerCase() != 'null') {
        // Resolve partial URLs
        if (value.startsWith('http://') || value.startsWith('https://')) {
          return value;
        }
        // If it starts with uploads/, we might need to prepend base URL.
        // But for now let's just return what we have and handle in CircleAvatar
        // or a central image resolver.
        return value; 
      }
    }
    return '';
  }

  String? _getCommentImage(Map<String, dynamic> comment) {
    // Get image URL based on whether it's a teacher or student
    String imageUrl = '';
    if (comment['is_teacher'] == true) {
      imageUrl = comment['teacher_image']?.toString() ?? '';
    } else {
      imageUrl = comment['student_image']?.toString() ?? '';
    }

    if (imageUrl.isEmpty || imageUrl.toLowerCase() == 'null') {
       return null;
    }

    // Resolve relative URLs if needed (assuming base URL exists)
    // For now, only return full URLs to avoid broken images if base path is unknown
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return imageUrl;
    }

    return null;
  }

  Future<void> _deleteComment(Map<String, dynamic> comment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const TranslatedText('Delete Comment'),
        content: const TranslatedText('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const TranslatedText('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const TranslatedText('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      // Check if it's a local comment
      if (comment['is_local'] == true) {
        // Delete from local storage
        final prefs = await SharedPreferences.getInstance();
        final commentsJson = prefs.getString(_localStorageKey);
        if (commentsJson != null && commentsJson.isNotEmpty) {
          final List<dynamic> decoded = jsonDecode(commentsJson);
          final localComments = decoded
              .map((c) => Map<String, dynamic>.from(c))
              .toList();
          
          // Remove the comment
          localComments.removeWhere((c) => 
            c['message'] == comment['message'] &&
            c['created_at'] == comment['created_at']
          );
          
          // Save back
          await prefs.setString(_localStorageKey, jsonEncode(localComments));
        }
      } else {
        // Delete from API
        // Try multiple ID fields including 'id' and 'lesson_plan_forum_id'
        final commentId = comment['id']?.toString() ?? 
                          comment['lesson_plan_forum_id']?.toString() ?? 
                          comment['student_incident_id']?.toString() ?? ''; // Just in case
                          
        if (commentId.isNotEmpty) {
          
          final res = await LessonApi.deleteForumComment(commentId);
          
          if (res['status'] != 1 && res['status'] != '1' && res['status'] != 200) {
             throw Exception(res['message'] ?? 'Failed to delete');
          }
        } else {
           
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(
               content: TranslatedText('Error: Could not find comment ID'),
               backgroundColor: Colors.red,
             ),
           );
           return;
        }
      }

      // Remove from UI
      if (mounted) {
        setState(() {
          _comments.removeWhere((c) => 
            c['message'] == comment['message'] &&
            c['created_at'] == comment['created_at']
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: TranslatedText('Comment deleted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: TranslatedText('Error deleting comment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getEffectiveValue(List<String?> candidates) {
    for (var candidate in candidates) {
      if (candidate != null && 
          candidate.toString().trim().isNotEmpty && 
          candidate.toString().trim().toLowerCase() != 'null') {
        return candidate.toString().trim();
      }
    }
    return '';
  }

  String _formatCommentDate(String dateString) {
    if (dateString.isEmpty) return '';
    try {
      DateTime? date;
      if (dateString.contains('T')) {
        date = DateTime.tryParse(dateString);
      } else if (dateString.contains('-')) {
        date = DateTime.tryParse(dateString);
      } else if (dateString.contains('/')) {
        final parts = dateString.split('/');
        if (parts.length == 3) {
           date = DateTime.tryParse('${parts[2]}-${parts[1]}-${parts[0]}') ??
                  DateTime.tryParse(dateString.replaceAll('/', '-'));
        }
      }
      
      if (date != null) {
        // Requested format: 01/16/2026 11:57 AM
        return DateFormat('MM/dd/yyyy hh:mm a').format(date);
      }
      return dateString;
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildRow(String label, String value) {
    if (value.isEmpty || value.toLowerCase() == 'null') return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: TranslatedText(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TranslatedText(
              value,
              style: const TextStyle(color: Colors.black87, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    // Determine if content is empty (null, empty string, or pure HTML whitespace)
    // Strip HTML tags for empty check to handle things like "<span></span>" or "<p>&nbsp;</p>"
    String strippedContent = content.replaceAll(RegExp(r'<[^>]*>|&nbsp;'), '').trim();
    bool isEmpty = content.isEmpty || strippedContent.isEmpty || content.toLowerCase() == 'null';
    if (isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TranslatedText(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Html(
            data: content,
            style: {
              "body": Style(
                fontSize: FontSize(14),
                color: Colors.black87,
                margin: Margins.zero,
                padding: HtmlPaddings.zero,
              ),
              "p": Style(margin: Margins.only(bottom: 8)),
              "img": Style(
                  width: Width(100, Unit.percent),
                  height: Height.auto(),
              ),
            },
            onLinkTap: (url, _, __) {
              if (url != null) {
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _saveComment() async {
    final message = _commentController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: TranslatedText('Please enter a comment')));
      return;
    }

    if (_forumSubjectId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: TranslatedText('Invalid lesson plan reference. Cannot save comment.'),
        ),
      );
      return;
    }

    setState(() {
      _isSavingComment = true;
    });

    try {
      final studentId = await AuthService.getStudentId();
      if (studentId.isEmpty) {
        throw Exception('Student ID not found. Please login again.');
      }

      

      final res = await LessonApi.saveForumComment(
        _forumSubjectId,
        message,
        studentId,
      );

      

      final dynamic status = res['status'];
      final bool ok =
          status == 1 || status == '1' || status == true || status == 200;

      if (mounted) {
        setState(() {
          _isSavingComment = false;
        });

        if (ok) {
          _commentController.clear();

          // Reload comments from server to get the saved comment with full details
          await _loadComments();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: TranslatedText('Comment saved successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          // API failed - try saving locally as fallback
          try {
            final localComment = await _saveCommentLocally(message);
            setState(() {
              _comments.insert(0, localComment);
              _usingLocalStorage = true;
            });
            _commentController.clear();

            if (mounted) {
              final errorMsg =
                  res['message']?.toString() ?? 'server unavailable';
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Comment saved locally ($errorMsg). Your comment is visible but may not sync to other devices.',
                  ),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          } catch (localError) {
            // Both API and local storage failed
            final errorMsg =
                res['message']?.toString() ?? 'Failed to save comment';
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '$errorMsg\nLocal storage also failed: $localError',
                  ),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSavingComment = false;
        });

        // Try saving locally as fallback
        try {
          final localComment = await _saveCommentLocally(message);
          setState(() {
            _comments.insert(0, localComment);
            _usingLocalStorage = true;
          });
          _commentController.clear();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Comment saved locally (server error). Your comment is visible but may not sync to other devices.',
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 5),
              ),
            );
          }
        } catch (localError) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Error saving comment: $e\nLocal save also failed: $localError',
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      }
    }
  }



  Future<void> _loadComments() async {
    if (_forumSubjectId.isEmpty) {
      
      return;
    }

    

    setState(() {
      _isLoadingComments = true;
    });

    // First try to load from server
    try {
      final response = await LessonApi.getForumComments(_forumSubjectId);

      
      
      

      if (mounted) {
        setState(() {
          _isLoadingComments = false;

          // Check for success (status can be 1, "1", true, or 200)
          // Also accept if status is missing but we have data
          final status = response['status'];
          final isSuccess =
              status == 1 ||
              status == '1' ||
              status == true ||
              status == 200 ||
              status == null;

          // Try multiple possible response keys
          dynamic commentsData =
              response['syllabus'] ??
              response['data'] ??
              response['comments'] ??
              response['forum'] ??
              response['messages'] ??
              response['raw_response'];

          
          
          

          // Accept response even if status is 0 but we have data (some APIs return status 0 with data)
          if ((isSuccess || commentsData != null) && commentsData != null) {
            // Handle both List and single object responses
            List<dynamic> items = [];
            if (commentsData is List) {
              items = commentsData;
            } else if (commentsData is Map) {
              // If it's a map, try to extract a list from it
              items =
                  commentsData['list'] ??
                  commentsData['items'] ??
                  commentsData['data'] ??
                  [commentsData];
            }

            

            if (items.isNotEmpty) {
              _comments.clear();
              _usingLocalStorage = false;

              for (var item in items) {
                if (item is Map<String, dynamic>) {
                  // Extract comment data from response (API format)
                  final message =
                      item['message']?.toString() ??
                      item['comment']?.toString() ??
                      item['staff_message']?.toString() ??
                      item['staff_comment']?.toString() ??
                      item['student_message']?.toString() ??
                      item['note']?.toString() ??
                      item['text']?.toString() ??
                      item['content']?.toString() ??
                      '';

                  

                  // Build student name from firstname, middlename, lastname
                  // Build student/staff name
                  String studentName = '';
                  final first = item['firstname']?.toString() ?? '';
                  final middle = item['middlename']?.toString() ?? '';
                  final last = item['lastname']?.toString() ?? '';
                  
                  if (first.isNotEmpty || last.isNotEmpty) {
                    studentName = [first, middle, last].where((n) => n.isNotEmpty).join(' ').trim();
                  }

                  if (studentName.isEmpty || studentName == 'null') {
                    studentName =
                        item['staff_name']?.toString() ??
                        item['teacher_name']?.toString() ??
                        item['student_name']?.toString() ??
                        item['name']?.toString() ??
                        item['created_by_name']?.toString() ??
                        item['staffname']?.toString() ??
                        item['created_by']?.toString() ??
                        'User';
                  }

                  // Use created_date (API format) or created_at
                  final createdAt =
                      item['created_date']?.toString() ??
                      item['created_at']?.toString() ??
                      item['date']?.toString() ??
                      item['timestamp']?.toString() ??
                      '';

                  // Extract IDs - be aggressive as backends vary
                  final studentId = item['student_id']?.toString() ??
                      item['studentId']?.toString() ??
                      item['user_id']?.toString() ??
                      '';
                  final teacherId = item['teacher_id']?.toString() ??
                      item['teacherId']?.toString() ??
                      item['staff_id']?.toString() ??
                      '';
                  final admissionNo = item['admission_no']?.toString() ?? '';
                  
                  // Determine if commenter is a teacher/staff
                  final isTeacher = item['staff_name'] != null ||
                      item['teacher_name'] != null ||
                      item['is_teacher'] == true ||
                      (item['role']?.toString().toLowerCase().contains('staff') == true) ||
                      teacherId.isNotEmpty;

                  if (message.isNotEmpty) {
                    _comments.add({
                      'message': message,
                      'student_name': studentName,
                      'created_at': createdAt,
                      'lesson_plan_forum_id':
                          item['lesson_plan_forum_id']?.toString() ??
                          item['id']?.toString(),
                      'admission_no': admissionNo,
                      'student_image': _extractImageUrl(
                        item,
                        ['student_image', 'image', 'profile_image'],
                      ),
                      'teacher_image': _extractImageUrl(
                        item,
                        ['teacher_image', 'staff_image', 'image', 'profile_image'],
                      ),
                      'student_id': studentId,
                      'teacher_id': teacherId,
                      'is_teacher': isTeacher,
                      'gender': item['gender']?.toString(), // Added for avatar fallback
                    });
                    
                  }
                }
              }
            }

            

            // Also load local comments and merge (avoid duplicates)
            _loadLocalComments();
            return;
          }

        
        // If server response failed, try loading from local storage
        _loadLocalComments();
      });
    }
    } catch (e, stackTrace) {
      if (mounted) {
        setState(() {
          _isLoadingComments = false;
        });
        
        
        // Fallback to local storage
        _loadLocalComments();
      }
    }
  }

  Future<void> _loadLocalComments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final commentsJson = prefs.getString(_localStorageKey);

      if (commentsJson != null && commentsJson.isNotEmpty) {
        final List<dynamic> localComments = jsonDecode(commentsJson);
        setState(() {
          _usingLocalStorage = true;
          // Merge with existing comments (avoid duplicates)
          for (var comment in localComments) {
            if (comment is Map<String, dynamic>) {
              // Check if comment already exists
              final exists = _comments.any(
                (c) =>
                    c['message'] == comment['message'] &&
                    c['created_at'] == comment['created_at'],
              );
              if (!exists) {
                _comments.add(comment);
              }
            }
          }
          // Sort by date (newest first)
          _comments.sort((a, b) {
            final dateA =
                DateTime.tryParse(a['created_at']?.toString() ?? '') ??
                DateTime(1970);
            final dateB =
                DateTime.tryParse(b['created_at']?.toString() ?? '') ??
                DateTime(1970);
            return dateB.compareTo(dateA);
          });
        });
      }
    } catch (e) {
      
    }
  }

  Future<Map<String, dynamic>> _saveCommentLocally(String message) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final studentName = prefs.getString('student_name') ?? 'You';
      
      // Get student ID from AuthService
      String studentId = '';
      try {
        studentId = await AuthService.getStudentId();
      } catch (e) {
        
      }

      final newComment = {
        'message': message,
        'student_name': studentName.isNotEmpty ? studentName : 'You',
        'student_id': studentId,
        'created_at': DateTime.now().toIso8601String(),
        'is_local': true, // Mark as locally stored
      };

      // Get existing local comments
      final commentsJson = prefs.getString(_localStorageKey);
      List<Map<String, dynamic>> localComments = [];

      if (commentsJson != null && commentsJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(commentsJson);
        localComments = decoded
            .map((c) => Map<String, dynamic>.from(c))
            .toList();
      }

      // Add new comment
      localComments.insert(0, newComment);

      // Save back to SharedPreferences
      await prefs.setString(_localStorageKey, jsonEncode(localComments));
      

      return newComment;
    } catch (e) {
      
      rethrow;
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _ytController?.dispose();
    super.dispose();
  }

  bool _isValidMaterialLink(String value) {
    if (value.isEmpty || value.toLowerCase() == 'null') return false;
    // If it's a long HTML string (like a description), it's not a valid link for a material card
    if (value.contains('<') && value.contains('>')) return false;
    return true;
  }

  Widget _buildStudyMaterialsSection() {
    // Collect all materials using effective values from both detailed and list data
    // Priorities: 1. widget.lessonPlan (list data), 2. _syllabusDetails (detail data)
    final attachment = _getEffectiveValue([
       widget.lessonPlan.attachment, 
       _syllabusDetails['attachment'],
       _syllabusDetails['file'],
       _syllabusDetails['document'],
       _syllabusDetails['syllabus_file'],
    ]);

    final video = _getFinalVideoUrl();

    final presentation = _getEffectiveValue([
       widget.lessonPlan.presentation,
       _syllabusDetails['presentation'],
       _syllabusDetails['ppt'],
       _syllabusDetails['presentation_file'],
    ]);

    final bool hasAttachment = _isValidMaterialLink(attachment);
    final bool hasVideo = _isValidMaterialLink(video);
    final bool hasPresentation = _isValidMaterialLink(presentation);

    if (!hasAttachment && !hasVideo && !hasPresentation) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder_open, color: Colors.blue[800], size: 24),
              const SizedBox(width: 8),
              Text(
                "Study Materials",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.blue[900],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (attachment.isNotEmpty)
            _buildMaterialItem(
              icon: Icons.attach_file,
              color: Colors.orange,
              title: "Attachment Document",
              subtitle: attachment.split('/').last,
              onTap: () => _openDocument(attachment),
            ),
          if (video.isNotEmpty)
            _buildMaterialItem(
              icon: Icons.play_circle_fill,
              color: Colors.red,
              title: "Video Lesson",
              subtitle: "Click to watch video",
              onTap: () {
                 final url = _getFinalVideoUrl();
                 if (url.isEmpty) return;

                 // Check if it's already playing in the page
                 if (_ytController != null) {
                    // Maybe scroll to player or just notify user
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Video is playing at the top of the page')),
                    );
                    return;
                 }

                 String launchUrlStr = url;
                 if (!launchUrlStr.startsWith('http') && launchUrlStr.length > 11) {
                   launchUrlStr = 'https://$launchUrlStr';
                 }
                 
                 // If it's a plain ID
                 if (launchUrlStr.length == 11 && !launchUrlStr.contains('.')) {
                    launchUrlStr = 'https://www.youtube.com/watch?v=$launchUrlStr';
                 }

                 
                 launchUrl(Uri.parse(launchUrlStr), mode: LaunchMode.externalApplication);
              },
            ),
          if (presentation.isNotEmpty)
            _buildMaterialItem(
              icon: Icons.slideshow,
              color: Colors.amber[700]!,
              title: "Presentation",
              subtitle: presentation.split('/').last,
              onTap: () => _openDocument(presentation),
            ),
        ],
      ),
    );
  }

  Widget _buildMaterialItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appConfigProvider = Provider.of<AppConfigProvider>(context);
    final primaryColor = appConfigProvider.primaryColorObj;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Lesson Plan"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoadingDetails
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                EnterpriseUIComponents.buildHeaderWithIllustration(
                  title: 'Lesson Detail',
                  subtitle: 'View detailed lesson information',
                  illustration: Image.asset(
                    'assets/images/lessonplanpage.jpg',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.menu_book_outlined,
                      color: primaryColor,
                      size: 40,
                    ),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      _loadInitialData();
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_ytController != null) ...[
                            _buildInPagePlayer(),
                            const SizedBox(height: 16),
                          ],
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with Title and Icons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Lesson Plan",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.black87,
                        ),
                      ),
                      Row(
                        children: [
                           // Attachment Icon
                           Builder(builder: (context) {
                            // ATTACHMENT: Prioritize widget.lessonPlan which has the data from the list API
                            // The detail API (_syllabusDetails) often mistakenly returns empty attachment
                            final attachment = _getEffectiveValue([
                               widget.lessonPlan.attachment, // Prioritize this!
                               _syllabusDetails['attachment'],
                               _syllabusDetails['file'],
                               _syllabusDetails['document'],
                            ]);
                            
                            

                            if (attachment.isNotEmpty) {
                              return IconButton(
                                icon: const Icon(Icons.description, color: Colors.blue),
                                onPressed: () => _openDocument(attachment),
                                tooltip: 'Attachment',
                              );
                            }
                            return const SizedBox.shrink();
                          }),

                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildRow(
                    "Class",
                    "${widget.lessonPlan.className} (${widget.lessonPlan.section})",
                  ),
                  _buildRow(
                    "Subject",
                    "${widget.lessonPlan.subjectName} (${widget.lessonPlan.subjectCode})",
                  ),
                  _buildRow(
                    "Date",
                    "${_formatDate(widget.lessonPlan.date)} ${widget.lessonPlan.timeFrom}-${widget.lessonPlan.timeTo}",
                  ),
                  _buildRow("Teacher", _displayTeacherName),
                  _buildRow("Lesson", widget.lessonPlan.lessonName),
                  _buildRow("Topic", widget.lessonPlan.topicName),
                  _buildRow("Description", widget.lessonPlan.description),
                  
                  // Attachment row moved to header icons
                  const SizedBox.shrink(),

                  // Reordered Sections:
                  if (_isLoadingDetails)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...[
                    // 1. General Objectives
                    _buildSection(
                      "General Objectives",
                      _syllabusDetails['general_objectives']?.toString() ?? "",
                    ),
                    // 2. Teaching Method
                    _buildSection(
                      "Teaching Method",
                      _syllabusDetails['teaching_method']?.toString() ?? "",
                    ),
                    // 3. Previous Knowledge
                    _buildSection(
                      "Previous Knowledge",
                      _syllabusDetails['previous_knowledge']?.toString() ?? "",
                    ),
                    // 5. Comprehensive Questions
                    _buildSection(
                      "Comprehensive Questions",
                      _syllabusDetails['comprehensive_questions']?.toString() ?? "",
                    ),
                    // 4. Presentation
                    _buildSection(
                      "Presentation",
                      _syllabusDetails['presentation']?.toString() ?? "",
                    ),
                    // 6. Comments (Lesson plan notes)
                    // Note: API might keys this as 'description' or 'note' - checking description first
                    if (widget.lessonPlan.description.isNotEmpty)
                      _buildSection(
                        "Comments",
                        widget.lessonPlan.description,
                      ),
                  ],

                  // View Lesson Topics Button
                  const SizedBox(height: 24),
                  
                  // New Study Materials Section
                  _buildStudyMaterialsSection(),
                  
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LessonDetailPage(
                              subjectName: widget.lessonPlan.subjectName,
                              subjectCode: widget.lessonPlan.subjectCode,
                              subjectId: widget.lessonPlan.subjectId,
                              classSectionId: '65', // Default class section ID
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.menu_book, color: Colors.white),
                      label: const Text(
                        'View Lesson Topics',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Comment Box Section
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Comments & Notes",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Input visible for all users on this screen
                  TextField(
                    controller: _commentController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText:
                          "Add your comments, notes, or observations about this lesson...",
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      filled: true,
                      fillColor: Colors.grey[50],
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
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          _commentController.clear();
                        },
                        child: const Text("Clear"),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isSavingComment ? null : _saveComment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isSavingComment
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                "Save Comment",
                                style: TextStyle(color: Colors.white),
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_isLoadingComments)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_comments.isNotEmpty) ...[
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      'Recent Comments',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._comments.map((comment) {
                          // Determine if it is current user's comment
                          // Check both student_id and admission_no for robustness
                          final commentStudentId = comment['student_id']?.toString() ?? '';
                          final commentAdmissionNo = comment['admission_no']?.toString() ?? '';
                          
                          // Debug prints to troubleshoot why delete button might be hidden
                          if (_comments.indexOf(comment) == 0) { // Print only for first comment
                             
                             
                             
                             
                             
                          }

                          final isMyComment = (_currentStudentId.isNotEmpty && commentStudentId == _currentStudentId) ||
                                              (_currentAdmissionNo.isNotEmpty && commentAdmissionNo == _currentAdmissionNo);
                          
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50], // Slightly lighter grey
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey[200]!),
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          FutureBuilder<String>(
                                            future: UrlManager.getBaseUrl(),
                                            builder: (context, snapshot) {
                                              final baseUrl = snapshot.data ?? '';
                                              
                                              // Determine image URL
                                              String? rawUrl;
                                              if (comment['is_teacher'] == true) {
                                                rawUrl = comment['image']?.toString() ?? 
                                                         comment['staff_image']?.toString() ??
                                                         comment['teacher_image']?.toString();
                                              } else {
                                                rawUrl = comment['image']?.toString() ?? 
                                                         comment['student_image']?.toString();
                                              }

                                              String? finalUrl;
                                              if (rawUrl != null && rawUrl.isNotEmpty && rawUrl.toLowerCase() != 'null') {
                                                if (rawUrl.startsWith('http')) {
                                                  finalUrl = rawUrl;
                                                } else if (baseUrl.isNotEmpty) {
                                                  // Clean up slashes
                                                  String cleanBase = baseUrl.endsWith('/') 
                                                      ? baseUrl.substring(0, baseUrl.length - 1) 
                                                      : baseUrl;
                                                  String cleanPath = rawUrl.startsWith('/') 
                                                      ? rawUrl.substring(1) 
                                                      : rawUrl;
                                                  finalUrl = '$cleanBase/$cleanPath';
                                                }
                                              }

                                              final gender = comment['gender']?.toString().toLowerCase() ?? '';
                                              final defaultAsset = gender == 'female' 
                                                  ? 'assets/images/default_female.jpg' 
                                                  : 'assets/images/default_image.jpg';

                                              Widget avatarContent;
                                              if (finalUrl != null) {
                                                avatarContent = ClipOval(
                                                  child: Image.network(
                                                    finalUrl,
                                                    width: 32,
                                                    height: 32,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) {
                                                      
                                                      return Image.asset(
                                                        defaultAsset,
                                                        width: 32,
                                                        height: 32,
                                                        fit: BoxFit.cover,
                                                      );
                                                    },
                                                    loadingBuilder: (context, child, loadingProgress) {
                                                      if (loadingProgress == null) return child;
                                                      return Center(
                                                        child: CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          value: loadingProgress.expectedTotalBytes != null
                                                              ? loadingProgress.cumulativeBytesLoaded / 
                                                                  loadingProgress.expectedTotalBytes!
                                                              : null,
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                );
                                              } else {
                                                avatarContent = ClipOval(
                                                  child: Image.asset(
                                                    defaultAsset,
                                                    width: 32,
                                                    height: 32,
                                                    fit: BoxFit.cover,
                                                  ),
                                                );
                                              }

                                              return Container(
                                                width: 32,
                                                height: 32,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Colors.grey[200],
                                                ),
                                                child: avatarContent,
                                              );
                                            }
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      comment['student_name'] ?? 'Unknown',
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 14,
                                                        color: Colors.black87,
                                                      ),
                                                    ),
                                                    if (comment['admission_no'] != null && 
                                                        comment['admission_no'].toString().isNotEmpty && 
                                                        comment['admission_no'].toString() != 'null')
                                                      Text(
                                                        '(${comment['admission_no']})',
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 13, // Slightly smaller or same
                                                          color: Colors.black87,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                if (comment['created_at']?.toString().isNotEmpty == true) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    _formatCommentDate(
                                                      comment['created_at']?.toString() ?? '',
                                                    ),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey[600],
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          if (isMyComment)
                                            IconButton(
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                  size: 18,
                                                  color: Colors.red,
                                                ),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                onPressed: () => _deleteComment(comment),
                                                tooltip: 'Delete comment',
                                              ),

                                      ],
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 8),
                              Text(
                                comment['message']?.toString() ?? '',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        );
                    }),
                  ] else ...[
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      'No comments yet. Be the first to comment!',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  if (_usingLocalStorage && _comments.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.orange[700],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Comments are stored locally. They may not sync to other devices.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange[900],
                              ),
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
                ),
              ],
            ),
    );
  }

  Widget _buildInPagePlayer() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: YoutubePlayer(
          controller: _ytController!,
          showVideoProgressIndicator: true,
          progressIndicatorColor: Colors.red,
          progressColors: const ProgressBarColors(
            playedColor: Colors.red,
            handleColor: Colors.redAccent,
          ),
          onReady: () {
            
          },
        ),
      ),
    );
  }
}


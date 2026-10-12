import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../utils/url_manager.dart';
import '../utils/dynamic_api_headers.dart'; // Added
import 'download_center_page.dart';
import '../services/auth_service.dart';
import '../providers/app_config_provider.dart';
import 'online_course/course_assessment_detail_page.dart';
import 'online_course/course_lesson_content_page.dart';
import 'online_course/online_course_assignment_page.dart';
import '../models/online_exam.dart';
import '../services/api/course_api.dart';

class CoursePerformancePage extends StatefulWidget {
  final Map<String, dynamic> course;

  const CoursePerformancePage({super.key, required this.course});

  @override
  State<CoursePerformancePage> createState() => _CoursePerformancePageState();
}

class _CoursePerformancePageState extends State<CoursePerformancePage> {
  List<Map<String, dynamic>> curriculum = [];
  bool isLoading = true;
  String? error;
  bool _hasAutoOpenedVideo = false;
  double _courseProgress = 0.0;
  
  // Debug info
  String? curriculumRawData;
  String? curriculumCurl;
  late Map<String, dynamic> _courseData;

  // New state for attachments
  Map<String, List<Map<String, dynamic>>> _lessonAttachments = {};
  Set<String> _loadingAttachments = {};

  @override
  void initState() {
    super.initState();
    _courseData = Map<String, dynamic>.from(widget.course);
    _loadCurriculum();
    // Auto-open video if available after a short delay
    // Auto-open video DISABLED as per user request to prevent redirection
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   Future.delayed(const Duration(milliseconds: 500), () {
    //     _autoOpenVideoIfAvailable();
    //   });
    // });
  }

  Future<void> _loadCurriculum({bool silent = false}) async {
    try {
      if (!silent) {
        setState(() {
          isLoading = true;
          error = null;
        });
      }

      final courseId = _courseData['id']?.toString() ?? '';
      
      if (courseId.isEmpty || courseId == 'null') {
        setState(() {
          error = 'Invalid Course ID';
          isLoading = false;
        });
        return;
      }

      final studentId = await AuthService.getStudentId();
      final response = await ApiService.getCourseCurriculum(courseId, studentId);
      
      // Store debug info for on-screen transparency
      setState(() {
        curriculumRawData = response['debug_raw_body']?.toString();
        curriculumCurl = response['debug_curl']?.toString();
      });

      // DEBUG: Log raw curriculum response
      
      
      
      
      // Extract the list from various possible keys
      final rawData = response['curriculum'] ?? 
                      response['sectionList'] ?? 
                      response['data'] ?? 
                      response;
      
      final parsed = _normalizeCurriculum(rawData);

      setState(() {
        curriculum = parsed; 
        _calculateProgress();
        isLoading = false;
        
        // Merge certificate data if found in response
        if (response.containsKey('certificate_id') || response.containsKey('certificate') || response.containsKey('certificate_template_id')) {
           _courseData['certificate_id'] ??= response['certificate_id'];
           _courseData['certificate_template_id'] ??= response['certificate_template_id'];
           _courseData['certificate'] ??= response['certificate'];
           _courseData['has_certificate'] ??= response['has_certificate'];
           
        }
      });

      // FALLBACK: If certificate ID is still missing and course is 100% completed,
      // try calling getCourseDetail as suggested by the user.
      if (_courseProgress >= 100.0) {
          final certId = _courseData['certificate_template_id']?.toString() ?? 
                         _courseData['certificate_id']?.toString() ?? 
                         (_courseData['certificate'] is Map ? _courseData['certificate']['id']?.toString() : '') ?? '';
          
          if (certId.isEmpty || certId == 'null') {
              
              try {
                  final detailResponse = await ApiService.getCourseDetail(courseId, studentId);
                  final detail = detailResponse['course'] ?? detailResponse['course_detail'] ?? detailResponse;
                  
                  if (detail != null && detail is Map) {
                      setState(() {
                         _courseData['certificate_id'] ??= detail['certificate_id'];
                         _courseData['certificate_template_id'] ??= detail['certificate_template_id'];
                         _courseData['certificate'] ??= detail['certificate'];
                         _courseData['has_certificate'] ??= detail['has_certificate'];
                      });
                      
                  }
              } catch (e) {
                  
              }
          }
      }
    } catch (e) {
      setState(() {
        curriculum = []; // No fallback
        
        error = e.toString();
        isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _normalizeCurriculum(dynamic raw) {
    var list = [];

    // 1. Handle Map input (e.g. {"0": sec1, "1": sec2})
    if (raw is Map) {
      // Check if it's a wrapper like {'curriculum': [...]}
      if (raw.containsKey('curriculum') && raw['curriculum'] is List) {
        list = raw['curriculum'];
      } else if (raw.containsKey('sectionList') && raw['sectionList'] is List) {
        list = raw['sectionList'];
      } else if (raw.containsKey('data') && raw['data'] is List) {
        list = raw['data'];
      } else {
        // Assume associative array
        list = raw.values.toList();
      }
    } else if (raw is List) {
      list = raw;
    }

    if (list.isEmpty) return [];

    final List<Map<String, dynamic>> sections = [];
    bool isFlatList = false;

    // 2. Detect if it's a list of sections or list of lessons
    if (list.isNotEmpty) {
      final first = list.first;
      if (first is Map) {
        // If it has 'section' or 'items', it's likely a section
        // If it has 'lesson_id' or 'video_url' but NO 'items', it's likely a flat lesson list
        final hasSectionKeys = first.containsKey('section') || 
                              first.containsKey('section_name') || 
                              first.containsKey('section_title') || // Added section_title
                              first.containsKey('items') || 
                              first.containsKey('lessons') ||
                              first.containsKey('lesson_quiz'); // Added lesson_quiz
        
         if (!hasSectionKeys) {
           isFlatList = true;
         }
      }
    }

    if (isFlatList) {
      // 3. Handle flat list of lessons
      final items = _parseItems(list);
      if (items.isNotEmpty) {
        sections.add({'section': 'Course Content', 'items': items});
      }
    } else {
      // 4. Handle list of sections
        if (mounted) {
          setState(() {
            isLoading = false;
            error = null;
          });
        }
      final provider = Provider.of<AppConfigProvider>(context, listen: false);
      for (final section in list) {
        // Ensure section is a Map
        if (section is! Map) continue;
        final Map<String, dynamic> sectionMap = Map<String, dynamic>.from(section);

        final title =
            sectionMap['section'] ??
            sectionMap['section_name'] ??
            sectionMap['section_title'] ?? // API key
            sectionMap['title'] ??
            'Section';
        
        // Extract section ID
        final sectionId = 
            sectionMap['section_id']?.toString() ??
            sectionMap['id']?.toString();

        // Merge all possible item sources to prevent misplaced items
        final List<dynamic> mergedRawItems = [];
        final itemSources = [
          sectionMap['items'],
          sectionMap['lessons'],
          sectionMap['topics'],
          sectionMap['rows'],
          sectionMap['lesson_quiz'],
        ];

        for (final source in itemSources) {
          if (source is List) {
            mergedRawItems.addAll(source);
          } else if (source is Map) {
            mergedRawItems.addAll(source.values);
          }
        }
        
        final allItems = _parseItems(mergedRawItems, sectionId: sectionId);
        
        // Deduplicate items by their ORIGINAL record ID to prevent functional ID collisions
        final Map<String, Map<String, dynamic>> uniqueItemsMap = {};
        for (final item in allItems) {
          // Use the original record ID from 'raw' if available
          final recordId = item['raw']?['id']?.toString() ?? item['id']?.toString() ?? '';
          if (recordId.isNotEmpty) {
            // Keep the one with status=1 if a duplicate exists
            if (!uniqueItemsMap.containsKey(recordId) || item['status'] == 1) {
              uniqueItemsMap[recordId] = item;
            }
          } else {
            final mockId = 'mock_${item['title']}_${item['type']}';
            uniqueItemsMap[mockId] = item;
          }
        }
        
        final List<Map<String, dynamic>> deduplicatedItems = uniqueItemsMap.values.toList();
        
        // Filter out items based on feature toggles
        final List<Map<String, dynamic>> items = deduplicatedItems.where((item) {
          final type = item['type']?.toString().toLowerCase();
          if (type == 'quiz' && !provider.isQuizEnabled) return false;
          if (type == 'exam' && !provider.isExamEnabled) return false;
          if (type == 'assignment' && !provider.isAssignmentEnabled) return false;
          return true;
        }).toList();
        
        // Always add section if it exists, even if empty (user can see empty section)
        sections.add({'section': title.toString(), 'items': items});
      }
    }

    return sections;
  }

  void _calculateProgress() {
    int totalItems = 0;
    int completedItems = 0;

    for (var section in curriculum) {
      final items = section['items'] as List<dynamic>? ?? [];
      for (var item in items) {
        // Items are already filtered in _normalizeCurriculum, so we can just count them all
        totalItems++;
        final status = item['status'];
        if (status == 1 || status == '1' || status == true || status == 'true') {
          completedItems++;
        }
      }
    }

    setState(() {
      if (totalItems > 0) {
        _courseProgress = (completedItems / totalItems) * 100;
      } else {
        // Fallback to API progress if curriculum is empty
        _courseProgress = double.tryParse(_courseData['course_progress']?.toString() ?? '') ?? 0;
      }
    });
    
  }

  List<Map<String, dynamic>> _parseItems(dynamic rawItems, {String? sectionId}) {
    if (rawItems == null) return [];
    var source = [];
    if (rawItems is List) source = rawItems;
    if (rawItems is Map) source = rawItems.values.toList();

    final List<Map<String, dynamic>> items = [];
    for (final item in source) {
      if (item is Map<String, dynamic>) {
         final type =
            (item['type'] ??
                    item['lesson_type'] ??
                    item['content_type'] ??
                    'lesson')
                .toString()
                .toLowerCase();
        
        // PRIMARY CHECK: progress field (1 = completed, 0 = not completed)
        final progress = item['progress'];
        final isCompleted = item['is_completed'] ?? item['is_complete'] ?? item['is_completed_status'] ?? item['completed_status'];
        final rawStatus = item['status'] ?? item['completion_status'] ?? item['completed'] ?? item['course_progress_id'] != null;
        
        // Very aggressive check: if any field suggests completion, mark it as 1
        final status = (progress == 1 || progress == '1' || progress == '100' || progress == 100 || progress == true || progress == 'true' ||
                        isCompleted == 1 || isCompleted == '1' || isCompleted == true || isCompleted == 'true' || isCompleted == 'completed' ||
                        rawStatus == 1 || rawStatus == '1' || rawStatus == true || rawStatus == 'true' || rawStatus == 'completed' || rawStatus == true) ? 1 : 0;
        
        // Helper to validate ID strings
        bool isValidId(dynamic id) {
          if (id == null) return false;
          final s = id.toString().trim().toLowerCase();
          return s.isNotEmpty && s != '0' && s != 'null' && s != 'undefined';
        }

        // Extract ID based on type as requested by user
        // However, we MUST preserve the original record ID as 'id' to prevent menu navigation issues
        final String recordId = (item['id'] ?? '').toString();
      
        String? functionalId;
        if (isValidId(item[type == 'quiz' ? 'quiz_id' : type == 'assignment' ? 'course_assignment_id' : type == 'exam' ? 'course_exam_id' : 'lesson_id'])) {
          functionalId = item[type == 'quiz' ? 'quiz_id' : type == 'assignment' ? 'course_assignment_id' : type == 'exam' ? 'course_exam_id' : 'lesson_id'].toString();
        } else if (isValidId(item['lesson_quiz_id'])) {
          functionalId = item['lesson_quiz_id'].toString();
        }
        
        final effectiveType = type;
        
        // Determine title based on type and available keys
        String title = item['title'] ?? item['lesson_title'] ?? item['name'] ?? '';
      
        if (title.isEmpty) {
          if (effectiveType == 'quiz') {
            title = item['quiz_title'] ?? 'Quiz';
          } else if (effectiveType == 'assignment') {
            title = item['assignment_title'] ?? 'Assignment';
          } else if (effectiveType == 'exam') {
            title = item['course_exam_name'] ?? item['exam_title'] ?? 'Exam';
          } else {
            title = 'Lesson';
          }
        }

        items.add({
          'type': effectiveType,
          'title': title,
          'duration':
              item['duration'] ??
              item['time'] ??
              item['lesson_duration'],
          'url':
              item['url'] ??
              item['video_url'] ??
              item['lesson_url'] ??
              item['file_link'],
          'status': status,
          'id': functionalId ?? recordId,
          'record_id': recordId, // Keep original
          'section_id': sectionId, // Store section ID
          'raw': item,
        });
      }
    }
    return items;
  }

  Future<String?> _resolveVideoUrl(dynamic videoData) async {
    final baseUrl = await UrlManager.getBaseUrl();

    String? normalizeUrl(String? raw) {
      if (raw == null) return null;
      var url = raw.trim();
      if (url.isEmpty || url.toLowerCase() == 'null' || url.toLowerCase() == 'none') return null;

      // Already absolute HTTP(S)
      if (url.startsWith('http://') || url.startsWith('https://')) {
        return url;
      }

      // Protocol-relative (//example.com)
      if (url.startsWith('//')) {
        return 'https:${url.substring(2)}';
      }

      // Common cases missing protocol (e.g., www.youtube.com)
      if (url.startsWith('www.')) {
        return 'https://$url';
      }

      // YouTube IDs or partial links
      if (url.contains('youtu.be') || url.contains('youtube.com')) {
        return url.startsWith('http') ? url : 'https://$url';
      }

      // If URL looks like a plain YouTube ID
      final youtubeIdRegex = RegExp(r'^[A-Za-z0-9_-]{10,}$');
      if (youtubeIdRegex.hasMatch(url)) {
        return 'https://www.youtube.com/watch?v=$url';
      }

      // Treat as relative path using base URL
      if (baseUrl.isEmpty) return null;
      var cleanBase = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;
      if (!url.startsWith('/')) {
        url = '/$url';
      }
      final resolved = '$cleanBase$url';
      
      return resolved;
    }

    // Convert to Map if not already
    Map<String, dynamic> data;
    if (videoData is Map<String, dynamic>) {
      data = videoData;
    } else {
      return null;
    }

    // Primary fields to check
    final primaryKeys = [
      'video_link',
    'video_url',
    'video',
    'video_id',
    'url',
    'link',
    'lesson_url',
    'course_url',
    'course_link',
    'file',
    'video_file',
    'videoPath',
    'videoName',
    ];

    for (final key in primaryKeys) {
      final value = data[key]?.toString();
      final resolved = normalizeUrl(value);
      if (resolved != null) {
        
        return resolved;
      }
    }

    
    return null;
  }

  Future<void> _autoOpenVideoIfAvailable() async {
    if (_hasAutoOpenedVideo) return;
    
    // Try to resolve video URL from course data
    final resolvedUrl = await _resolveVideoUrl(_courseData);
    if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
      _hasAutoOpenedVideo = true;
      
      await _launchVideo(resolvedUrl, showError: false);
    }
  }


  Future<void> _handleItemTap(Map<String, dynamic> item) async {
    final raw = item['raw'] ?? {};
    final type = item['type']?.toString().toLowerCase() ?? '';
    final lessonType = (item['lesson_type'] ?? raw['lesson_type'])?.toString().toLowerCase() ?? '';
    
    // Check if this item should be handled as a video
    // Use the same logic as _hasVideo for consistency
    final isVideo = (type == 'video' || lessonType == 'video' || lessonType == 'video-link' || _hasVideo(item));
    
    // Try to resolve video URL from item
    String? resolvedUrl = await _resolveVideoUrl(item);

    // Fallback to course video if it's a video item but has no specific URL
    if ((resolvedUrl == null || resolvedUrl.isEmpty) && isVideo) {
      final title = (item['lesson_title'] ?? item['title'] ?? '').toString().toLowerCase();
      
      resolvedUrl = await _resolveVideoUrl(_courseData);
    }

    Future<void> openUrl(String? url) async {
      if (url == null || url.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No media available for this lesson')),
        );
        return;
      }
      await _launchVideo(url);
    }

    // Prioritize video playback if flagged as video
    if (isVideo) {
      if (resolvedUrl == null || resolvedUrl.isEmpty) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CourseLessonContentPage(
              item: item,
              courseId: _courseData['id']?.toString() ?? '',
              courseTitle: _courseData['title']?.toString() ?? 'Course',
            ),
          ),
        ).then((_) {
          _loadCurriculum(silent: true);
        });
      } else {
        await openUrl(resolvedUrl);
      }
      return;
    }

    switch (type) {
      case 'lesson':
        // If it wasn't caught by isVideo above, it's a regular text lesson
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CourseLessonContentPage(
              item: item,
              courseId: _courseData['id']?.toString() ?? '',
              courseTitle: _courseData['title']?.toString() ?? 'Course',
            ),
          ),
        ).then((_) {
          _loadCurriculum(silent: true);
        });
        break;
      case 'quiz':
      case 'exam':
        try {
          // Helper to validate ID strings
          bool isValidId(dynamic id) {
            if (id == null) return false;
            final s = id.toString().trim().toLowerCase();
            return s.isNotEmpty && s != '0' && s != 'null' && s != 'undefined';
          }

          // Dedicated assessment flow for Online Course
          // We prioritize quiz_id as requested by user (should be 55)
          String? quizId;
          final raw = item['raw'] ?? {};
          
          if (isValidId(raw['quiz_id'])) {
             quizId = raw['quiz_id'].toString();
          } else if (isValidId(raw['quiz id'])) {
             quizId = raw['quiz id'].toString();
          } else if (isValidId(raw['quizid'])) {
             quizId = raw['quizid'].toString();
          } else if (isValidId(raw['online_quiz_id'])) {
             quizId = raw['online_quiz_id'].toString();
          } else if (isValidId(raw['lesson_quiz_id'])) {
             quizId = raw['lesson_quiz_id'].toString();
          } else if (isValidId(raw['course_quizzes_id'])) {
             quizId = raw['course_quizzes_id'].toString();
          } else if (isValidId(item['id'])) {
             quizId = item['id'].toString();
          }
                         
          if (quizId == null || quizId.isEmpty) {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text('Invalid Quiz ID configuration')),
             );
             return;
          }
          
          if (!mounted) return;
          
          // Use NEW dedicated page to bypass "Closed" status checks
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CourseAssessmentDetailPage(
                item: {
                  ...raw,
                  'quiz_id': quizId, // Ensure resolved ID is passed
                },
                courseTitle: _courseData['title']?.toString() ?? 'Course',
              ),
            ),
          ).then((_) {
             _loadCurriculum(silent: true);
          });
        } catch (e) {
          
        }
        break;
      case 'assignment':
        final studentId = await AuthService.getStudentId();
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OnlineCourseAssignmentPage(
              assignment: raw,
              studentId: studentId,
            ),
          ),
        ).then((_) {
          _loadCurriculum(silent: true);
        });
        break;
      default:
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Content type not supported')),
        );
    }
  }

  Future<void> _launchVideo(String url, {bool showError = true}) async {
    
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (!mounted) return;
      if (showError) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invalid video url')));
      }
      return;
    }

    bool launched = false;

    Future<void> tryLaunch(LaunchMode mode, String label) async {
      if (launched) return;
      try {
        final success = await launchUrl(uri, mode: mode);
        if (success) {
          launched = true;
          
        }
      } catch (e) {
        
      }
    }

    // Prioritize in-app viewing (opens at top) before external redirect
    await tryLaunch(LaunchMode.inAppWebView, 'inAppWebView');
    await tryLaunch(LaunchMode.inAppBrowserView, 'inAppBrowserView');
    await tryLaunch(LaunchMode.platformDefault, 'platformDefault');
    // Only try external as last resort
    await tryLaunch(LaunchMode.externalApplication, 'externalApplication');

    if (!mounted) return;
    if (!launched && showError) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to open video')));
    }
  }

  Future<void> _toggleLessonCompletion(Map<String, dynamic> item) async {
    // Check if ID is available
    // Priority 1: lesson_quiz_id from raw data (most accurate for markascomplete)
    final lessonQuizId = item['raw']?['lesson_quiz_id']?.toString() ?? 
                         item['raw']?['id']?.toString(); // PHP code uses lesson_quiz_id
    
    // Priority 2: section_id (course_section_id in PHP)
    final sectionId = item['raw']?['section_id']?.toString() ?? 
                      item['raw']?['course_section_id']?.toString() ??
                      item['section_id']?.toString();
                      
    final finalId = lessonQuizId;
    
    if (finalId == null || finalId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot mark completion: Missing ID')),
      );
      return;
    }

    // OPTIMISTIC UPDATE: Toggle UI immediately
    final originalStatus = item['status'];
    final newStatus = (originalStatus == 1 || originalStatus == '1') ? 0 : 1;

    // Rule about "Please watch the full video" removed as per user request to allow manual completion.
    
    
    

    setState(() {
      item['status'] = newStatus; 
      _calculateProgress();
    });

    try {
      final studentId = await AuthService.getStudentId();
      final courseId = _courseData['id']?.toString() ?? '';
      
      String lessonQuizType = '1'; // Default: Lesson
      final type = item['type']?.toString().toLowerCase();
      if (type == 'quiz') {
        lessonQuizType = '2';
      } else if (type == 'assignment' || type == 'assessment' || type == 'assesment') {
        lessonQuizType = '3';
      } else if (type == 'exam') {
        lessonQuizType = '4';
      }

      if (item['raw'] != null && item['raw']['lesson_quiz_type'] != null) {
        lessonQuizType = item['raw']['lesson_quiz_type'].toString();
      }

      final sectionId = item['section_id']?.toString();

      

      final response = await ApiService.updateCourseProgress(
        courseId: courseId,
        studentId: studentId,
        lessonId: finalId,
        sectionId: sectionId,
        lessonQuizType: lessonQuizType,
        status: newStatus,
      );

      if (!mounted) return;

      if (response['status'] == 1 || response['status'] == '1' || 
          response['success'] == true) {
        
        
        // Show immediate feedback
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lesson marked as complete!'),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.green,
          ),
        );
        
        // RELOAD in background after a longer delay to ensure server DB sync
        Future.delayed(const Duration(milliseconds: 3000), () {
          if (mounted) _loadCurriculum(silent: true);
        });
        
        // Check if course is now 100% complete and show congratulations
        if (_courseProgress >= 100.0) {
          _showCongratulationsDialog();
        }
      } else {
        
        
        // REVERT optimistic update
        setState(() {
          item['status'] = originalStatus;
          _calculateProgress();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Failed to update progress'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  bool _isCourseCompleted() {
    // Check multiple possible completion indicators
    final completionStatus =
        _courseData['completion_status']?.toString().toLowerCase() ?? '';
    final isCompleted = _courseData['is_completed'];
    final status = _courseData['status']?.toString().toLowerCase() ?? '';
    final progress = _courseData['progress']?.toString() ?? '';
    final completionPercentage =
        _courseData['completion_percentage']?.toString() ?? '';
    final courseProgress = _courseData['course_progress']?.toString() ?? '';
    final hasCertificate = _courseData['certificate'] ?? _courseData['has_certificate'];

    
    
    
    
    
    
    
    
    
    

    if (completionStatus == 'completed' ||
        completionStatus == 'done' ||
        completionStatus == 'finished') {
      
      return true;
    }

    if (isCompleted == true || isCompleted == 1 || isCompleted == '1') {
      
      return true;
    }

    if (status == 'completed' || status == 'done' || status == 'finished') {
      
      return true;
    }

    if (progress == '100' ||
        completionPercentage == '100' ||
        progress == '100%' ||
        completionPercentage == '100%' ||
        courseProgress == '100') {
      
      return true;
    }
    
    // Check calculated progress
    if (_courseProgress >= 100.0) {
      
      return true;
    }
    
    // Check if certificate exists (implies completion)
    if (hasCertificate != null && hasCertificate.toString().toLowerCase() != 'null' && hasCertificate.toString().isNotEmpty) {
      
      return true;
    }

    
    return false;
  }

  Future<void> _downloadCertificate() async {
    try {
      final courseData = _courseData;
      final courseId = courseData['id']?.toString() ?? 
                       courseData['course_id']?.toString() ?? '';
      final courseTitle = courseData['title']?.toString() ?? 
                          courseData['course_title']?.toString() ?? 'Course';
      
      if (courseId.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to identify course for certificate download'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Get student ID
      final studentId = await AuthService.getStudentId();
      if (studentId.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Student information not available'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Get base URL
      final baseUrl = await UrlManager.getBaseUrl();
      if (baseUrl.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Server configuration not available'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      
      
      
      

      String certificateId = '';
      
      try {
         // Prioritize certificate_template_id as per latest user request
         final templateId = _courseData['certificate_template_id']?.toString() ?? '';
         final directCertId = _courseData['certificate_id']?.toString() ?? '';
         
         if (templateId.isNotEmpty && templateId != 'null') {
             certificateId = templateId;
             
         } else if (directCertId.isNotEmpty && directCertId != 'null') {
             certificateId = directCertId;
             
         } else {
             var certData = _courseData['certificate'];
             if (certData is Map) {
                certificateId = certData['id']?.toString() ?? certData['certificate_id']?.toString() ?? '';
                
             } else if (certData != null && certData.toString().isNotEmpty && certData.toString() != 'null') {
                certificateId = certData.toString();
                
             }
         }
      } catch (e) {
         
      }

      
      
      
      

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Generating Certificate...')),
        );
      }

      final response = await CourseApi.downloadCertificate(
        studentId: studentId,
        courseId: courseId,
        certificateId: certificateId,
      );

      
      final dynamic status = response['status'];
      final String message = (response['message'] ?? '').toString().toLowerCase();
      
      // Multi-layer success check:
      // 1. Status code is 1 or 200 (common success codes in this app)
      // 2. Status is boolean true
      // 3. Message contains "success" or "generated"
      bool isSuccess = (status == 1 || status == '1' || status == 200 || status == '200' || 
                        status == true || status == 'true' || 
                        message.contains('success') || message.contains('generated'));

      if (isSuccess) {
        final fileName = 'certificate_${courseId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
        
        // CASE 1: Response contains the PDF bytes directly
        if (response['is_stream'] == true && response['raw_body_bytes'] != null) {
           
           final success = await _downloadAndOpenCertificate('', fileName, bytes: response['raw_body_bytes']);
           
           if (success) {
              if (mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(
                     content: Text('Certificate generated and downloaded successfully!'),
                     backgroundColor: Colors.green,
                   ),
                 );
              }

              // Check if there's a file on the server to clean up
              String? serverFileName;
              for (final key in ['certificate_name', 'pdf_path', 'certificate_path', 'file_path']) {
                if (response.containsKey(key) && response[key] != null) {
                  final val = response[key].toString();
                  if (val.isNotEmpty) {
                    serverFileName = val.split('/').last;
                    break;
                  }
                }
              }

              if (serverFileName != null && serverFileName.isNotEmpty && serverFileName.endsWith('.pdf')) {
                 
                 Future.delayed(const Duration(minutes: 2), () async {
                    try {
                      final res = await CourseApi.deleteCertificateFile(serverFileName!);
                      
                    } catch (e) {
                      
                    }
                 });
              }
           }
           return;
        }

        // CASE 2: Response contains a URL or path to the generated file
        String? downloadUrl;
        final possibleKeys = [
          'download_url', 'downloadUrl', 'url', 'path', 'file_path', 
          'certificate_url', 'certificate_path', 'filename', 'file',
          'certificate_name', 'pdf_path', 'certificate'
        ];

        for (final key in possibleKeys) {
          if (response.containsKey(key) && response[key] != null) {
            final val = response[key].toString();
            if (val.isNotEmpty && (val.endsWith('.pdf') || val.startsWith('http'))) {
              if (val.startsWith('http')) {
                downloadUrl = val;
              } else {
                if (!val.contains('temp_certificates') && !val.startsWith('uploads/')) {
                  downloadUrl = '$baseUrl/uploads/temp_certificates/$val';
                } else {
                  downloadUrl = '$baseUrl/$val';
                }
              }
              break;
            }
          }
        }

        if (downloadUrl != null) {
           final success = await _downloadAndOpenCertificate(downloadUrl!, fileName);
           if (success) {
              String? serverFileName;
              for (final key in ['certificate_name', 'pdf_path', 'certificate_path', 'file_path']) {
                if (response.containsKey(key) && response[key] != null) {
                  final val = response[key].toString();
                  if (val.isNotEmpty) {
                    serverFileName = val.split('/').last;
                    break;
                  }
                }
              }
              
              if (serverFileName == null) {
                serverFileName = downloadUrl!.split('/').last;
              }

              if (serverFileName.isNotEmpty && serverFileName.endsWith('.pdf')) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Certificate generated and downloaded successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );

                    // Redirection to Download Center removed as per user request to prevent unwanted navigation
                  }
                 
                 
                 Future.delayed(const Duration(minutes: 2), () async {
                    try {
                      final res = await CourseApi.deleteCertificateFile(serverFileName!);
                      
                    } catch (e) {
                      
                    }
                 });
              }
           }
        } else {
           
           final genUrl = '$baseUrl/api/webservice/coursedownloadcertificatepdf/$certificateId/$studentId/$courseId';
           final success = await _downloadAndOpenCertificate(genUrl, fileName, isPost: true);
           if (success && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Certificate generated and downloaded successfully!'),
                  backgroundColor: Colors.green,
                ),
              );

              // Redirection to Download Center removed as per user request to prevent unwanted navigation
           }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Failed to generate certificate'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating certificate: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _downloadAndOpenCertificate(String url, String localName, {bool isPost = false, dynamic bytes}) async {
    File? tempFile;
    try {
      if (bytes != null) {
         
      } else {
         
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Downloading Certificate...')),
        );
      }

      Uint8List fileBytes;
      if (bytes != null) {
         if (bytes is Uint8List) {
           fileBytes = bytes;
         } else if (bytes is List<int>) {
           fileBytes = Uint8List.fromList(bytes);
         } else {
            
            return false;
         }
      } else {
          final headers = await DynamicApiHeaders.getCompleteHeaders();
          final prefs = await SharedPreferences.getInstance();
          final sessionCookie = prefs.getString('session_cookie');
          if (sessionCookie != null) {
            headers['Cookie'] = sessionCookie;
          }

          http.Response response;
          if (isPost) {
            response = await http.post(Uri.parse(url), headers: headers);
          } else {
            response = await http.get(Uri.parse(url), headers: headers);
          }

          if (response.statusCode == 200) {
            fileBytes = response.bodyBytes;
            
            // If the response is short and looks like JSON, it might be an error even with 200 OK
            if (fileBytes.length < 500) {
              try {
                final json = jsonDecode(utf8.decode(fileBytes));
                final dynamic status = json['status'];
                final String msg = (json['message'] ?? '').toString().toLowerCase();
                
                bool isActuallySuccess = (status == 1 || status == '1' || status == true || status == 'true' || 
                                         msg.contains('success') || msg.contains('generated'));
                                         
                if (!isActuallySuccess) {
                   if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(json['message'] ?? 'Download failed'),
                          backgroundColor: Colors.red,
                        ),
                      );
                   }
                   return false;
                }
              } catch (_) {}
            }
          } else {
            
            return false;
          }
      }

      final dir = await getTemporaryDirectory();
      tempFile = File('${dir.path}/$localName');

      await tempFile.writeAsBytes(fileBytes);
      

      final result = await OpenFile.open(tempFile.path);
      
      
      // "after download delete this"
      Future.delayed(const Duration(minutes: 5), () async {
         try {
           final fileToDelete = tempFile;
           if (fileToDelete != null && await fileToDelete.exists()) {
             await fileToDelete.delete();
             
           }
         } catch (e) {
           
         }
      });

      return result.type == ResultType.done;
    } catch (e) {
      
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appConfigProvider = Provider.of<AppConfigProvider>(context);
    final primaryColor = appConfigProvider.primaryColorObj;
    final secondaryColor = appConfigProvider.secondaryColorObj;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text(
          'Course Performance',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeader(primaryColor),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadCurriculum,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                      children: [
                        if (error != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange[200]!),
                            ),
                            child: Text(
                              'Showing cached lessons. Error: $error',
                              style: TextStyle(
                                color: Colors.orange[900],
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ...curriculum.map((s) => _buildSectionCard(s, secondaryColor, primaryColor)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader(Color primaryColor) {
    final progress = _courseProgress;
    final duration =
        _courseData['total_duration']?.toString() ??
        _courseData['total_hour_count']?.toString() ??
        '00:00:00';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your Lessons are here!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _courseData['title']?.toString() ?? 'Course',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: (progress / 100).clamp(0, 1),
                            minHeight: 8,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${progress.round()}%',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total Duration: $duration Hrs',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 100,
                height: 90,
                child: Image.asset(
                  'assets/images/coursepage.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) {
                    return const Icon(
                      Icons.auto_graph,
                      size: 60,
                      color: Colors.grey,
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final resolvedUrl = await _resolveVideoUrl(_courseData);
                if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
                  await _launchVideo(resolvedUrl);
                } else {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No video available')),
                  );
                }
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Watch Intro Video'),
            ),
          ),
          if (_isCourseCompleted()) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _downloadCertificate,
                icon: const Icon(Icons.download, size: 20),
                label: const Text(
                  'Download Certificate',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDuration(String? duration) {
    if (duration == null || duration.isEmpty) return '';
    
    // If it contains ':', assume it's already formatted (HH:MM:SS or MM:SS)
    if (duration.contains(':')) return duration;
    
    // If it's pure digits, assume it represents minutes or seconds based on value
    // This is a heuristic. If < 1000, probably minutes. 
    if (RegExp(r'^\d+$').hasMatch(duration)) {
       return '$duration Min';
    }
    
    return duration;
  }

  Widget _buildSectionCard(Map<String, dynamic> section, Color secondaryColor, Color primaryColor) {
    final items = (section['items'] as List).cast<Map<String, dynamic>>();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: secondaryColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Text(
              section['section']?.toString() ?? 'Section',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          ...items.where((i) {
            final type = i['type']?.toString().toLowerCase();
            final provider = Provider.of<AppConfigProvider>(context, listen: false);
            if (type == 'quiz' && !provider.isQuizEnabled) return false;
            if (type == 'exam' && !provider.isExamEnabled) return false;
            if (type == 'assignment' && !provider.isAssignmentEnabled) return false;
            return true;
          }).map((i) => _buildLessonRow(i, primaryColor)),
        ],
      ),
    );
  }


  Widget _buildLessonRow(Map<String, dynamic> item, Color primaryColor) {
    final duration = item['duration']?.toString();
    final type = item['type']?.toString().toLowerCase() ?? 'lesson';
    final lessonId = item['id']?.toString() ?? '';
    final hasAttachmentsFetched = _lessonAttachments.containsKey(lessonId);
    final isLoadingAttachments = _loadingAttachments.contains(lessonId);
    final attachments = _lessonAttachments[lessonId] ?? [];

    return Column(
      children: [
        InkWell(
          onTap: () => _handleItemTap(item),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                Builder(
                  builder: (context) {
                    final isCompleted = item['status'] == 1 || item['status'] == '1' || item['status'] == true;
                    return InkWell(
                      onTap: () => _toggleLessonCompletion(item),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(
                          isCompleted
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          color: isCompleted
                              ? primaryColor
                              : Colors.grey[400],
                          size: 24,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                _buildTypeIcon(item),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['title']?.toString() ?? 'Lesson',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      // Only show duration if video exists
                      if (duration != null && duration.isNotEmpty && _hasVideo(item))
                        Text(
                          _formatDuration(duration),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      if ((type == 'lesson' || type == 'pdf') && !_hasVideo(item) && !hasAttachmentsFetched && !isLoadingAttachments)
                        GestureDetector(
                          onTap: () => _fetchAttachments(item),
                          child: const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(Icons.attachment, size: 14, color: Colors.blue),
                                SizedBox(width: 4),
                                Text('Show Attachments', style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (isLoadingAttachments)
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                if (item['url'] != null && item['url'].toString().isNotEmpty && !_hasVideo(item))
                  IconButton(
                    icon: const Icon(Icons.download, color: Colors.blue, size: 20),
                    onPressed: () async {
                      final url = item['url'].toString();
                      final uri = Uri.tryParse(url);
                      if (uri != null && (url.startsWith('http') || url.startsWith('https'))) {
                        await _launchVideo(url);
                      } else {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Invalid download link')),
                        );
                      }
                    },
                  ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),
        if (hasAttachmentsFetched && attachments.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey[50],
            child: Wrap(
              spacing: 16,
              runSpacing: 12,
              children: attachments.map((att) => _buildAttachmentItem(att)).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildAttachmentItem(Map<String, dynamic> attachment) {
    final fileName = attachment['attachment']?.toString() ?? 'Attachment';
    final fileUrl = attachment['attachment_url']?.toString() ?? '';
    
    return InkWell(
      onTap: () {
        if (fileUrl.isNotEmpty) {
          _launchVideo(fileUrl);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
            child: const Icon(Icons.file_present, color: Colors.red, size: 30),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 80,
            child: Text(
              fileName,
              style: const TextStyle(fontSize: 10),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchAttachments(Map<String, dynamic> item) async {
    final lessonId = item['id']?.toString() ?? '';
    final sectionId = item['section_id']?.toString() ?? '';
    
    if (lessonId.isEmpty) return;
    
    setState(() {
      _loadingAttachments.add(lessonId);
    });
    
    try {
      final response = await ApiService.getLessonAttachments(lessonId);
      
      List<Map<String, dynamic>> attachmentsList = [];
      if (response['attachments'] != null) {
        attachmentsList = List<Map<String, dynamic>>.from(response['attachments']);
      } else if (response['data'] != null && response['data'] is List) {
        attachmentsList = List<Map<String, dynamic>>.from(response['data']);
      }

      // Resolve URLs
      final baseUrl = await UrlManager.getBaseUrl();
      for (var att in attachmentsList) {
        final path = att['attachment']?.toString() ?? '';
        if (path.isNotEmpty && !path.startsWith('http')) {
          // Dynamic path format: /uploads/course_content/$sectionid/$lesson_id/$attachment_name
          if (sectionId.isNotEmpty && lessonId.isNotEmpty) {
             att['attachment_url'] = '$baseUrl/uploads/course_content/$sectionId/$lessonId/$path';
          } else {
             // Fallback to legacy path if IDs are missing
             att['attachment_url'] = '$baseUrl/user/studentcourse/$path';
          }
          
        } else {
          att['attachment_url'] = path;
        }
      }

      setState(() {
        _lessonAttachments[lessonId] = attachmentsList;
        if (attachmentsList.isEmpty) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('No attachments found for this lesson'), duration: Duration(seconds: 1)),
           );
        }
      });
    } catch (e) {
      
    } finally {
      setState(() {
        _loadingAttachments.remove(lessonId);
      });
    }
  }

  Widget _buildTypeIcon(Map<String, dynamic> item) {
    final type = item['type']?.toString().toLowerCase() ?? 'lesson';
    IconData icon;
    Color color;
    switch (type) {
      case 'quiz':
        icon = Icons.quiz;
        color = Colors.purple;
        break;
      case 'exam':
        icon = Icons.wifi;
        color = Colors.orange;
        break;
      case 'assignment':
        icon = Icons.assignment;
        color = Colors.blue;
        break;
      default:
        // Use description icon if it's a lesson without a video
        if (!_hasVideo(item)) {
          icon = Icons.description;
          color = Colors.blue;
        } else {
          icon = Icons.play_circle_fill;
          color = Colors.green;
        }
    }
    return CircleAvatar(
      radius: 16,
      backgroundColor: color.withOpacity(0.1),
      child: Icon(icon, color: color, size: 18),
    );
  }

  // Helper method to check if a lesson has a video
  bool _hasVideo(Map<String, dynamic> item) {
    final raw = item['raw'] ?? {};
    final type = item['type']?.toString().toLowerCase() ?? '';
    final lessonType = (item['lesson_type'] ?? raw['lesson_type'])?.toString().toLowerCase() ?? '';
    final duration = (item['duration'] ?? raw['duration'])?.toString() ?? '';
    
    // 1. Check explicit video flags in type or lesson_type
    if (type == 'video' || lessonType == 'video' || lessonType == 'video-link') return true;
    
    // 2. Check for duration (videos usually have one)
    if (duration.isNotEmpty && duration != '00:00:00' && duration != '0') return true;

    // 3. Check for any video URL fields
    String? getVal(dynamic val) {
      if (val == null) return null;
      final s = val.toString().trim();
      return (s.isEmpty || s.toLowerCase() == 'null' || s.toLowerCase() == 'none') ? null : s;
    }

    final videoUrl = getVal(item['url']) ?? 
                     getVal(item['video_url']) ?? 
                     getVal(item['video_link']) ?? 
                     getVal(item['video']) ?? 
                     getVal(raw['video_url']) ?? 
                     getVal(raw['video_id']) ?? 
                     getVal(raw['video_link']);
    
    if (videoUrl != null) return true;

    // 4. Fallback for Introduction lessons
    final title = (item['lesson_title'] ?? item['title'] ?? '').toString().toLowerCase();
    if (title.contains('intro') || title.contains('introduction')) return true;
    
    return false;
  }

  // Show congratulations dialog when course is completed
  void _showCongratulationsDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.celebration, color: Colors.amber, size: 32),
            SizedBox(width: 12),
            Text('🎉 Congratulations!'),
          ],
        ),
        content: const Text(
          'Great job! You\'ve successfully completed the course. '
          'Keep learning and growing 🚀\n\n'
          'You can now download your certificate!',
          style: TextStyle(fontSize: 16, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _downloadCertificate();
            },
            icon: const Icon(Icons.download),
            label: const Text('Download Certificate'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
  // Helper to convert curriculum map to OnlineExam object
  OnlineExam? _mapToOnlineExam(Map<String, dynamic> item) {
    
    final raw = item['raw'];
    if (raw == null || raw is! Map) {
      
      return null;
    }
    
    // Create a mutable copy to populate missing fields
    final data = Map<String, dynamic>.from(raw as Map);
    
    // Ensure required fields exist by mapping from alternative keys
    // Item['id'] from _parseItems is already robust, but we want the one from raw if possible
    
    // ID mapping - CRITICAL: Follow User's Detailed Quiz ID Flow
    // Helper to validate ID strings
    bool isValidId(dynamic id) {
      if (id == null) return false;
      final s = id.toString().trim().toLowerCase();
      return s.isNotEmpty && s != '0' && s != 'null' && s != 'undefined';
    }

    final itemData = Map<String, dynamic>.from(item);
  
  // Capture IDs but DO NOT overwrite the main 'id' if possible
  final recordId = itemData['id']?.toString();
  
  // Prepare data for OnlineExam
  final itemType = item['type']?.toString().toLowerCase();

  // If we already have a functional ID in the raw data, keep it.
  // Otherwise, use the item ID as the primary.
  if (!isValidId(data['id'])) {
    data['id'] = recordId ?? '0';
  }
  
  data['is_quiz'] = (itemType == 'quiz') ? '1' : '0';
  
  // Create rawExam with explicit item_id and functional id mapping
  data['rawExam'] = {
    ...itemData,
    if (recordId != null) 'record_id': recordId,
    // Add all potential functional IDs to rawExam for Candidate ID search
    'quiz_id': data['quiz_id'] ?? itemData['quiz_id'] ?? itemData['quiz id'] ?? itemData['course_quizzes_id'] ?? itemData['online_quiz_id'] ?? itemData['lesson_quiz_id'],
    'exam_id': data['course_exam_id'] ?? data['exam_id'] ?? itemData['exam_id'] ?? itemData['onlineexam_id'] ?? itemData['course_exam_id'] ?? itemData['online_exam_id'],
    'online_exam_id': data['course_exam_id'] ?? itemData['online_exam_id'] ?? itemData['course_exam_id'] ?? itemData['onlineexam_id'],
    'course_exam_id': data['course_exam_id'] ?? itemData['course_exam_id'],
    'course_assignment_id': data['course_assignment_id'] ?? itemData['course_assignment_id'],
  };
    
    // CRITICAL: Preserve original item ID for fallback logic
    // We add it as 'item_id' so it's not overwritten by the mapped 'id'
    if (item['id'] != null) {
      data['item_id'] = item['id'].toString();
    }
    
    // Title mapping
    if (data['exam'] == null || data['exam'].toString().isEmpty) {
        data['exam'] = item['title']?.toString() ?? 
                       data['title']?.toString() ?? 
                       data['course_exam_name']?.toString() ?? 
                       data['exam_title']?.toString() ?? 
                       'Untitled Exam';
    }
    
    // Description
    if (data['description'] == null) {
        data['description'] = data['instruction']?.toString() ?? '';
    }

    // Duration
    if (data['duration'] == null || data['duration'].toString().isEmpty || data['duration'] == '00:00:00') {
         data['duration'] = item['duration']?.toString() ?? '00:00:00';
    }
    
    // onlineexam_student_id
    // This is critical for submission. 
    // If the API doesn't return it, we might be in trouble for submission.
    // However, sometimes 'id' IS the student-exam link ID (especially in 'my exams').
    // In curriculum, 'lesson_quiz_id' might be the link.
    if (data['onlineexam_student_id'] == null) {
         data['onlineexam_student_id'] = data['id']?.toString() ?? '';
    }

    // Fill other required fields with safe defaults to satisfy FromJson
    data.putIfAbsent('session_id', () => '');
    data.putIfAbsent('attempt', () => '0');
    data.putIfAbsent('exam_from', () => DateTime.now().toString());
    data.putIfAbsent('exam_to', () => DateTime.now().add(const Duration(days: 365)).toString());
    
    // Determine quiz mode
    data.putIfAbsent('is_quiz', () => (itemType == 'quiz') ? '1' : '0');
    
    data.putIfAbsent('passing_percentage', () => '0');
    data.putIfAbsent('publish_result', () => '0');
    data.putIfAbsent('answer_word_count', () => '0');
    data.putIfAbsent('is_active', () => '1');
    data.putIfAbsent('is_marks_display', () => '1');
    data.putIfAbsent('is_neg_marking', () => '0');
    data.putIfAbsent('is_random_question', () => '0');
    data.putIfAbsent('is_rank_generated', () => '0');
    data.putIfAbsent('publish_exam_notification', () => '0');
    data.putIfAbsent('publish_result_notification', () => '0');
    data.putIfAbsent('created_at', () => '');
    data.putIfAbsent('updated_at', () => '');
    data.putIfAbsent('is_attempted', () => '0');
    data.putIfAbsent('counter', () => '0');
    data.putIfAbsent('total_question', () => '0');
    data.putIfAbsent('total_descriptive', () => '0');

    try {
      return OnlineExam.fromJson(data);
    } catch (e) {
      
      return null;
    }
  }
}

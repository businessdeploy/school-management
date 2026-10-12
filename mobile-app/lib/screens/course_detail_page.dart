import 'dart:io'; 
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/url_manager.dart';
import '../utils/dynamic_api_headers.dart'; // Added
import '../providers/app_config_provider.dart';
import 'download_center_page.dart';
import 'online_exam_page.dart';
import 'course_payment_page.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'course_performance_page.dart';
import '../models/online_exam.dart';
import 'exam_taking_page.dart';
import 'online_course/course_assessment_detail_page.dart';
import 'online_course/online_course_assignment_page.dart';
import '../services/api/course_api.dart';


class CourseDetailPage extends StatefulWidget {
  final Map<String, dynamic> course;

  const CourseDetailPage({super.key, required this.course});

  @override
  State<CourseDetailPage> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends State<CourseDetailPage> {
  Map<String, dynamic>? courseDetails;
  List<Map<String, dynamic>> reviews = [];
  Map<String, dynamic>? studentReview;
  List<Map<String, dynamic>> curriculum = [];
  bool isLoading = true;
  String? error;
  YoutubePlayerController? _youtubeController;
  final ScrollController _scrollController = ScrollController();
  
  // Debug info
  String? curriculumRawData;
  String? curriculumCurl;


  /// Remove basic HTML tags/entities from text so UI shows clean content.
  String _cleanHtmlText(String htmlText) {
    if (htmlText.isEmpty) return htmlText;
    return htmlText
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Parse a review map into a DateTime for sorting (latest first).
  /// Tries multiple common fields: updated_at, created_at, date, etc.
  DateTime _parseReviewDate(Map<String, dynamic> review) {
    final candidates = [
      review['updated_at'],
      review['updatedAt'],
      review['modified_at'],
      review['created_at'],
      review['createdAt'],
      review['date'],
    ];

    String? raw;
    for (final c in candidates) {
      if (c != null && c.toString().trim().isNotEmpty) {
        raw = c.toString().trim();
        break;
      }
    }

    if (raw == null || raw.isEmpty) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    // Try native parsing first (handles ISO, yyyy-MM-dd, etc.)
    DateTime? parsed = DateTime.tryParse(raw);

    // Handle DD/MM/YYYY or MM/DD/YYYY formats
    if (parsed == null && raw.contains('/')) {
      final parts = raw.split('/');
      if (parts.length == 3) {
        try {
          final p0 = int.parse(parts[0]);
          final p1 = int.parse(parts[1]);
          final year = int.parse(parts[2]);

          // Heuristic: if first part > 12 it's definitely a day (DD/MM/YYYY),
          // otherwise assume API used MM/DD/YYYY and convert accordingly.
          final day = p0 > 12 ? p0 : p1;
          final month = p0 > 12 ? p1 : p0;
          parsed = DateTime(year, month, day);
        } catch (_) {
          // Ignore and fall through
        }
      }
    }

    // Fallback to 0 epoch so entries without proper dates go last
    return parsed ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  @override
  void initState() {
    super.initState();
    _loadCourseDetails();
  }

  @override
  @override
  void dispose() {
    _disposeInlinePlayer();
    _scrollController.dispose();
    super.dispose();
  }

  void _disposeInlinePlayer() {
    _youtubeController?.dispose();
    _youtubeController = null;
  }

  void _initYoutubePlayer(String videoId) {
    _disposeInlinePlayer();
    
    setState(() {
      _youtubeController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          enableCaption: false,
        ),
      );
    });
    
    // Scroll to top to show player
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }




  Future<void> _loadCourseDetails() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final studentId = await AuthService.getStudentId();
      final courseId = widget.course['id']?.toString() ?? '1';

      

      // Base data always starts from the mapped course coming from the list page.
      // This already contains instructor_name, instructor_id and last_updated.
      Map<String, dynamic> mergedDetails =
          Map<String, dynamic>.from(widget.course);

      // Try to load additional course details from API and merge them in.
      try {
        final detailsResponse = await ApiService.getCourseDetail(
          courseId,
          studentId,
        );
        

        // Handle various response structures
        if (detailsResponse['course'] is Map <String, dynamic>) {
             mergedDetails.addAll(detailsResponse['course']);
        } else if (detailsResponse['course_detail'] is Map<String, dynamic>) {
             // Logs showed 'course_detail' key
             mergedDetails.addAll(detailsResponse['course_detail']);
        } else {
             mergedDetails.addAll(detailsResponse);
        }
        
      } catch (e) {
        
      }

      // Ensure our critical fields are still present after merge.
      mergedDetails['instructor_name'] ??=
          widget.course['instructor_name'] ?? 'Unknown Instructor';
      mergedDetails['instructor_id'] ??=
          widget.course['instructor_id'] ?? '0000';
      mergedDetails['last_updated'] ??=
          widget.course['last_updated'] ?? 'N/A';

      courseDetails = mergedDetails;
      
      // DEBUG: Log all course data fields to identify purchase/completion status fields
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      

      // Try to load reviews (this might fail)
      try {
        final reviewsResponse = await ApiService.getCourseReviews(courseId);
        
        
        final reviewList = reviewsResponse['reviews'] ?? 
                           reviewsResponse['result_array'] ?? 
                           reviewsResponse['data'];
                           
        if (reviewList != null && reviewList is List) {
           reviews = List<Map<String, dynamic>>.from(reviewList);
        } else {
           reviews = [];
        }
        

        // Sort reviews by updated/created date DESC so latest feedback appears first
        reviews.sort((a, b) {
          final dateA = _parseReviewDate(a);
          final dateB = _parseReviewDate(b);
          return dateB.compareTo(dateA);
        });
        
        // Deduplicate: Keep only the latest review per user
        final uniqueReviews = <Map<String, dynamic>>[];
        final seenUsers = <String>{};
        
        for (final review in reviews) {
          // Identify user by ID or Name
          final userId = review['student_id']?.toString() ?? 
                         review['user_id']?.toString() ?? 
                         review['rating_provider_id']?.toString();
                         
          final userName = review['rating_provider_name']?.toString() ?? 
                           review['user_name']?.toString() ?? 
                           review['name']?.toString();
                           
          final key = (userId != null && userId.isNotEmpty && userId != '0') 
              ? 'id:$userId' 
              : (userName != null && userName.isNotEmpty) 
                  ? 'name:$userName' 
                  : null;
                  
          if (key != null) {
            if (!seenUsers.contains(key)) {
              seenUsers.add(key);
              uniqueReviews.add(review);
            }
          } else {
            // If we can't identify the user, keep the review (or maybe discard? keeping for safety)
            uniqueReviews.add(review);
          }
        }
        reviews = uniqueReviews;

        // Find current student's review
        try {
          final sId = await AuthService.getStudentId();
          studentReview = reviews.firstWhere(
            (r) => r['student_id']?.toString() == sId || r['user_id']?.toString() == sId,
            orElse: () => {},
          );
          if (studentReview!.isEmpty) studentReview = null;
          if (studentReview != null) {
            
          }
        } catch (e) {
          
        }
      } catch (e) {
        
        reviews = []; 
      }

      // Try to load curriculum (this might fail)
      try {
        
        
        
        
        final curriculumResponse = await ApiService.getCourseCurriculum(
          courseId,
        );
        
        
        // Store debug info for on-screen transparency
        setState(() {
          curriculumRawData = curriculumResponse['debug_raw_body']?.toString();
          curriculumCurl = curriculumResponse['debug_curl']?.toString();
        });

        final curriculumList = curriculumResponse['curriculum'] ?? 
                               curriculumResponse['sectionList'] ?? 
                               curriculumResponse['sections'] ??
                               curriculumResponse['data'];

        if (curriculumList != null && curriculumList is List) {
            final List<Map<String, dynamic>> processedCurriculum = [];
            
            for (final section in curriculumList) {
              if (section is! Map) continue;
              final sectionMap = Map<String, dynamic>.from(section);
              
              // Merge all possible item sources
              final List<dynamic> mergedItems = [];
              final itemSources = [
                sectionMap['items'],
                sectionMap['lessons'],
                sectionMap['topics'],
                sectionMap['rows'],
                sectionMap['lesson_quiz'],
                sectionMap['content'],
              ];

              for (final source in itemSources) {
                if (source is List) {
                  mergedItems.addAll(source);
                } else if (source is Map) {
                  mergedItems.addAll(source.values);
                }
              }
              
              // Deduplicate items by ID
              final Map<String, dynamic> uniqueItems = {};
              for (final item in mergedItems) {
                if (item is! Map) continue;
                final itemId = (item['id'] ?? item['lesson_quiz_id'] ?? item['lesson_id'] ?? item['quiz_id'] ?? item['exam_id'] ?? item['assignment_id'] ?? item['item_id'])?.toString() ?? '';
                
                if (itemId.isNotEmpty) {
                  // Keep the one with status/progress if duplicate exists
                  final status = item['status'] ?? item['progress'] ?? item['is_completed'];
                  final hasStatus = status == 1 || status == '1' || status == true || status == 'true';
                  
                  if (!uniqueItems.containsKey(itemId) || hasStatus) {
                    uniqueItems[itemId] = item;
                  }
                } else {
                  final mockId = 'detail_mock_${item['title'] ?? item['name']}_${item['type']}';
                  uniqueItems[mockId] = item;
                }
              }
              
              sectionMap['items'] = uniqueItems.values.toList();
              processedCurriculum.add(sectionMap);
            }
            
            curriculum = processedCurriculum;
            
        } else {
            curriculum = [];
        }
      } catch (e) {
        
        curriculum = [];
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      
      setState(() {
        isLoading = false;
        error = e.toString();
        // Preserve minimal data from list item so page can still render basics
        courseDetails = widget.course;
        reviews = [];
        curriculum = [];
      });
    }
  }

  Future<String?> _resolveVideoUrl(dynamic videoData) async {
    final baseUrl = await UrlManager.getBaseUrl();

    String? normalizeUrl(String? raw) {
      if (raw == null) return null;
      var url = raw.trim();
      if (url.isEmpty || url.toLowerCase() == 'null') return null;

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

    // Check for explicit video_id first, as it's often more reliable for YouTube
    if (videoData is Map<String, dynamic>) {
       final videoId = videoData['video_id']?.toString();
       if (videoId != null && videoId.isNotEmpty && videoId != 'null') {
          // If it looks like a YouTube ID (approximate check), return a YouTube URL
          final youtubeIdRegex = RegExp(r'^[A-Za-z0-9_-]{10,}$');
          if (youtubeIdRegex.hasMatch(videoId)) {
             return 'https://www.youtube.com/watch?v=$videoId';
          }
       }
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
      'url',
      'link',
      'lesson_url',
      'course_url',
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

  String? _extractYoutubeId(String url) {
    return YoutubePlayer.convertUrlToId(url);
  }

  String _calculateTotalDuration() {
    if (curriculum.isEmpty) return '00:00:00';

    int totalSeconds = 0;

    for (var section in curriculum) {
       // items might be under 'items', 'lessons', 'content', or 'lesson_quiz'
       final items = section['items'] ?? section['lessons'] ?? section['content'] ?? section['lesson_quiz'];
       if (items is List) {
         for (var item in items) {
           final type = item['type']?.toString().toLowerCase() ?? '';
           // Count lessons, videos, quizzes, and exams if they have duration
           if (type == 'lesson' || type == 'video' || type == 'quiz' || type == 'exam') {
              final durationStr = item['duration']?.toString() ?? '00:00:00';
              totalSeconds += _parseDurationToSeconds(durationStr);
           }
         }
       }
    }

    if (totalSeconds == 0) return '00:00:00';
    
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  int _parseDurationToSeconds(String duration) {
     if (duration.isEmpty) return 0;
     try {
       final parts = duration.split(':');
       if (parts.length == 3) {
         return int.parse(parts[0]) * 3600 + int.parse(parts[1]) * 60 + int.parse(parts[2]);
       } else if (parts.length == 2) {
         return int.parse(parts[0]) * 60 + int.parse(parts[1]);
       } else {
         // Maybe just minutes or seconds? Assume minutes if single number
         return (int.tryParse(duration) ?? 0) * 60;
       }
     } catch (_) {}
     return 0;
  }


  Future<void> _handleCurriculumItemTap(Map<String, dynamic> item) async {
    final type = item['type']?.toString().toLowerCase() ?? '';
    final itemId = item['id']?.toString() ?? 
                   item['item_id']?.toString() ?? 
                   item['lesson_id']?.toString() ?? 
                   item['quiz_id']?.toString() ?? 
                   item['exam_id']?.toString() ?? 
                   item['assignment_id']?.toString() ?? '';
    final itemTitle = item['title']?.toString() ?? 'Item';
    
    
    
    
    
    

    switch (type) {
      case 'lesson':
      case 'video':
        // For lessons, try to resolve and launch video URL
        String? resolvedUrl;
        resolvedUrl = await _resolveVideoUrl(item);
        if (resolvedUrl == null && courseDetails != null) {
          resolvedUrl = await _resolveVideoUrl(courseDetails);
        }
        resolvedUrl ??= await _resolveVideoUrl(widget.course);
        
        if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
           // Check if it's a YouTube video
           final youtubeId = _extractYoutubeId(resolvedUrl);
           if (youtubeId != null) {
             
             _initYoutubePlayer(youtubeId);
           } else {
             await _launchVideoUrl(resolvedUrl);
           }
        } else {
          // If no video URL, navigate to lesson detail page if available
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Opening lesson: $itemTitle'),
            ),
          );
        }
        break;

        
      case 'quiz':
      case 'exam':
        // Navigate to specific exam/quiz detail page with item data
        
        
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
          
          if (isValidId(item['quiz_id'])) {
             quizId = item['quiz_id'].toString();
          } else if (isValidId(item['quiz id'])) {
             quizId = item['quiz id'].toString();
          } else if (isValidId(item['quizid'])) {
             quizId = item['quizid'].toString();
          } else if (isValidId(item['online_quiz_id'])) {
             quizId = item['online_quiz_id'].toString();
          } else if (isValidId(item['lesson_quiz_id'])) {
             quizId = item['lesson_quiz_id'].toString();
          } else if (isValidId(item['course_quizzes_id'])) {
             quizId = item['course_quizzes_id'].toString();
          } else {
             // Fallback to record ID only if no specific quiz_id is found
             quizId = item['id']?.toString();
          }
                         
          if (quizId == null || quizId.isEmpty) {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text('Invalid Quiz ID configuration')),
             );
             return;
          }
          
          if (!mounted) return;
          
          // Use NEW dedicated page
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CourseAssessmentDetailPage(
                item: {
                  ...item,
                  'quiz_id': quizId, // Ensure resolved ID is passed
                },
                courseTitle: courseDetails?['title']?.toString() ?? 'Course',
              ),
            ),
          );
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
              assignment: item,
              studentId: studentId,
            ),
          ),
        );
        break;
        
      default:
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Opening: $itemTitle'),
          ),
        );
    }
  }

  Future<void> _launchVideoUrl(String url) async {
    if (url.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No video available for this lesson')),
      );
      return;
    }

    
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid video url')),
      );
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
    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open video')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Course Details',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: const Color(0xFF6A1B9A), // Purple header color
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Text(
                    'Failed to load course details: $error',
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              : SingleChildScrollView(
                  controller: _scrollController,
                  child: Column(

                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderSection(),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             _buildCourseTitleAndDescription(),
                            const SizedBox(height: 24),
                            _buildInstructorDetails(),
                            const SizedBox(height: 24),
                            _buildCourseInfo(),
                            const SizedBox(height: 24),
                            // SECTION ORDER FIX: What will I learn → Curriculum → Reviews
                            _buildWhatWillILearnSection(),
                            const SizedBox(height: 24),
                            _buildCurriculumSection(),
                            const SizedBox(height: 24),
                            _buildCertificateSection(),
                            const SizedBox(height: 24),
                            _buildReviewsSection(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
      bottomNavigationBar: !isLoading && error == null && !_isCoursePurchased() ? _buildBottomDock() : null,
    );
  }

  Widget _buildBottomDock() {
    final courseData = courseDetails ?? widget.course;
    
    // Check purchase status and payment gateway availability
    final isPurchased = _isCoursePurchased();
    final payMethod = courseData['pay_method'];
    final isPaymentGatewayEnabled = payMethod == 1 || payMethod == '1';
    
    // Price logic
    final isFree = courseData['free_course'] == '1' || courseData['free_course'] == 1;
    final price = courseData['price']?.toString() ?? '0.00';
    final discount = courseData['discount']?.toString();
    
    // Calculate final price if discount exists
    String displayPrice = isFree ? 'Free' : '\$$price';
    String? originalPrice;
    
    if (!isFree && discount != null && discount != '0' && discount != '0.00') {
        try {
            double p = double.parse(price);
            double d = double.parse(discount);
            // Assuming discount is a percentage or fixed amount? 
            // Usually API returns final price or we calculate. 
            // Only 'price' and 'discount' fields are standard. 
            // Let's assume 'discount' is the percentage off or the actual discounted price?
            // Checking common patterns: often 'price' is original, 'discount' might be % or fixed.
            // But usually there is a 'selling_price' or similar. 
            // Safe bet: Show price. If discount exists, show it.
            // For now, let's just show Price. If user needs specific calc, we can adjust.
            // Screenshot shows "$108.00" (large) and "$120.00" (crossed out).
            
            // Let's blindly assume price is selling price and we might calculate original if needed, 
            // OR price is original and we apply discount.
            // Let's rely on data:
            // If API has 'price' and 'discount', usually price is the selling price? No, usually price is base.
            // Let's assume price is the main price to pay.
        } catch (_) {}
    }
    
    // Rating logic
    final ratingCount = reviews.length;
    double averageRating = 0;
    if (reviews.isNotEmpty) {
      double total = 0;
      for (var r in reviews) {
        final val = r['rating'] ?? r['rate'] ?? '0';
        total += (val is int ? val.toDouble() : double.tryParse(val.toString()) ?? 0.0);
      }
      averageRating = total / reviews.length;
    }
    
    
    
    
    

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pricing',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                displayPrice,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (originalPrice != null) ...[
                const SizedBox(width: 8),
                Text(
                  originalPrice,
                  style: TextStyle(
                    fontSize: 16,
                    decoration: TextDecoration.lineThrough,
                    color: Colors.grey[400],
                  ),
                ),
              ],
              const Spacer(),
              Row(
                children: [
                  ...List.generate(5, (index) {
                    return Icon(
                      index < averageRating.round() ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 20,
                    );
                  }),
                  const SizedBox(width: 4),
                  Text(
                    '($ratingCount Rating)',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                 if (isPurchased) {
                    // Course is purchased - Navigate to Course Performance Page
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CoursePerformancePage(
                          course: courseData,
                        ),
                      ),
                    );
                 } else {
                    // Check if payment gateway is enabled
                    if (isPaymentGatewayEnabled) {
                      // Show payment page
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CoursePaymentPage(course: courseData),
                        ),
                      ).then((success) {
                        if (success == true) {
                          _loadCourseDetails();
                        }
                      });
                    } else {
                      // Payment gateway disabled - Show message
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Payment method is not available for this course'),
                          backgroundColor: Colors.orange,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                 }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isPurchased ? Colors.green[600] : Colors.green[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: Text(
                isPurchased 
                    ? 'Start Lesson' 
                    : 'Buy Now $displayPrice',
                style: const TextStyle(
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
  
  // Helper to check purchase status (reused logic or need to fetch/store it)
  bool _isCoursePurchased() {
    final courseData = courseDetails ?? widget.course;
    
    // PRIMARY CHECK: paidstatus field (1 = purchased, 0 = not purchased)
    final paidstatus = courseData['paidstatus'];
    if (paidstatus == 1 || paidstatus == '1') {
      
      return true;
    }
    
    // Check if it's a free course
    final isFree = courseData['is_free'] == true || 
                   courseData['free_course'] == '1' || 
                   courseData['free_course'] == 1;
    if (isFree) {
      
      return true;
    }
    
    // Fallback checks for other possible purchase indicators
    final paid_status = courseData['paid_status'];
    final isPurchased = courseData['is_purchased'];
    final purchaseStatus = courseData['purchase_status'];
    final status = courseData['status'];
    final paymentStatus = courseData['payment_status'];
    final enrolled = courseData['enrolled'] ?? courseData['is_enrolled'];

    bool flagIsTrue(dynamic value) {
      if (value == null) return false;
      final s = value.toString().toLowerCase().trim();
      if (s.isEmpty || s == '0' || s == 'no' || s == 'false' || s == 'unpaid') {
        return false;
      }
      return true;
    }

    
    
    
    
    
    

    if (flagIsTrue(paid_status)) {
      
      return true;
    }
    if (flagIsTrue(isPurchased)) {
      
      return true;
    }
    if (flagIsTrue(purchaseStatus)) {
      
      return true;
    }
    if (flagIsTrue(paymentStatus)) {
      
      return true;
    }
    if (flagIsTrue(enrolled)) {
      
      return true;
    }

    if (status != null) {
      final s = status.toString().toLowerCase().trim();
      if (s == 'purchased' || s == 'paid' || s == 'active' || s == 'completed' || s == 'success') {
        
        return true;
      }
    }

    
    return false;
  }


  Widget _buildHeaderSection() {
    if (_youtubeController != null) {
      return Container(
        width: double.infinity,
        color: Colors.black,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: YoutubePlayer(
            controller: _youtubeController!,
            showVideoProgressIndicator: true,
            progressIndicatorColor: const Color(0xFF6A1B9A),
            onEnded: (metaData) {
               // Optional: Auto-play next or close
            },
          ),
        ),
      );
    }

    return FutureBuilder<String?>(
      future: _resolveVideoUrl(courseDetails ?? widget.course),
      builder: (context, snapshot) {
        final videoUrl = snapshot.data;
        // Even if no video, show the purple header skeleton
        
        return Container(
          width: double.infinity,
          height: 250, // Approximate height from screenshot
          decoration: const BoxDecoration(
             color: Color(0xFF6A1B9A), // Purple
             borderRadius: BorderRadius.only(
               bottomLeft: Radius.circular(20),
               bottomRight: Radius.circular(20),
             )
          ),
          child: Stack(
            children: [
               Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                    // Course Title in Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        courseDetails?['title']?.toString() ?? 'Course Title',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Play Button
                    GestureDetector(
                      onTap: () {
                         if (videoUrl != null) {
                             // Check for inline playback first
                             final youtubeId = _extractYoutubeId(videoUrl);
                             if (youtubeId != null) {
                               _initYoutubePlayer(youtubeId);
                             } else {
                               _launchVideoUrl(videoUrl);
                             }
                         } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('No preview video available')),
                            );
                         }
                      },
                      child: Container(
                         padding: const EdgeInsets.all(16),
                         decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                         ),
                         child: const Icon(Icons.play_arrow, size: 40, color: Color(0xFF6A1B9A)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Watch on YouTube button
                    if (videoUrl != null)
                        ElevatedButton.icon(
                          onPressed: () {
                             final youtubeId = _extractYoutubeId(videoUrl);
                             if (youtubeId != null) {
                               _initYoutubePlayer(youtubeId);
                             } else {
                               _launchVideoUrl(videoUrl);
                             }
                          },
                          icon: const Icon(Icons.play_arrow, color: Colors.white),
                          label: const Text('Watch on YouTube'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red, // YouTube Red
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                               borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                 ],
               ),
            ],
          ),
        );
      },
    );
  }


  // Renamed and updated from _buildCourseDescription
  Widget _buildCourseTitleAndDescription() {
    final rawDescription = courseDetails?['description']?.toString() ?? '';
    final cleanDescription = rawDescription.isNotEmpty
        ? _cleanHtmlText(rawDescription)
        : 'Description not available.';
    
    // Screenshot shows Title again, then Description
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          courseDetails?['title']?.toString() ?? 'Course Title',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          cleanDescription,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildInstructorDetails() {
    final courseData = courseDetails ?? widget.course;
    final isPurchased = _isCoursePurchased();
    
    
    
    
    
    
    // Get course info for the card
    final classList = courseData['class']?.toString() ?? '';
    final lessonTitle = courseData['lesson']?.toString() ?? courseData['title']?.toString() ?? '';
    final quizCount = courseData['quiz_count']?.toString() ?? '0';
    final examCount = courseData['exam_count']?.toString() ?? '0';
    final assignmentCount = courseData['assignment_count']?.toString() ?? '0';
    // Duration logic
    String duration = courseData['total_hour_count']?.toString() ?? 
                     courseData['total_duration']?.toString() ??
                     courseData['duration']?.toString() ?? '';
    // If duration is missing or zero, calculate from curriculum
    if (duration.isEmpty || duration == '00:00:00' || duration == '0' || duration == 'null') {
      duration = _calculateTotalDuration();
    }
    if (duration.isEmpty) duration = '00:00:00';
    final bool showDuration = duration != '00:00:00';
    
    // Rating logic
    final ratingCount = reviews.length;
    double averageRating = 0;
    if (reviews.isNotEmpty) {
      double total = 0;
      for (var r in reviews) {
        final val = r['rating'] ?? r['rate'] ?? '0';
        total += (val is int ? val.toDouble() : double.tryParse(val.toString()) ?? 0.0);
      }
      averageRating = total / reviews.length;
    }
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.grey[200],
                backgroundImage:
                    (courseDetails?['instructor_image'] != null &&
                        (courseDetails?['instructor_image'].toString().isNotEmpty ??
                            false))
                    ? NetworkImage(courseDetails!['instructor_image'].toString())
                    : null,
                child:
                    (courseDetails?['instructor_image'] == null ||
                        (courseDetails?['instructor_image'].toString().isEmpty ??
                            true))
                    ? const Icon(Icons.person, color: Colors.grey, size: 30)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      courseDetails?['instructor_name']?.toString() ??
                          'Unknown Instructor',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '(${courseDetails?['instructor_id']?.toString() ?? '0000'})',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Last Updated: ${_formatDateOnly(courseDetails?['last_updated']?.toString())}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              // Rate This button - ONLY if purchased
              if (isPurchased)
                TextButton(
                  onPressed: _showRatingDialog,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: const Text(
                    'Rate This',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          
          // Course info section
          const SizedBox(height: 16),
          if (classList.isNotEmpty)
            _buildInfoRow(Icons.class_, classList),
          if (lessonTitle.isNotEmpty)
            _buildInfoRow(Icons.play_circle_outline, lessonTitle),
          if (Provider.of<AppConfigProvider>(context, listen: false).isQuizEnabled && quizCount != '0')
            _buildInfoRow(Icons.help_outline, 'Quiz $quizCount'),
          if (Provider.of<AppConfigProvider>(context, listen: false).isExamEnabled && examCount != '0')
            _buildInfoRow(Icons.wifi, 'Exam $examCount'),
          if (Provider.of<AppConfigProvider>(context, listen: false).isAssignmentEnabled && assignmentCount != '0' && assignmentCount != 'null')
            _buildInfoRow(Icons.assignment, 'Assignment $assignmentCount'),
          if (showDuration)
            _buildInfoRow(Icons.access_time, '$duration Hrs'),
          
          // Rating stars
          const SizedBox(height: 8),
          Row(
            children: [
              ...List.generate(5, (index) {
                return Icon(
                  index < averageRating.round() ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 18,
                );
              }),
              const SizedBox(width: 8),
              Text(
                '($ratingCount Rating)',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          
          // Start Lesson button (only for purchased courses)
          if (isPurchased) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CoursePerformancePage(
                        course: courseData,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Start Lesson',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
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

  Widget _buildActionButtons() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _showRatingDialog,
          icon: Icon(Icons.star_rounded, size: 26, color: Colors.amber[700]),
          label: Text(
            'Course Rating',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.grey[800],
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: Colors.grey[300]!, width: 2),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: Colors.grey[50],
          ),
        ),
      ),
    );
  }


  void _showRatingDialog() {
    int selectedRating = studentReview != null 
        ? int.tryParse(studentReview!['rating']?.toString() ?? '5') ?? 5 
        : 5;
    final TextEditingController commentController = TextEditingController(
      text: studentReview != null 
          ? studentReview!['review']?.toString() ?? studentReview!['comment']?.toString() ?? '' 
          : ''
    );
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Rate this Course'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(
                        index < selectedRating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 32,
                      ),
                      onPressed: () {
                        setState(() {
                          selectedRating = index + 1;
                        });
                      },
                    );
                  }),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: commentController,
                  maxLines: 3,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: InputDecoration(
                    labelText: 'Comments *',
                    hintText: 'Share your experience...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a comment';
                    }
                    if (value.trim().length < 5) {
                      return 'Comment is too short';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) {
                        return;
                      }
                      setState(() => isSubmitting = true);

                      try {
                        final studentId = await AuthService.getStudentId();
                        final courseId = widget.course['id']?.toString() ?? '';

                        final response = await ApiService.addCourseRating(
                          courseId: courseId,
                          studentId: studentId,
                          rating: selectedRating.toString(),
                          comment: commentController.text,
                          reviewId: studentReview?['id']?.toString(),
                        );

                        if (!mounted) return;

                        if (response['status'] == 1 ||
                            response['status'] == '1') {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Rating submitted successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          _loadCourseDetails(); // Refresh details to show new review
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(response['message'] ??
                                  'Failed to submit rating'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => isSubmitting = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseInfo() {
    // Get course data from courseDetails or widget.course
    final courseData = courseDetails ?? widget.course;
    
    final classInfo = courseData['class']?.toString() ?? 
                     courseData['class_info']?.toString() ?? '';
    final sectionCount = courseData['total_section']?.toString() ??
                        courseData['section_count']?.toString() ??
                        (curriculum.isNotEmpty ? curriculum.length.toString() : '0');
    final lessonCount = courseData['total_lesson']?.toString() ?? 
                       courseData['lesson_count']?.toString() ?? '0';
    final quizCount = courseData['quiz_count']?.toString() ?? '0';
    final examCount = courseData['exam_count']?.toString() ?? '0';
    final assignmentCount = courseData['assignment_count']?.toString() ?? '0';
    String duration = courseData['total_hour_count']?.toString() ?? 
                    courseData['total_duration']?.toString() ?? 
                    courseData['duration']?.toString() ??
                    '00:00:00';
                    
    // Calculate duration from curriculum if API duration is empty or zero
    if (duration == '00:00:00' || duration.isEmpty || duration == 'null') {
      duration = _calculateTotalDuration();
    }
    
    // items list for grid - Filter out empty/zero items
    final items = <Map<String, dynamic>>[];
    
    // Only show Class info if available
    if (classInfo.isNotEmpty && classInfo != 'null') {
      items.add({'icon': Icons.book, 'text': classInfo});
    }
    
    // Only show Section count
    if (sectionCount != '0' && sectionCount != 'null') {
      items.add({'icon': Icons.list, 'text': 'Section $sectionCount'});
    }
    
    // Only show Lesson count
    if (lessonCount != '0' && lessonCount != 'null') {
      items.add({'icon': Icons.play_arrow, 'text': 'Lesson $lessonCount'});
    }
    
    // Only show Quiz if count > 0
    if (quizCount != '0' && quizCount != 'null' && Provider.of<AppConfigProvider>(context, listen: false).isQuizEnabled) {
      items.add({'icon': Icons.quiz, 'text': 'Quiz $quizCount'});
    }
    
    // Only show Exam if count > 0
    if (examCount != '0' && examCount != 'null' && Provider.of<AppConfigProvider>(context, listen: false).isExamEnabled) {
      items.add({'icon': Icons.wifi, 'text': 'Exam $examCount'});
    }
    
    // Only show Assignment if count > 0
    if (assignmentCount != '0' && assignmentCount != 'null' && Provider.of<AppConfigProvider>(context, listen: false).isAssignmentEnabled) {
      items.add({'icon': Icons.assignment, 'text': 'Assignment $assignmentCount'});
    }
    
    // Only show Duration if it's not zero
    if (duration != '00:00:00' && 
        duration != '00:00' && 
        duration != '0' && 
        duration != 'null' && 
        duration.trim().isNotEmpty) {
      items.add({'icon': Icons.access_time, 'text': duration});
    }

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           const Text(
            'Course Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          // 2-column grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
               crossAxisCount: 2,
               childAspectRatio: 5.0, // Adjust for row height
               crossAxisSpacing: 16,
               mainAxisSpacing: 8,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
               final item = items[index];
               return Row(
                  children: [
                     Icon(item['icon'] as IconData, size: 20, color: Colors.grey[600]),
                     const SizedBox(width: 8),
                     Expanded(
                        child: Text(
                          item['text'] as String,
                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                          overflow: TextOverflow.ellipsis,
                        ),
                     ),
                  ],
               );
            },
          ),
        ],
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
     // Legacy helper, kept if referenced elsewhere or can be removed if unused.
     // Since I replaced usage in _buildCourseInfo, it might be unused.
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildCurriculumSection() {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Curriculum For This Course',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          if (curriculum.isEmpty)
            const Text(
              'No curriculum available.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            )
          else
            ...curriculum.map((section) => _buildCurriculumSectionItem(section)),
        ],
    );
  }

  Widget _buildCurriculumSectionItem(Map<String, dynamic> section) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        // border: Border.all(color: Colors.grey[200]!), // Clean look, maybe no border needed
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          backgroundColor: Colors.transparent,
          collapsedBackgroundColor: Colors.grey[100],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          leading: const Icon(Icons.add, color: Colors.grey, size: 20),
          title: Text(
            section['section']?.toString() ?? section['section_title']?.toString() ?? 'Section',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          children: () {
            final provider = Provider.of<AppConfigProvider>(context, listen: false);
            final List<dynamic> allItems = section['items'] as List<dynamic>? ?? 
                                           section['lesson_quiz'] as List<dynamic>? ?? [];
            
            // Filter out items based on feature toggles from Admin
            final List<Map<String, dynamic>> filteredItems = allItems.whereType<Map<String, dynamic>>().where((item) {
              final type = item['type']?.toString().toLowerCase();
              if (type == 'quiz' && !provider.isQuizEnabled) return false;
              if (type == 'exam' && !provider.isExamEnabled) return false;
              if (type == 'assignment' && !provider.isAssignmentEnabled) return false;
              return true;
            }).toList();

            return filteredItems.map(
               (item) => _buildCurriculumItem(item),
            ).toList();
          }(),
        ),
      ),
    );
  }

  Widget _buildCurriculumItem(Map<String, dynamic> item) {
    IconData icon;
    String typeLabel = '';
    Color iconColor = Colors.grey[600]!;
    
    final type = item['type']?.toString().toLowerCase() ?? '';

    switch (type) {
      case 'lesson':
        icon = Icons.play_circle_fill; // More prominent play icon
        iconColor = Colors.orange; // Match web styling
        typeLabel = 'Lesson';
        break;
      case 'quiz':
        icon = Icons.quiz;
        iconColor = Colors.blue; 
        typeLabel = 'Quiz';
        break;
      case 'exam':
        icon = Icons.assignment_turned_in;
        iconColor = Colors.purple;
        typeLabel = 'Exam';
        break;
      case 'assignment':
        icon = Icons.assignment;
        iconColor = Colors.green;
        typeLabel = 'Assignment';
        break;
      default:
        icon = Icons.circle;
        typeLabel = 'Item';
    }
    
    final title = item['title']?.toString() ?? 
                  item['lesson_title']?.toString() ?? 
                  item['assignment_title']?.toString() ?? 
                  item['course_exam_name']?.toString() ?? 
                  item['name']?.toString() ?? 'Item';
    final duration = item['duration']?.toString() ?? '';
    
    // Format duration for display
    String displayDuration = duration;
    if (duration.isNotEmpty) {
       // Try to make it look nicer if it's just raw minutes or seconds
       // If it contains ':', assume it's already HH:MM:SS or MM:SS
       if (!duration.contains(':')) {
          // Check if it's all digits
          if (RegExp(r'^\d+$').hasMatch(duration)) {
             // Assume minutes if < 1000, seconds if large? 
             // Usually API returns formatted string, but if not:
             displayDuration = '$duration Min';
          }
       }
    }

    // Extract detailed fields for Exams and Assignments
    // Note: Keys might vary depending on API, using common likely keys based on screenshot content
    final examFrom = item['exam_from']?.toString();
    final examTo = item['exam_to']?.toString();
    final examDuration = item['duration']?.toString(); // often shared field
    final passingPercentage = item['passing_percentage']?.toString();

    final assignmentDate = item['assignment_date']?.toString();
    final submissionDate = item['submission_date']?.toString();
    final maxMarks = item['max_marks']?.toString();

    return Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 15, color: Colors.black87), // Increased font size
                          children: [
                            TextSpan(text: '$typeLabel: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                            TextSpan(text: title),
                          ],
                        ),
                      ),
                      // Only show duration if video exists
                      if (type == 'lesson' && duration.isNotEmpty && _hasVideo(item))
                         Padding(
                           padding: const EdgeInsets.only(top: 4),
                           child: Text(
                             displayDuration,
                             style: const TextStyle(fontSize: 12, color: Colors.grey),
                           ),
                         ),
                    ],
                  ),
                ),

              ],
            ),
            
            // Exam Details Section
            if (type == 'exam')
              Padding(
                padding: const EdgeInsets.only(left: 32, top: 8), // Indent to align with text
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (examFrom != null) _buildDetailRow('Exam From:', examFrom),
                    if (examTo != null) _buildDetailRow('Exam To:', examTo),
                    if (examDuration != null && examDuration != '00:00:00') _buildDetailRow('Exam Duration:', examDuration),
                    if (passingPercentage != null) _buildDetailRow('Passing Percentage:', passingPercentage),
                  ],
                ),
              ),

            // Assignment Details Section
            if (type == 'assignment')
              Padding(
                padding: const EdgeInsets.only(left: 32, top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (assignmentDate != null) _buildDetailRow('Assignment Date:', assignmentDate),
                    if (submissionDate != null) _buildDetailRow('Submission Date:', submissionDate),
                    if (maxMarks != null) _buildDetailRow('Max Marks:', maxMarks),
                  ],
                ),
              ),
          ],
        ),
      );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           SizedBox(
             width: 140, // Fixed width for labels to align nicely
             child: Text(
               label,
               style: const TextStyle(
                 fontSize: 13,
                 fontWeight: FontWeight.w600,
                 color: Colors.black54,
               ),
             ),
           ),
           Expanded(
             child: Text(
               value,
               style: const TextStyle(
                 fontSize: 13,
                 color: Colors.black87,
               ),
             ),
           ),
        ],
      ),
    );
  }

  Widget _buildReviewsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(top: 8),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reviews',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          if (reviews.isEmpty)
            const Text(
              'No reviews yet.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            )
          else
            ...reviews.map((review) => _buildReviewItem(review)),
        ],
      ),
    );
  }



  String _formatDateOnly(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty || dateStr == 'N/A') return 'N/A';
    
    try {
      DateTime date;
      if (dateStr.contains('/')) {
         final parts = dateStr.split('/');
         if (parts.length == 3) {
             date = DateTime(
               int.parse(parts[2]),
               int.parse(parts[1]),
               int.parse(parts[0]),
             );
         } else {
             date = DateTime.parse(dateStr);
         }
      } else {
         date = DateTime.parse(dateStr);
      }
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      
      return dateStr;
    }
  }
  
  // Update in helper or build method
  Widget _buildReviewItem(Map<String, dynamic> review) {
    // Map API keys to local variables
    final userName = review['rating_provider_name']?.toString() ?? 
                     review['user_name']?.toString() ?? 
                     'Anonymous';
    
    // For image, we need to handle relative vs absolute
    String? userImage = review['image']?.toString() ?? review['user_image']?.toString();
    // The logs showed "uploads/guest_images/..." so it's relative.
    // We can prepend base url if we have it, or use a helper.
    // Let's assume we need to prepend.
    
    final comment = review['review']?.toString() ?? 
                    review['comment']?.toString() ?? 
                    'No review text provided.';
    
    final date = review['date']?.toString() ?? 'N/A';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
           BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 4),
           ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FutureBuilder<String>(
                future: UrlManager.getBaseUrl(),
                builder: (context, snapshot) {
                   final baseUrl = snapshot.data ?? '';
                   String? fullImageUrl;
                   if (userImage != null && userImage.isNotEmpty) {
                      fullImageUrl = userImage.startsWith('http') 
                          ? userImage 
                          : '$baseUrl/$userImage';
                   }
                   
                   return CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: fullImageUrl != null
                        ? NetworkImage(fullImageUrl)
                        : null,
                    child: fullImageUrl == null
                        ? const Icon(Icons.person, color: Colors.grey, size: 24)
                        : null,
                  );
                }
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDateOnly(date),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            comment,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(
              5,
              (index) {
                final rating = double.tryParse(review['rating']?.toString() ?? review['rate']?.toString() ?? '0') ?? 0.0;
                return Icon(
                  index < rating
                      ? Icons.star
                      : Icons.star_border,
                  color: Colors.amber,
                  size: 20,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _isCourseCompleted() {
    final courseData = courseDetails ?? widget.course;
    
    // Check multiple possible completion indicators
    final completionStatus = courseData['completion_status']?.toString().toLowerCase() ?? '';
    final isCompleted = courseData['is_completed'];
    final status = courseData['status']?.toString().toLowerCase() ?? '';
    final progress = courseData['progress']?.toString() ?? '';
    final completionPercentage = courseData['completion_percentage']?.toString() ?? '';
    
    // Check if explicitly marked as completed
    if (completionStatus == 'completed' || 
        completionStatus == 'done' ||
        completionStatus == 'finished') {
      return true;
    }
    
    // Check boolean flag
    if (isCompleted == true || isCompleted == 1 || isCompleted == '1') {
      return true;
    }
    
    // Check status field
    if (status == 'completed' || status == 'done' || status == 'finished') {
      return true;
    }
    
    // Check progress/percentage (100% = completed)
    if (progress == '100' || completionPercentage == '100' || 
        progress == '100%' || completionPercentage == '100%') {
      return true;
    }
    
    return false;
  }

  Future<void> _downloadCertificate() async {
    try {
      final courseData = courseDetails ?? widget.course;
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
         final templateId = courseData['certificate_template_id']?.toString() ?? '';
         final directCertId = courseData['certificate_id']?.toString() ?? '';
         
         if (templateId.isNotEmpty && templateId != 'null') {
             certificateId = templateId;
             
         } else if (directCertId.isNotEmpty && directCertId != 'null') {
             certificateId = directCertId;
             
         } else {
             var certData = courseData['certificate'];
             if (certData is Map) {
                certificateId = certData['id']?.toString() ?? certData['certificate_id']?.toString() ?? '';
                
             } else if (certData != null && certData.toString().isNotEmpty && certData.toString() != 'null') {
                certificateId = certData.toString();
                
             }
         }
      } catch (e) {
         
      }

      
      
      

      // Construct certificate URL
      // Try multiple possible certificate endpoint patterns
      final certificateUrls = <String>[];
      
      // CRITICAL: New endpoint requested by user (POST Required)
      if (certificateId.isNotEmpty && certificateId.toLowerCase() != 'null') {
          certificateUrls.add('$baseUrl/api/webservice/coursedownloadcertificatepdf/$certificateId/$studentId/$courseId');
      } else {
         
         certificateUrls.addAll([
            '$baseUrl/api/webservice/downloadCertificate?course_id=$courseId&student_id=$studentId&role=student',
            '$baseUrl/api/webservice/getCertificate?course_id=$courseId&student_id=$studentId&role=student',
            '$baseUrl/api/webservice/courseCertificate?course_id=$courseId&student_id=$studentId&role=student',
            '$baseUrl/uploads/certificates/$courseId/$studentId.pdf',
            '$baseUrl/uploads/certificates/$studentId/$courseId.pdf',
         ]);
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

                 // Redirect to Download Center after short delay
                 Future.delayed(const Duration(seconds: 2), () {
                   if (mounted) {
                     Navigator.push(
                       context,
                       MaterialPageRoute(builder: (context) => const DownloadCenterPage()),
                     );
                   }
                 });
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
                serverFileName = downloadUrl.split('/').last;
              }

              if (serverFileName.isNotEmpty && serverFileName.endsWith('.pdf')) {
                 if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Certificate generated and downloaded successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );

                    // Redirect to Download Center after short delay
                    Future.delayed(const Duration(seconds: 2), () {
                      if (mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const DownloadCenterPage()),
                        );
                      }
                    });
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

              // Redirect to Download Center after short delay
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const DownloadCenterPage()),
                  );
                }
              });
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
            
            // CRITICAL: Validate if it's actually a PDF (starts with %PDF)
            // and check minimum size to avoid error pages
            if (fileBytes.length < 1000 || !utf8.decode(fileBytes.take(4).toList(), allowMalformed: true).contains('%PDF')) {
               if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Invalid certificate file received. Please contact support.'),
                      backgroundColor: Colors.red,
                    ),
                  );
               }
               return false;
            }

            // If the response is short and looks like JSON, it might be an error even with 200 OK
            if (fileBytes.length < 2000) {
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

  Widget _buildCertificateSection() {
    // Only show certificate section if course is completed
    if (!_isCourseCompleted()) {
      return const SizedBox.shrink();
    }

    final courseData = courseDetails ?? widget.course;
    final courseTitle = courseData['title']?.toString() ?? 
                        courseData['course_title']?.toString() ?? 'Course';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(top: 8),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified, color: Colors.green[600], size: 24),
              const SizedBox(width: 12),
              const Text(
                'Course Completed',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.celebration, color: Colors.green[700], size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Congratulations!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'You have successfully completed "$courseTitle". Download your certificate now!',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
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
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhatWillILearnSection() {
    // Handle outcomes field - can be List or String from API
    List<dynamic> outcomes;
    final outcomesData = courseDetails?['outcomes'];

    if (outcomesData is List) {
      outcomes = outcomesData;
    } else if (outcomesData is String && outcomesData.isNotEmpty) {
      // Try to decode as JSON array
      try {
        final decoded = jsonDecode(outcomesData);
        if (decoded is List) {
          outcomes = decoded;
        } else {
          // If not a list, maybe a single string?
          outcomes = [decoded.toString()];
        }
      } catch (e) {
        // Fallback: Manual parsing if JSON decode fails
        // Remove brackets [] and quotes " '
        String cleaned = outcomesData.replaceAll('[', '').replaceAll(']', '');
        outcomes = cleaned.split(',')
            .map((s) => s.trim().replaceAll('"', '').replaceAll("'", ""))
            .where((s) => s.isNotEmpty)
            .toList();
      }
    } else {
      // Fallback default outcomes
      outcomes = [
        'High School Mathematics',
        'Graphs and Functions',
        'Exponential and Logarithmic Functions',
        'Learn in an Intuitive Fun Graphical Way',
      ];
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(top: 8),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What will I learn?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          ...outcomes.map(
            (outcome) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      outcome.toString(),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
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

  // Helper method to check if a lesson has a video
  bool _hasVideo(Map<String, dynamic> item) {
    final videoUrl = item['video_url']?.toString() ?? 
                     item['video_link']?.toString() ?? 
                     item['video']?.toString() ?? 
                     item['url']?.toString() ?? '';
    
    return videoUrl.isNotEmpty && 
           videoUrl.toLowerCase() != 'null' && 
           videoUrl.toLowerCase() != 'none';
  }


}

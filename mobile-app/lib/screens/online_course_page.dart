import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:provider/provider.dart';
import '../widgets/translated_text.dart';
import '../config/app_config.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/api_image_manager.dart';
import '../utils/url_manager.dart';
import '../providers/app_config_provider.dart';
import 'course_detail_page.dart';
import 'course_performance_page.dart';
import 'payment_webview_page.dart';

class OnlineCoursePage extends StatefulWidget {
  const OnlineCoursePage({super.key});

  @override
  State<OnlineCoursePage> createState() => _OnlineCoursePageState();
}

class _OnlineCoursePageState extends State<OnlineCoursePage> {
  List<Map<String, dynamic>> courses = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadCourseData();
  }

  Future<void> _loadCourseData() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      // Wrap entire operation in timeout to prevent indefinite loading
      await Future(() async {
        final studentId = await AuthService.getStudentId();
        final response = await ApiService.getCourseList(studentId);

        // Debug information
        
        

        // Check different possible keys for course data
        List<Map<String, dynamic>> rawCourses = [];
        if (response['courselist'] != null) {
          rawCourses = List<Map<String, dynamic>>.from(response['courselist']);
          
        } else if (response['course_list'] != null) {
          rawCourses = List<Map<String, dynamic>>.from(response['course_list']);
          
        } else if (response['courses'] != null) {
          rawCourses = List<Map<String, dynamic>>.from(response['courses']);
          
        }

        

        // Map API data to expected format
        List<Map<String, dynamic>> mappedCourses = [];
        for (var course in rawCourses) {
          final mappedCourse = await _mapApiDataToCourse(course);
          mappedCourses.add(mappedCourse);
        }

        setState(() {
          courses = mappedCourses;
          isLoading = false;
        });

        
      }).timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          throw TimeoutException('Course loading timed out after 45 seconds');
        },
      );
    } on TimeoutException {
      
      setState(() {
        isLoading = false;
        error = 'Loading timed out. Please check your connection and try again.';
      });
    } catch (e) {
      
      setState(() {
        isLoading = false;
        error = e.toString();
      });
    }
  }

  String _formatDateOnly(String? dateString) {
    if (dateString == null || dateString.isEmpty || dateString == 'N/A') {
      return 'N/A';
    }

    try {
      // Try parsing YYYY-MM-DD HH:MM:SS format
      DateTime? parsedDate;
      if (dateString.contains(' ')) {
        // Has time component - remove it
        final datePart = dateString.split(' ')[0];
        parsedDate = DateFormat('yyyy-MM-dd').parse(datePart);
      } else {
        // Try parsing as YYYY-MM-DD
        parsedDate = DateFormat('yyyy-MM-dd').parse(dateString);
      }

      // Format as DD/MM/YYYY (remove time)
      return DateFormat('dd/MM/yyyy').format(parsedDate);
    } catch (e) {
      
      // Return original if parsing fails
      return dateString.split(' ')[0]; // At least remove time if present
    }
  }

  Future<Map<String, dynamic>> _mapApiDataToCourse(
    Map<String, dynamic> apiCourse,
  ) async {
    // Reduced logging for better performance

    // Calculate prices using API fields as source of truth
    double parseAmount(dynamic value) {
      if (value == null) return 0.0;
      return double.tryParse(value.toString()) ?? 0.0;
    }

    // Base/original price from API
    final originalPrice = parseAmount(apiCourse['price']);

    // Prefer API-provided final/discounted amounts if present
    double discountedPrice = 0.0;
    final candidates = [
      apiCourse['final_amount'],
      apiCourse['final_price'],
      apiCourse['discounted_price'],
      apiCourse['course_amount'],
    ];
    for (final c in candidates) {
      final v = parseAmount(c);
      if (v > 0) {
        discountedPrice = v;
        break;
      }
    }

    // If no explicit discounted price, fall back to percentage discount
    if (discountedPrice <= 0 && originalPrice > 0) {
      final discountPercent = parseAmount(apiCourse['discount']);
      if (discountPercent > 0) {
        discountedPrice = originalPrice * (1 - (discountPercent / 100));
      } else {
        discountedPrice = originalPrice;
      }
    }

    // Get processed image URLs in parallel for better performance
    final imageResults = await Future.wait([
      ApiImageManager.getInstructorImageUrl(
        apiCourse['image']?.toString(),
      ),
      ApiImageManager.getCourseThumbnailUrl(
        apiCourse['course_thumbnail']?.toString(),
      ),
    ]);
    
    final instructorImageUrl = imageResults[0];
    final courseThumbnailUrl = imageResults[1];

    // Images processed in parallel

    // Format the last updated date (remove time, change format)
    final rawUpdatedDate = apiCourse['updated_date']?.toString() ?? 'N/A';
    final formattedDate = _formatDateOnly(rawUpdatedDate);

    // Calculate progress
    double progress = 0.0;
    if (apiCourse['course_progress'] != null) {
      progress = parseAmount(apiCourse['course_progress']);
      // Normalize to 0.0 - 1.0 if it's 0-100
      if (progress > 1.0) progress /= 100;
    }

    return {
      'id': apiCourse['id']?.toString() ?? '1',
      'title': apiCourse['title']?.toString() ?? 'Course Title',
      'description':
          apiCourse['description']?.toString() ?? 'Course Description',
      'instructor_name':
          '${apiCourse['name']?.toString() ?? 'Unknown'} ${apiCourse['surname']?.toString() ?? 'Instructor'}',
      'instructor_id': apiCourse['staff_employee_id']?.toString() ?? '0000',
      'instructor_image': instructorImageUrl,
      'last_updated': formattedDate,
      'class_info': apiCourse['class']?.toString() ?? 'Class 1',
      'lesson_count': apiCourse['total_lesson']?.toString() ?? '2',
      'quiz_count': apiCourse['quiz_count']?.toString() ?? '0',
      'exam_count': apiCourse['exam_count']?.toString() ?? '0',
      'assignment_count': apiCourse['assignment_count']?.toString() ?? '0',
      'total_duration': apiCourse['total_hour_count']?.toString(),
      'original_price': originalPrice.toStringAsFixed(2),
      'discounted_price': discountedPrice.toStringAsFixed(2),
      'rating_count': apiCourse['totalcourserating']?.toString() ?? 
                      apiCourse['total_rating']?.toString() ?? 
                      apiCourse['rating_count']?.toString() ?? 
                      apiCourse['reviews_count']?.toString() ?? '0',
      'rating': apiCourse['courserating']?.toString() ?? '0.0',
      'course_thumbnail': courseThumbnailUrl,
      'course_url': apiCourse['course_url']?.toString() ?? '',
      'progress': progress,
      // Purchase status fields - preserve all possible variations
      'paidstatus': apiCourse['paidstatus'],
      'paid_status': apiCourse['paid_status'],
      'is_purchased': apiCourse['is_purchased'],
      'purchase_status': apiCourse['purchase_status'],
      'status': apiCourse['status'],
      'free_course': apiCourse['free_course'],
      'is_free': apiCourse['is_free'] ?? (apiCourse['free_course'] == '1' || apiCourse['free_course'] == 1),
      'price': apiCourse['price'],
      'discount': apiCourse['discount'],
      // Certificate fields - ensure they are passed to detail/performance pages
      'certificate': apiCourse['certificate'],
      'certificate_id': apiCourse['certificate_id'],
      'certificate_template_id': apiCourse['certificate_template_id'],
      'has_certificate': apiCourse['has_certificate'],
    };
  }

  @override
  Widget build(BuildContext context) {
    final appConfigProvider = Provider.of<AppConfigProvider>(context);
    final primaryColor = appConfigProvider.primaryColorObj;

    return Scaffold(
      appBar: AppBar(
        title: const TranslatedText(
          'Online Course',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        color: Colors.grey[50],
        child: Column(
          children: [
            // Header with image beside title
            Container(
              padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const TranslatedText(
                          'Your Online Course is here!',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Explore and enroll in courses to enhance your learning journey',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Image.asset(
                    'assets/images/coursepage.jpg',
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      
                      return Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.school,
                          color: Colors.grey,
                          size: 40,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            // Course List
            Expanded(child: _buildCourseList(primaryColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseList(Color primaryColor) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null && courses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 50, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Failed to load courses: $error',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadCourseData,
              child: const TranslatedText('Retry'),
            ),
          ],
        ),
      );
    }

    if (courses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.school, size: 50, color: Colors.grey),
            const SizedBox(height: 16),
            const TranslatedText(
              'No courses available',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadCourseData,
              child: const TranslatedText('Refresh'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: courses.length,
      itemBuilder: (context, index) {
        if (index >= courses.length) return const SizedBox.shrink();
        return _buildCourseCard(courses[index], primaryColor);
      },
    );
  }

  Widget _buildCourseCard(Map<String, dynamic> course, Color primaryColor) {
    if (course.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildMathBackgroundWithOverlay(course),
          _buildCourseDetails(course, primaryColor),
        ],
      ),
    );
  }

  Widget _buildMathBackgroundWithOverlay(Map<String, dynamic> course) {
    return FutureBuilder<String>(
      future: ApiImageManager.getCourseThumbnailUrl(
        course['course_thumbnail']?.toString(),
      ),
      builder: (context, snapshot) {
        final hasThumbnail =
            snapshot.hasData &&
            snapshot.data!.isNotEmpty &&
            snapshot.data != 'null';

        return Container(
          height: 200,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            // Use API thumbnail if available, otherwise use default background
            image: hasThumbnail
                ? DecorationImage(
                    image: NetworkImage(snapshot.data!),
                    fit: BoxFit.cover,
                    onError: (exception, stackTrace) {
                      
                      
                      // Fallback to default background on error
                    },
                  )
                : null,
            color: hasThumbnail ? null : Colors.grey[100],
          ),
          child: Stack(
            children: [
              // Mathematical symbols background (only show if no API thumbnail)
              if (!hasThumbnail)
                Positioned.fill(
                  child: CustomPaint(painter: MathBackgroundPainter()),
                ),
              // Dark overlay with instructor details
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 70, // Increased height to prevent overflow
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      FutureBuilder<String>(
                        future: ApiImageManager.getInstructorImageUrl(
                          course['instructor_image']?.toString(),
                        ),
                        builder: (context, instructorSnapshot) {
                          final hasInstructorImage =
                              instructorSnapshot.hasData &&
                              instructorSnapshot.data!.isNotEmpty &&
                              instructorSnapshot.data != 'null';

                          return CircleAvatar(
                            radius: 18, // Slightly smaller to fit better
                            backgroundColor: Colors.white,
                            backgroundImage: hasInstructorImage
                                ? NetworkImage(instructorSnapshot.data!)
                                : null,
                            child: !hasInstructorImage
                                ? const Icon(
                                    Icons.person,
                                    color: Colors.grey,
                                    size: 20,
                                  )
                                : null,
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min, // Prevent overflow
                          children: [
                            Text(
                              (course['instructor_name']?.toString() ??
                                      'Unknown Instructor')
                                  .replaceAll('na na', 'Unknown Instructor'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '(${course['instructor_id']?.toString() ?? '0000'})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Last Updated ${course['last_updated']?.toString() ?? 'N/A'}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 9,
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
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCourseDetails(Map<String, dynamic> course, Color primaryColor) {
    if (course.isEmpty) {
      return const SizedBox.shrink();
    }

    final rating =
        double.tryParse(course['rating']?.toString() ?? '0') ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Course Title
          Text(
            (course['title']?.toString() ?? 'Course Title').replaceAll(
              'na na',
              'Course Title',
            ),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          // Course Info - Simplified layout
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildInfoItem(
                Icons.class_,
                (course['class_info']?.toString() ?? 'Class 1 (A, B, C, D)')
                    .replaceAll('na na', 'Class 1'),
              ),
              _buildInfoItem(
                Icons.play_arrow,
                'Lesson ${course['lesson_count']?.toString() ?? '2'}',
              ),
              if (Provider.of<AppConfigProvider>(context, listen: false).isQuizEnabled && course['quiz_count'] != null && course['quiz_count'] != '0' && course['quiz_count'] != 'null')
                _buildInfoItem(
                  Icons.quiz,
                  'Quiz ${course['quiz_count']}',
                ),
              if (Provider.of<AppConfigProvider>(context, listen: false).isExamEnabled && course['exam_count'] != null && course['exam_count'] != '0' && course['exam_count'] != 'null')
                _buildInfoItem(
                  Icons.wifi,
                  'Exam ${course['exam_count']}',
                ),
              if (Provider.of<AppConfigProvider>(context, listen: false).isAssignmentEnabled && course['assignment_count'] != null && course['assignment_count'] != '0' && course['assignment_count'] != 'null')
                _buildInfoItem(
                  Icons.assignment,
                  'Assignment ${course['assignment_count']}',
                ),

              if (course['total_duration'] != null &&
                  course['total_duration'].toString().trim() != '00:00:00' &&
                  course['total_duration'].toString().trim() != '00:00' &&
                  course['total_duration'].toString().trim() != '0' &&
                  course['total_duration'].toString().trim() != 'null' &&
                  course['total_duration'].toString().trim().isNotEmpty)
                _buildInfoItem(
                  Icons.access_time,
                  '${course['total_duration']} Hrs',
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Pricing and Rating
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Builder(
                builder: (context) {
                  final appConfigProvider = Provider.of<AppConfigProvider>(context);
                  final currencySymbol = appConfigProvider.selectedCurrencySymbol;

                  double parsePrice(dynamic value) {
                    if (value == null) return 0.0;
                    return double.tryParse(value.toString()) ?? 0.0;
                  }

                  final rawDiscounted = parsePrice(course['discounted_price']);
                  final rawOriginal = parsePrice(course['original_price']);
                  
                  final discounted = appConfigProvider.convertAmount(rawDiscounted);
                  final original = appConfigProvider.convertAmount(rawOriginal);
                  
                  final isFree = rawDiscounted <= 0.0; // Check original base price for free status logic

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isFree)
                        const TranslatedText(
                          'Free',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        )
                      else
                        Text(
                          '$currencySymbol ${discounted.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      if (!isFree && rawOriginal > rawDiscounted)
                        Text(
                          '$currencySymbol ${original.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                    ],
                  );
                },
              ),
              Row(
                children: [
                  Row(
                    children: [
                      ...List.generate(5, (index) {
                        if (index + 1 <= rating) {
                          return const Icon(
                            Icons.star,
                            size: 16,
                            color: Colors.amber,
                          );
                        } else if (index < rating && index + 1 > rating) {
                          return const Icon(
                            Icons.star_half,
                            size: 16,
                            color: Colors.amber,
                          );
                        } else {
                          return const Icon(
                            Icons.star_border,
                            size: 16,
                            color: Colors.grey,
                          );
                        }
                      }),
                    ],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '(${course['rating_count'] ?? 0} Rating)',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress: ${((course['progress'] ?? 0.0) * 100).round()}%',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    '${((course['progress'] ?? 0.0) * 100).round()}%',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: (course['progress'] ?? 0.0) as double,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _navigateToCourseDetails(course),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const TranslatedText(
                      'Course Details',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _buildActionButton(course, primaryColor)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      ],
    );
  }

  void _navigateToCourseDetails(Map<String, dynamic> course) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CourseDetailPage(course: course)),
    );
  }

  Future<void> _navigateToCoursePayment(Map<String, dynamic> course) async {
    final studentId = await AuthService.getStudentId();
    if (studentId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: TranslatedText('Unable to determine your student profile. Please re-login.'),
          ),
        );
      }
      return;
    }

    final courseId = course['id']?.toString() ??
        course['course_id']?.toString() ??
        course['courseId']?.toString() ??
        '';
    if (courseId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: TranslatedText('Course ID missing. Unable to open payment.')),
        );
      }
      return;
    }

    var baseUrl = await UrlManager.getBaseUrl();
    if (baseUrl.isEmpty) {
      baseUrl = await AppConfig.getBaseUrl();
    }

    if (baseUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Base URL is not configured.')),
        );
      }
      return;
    }

    final cleanBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final appConfigProvider = Provider.of<AppConfigProvider>(context, listen: false);
    final currencyCode = appConfigProvider.selectedCurrencyLabel; 
    
    // Resolve final price for payment
    final basePrice = double.tryParse(course['price']?.toString() ?? '0') ?? 0.0;
    final discountedPrice = double.tryParse(course['discounted_price']?.toString() ?? '0') ?? 0.0;
    final finalPrice = discountedPrice > 0 ? discountedPrice : basePrice;
    
    // CRITICAL: Convert the price to the selected currency
    final convertedAmount = appConfigProvider.convertAmount(finalPrice);
    final amountStr = convertedAmount.toStringAsFixed(2);
    
    // Construct the payment URL with query parameters
    String paymentUrl =
        '$cleanBaseUrl/api/course_payment/course_payment/payment/$courseId/$studentId';
        
    final List<String> queryParams = [];
    if (currencyCode.isNotEmpty) {
      queryParams.add('currency=$currencyCode');
    }
    queryParams.add('amount=$amountStr');
    queryParams.add('total=$amountStr');
    
    if (queryParams.isNotEmpty) {
      paymentUrl += '?${queryParams.join('&')}';
    }
            
    final encodedUrl = Uri.encodeFull(paymentUrl);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Launching payment: $encodedUrl'),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    if (mounted) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentWebViewPage(
            url: encodedUrl,
            title: 'Course Payment',
          ),
        ),
      );

      if (result == true) {
        _loadCourseData();
      }
    }
  }

  bool _isCoursePurchased(Map<String, dynamic> course) {
    // Check multiple possible flags that may indicate purchase/enrollment
    final paidstatus = course['paidstatus'];
    final paid_status = course['paid_status'];
    final isPurchased = course['is_purchased'];
    final purchaseStatus = course['purchase_status'];
    final status = course['status'];
    final paymentStatus = course['payment_status'];
    final enrolled = course['enrolled'] ?? course['is_enrolled'];
    final isFree = course['is_free'] == true;

    
    
    
    
    
    

    bool flagIsTrue(dynamic value) {
      if (value == null) return false;
      final s = value.toString().toLowerCase().trim();
      if (s.isEmpty || s == '0' || s == 'no' || s == 'false' || s == 'unpaid') {
        return false;
      }
      // Treat any other non‑empty / non‑zero as truthy (handles 1, true, yes, paid, success, completed, etc.)
      return true;
    }

    // Free courses are effectively "purchased"
    if (isFree) {
      
      return true;
    }

    bool isPurchasedValue = false;

    if (flagIsTrue(paidstatus)) {
      isPurchasedValue = true;
      
    }
    if (!isPurchasedValue && flagIsTrue(paid_status)) {
      isPurchasedValue = true;
      
    }
    if (!isPurchasedValue && flagIsTrue(isPurchased)) {
      isPurchasedValue = true;
      
    }
    if (!isPurchasedValue && flagIsTrue(purchaseStatus)) {
      isPurchasedValue = true;
      
    }
    if (!isPurchasedValue && flagIsTrue(paymentStatus)) {
      isPurchasedValue = true;
      
    }
    if (!isPurchasedValue && flagIsTrue(enrolled)) {
      isPurchasedValue = true;
      
    }

    // Some APIs may simply mark purchased courses as "active"
    if (!isPurchasedValue && status != null) {
      final s = status.toString().toLowerCase().trim();
      if (s == 'purchased' ||
          s == 'paid' ||
          s == 'active' ||
          s == 'completed' ||
          s == 'success') {
        isPurchasedValue = true;
        
      }
    }

    if (!isPurchasedValue) {
      
    }

    return isPurchasedValue;
  }

  Widget _buildActionButton(Map<String, dynamic> course, Color primaryColor) {
    final isPurchasedValue = _isCoursePurchased(course);

    if (isPurchasedValue) {
      // Show Start Lesson button for purchased courses
      return GestureDetector(
        onTap: () => _startLesson(course),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: primaryColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const TranslatedText(
            'Start Lesson',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    } else {
      // Show Buy Now or Start Lesson for unpurchased courses
      final appConfigProvider = Provider.of<AppConfigProvider>(context, listen: false);
      final currencySymbol = appConfigProvider.selectedCurrencySymbol;
      
      final rawDiscountedPrice =
          double.tryParse(course['discounted_price']?.toString() ?? '0') ??
              0.0;
      final double finalPrice = appConfigProvider.convertAmount(rawDiscountedPrice);
      final isFree = rawDiscountedPrice == 0 || rawDiscountedPrice == 0.0;

      return GestureDetector(
        onTap: () {
          if (isFree) {
            // Free course - start directly
            _startLesson(course);
          } else {
            // Paid course - navigate to payment
            _navigateToCoursePayment(course);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: primaryColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: isFree 
              ? const TranslatedText(
                  'Start Lesson',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const TranslatedText(
                      'Buy Now',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      ' $currencySymbol ${finalPrice.toStringAsFixed(1)}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
        ),
      );
    }
  }

  void _startLesson(Map<String, dynamic> course) {
    // Navigate to CoursePerformancePage which will auto-open video if available
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CoursePerformancePage(course: course),
      ),
    );
  }
}

class MathBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: const TextSpan(text: ''),
    );

    // Draw various mathematical symbols
    final symbols = [
      '√',
      'π',
      'α',
      'β',
      '∑',
      '∫',
      '∞',
      '±',
      '×',
      '÷',
      'a²',
      'b²',
      'c²',
      'x²',
      'y²',
      'sin',
      'cos',
      'tan',
      'A',
      'B',
      'C',
      'D',
      'E',
      'F',
      'G',
      'H',
    ];

    final random = math.Random(42); // Fixed seed for consistent layout

    for (int i = 0; i < 30; i++) {
      final symbol = symbols[random.nextInt(symbols.length)];
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final fontSize = 12 + random.nextDouble() * 8;

      textPainter.text = TextSpan(
        text: symbol,
        style: TextStyle(
          fontSize: fontSize,
          color: Colors.grey[400],
          fontWeight: FontWeight.w300,
        ),
      );

      textPainter.layout();
      textPainter.paint(canvas, Offset(x, y));
    }

    // Draw some geometric shapes
    final shapePaint = Paint()
      ..color = Colors.grey[300]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw circles
    for (int i = 0; i < 5; i++) {
      final center = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      final radius = 10 + random.nextDouble() * 20;
      canvas.drawCircle(center, radius, shapePaint);
    }

    // Draw lines
    for (int i = 0; i < 8; i++) {
      final start = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      final end = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      canvas.drawLine(start, end, shapePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'dart:io' show Platform;
import 'course_detail_page.dart';
import 'course_payment_page.dart';

class VideoTutorialsPage extends StatefulWidget {
  const VideoTutorialsPage({super.key});

  @override
  State<VideoTutorialsPage> createState() => _VideoTutorialsPageState();
}

class _VideoTutorialsPageState extends State<VideoTutorialsPage> {
  List<Map<String, dynamic>> courseList = [];
  bool isLoading = true;
  String? errorMessage;
  String selectedSubject = 'All';
  List<String> subjects = ['All'];

  @override
  void initState() {
    super.initState();
    loadVideoTutorials();
  }

  Future<void> loadVideoTutorials() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // Get dynamic student ID from authentication service
      final studentId = await AuthService.getStudentId();

      // Check if we're running on web platform (CORS issues)
      bool isWeb = false;
      try {
        Platform.isAndroid; // This will throw on web
        isWeb = false;
      } catch (e) {
        isWeb = true;
      }

      if (isWeb) {
        
        // No sample data - show empty state
      } else {
        // Test course API connectivity first
        await ApiService.testCourseApiConnectivity();
        // Try to call the real API first
        try {
          
          final response = await ApiService.getCourseList(studentId);
          
        
        if (response['course_list'] != null && response['course_list'].isNotEmpty) {
          final courses = List<Map<String, dynamic>>.from(response['course_list']);
          
          // Transform API data to match our UI format
          final transformedCourses = courses.map((course) {
            return {
              'id': course['id']?.toString() ?? '',
              'title': course['title'] ?? 'Untitled Course',
              'subject': course['class'] ?? 'General',
              'description': _cleanHtmlDescription(course['description'] ?? ''),
              'duration': course['total_hour_count'] ?? '0:00:00',
              'instructor': '${course['name'] ?? ''} ${course['surname'] ?? ''}'.trim(),
              'thumbnail': course['course_thumbnail'] ?? '',
              'video_url': course['course_url'] ?? '',
              'progress': (double.tryParse(course['course_progress']?.toString() ?? '0') ?? 0.0),
              'total_lessons': int.tryParse(course['total_lesson']?.toString() ?? '0') ?? 0,
              'completed_lessons': ((double.tryParse(course['course_progress']?.toString() ?? '0') ?? 0.0) * (int.tryParse(course['total_lesson']?.toString() ?? '0') ?? 0) / 100).round(),
              'rating': (double.tryParse(course['courserating']?.toString() ?? '0') ?? 0.0),
              'students_enrolled': int.tryParse(course['view_count']?.toString() ?? '0') ?? 0,
              'price': course['price'] ?? '0.00',
              'discount': course['discount'] ?? '0.00',
              'free_course': course['free_course'] ?? '0',
            };
          }).toList();

          // Extract unique subjects
          final uniqueSubjects = transformedCourses
              .map((course) => course['subject'] as String)
              .toSet()
              .toList();
          subjects = ['All', ...uniqueSubjects];

          setState(() {
            courseList = transformedCourses;
            isLoading = false;
          });
          return; // Success, exit early
        }
        } catch (apiError) {
          
          
          
        }
      }
      
      // No fallback data - use only real API data
      setState(() {
        courseList = [];
        subjects = ['All'];
        isLoading = false;
      });

    } catch (e) {
      
      if (!mounted) return;

      setState(() {
        errorMessage = 'Error loading video tutorials: $e';
        isLoading = false;
      });
    }
  }


  String _cleanHtmlDescription(String htmlDescription) {
    // Remove HTML tags and clean up the description
    return htmlDescription
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }

  void _navigateToCourseDetail(Map<String, dynamic> course) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CourseDetailPage(course: course),
      ),
    );
  }

  void _navigateToCoursePayment(Map<String, dynamic> course) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CoursePaymentPage(course: course),
      ),
    );
  }

  List<Map<String, dynamic>> get filteredCourses {
    if (selectedSubject == 'All') return courseList;
    return courseList
        .where((course) => course['subject'] == selectedSubject)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Online Course',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
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
                      children: [
                        // Title
                        Expanded(
                          child: Text(
                            'Your Online Course is here!',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Course illustration
                        SizedBox(
                          width: 100,
                          height: 80,
                          child: _buildCourseIllustration(),
                        ),
                      ],
                    ),
                  ),

                  // Course content area
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : errorMessage != null
                            ? Center(
                                child: Text(
                                  errorMessage!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              )
                            : filteredCourses.isEmpty
                                ? const Center(
                                    child: Text(
                                      'No courses available',
                                      style: TextStyle(fontSize: 16, color: Colors.grey),
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    itemCount: filteredCourses.length,
                                    itemBuilder: (context, index) {
                                      return _buildCourseCard(filteredCourses[index]);
                                    },
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

  Widget _buildCourseIllustration() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          // Person in chair
          Positioned(
            bottom: 5,
            left: 20,
            child: Container(
              width: 25,
              height: 35,
              decoration: BoxDecoration(
                color: Colors.teal[300],
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          // Chair
          Positioned(
            bottom: 0,
            left: 15,
            child: Container(
              width: 35,
              height: 15,
              decoration: BoxDecoration(
                color: Colors.teal[400],
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          // Mobile screens
          Positioned(
            top: 10,
            right: 15,
            child: Container(
              width: 20,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.blue[300],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.blue[400]!, width: 1),
              ),
            ),
          ),
          Positioned(
            top: 20,
            right: 40,
            child: Container(
              width: 18,
              height: 25,
              decoration: BoxDecoration(
                color: Colors.green[300],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.green[400]!, width: 1),
              ),
            ),
          ),
          // Plant leaves
          Positioned(
            top: 15,
            left: 5,
            child: Container(
              width: 15,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.green[400],
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          // Text labels
          Positioned(
            top: 5,
            right: 5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.blue[600],
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                'My Course',
                style: TextStyle(
                  fontSize: 5,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseCard(Map<String, dynamic> course) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Mathematical symbols section
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: _buildMathSymbolsSection(),
          ),

          // Instructor info overlay
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Instructor avatar
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                // Instructor info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course['instructor'] ?? 'Unknown Instructor',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Last Updated: ${course['last_updated'] ?? 'N/A'}',
                        style: TextStyle(
                          color: Colors.grey[300],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Course details
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Course title
                Text(
                  course['title'] ?? 'Untitled Course',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),

                // Course info row
                Row(
                  children: [
                    // Left side - course components
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCourseComponent(Icons.list, course['subject'] ?? 'N/A'),
                          _buildCourseComponent(Icons.play_arrow, course['lesson_count'] ?? 'N/A'),
                          _buildCourseComponent(Icons.quiz, course['quiz_count'] ?? 'N/A'),
                          _buildCourseComponent(Icons.wifi, course['exam_count'] ?? 'N/A'),
                          _buildCourseComponent(Icons.assignment, course['assignment_count'] ?? 'N/A'),
                        ],
                      ),
                    ),
                    
                    // Right side - duration and pricing
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Duration
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              '${course['duration'] ?? 'N/A'} Hrs',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        // Pricing
                        Row(
                          children: [
                            Text(
                              '\$${course['price'] ?? '0.00'}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            if (course['discount'] != null && course['discount'] != '0.00')
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Text(
                                  '\$${course['discount']}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    decoration: TextDecoration.lineThrough,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        
                        // Rating
                        Row(
                          children: [
                            ...List.generate(5, (index) {
                              return Icon(
                                Icons.star,
                                size: 14,
                                color: index < 4 ? Colors.amber[600] : Colors.grey[400],
                              );
                            }),
                            const SizedBox(width: 4),
                            Text(
                              '(1 Rating)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        
                        // Progress bar
                        Container(
                          width: 80,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: 0.0, // 0% progress
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[600],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '0%',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _navigateToCourseDetail(course),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Course Details',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _navigateToCoursePayment(course),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Buy Now \$${course['price'] ?? '0.00'}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMathSymbolsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Top row of symbols
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMathSymbol('√X', Colors.black),
              _buildMathSymbol('a²+b²=c²', Colors.black),
              _buildMathSymbol('sin²α+cos²β=1', Colors.black),
            ],
          ),
          const SizedBox(height: 12),
          // Bottom row of symbols
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMathSymbol('?', Colors.black),
              _buildMathSymbol('85%', Colors.black),
              _buildMathSymbol('15%', Colors.black),
            ],
          ),
          const SizedBox(height: 12),
          // Visual elements
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildVisualElement(Icons.straighten, Colors.black), // Ruler
              _buildVisualElement(Icons.calculate, Colors.black), // Calculator
              _buildVisualElement(Icons.quiz, Colors.black), // Quiz icon
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMathSymbol(String symbol, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        symbol,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildVisualElement(IconData icon, Color color) {
    return Icon(
      icon,
      size: 16,
      color: color,
    );
  }

  Widget _buildCourseComponent(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}
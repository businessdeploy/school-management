import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'lesson_detail_page.dart';
import '../widgets/translated_text.dart';
import '../widgets/enterprise_ui_components.dart';

class SyllabusStatusPage extends StatefulWidget {
  const SyllabusStatusPage({super.key});

  @override
  State<SyllabusStatusPage> createState() => _SyllabusStatusPageState();
}

class _SyllabusStatusPageState extends State<SyllabusStatusPage> {
  List<Map<String, dynamic>> syllabusList = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadSyllabusStatus();
  }

  Future<void> loadSyllabusStatus() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // Get dynamic student ID from authentication service
      final studentId = await AuthService.getStudentId();
      

      // Try to get data from API first
      try {
        
        final response = await ApiService.getSyllabusStatus(studentId);
        
        
        
        
        
        
        
        if (response['data'] != null && response['data'] is List) {
          final apiData = List<Map<String, dynamic>>.from(response['data']);
          
          
          if (apiData.isEmpty) {
            
            setState(() {
              isLoading = false;
              errorMessage = 'No syllabus data available from server.';
            });
            return;
          }
          
          // Convert string completion percentages to double
          final processedData = apiData.map((item) {
            final processedItem = Map<String, dynamic>.from(item);
            if (processedItem['completion_percentage'] != null) {
              final percentage = processedItem['completion_percentage'];
              if (percentage is String) {
                processedItem['completion_percentage'] = double.tryParse(percentage) ?? 0.0;
              }
            }
            return processedItem;
          }).toList();
          
          setState(() {
            syllabusList = processedData;
            isLoading = false;
          });
          
          return; // Success, exit early
        } else {
          
          
          
        }
      } catch (apiError) {
        
        
      }

      // No data from API - show empty state
      setState(() {
        isLoading = false;
        errorMessage = 'No syllabus data available. Please check your connection or contact support.';
      });

    } catch (e) {
      
      if (!mounted) return;

      setState(() {
        errorMessage = 'Error loading syllabus status: $e';
        isLoading = false;
      });
    }
  }


  Future<void> _debugSyllabusStatus() async {
    try {
      
      
      
      // Get dynamic student ID from authentication service
      final studentId = await AuthService.getStudentId();
      
      
      // Test API call directly
      
      final response = await ApiService.getSyllabusStatus(studentId);
      
      
      // Enhanced debugging
      
      
      
      
      if (response['data'] is List) {
        final dataList = response['data'] as List;
        
        if (dataList.isNotEmpty) {
          
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debug info logged to console'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Debug failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = Colors.grey[50];
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const TranslatedText(
          'Syllabus Status',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.grey[800],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.bug_report),
              onPressed: _debugSyllabusStatus,
              tooltip: 'Debug Syllabus Status',
            ),
        ],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          EnterpriseUIComponents.buildHeaderWithIllustration(
            title: 'Syllabus Status',
            subtitle: 'Track your subject completion progress',
            illustration: Image.asset(
              "assets/images/syllabusstatuspage.jpg",
              fit: BoxFit.cover,
            ),
          ),
          
          // Scrollable Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: loadSyllabusStatus,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 80),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Colors.red),
                            const SizedBox(height: 12),
                            Text(
                              errorMessage!,
                              style: const TextStyle(color: Colors.red, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: loadSyllabusStatus,
                              child: const TranslatedText('Retry'),
                            ),
                          ],
                        ),
                      )
                    else if (syllabusList.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 80),
                        child: Center(
                          child: TranslatedText(
                            'No syllabus status available',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Column(
                          children:
                              syllabusList.map((syllabus) => _buildSyllabusCard(syllabus)).toList(),
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyllabusIllustration() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          // Person sitting on books
          Positioned(
            bottom: 5,
            left: 20,
            child: Container(
              width: 25,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.blue[300],
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          // Stack of books
          Positioned(
            bottom: 0,
            left: 15,
            child: Column(
              children: [
                Container(
                  width: 20,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.orange[400],
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                Container(
                  width: 20,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.blue[400],
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                Container(
                  width: 20,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.green[400],
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ),
          ),
          // Laptop
          Positioned(
            top: 15,
            left: 30,
            child: Container(
              width: 25,
              height: 15,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          // Circular arrows
          Positioned(
            top: 10,
            right: 15,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border.all(color: Colors.orange[400]!, width: 2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.refresh,
                  size: 12,
                  color: Colors.orange[400],
                ),
              ),
            ),
          ),
          // Lightbulb
          Positioned(
            top: 25,
            right: 25,
            child: Icon(
              Icons.lightbulb,
              size: 12,
              color: Colors.yellow[600],
            ),
          ),
          // Gears
          Positioned(
            top: 5,
            left: 10,
            child: Icon(
              Icons.settings,
              size: 8,
              color: Colors.grey[400],
            ),
          ),
          Positioned(
            bottom: 10,
            right: 5,
            child: Icon(
              Icons.settings,
              size: 6,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyllabusCard(Map<String, dynamic> syllabus) {
    final subjectName = syllabus['subject_name'] ?? '';
    final subjectCode = syllabus['subject_code'] ?? '';
    
    // Calculate completion percentage from total and total_complete
    double completionPercentage = 0.0;
    final total = int.tryParse(syllabus['total']?.toString() ?? '0') ?? 0;
    final totalComplete = int.tryParse(syllabus['total_complete']?.toString() ?? '0') ?? 0;
    
    if (total > 0) {
      completionPercentage = (totalComplete / total) * 100;
    }
    
    
    
    

    const Color headerColor = Color(0xFFE7F3ED);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            decoration: const BoxDecoration(
              color: headerColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.menu_book_outlined,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (subjectName?.toString().toUpperCase() ?? 'SUBJECT'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subjectCode.toString().isEmpty
                            ? 'Code -'
                            : '(${subjectCode.toString()})',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${completionPercentage.toStringAsFixed(0)}% ',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const TranslatedText(
                          'Complete',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 80,
                      height: 6,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (completionPercentage / 100).clamp(0.0, 1.0),
                          backgroundColor: Colors.white,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getProgressColor(completionPercentage),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                           Text(
                            '$totalComplete ',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const TranslatedText(
                            'of',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            ' $total ',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const TranslatedText(
                            'Topics',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      TranslatedText(
                        'Updated automatically from your syllabus progress.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _navigateToLessonDetail(syllabus),
                  icon: Icon(Icons.list_alt, color: Colors.blue[600], size: 18),
                  label: const TranslatedText(
                    'Lesson Topic',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getProgressColor(double percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.blue;
    if (percentage >= 40) return Colors.orange;
    return Colors.red;
  }

  void _navigateToLessonDetail(Map<String, dynamic> syllabus) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LessonDetailPage(
          subjectName: syllabus['subject_name'] ?? '',
          subjectCode: syllabus['subject_code'] ?? '',
          subjectId: syllabus['subject_group_subject_id']?.toString(),
          classSectionId: syllabus['id']?.toString(),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import '../models/cbse_exam.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'cbse_exam_schedule_page.dart';
import '../widgets/translated_text.dart';

class CBSEExamResultPage extends StatefulWidget {
  const CBSEExamResultPage({super.key});

  @override
  State<CBSEExamResultPage> createState() => _CBSEExamResultPageState();
}

class _CBSEExamResultPageState extends State<CBSEExamResultPage> {
  List<CBSEExam> examList = [];
  List<CBSEExam> timetableList = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadExamResults();
  }

  Future<void> _loadExamResults() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final studentSessionId = await AuthService.getStudentSessionId();

      // Load both result and timetable
      final Future<List<Map<String, dynamic>>> resultFuture = 
          ApiService.getCBSEExamResult(studentSessionId);
      final Future<List<Map<String, dynamic>>> timetableFuture = 
          ApiService.getCBSEExamTimetable(studentSessionId);

      final results = await Future.wait([resultFuture, timetableFuture]);
      final examData = results[0];
      final timetableData = results[1];

      if (!mounted) return;

      setState(() {
        examList = examData.map((item) => CBSEExam.fromJson(item)).toList();
        timetableList = timetableData.map((item) => CBSEExam.fromJson(item)).toList();
        isLoading = false;
        
        
        
      });
    } catch (e) {
      
      if (!mounted) return;
      
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
          'CBSE Exam Result',
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
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            onPressed: () {
              if (timetableList.isEmpty) {
                // If timetable list empty, check if we have exams in the result list as fallback
                if (examList.isNotEmpty) {
                   Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CBSEExamSchedulePage(exams: examList),
                    ),
                  );
                  return;
                }
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: TranslatedText('No CBSE exam schedule available yet'),
                  ),
                );
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CBSEExamSchedulePage(exams: timetableList),
                ),
              );
            },
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: TranslatedText(
                'Exam Schedule',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
      body: Column(
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
                          'Your CBSE Exam Result is here!',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TranslatedText(
                          'Check your academic performance',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Illustration
                  SizedBox(
                    width: 120,
                    height: 100,
                    child: Image.asset(
                      "assets/images/cbseexaminationpage.jpg",
                      width: 120,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildResultIllustration();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Exam Results Content
          Expanded(
            child: Container(
              color: Colors.grey[100],
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
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          TranslatedText(
                            'Failed to load exam results',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadExamResults,
                            child: const TranslatedText('Retry'),
                          ),
                        ],
                      ),
                    )
                  : examList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.assignment_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          TranslatedText(
                            'No exam results found',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: examList.length,
                      itemBuilder: (context, index) {
                        return _buildExamResultCard(examList[index]);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamResultCard(CBSEExam exam) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Exam Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.green[50], // Match Student Behaviour module
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Text(
              exam.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          // Subject Results Table
          // Show subjects if examData exists and has subjects, OR if subjects list is not empty
          if ((exam.examData != null && exam.examData!.subjects.isNotEmpty) || exam.subjects.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Table Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TranslatedText(
                            'Subject',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                              fontSize: 11,
                            ),
                          ),
                        ),
                        // Dynamic Assessment Columns
                        ...exam.examAssessments.map((assessment) => Expanded(
                          child: Text(
                            '${assessment.name}\n(Max ${assessment.maximumMarks})',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                              fontSize: 10,
                            ),
                          ),
                        )),
                        // Total Column
                        Expanded(
                          child: TranslatedText(
                            'Total',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Subject Rows - Use examData if available, otherwise build from subjects list
                  if (exam.examData != null && exam.examData!.subjects.isNotEmpty)
                    ...exam.examData!.subjects.map(
                      (subject) => _buildSubjectRow(subject, exam.examAssessments),
                    )
                  else
                    ...exam.subjects.map(
                      (subject) => _buildSubjectRowFromSubject(subject, exam.examAssessments),
                    ),
                  const SizedBox(height: 16),
                  // Overall Result Summary
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSummaryItem(
                          'Total Marks',
                          '${exam.examObtainMarks}/${exam.examTotalMarks}',
                        ),
                        _buildSummaryItem(
                          'Percentage',
                          '${exam.examPercentage}%',
                        ),
                        _buildSummaryItem('Grade', exam.examGrade),
                        _buildSummaryItem('Rank', exam.examRank),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubjectRow(CBSEExamDataSubject subject, List<CBSEExamAssessment> assessments) {
    double totalMarks = 0;
    bool hasAnyMarks = false;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '${subject.subjectName} (${subject.subjectCode})',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.black87,
                fontSize: 10,
              ),
            ),
          ),
          ...assessments.map((assessment) {
            final dataAssessment = subject.examAssessments[assessment.id];
            final marks = dataAssessment?.marks ?? '';
            
            // Add to total
            if (marks.isNotEmpty && marks.toLowerCase() != 'null') {
              totalMarks += double.tryParse(marks) ?? 0;
              hasAnyMarks = true;
            }

            return Expanded(
              child: Text(
                _formatMarks(marks),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _formatMarks(marks) == 'xx'
                      ? Colors.grey[400]
                      : Colors.black87,
                  fontWeight: FontWeight.w500,
                  fontSize: 10,
                ),
              ),
            );
          }),
          // Total Column
          Expanded(
            child: Text(
              hasAnyMarks ? _formatMarks(totalMarks.toString()) : 'xx',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: hasAnyMarks ? Colors.blue[700] : Colors.grey[400],
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectRowFromSubject(CBSEExamSubject subject, List<CBSEExamAssessment> assessments) {
    double totalMarks = 0;
    bool hasAnyMarks = false;
    
    // Create a map for easy lookup of marks by assessment type ID
    Map<String, String> marksByAssessmentId = {};
    
    if (subject.raw.containsKey('student_subject_marks') && subject.raw['student_subject_marks'] is List) {
      final marksList = subject.raw['student_subject_marks'] as List;
      for (var markItem in marksList) {
        if (markItem is Map) {
          final assessmentTypeId = markItem['cbse_exam_assessment_type_id']?.toString();
          final marks = markItem['marks']?.toString();
          if (assessmentTypeId != null && marks != null) {
            marksByAssessmentId[assessmentTypeId] = marks;
          }
        }
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '${subject.subjectName} (${subject.subjectCode})',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.black87,
                fontSize: 10,
              ),
            ),
          ),
          ...assessments.map((assessment) {
            final marks = marksByAssessmentId[assessment.id] ?? '';
            
            // Add to total
            if (marks.isNotEmpty && marks.toLowerCase() != 'null') {
              totalMarks += double.tryParse(marks) ?? 0;
              hasAnyMarks = true;
            }

            return Expanded(
              child: Text(
                _formatMarks(marks),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _formatMarks(marks) == 'xx'
                      ? Colors.grey[400]
                      : Colors.black87,
                  fontWeight: FontWeight.w500,
                  fontSize: 10,
                ),
              ),
            );
          }),
          // Total Column
          Expanded(
            child: Text(
              hasAnyMarks ? _formatMarks(totalMarks.toString()) : 'xx',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: hasAnyMarks ? Colors.blue[700] : Colors.grey[400],
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMarks(String? marks) {
    if (marks == null || marks.isEmpty || marks.toLowerCase() == 'null') {
      return 'xx';
    }
    // Try to format as decimal if it's a number
    final numValue = double.tryParse(marks);
    if (numValue != null) {
      return numValue.toStringAsFixed(2);
    }
    return marks;
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        TranslatedText(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildResultIllustration() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          // Student 1
          Positioned(
            bottom: 10,
            left: 15,
            child: Container(
              width: 30,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.blue[200],
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
          // Student 2
          Positioned(
            bottom: 10,
            right: 15,
            child: Container(
              width: 30,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.green[200],
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
          // Speech bubble
          Positioned(
            top: 5,
            left: 20,
            child: Container(
              width: 20,
              height: 15,
              decoration: BoxDecoration(
                color: Colors.orange[200],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          // Question marks
          Positioned(
            top: 8,
            right: 20,
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 2),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

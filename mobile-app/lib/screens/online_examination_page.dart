import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:schoolapp/services/api/online_exam_api.dart';
import 'package:schoolapp/services/auth_service.dart';
import 'package:flutter_html/flutter_html.dart';
import '../widgets/translated_text.dart';
import '../widgets/enterprise_ui_components.dart';

class OnlineExaminationPage extends StatefulWidget {
  const OnlineExaminationPage({super.key});

  @override
  State<OnlineExaminationPage> createState() => _OnlineExaminationPageState();
}

class _OnlineExaminationPageState extends State<OnlineExaminationPage> {
  bool isLoading = true;
  String? error;
  int selectedTab = 0;
  final List<OnlineExamSummary> upcomingExams = [];
  final List<OnlineExamSummary> closedExams = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      isLoading = true;
      error = null;
      upcomingExams.clear();
      closedExams.clear();
    });

    final studentId = await AuthService.getStudentId();
    if (studentId.isEmpty) {
      setState(() {
        error = 'Student ID missing. Please login again.';
        isLoading = false;
      });
      return;
    }

    try {
      final response = await OnlineExamApi.getOnlineExam(studentId, examType: ' ');
      final rawList = (response['onlineexam'] as List?) ?? [];
      final parsed = rawList
          .whereType<Map<String, dynamic>>()
          .map((exam) => OnlineExamSummary.fromJson(exam))
          .toList();

      final now = DateTime.now();
      for (final exam in parsed) {
        if (exam.isActive(now)) {
          upcomingExams.add(exam);
        } else {
          closedExams.add(exam);
        }
      }

      setState(() {
        isLoading = false;
        if (upcomingExams.isEmpty && closedExams.isEmpty) {
          error = response['message']?.toString() ?? 'No exams found';
        }
      });
    } catch (e) {
      setState(() {
        error = 'Failed to load exams: $e';
        isLoading = false;
      });
    }
  }

  List<OnlineExamSummary> get _currentList =>
      selectedTab == 0 ? upcomingExams : closedExams;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildHeader(),
                  EnterpriseUIComponents.buildHeaderWithIllustration(
                    title: 'Online Examination',
                    subtitle: 'Manage your online assessments',
                    illustration: Container(
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.school_outlined,
                          size: 40,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _buildTabs(),
                          ),
                          const SizedBox(height: 16),
                          if (error != null && _currentList.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(32),
                              child: Text(
                                error!,
                                style: const TextStyle(fontSize: 16, color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                            )
                          else
                            ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _currentList.length,
                              itemBuilder: (context, index) => _buildExamCard(_currentList[index]),
                            ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back, color: Colors.black),
          ),
          const SizedBox(width: 8),
          const TranslatedText(
            'Online Examination',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildTabs() {
    return Row(
      children: [
        Expanded(
          child: _buildTabButton(
            label: 'Upcoming Exams',
            isSelected: selectedTab == 0,
            activeColor: Colors.red.shade600,
            onTap: () => setState(() => selectedTab = 0),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTabButton(
            label: 'Closed Exams',
            isSelected: selectedTab == 1,
            activeColor: Colors.orange.shade700,
            onTap: () => setState(() => selectedTab = 1),
          ),
        ),
      ],
    );
  }

  Widget _buildTabButton({
    required String label,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(32),
          border: isSelected
              ? null
              : Border.all(color: Colors.grey.shade400, width: 1),
        ),
        child: Center(
          child: TranslatedText(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExamCard(OnlineExamSummary exam) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: BoxDecoration(
              color: selectedTab == 0 ? Colors.blue[50] : Colors.green[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Text(
              exam.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                _buildDetailRow('Exam From', exam.formattedFrom),
                _buildDetailRow('Exam To', exam.formattedTo),
                _buildDetailRow('Total Attempt', exam.totalAttempt),
                _buildDetailRow('Attempted', exam.attempted),
                _buildDetailRow('Duration', exam.duration),
                _buildDetailRow('Status', exam.statusLabel),
                _buildDetailRow('Quiz', exam.quizLabel),
                _buildDetailRow('Passing (%)', exam.passingPercentage),
                _buildDetailRow(
                  'Descriptive Questions',
                  exam.descriptiveQuestions,
                ),
                _buildDetailRow('Total Question', exam.totalQuestions),
                _buildDetailRow('Answer Word Limit', exam.answerWordLimit),
              ],
            ),
          ),
          const Divider(height: 24, thickness: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _buildStatusRow(
                  icon: Icons.check_circle_outline,
                  color: Colors.green,
                  label: 'Correct Answer',
                ),
                const SizedBox(height: 8),
                _buildStatusRow(
                  icon: Icons.circle_outlined,
                  color: Colors.green,
                  label: 'Correct Answer But Not Attempted',
                ),
                const SizedBox(height: 8),
                _buildStatusRow(
                  icon: Icons.cancel_outlined,
                  color: Colors.red,
                  label: 'Wrong Answer',
                ),
              ],
            ),
          ),
          const Divider(height: 24, thickness: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TranslatedText(
                  'Description',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Html(
                  data: exam.description.isEmpty ? 'No description available' : exam.description,
                  style: {
                    "body": Style(
                      margin: Margins.zero,
                      padding: HtmlPaddings.zero,
                      color: Colors.black87,
                      fontSize: FontSize(14),
                      lineHeight: const LineHeight(1.5),
                    ),
                  },
                ),
// Modified from Text widget with _formatDescription
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: TranslatedText(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow({
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        TranslatedText(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

}

class OnlineExamSummary {
  final String title;
  final String examFrom;
  final String examTo;
  final String totalAttempt;
  final String attempted;
  final String duration;
  final String status;
  final String isQuiz;
  final String passingPercentage;
  final String descriptiveQuestions;
  final String totalQuestions;
  final String answerWordLimit;
  final String description;

  OnlineExamSummary({
    required this.title,
    required this.examFrom,
    required this.examTo,
    required this.totalAttempt,
    required this.attempted,
    required this.duration,
    required this.status,
    required this.isQuiz,
    required this.passingPercentage,
    required this.descriptiveQuestions,
    required this.totalQuestions,
    required this.answerWordLimit,
    required this.description,
  });

  factory OnlineExamSummary.fromJson(Map<String, dynamic> json) {
    return OnlineExamSummary(
      title: json['exam_title']?.toString() ??
          json['exam']?.toString() ??
          'Untitled Exam',
      examFrom: json['exam_from']?.toString() ?? '',
      examTo: json['exam_to']?.toString() ?? '',
      totalAttempt: json['total_attempt']?.toString() ??
          json['attempt']?.toString() ??
          '0',
      attempted: json['attempted']?.toString() ??
          json['is_attempted']?.toString() ??
          '0',
      duration: json['duration']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      isQuiz: json['is_quiz']?.toString() ??
          json['quiz']?.toString() ??
          '0',
      passingPercentage:
          json['passing_percentage']?.toString() ?? '0',
      descriptiveQuestions:
          json['descriptive_questions']?.toString() ??
          json['total_descriptive']?.toString() ??
          '0',
      totalQuestions: json['total_question']?.toString() ??
          json['total_questions']?.toString() ??
          '0',
      answerWordLimit:
          json['answer_word_limit']?.toString() ??
          json['answer_word_count']?.toString() ??
          '0',
      description: (json['description'] ?? json['instructions'] ?? '').toString().trim(),
    );
  }

  DateTime? _parseDate(String value) {
    if (value.isEmpty) return null;
    try {
      return DateTime.parse(value);
    } catch (_) {
      try {
        return DateFormat('yyyy-MM-dd HH:mm:ss').parse(value);
      } catch (_) {
        return null;
      }
    }
  }

  bool isActive(DateTime now) {
    final start = _parseDate(examFrom);
    final end = _parseDate(examTo);
    if (start == null || end == null) return false;
    final afterStart = now.isAfter(start) || now.isAtSameMomentAs(start);
    final beforeEnd = now.isBefore(end) || now.isAtSameMomentAs(end);
    return afterStart && beforeEnd;
  }

  String get formattedFrom => _formatDate(examFrom);
  String get formattedTo => _formatDate(examTo);

  String _formatDate(String raw) {
    final parsed = _parseDate(raw);
    if (parsed == null) return 'Not specified';
    return DateFormat('MM/dd/yyyy hh:mm a').format(parsed);
  }

  String get statusLabel => status.isNotEmpty
      ? '${status[0].toUpperCase()}${status.substring(1)}'
      : 'Status not available';

  String get quizLabel =>
      (isQuiz.toLowerCase() == 'yes' || isQuiz == '1') ? 'Yes' : 'No';
}


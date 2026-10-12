import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:schoolapp/models/online_exam.dart';
import 'package:schoolapp/screens/online_exam_result_page.dart';
import 'package:schoolapp/services/api/online_exam_api.dart';
import 'package:schoolapp/services/auth_service.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:schoolapp/screens/exam_taking_page.dart';
import '../widgets/translated_text.dart';
import '../widgets/enterprise_ui_components.dart';

class OnlineExamPage extends StatefulWidget {
  const OnlineExamPage({super.key});

  @override
  State<OnlineExamPage> createState() => _OnlineExamPageState();
}

class _OnlineExamPageState extends State<OnlineExamPage> {
  bool _loading = true;
  String? _message;
  int _selectedTab = 0;
  final List<OnlineExamSummary> _upcomingExams = [];
  final List<OnlineExamSummary> _closedExams = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _message = null;
      _upcomingExams.clear();
      _closedExams.clear();
    });

    final studentId = await AuthService.getStudentId();
      if (studentId.isEmpty) {
        setState(() {
          _message = 'Student ID missing. Please login again.';
          _loading = false;
        });
        return;
      }

    try {
      // Fetch both upcoming and closed exams concurrently
      final responses = await Future.wait([
        OnlineExamApi.getOnlineExam(studentId, examType: ' '), // Default/Upcoming
        OnlineExamApi.getOnlineExam(studentId, examType: 'closed'), // Explicit Closed
      ]);

      final upcomingResponse = responses[0];
      final closedResponse = responses[1];
      
      final upcomingRaw = (upcomingResponse['onlineexam'] as List?) ?? [];
      final closedRaw = (closedResponse['onlineexam'] as List?) ?? [];

      final upcomingParsed = upcomingRaw
          .whereType<Map<String, dynamic>>()
          .map(OnlineExamSummary.fromJson)
          .toList();
          
      final closedParsed = closedRaw
          .whereType<Map<String, dynamic>>()
          .map(OnlineExamSummary.fromJson)
          .toList();

      setState(() {
        _partitionExams(upcomingParsed, closedParsed);
        if (_upcomingExams.isEmpty && _closedExams.isEmpty) {
          _message = upcomingResponse['message']?.toString() ?? 'No exams found';
        }
        _loading = false;
      });
    } catch (e) {
      
      setState(() {
        _message = 'Failed to load exams. Please try again.';
        _loading = false;
      });
    }
  }

  void _partitionExams(List<OnlineExamSummary> upcoming, List<OnlineExamSummary> closed) {
    final now = DateTime.now();
    _upcomingExams.clear();
    _closedExams.clear();
    
    final allExams = <String, OnlineExamSummary>{};
    for (var e in closed) {
      allExams[e.rawExam.id] = e;
    }
    for (var e in upcoming) {
      allExams[e.rawExam.id] = e;
    }

    for (var exam in allExams.values) {
      final m = exam.rawExam;
      
      DateTime? endDate;
      try { endDate = DateTime.parse(m.examTo); } catch (_) {}
      final isPast = endDate != null && now.isAfter(endDate);

      // Rule: Partition based on attempt status and date
      if (m.isSubmitted || m.hasReachedMaxAttempts || isPast) {
        _closedExams.add(exam);
      } else {
        _upcomingExams.add(exam);
      }
    }

  }

  List<OnlineExamSummary> get _currentList =>
      _selectedTab == 0 ? _upcomingExams : _closedExams;

  void _changeTab(int index) {
    if (_selectedTab == index) return;
    setState(() {
      _selectedTab = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const TranslatedText(
          'Online Examination',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        shape: const Border(
          bottom: BorderSide(color: Colors.white, width: 1),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Sticky Enterprise Header
                  EnterpriseUIComponents.buildHeaderWithIllustration(
                    title: 'Your Exams are here!',
                    subtitle: 'Take your exams and view results',
                    illustration: Image.network(
                      'https://cdn-icons-png.flaticon.com/512/139/139899.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
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
                          _buildTabBar(),
                          const SizedBox(height: 8),
                          _buildExamList(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }


  Widget _buildTabBar() {
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          _buildTabItem('Upcoming Exams', true, _selectedTab == 0,
              () => _changeTab(0)),
          const SizedBox(width: 8),
          _buildTabItem('Closed Exams', false, _selectedTab == 1,
              () => _changeTab(1)),
        ],
      ),
    );
  }

  Widget _buildTabItem(
    String label,
    bool isPrimary,
    bool active,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFFF0000) : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
            border: active
                ? null
                : Border.all(color: const Color(0xFFFFA500), width: 2),
          ),
          alignment: Alignment.center,
          child: TranslatedText(
            label,
            style: TextStyle(
              color: active ? Colors.white : Colors.black,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExamList() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final exams = _currentList;
    if (exams.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
        child: Center(
          child: TranslatedText(
            _message ?? 'No exams found',
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 32),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: exams.length,
      itemBuilder: (context, index) => _buildExamCard(exams[index]),
    );
  }

  Widget _buildExamCard(OnlineExamSummary exam) {
    return Container(
      margin: const EdgeInsets.only(top: 16, left: 16, right: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: _selectedTab == 0 ? Colors.blue[50] : Colors.green[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            alignment: Alignment.centerLeft,
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
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildFieldRow('Exam From', exam.formattedFrom),
                _buildFieldRow('Exam To', exam.formattedTo),
                _buildFieldRow('Total Attempt', exam.totalAttempt),
                _buildFieldRow('Attempted', exam.attempted),
                _buildFieldRow('Duration', exam.duration),
                _buildFieldRow('Status', exam.statusLabel),
                _buildFieldRow('Quiz', exam.quizLabel),
                _buildFieldRow('Passing (%)', exam.passingPercentage),
                _buildFieldRow(
                  'Descriptive Questions',
                  exam.descriptiveQuestions,
                ),
                _buildFieldRow('Total Question', exam.totalQuestions),
                _buildFieldRow('Answer Word Limit', exam.answerWordLimit),
                const SizedBox(height: 8),
                _buildStatusRow(
                  icon: _filledCircle(Colors.green),
                  label: 'Correct Answer',
                ),
                const SizedBox(height: 6),
                _buildStatusRow(
                  icon: _outlinedCircle(Colors.green),
                  label: 'Correct Answer But Not Attempted',
                ),
                const SizedBox(height: 6),
                _buildStatusRow(
                  icon: _filledCircle(Colors.red, icon: Icons.close),
                  label: 'Wrong Answer',
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TranslatedText(
                    'Description',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Html(
                  data: exam.description,
                  style: {
                    "body": Style(
                      margin: Margins.zero,
                      padding: HtmlPaddings.zero,
                      fontSize: FontSize(14),
                      color: Colors.black87,
                      fontFamily: 'Roboto',
                    ),
                    "p": Style(
                      margin: Margins.only(bottom: 8),
                    ),
                  },
                ),
                const SizedBox(height: 12),
                if (_selectedTab == 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Builder(
                      builder: (context) {
                        final now = DateTime.now();
                        final m = exam.rawExam;
                        
                        DateTime? startDate;
                        try { startDate = DateTime.parse(m.examFrom); } catch (_) {}
                        
                        final isFuture = startDate != null && now.isBefore(startDate);
                        final canStart = m.canStartExam(now);
                        
                        String buttonText = 'Start Exam';
                        if (isFuture) {
                          buttonText = 'Starts on ${DateFormat('dd MMM hh:mm a').format(startDate)}';
                        } else if (m.isSubmitted) {
                          buttonText = 'Submitted';
                        } else if (m.hasReachedMaxAttempts) {
                          buttonText = 'Max Attempts Reached';
                        }

                        return SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: canStart ? () => _startExam(m) : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: canStart ? const Color(0xFFFF0000) : Colors.grey,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              buttonText,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                if (_selectedTab == 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: exam.rawExam.isSubmitted ? () => _viewResults(exam.rawExam) : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: exam.rawExam.isSubmitted ? Colors.green[600] : Colors.grey[400],
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: TranslatedText(
                          exam.rawExam.isSubmitted ? 'View Results' : 'Exam Closed',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
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

  Widget _buildFieldRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: TranslatedText(
              label,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow({
    required Widget icon,
    required String label,
  }) {
    return Row(
      children: [
        icon,
        const SizedBox(width: 10),
        TranslatedText(label, style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  Widget _filledCircle(Color color, {IconData icon = Icons.check}) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 16),
    );
  }

  Widget _outlinedCircle(Color color) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
    );
  }


  void _startExam(OnlineExam exam) async {
    final bool? submitted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ExamTakingPage(onlineExam: exam),
      ),
    );

    if (submitted == true) {
      // Rule 1: Immediate redirect to results page
      if (mounted) {
        _viewResults(exam);
      }
    }
    _refresh();
  }

  void _viewResults(OnlineExam exam) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OnlineExamResultPage(exam: exam),
      ),
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
  final OnlineExam rawExam;

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
    required this.rawExam,
  });

  factory OnlineExamSummary.fromJson(Map<String, dynamic> json) {
    final raw = OnlineExam.fromJson(json);
    return OnlineExamSummary(
      title: json['exam_title']?.toString() ??
          json['exam']?.toString() ??
          'Untitled Exam',
      examFrom: json['exam_from']?.toString() ?? '',
      examTo: json['exam_to']?.toString() ?? '',
      totalAttempt: json['total_attempt']?.toString() ??
          json['attempt']?.toString() ??
          '0',
      attempted: json['counter']?.toString() ?? 
          json['attempted']?.toString() ??
          json['is_attempted']?.toString() ??
          '0',
      duration: json['duration']?.toString() ?? 
                json['time_duration']?.toString() ?? 
                json['duration_minutes']?.toString() ?? 
                '',
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
      description: (json['description'] ?? json['instructions'] ?? '')
          .toString()
          .trim()
          .replaceAll(RegExp(r'\s{2,}'), ' '),
      rawExam: raw,
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


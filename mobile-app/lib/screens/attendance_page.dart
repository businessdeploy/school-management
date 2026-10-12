import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../providers/app_config_provider.dart';
import 'package:provider/provider.dart';
import '../widgets/translated_text.dart';
import '../widgets/enterprise_ui_components.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  List<Map<String, dynamic>> attendanceData = [];
  bool isLoading = false;
  String? error;
  String? infoMessage;
  String selectedMonth = DateTime.now().month.toString();
  String selectedYear = DateTime.now().year.toString();
  DateTime currentDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadAttendanceData();
  }

  Future<void> _loadAttendanceData() async {
    setState(() {
      isLoading = true;
      error = null;
      infoMessage = null;
    });

    try {
      // Get dynamic student ID from authentication service
      final studentId = await AuthService.getStudentId();

      final result = await ApiService.getAttendance(
        studentId,
        month: selectedMonth,
        year: selectedYear,
      );

      if (mounted) {
        
        if (result['status'] == 1 && result['attendance'] != null) {
          final attendanceList = List<Map<String, dynamic>>.from(
            result['attendance'],
          );
          
          

          setState(() {
            attendanceData = attendanceList;
            isLoading = false;
          });
        } else {
          
          final message = result['message']?.toString() ?? 'No attendance data available for this month.';
          final lowerMessage = message.toLowerCase();
          final bool treatAsError = lowerMessage.contains('failed to load') ||
              lowerMessage.contains('404') ||
              lowerMessage.contains('exception');

          setState(() {
            attendanceData = [];
            isLoading = false;
            error = treatAsError ? message : null;
            infoMessage = treatAsError ? null : message;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          error = 'Error loading attendance: $e';
        });
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return Colors.green;
      case 'absent':
        return Colors.red;
      case 'late':
        return Colors.yellow[700]!;
      case 'half day':
        return Colors.orange;
      case 'holiday':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  List<DateTime> _getDaysInMonth(DateTime date) {
    final lastDay = DateTime(date.year, date.month + 1, 0);
    List<DateTime> days = [];
    for (int i = 1; i <= lastDay.day; i++) {
      days.add(DateTime(date.year, date.month, i));
    }
    return days;
  }

  String? _getAttendanceStatus(DateTime date) {
    // Only show attendance for the current month being viewed
    final currentMonth = currentDate.month;
    final currentYear = currentDate.year;

    // Don't show attendance dots for future months
    if (date.month != currentMonth || date.year != currentYear) {
      return null;
    }

    final dateStr = date.toIso8601String().split('T')[0];

    for (var record in attendanceData) {
      if (record['date'] == dateStr) {
        return record['type'];
      }
    }
    return null;
  }

  void _previousMonth() {
    setState(() {
      if (currentDate.month == 1) {
        currentDate = DateTime(currentDate.year - 1, 12);
      } else {
        currentDate = DateTime(currentDate.year, currentDate.month - 1);
      }
      selectedMonth = currentDate.month.toString();
      selectedYear = currentDate.year.toString();
    });
    _loadAttendanceData();
  }

  void _nextMonth() {
    final now = DateTime.now();
    final candidate = currentDate.month == 12
        ? DateTime(currentDate.year + 1, 1)
        : DateTime(currentDate.year, currentDate.month + 1);

    final bool isFutureMonth =
        candidate.year > now.year ||
        (candidate.year == now.year && candidate.month > now.month);

    if (isFutureMonth) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attendance for future months is not available yet.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      currentDate = candidate;
      selectedMonth = currentDate.month.toString();
      selectedYear = currentDate.year.toString();
    });
    _loadAttendanceData();
  }

  String _getMonthName(int month) {
    const months = [
      'JANUARY',
      'FEBRUARY',
      'MARCH',
      'APRIL',
      'MAY',
      'JUNE',
      'JULY',
      'AUGUST',
      'SEPTEMBER',
      'OCTOBER',
      'NOVEMBER',
      'DECEMBER',
    ];
    return months[month - 1];
  }

  List<String> _getDaysOfWeek() {
    return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  }

  // Calculate attendance totals
  Map<String, int> _getAttendanceTotals() {
    Map<String, int> totals = {
      'present': 0,
      'absent': 0,
      'late': 0,
      'half_day': 0,
      'holiday': 0,
      'total': 0,
    };

    for (var record in attendanceData) {
      final status = record['type']?.toString().toLowerCase() ?? '';
      totals['total'] = totals['total']! + 1;

      switch (status) {
        case 'present':
          totals['present'] = totals['present']! + 1;
          break;
        case 'absent':
          totals['absent'] = totals['absent']! + 1;
          break;
        case 'late':
          totals['late'] = totals['late']! + 1;
          break;
        case 'half day':
        case 'half_day':
          totals['half_day'] = totals['half_day']! + 1;
          break;
        case 'holiday':
          totals['holiday'] = totals['holiday']! + 1;
          break;
        default:
          totals['absent'] =
              totals['absent']! + 1; // Default to absent for unknown status
      }
    }

    return totals;
  }

  @override
  Widget build(BuildContext context) {
    
    
    
    
    

    final appConfig = Provider.of<AppConfigProvider>(context);
    final primaryColor = appConfig.primaryColorObj;
    // final secondaryColor = appConfig.secondaryColorObj; // Unused

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: TranslatedText('Attendance'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          EnterpriseUIComponents.buildHeaderWithIllustration(
            title: 'Your Attendance is here!',
            subtitle: 'Track your daily academic presence',
            illustration: Image.asset(
              "assets/images/attendancepage.jpg",
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.calendar_month,
                color: primaryColor,
                size: 40,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Container(
                    height: 400, // Fixed height for calendar
                    margin: EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withValues(alpha: 0.1),
                          spreadRadius: 1,
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: isLoading
                        ? Center(child: CircularProgressIndicator())
                        : error != null
                        ? _errorView()
                        : _calendarView(),
                  ),
                  SizedBox(height: 10),
                  _attendanceSummary(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _calendarView() {
    
    
    

    return Column(
      children: [
        // Month header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: _previousMonth,
                icon: const Icon(Icons.arrow_back_ios),
              ),
              Text(
                '${_getMonthName(currentDate.month)} ${currentDate.year}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: _nextMonth,
                icon: const Icon(Icons.arrow_forward_ios),
              ),
            ],
          ),
        ),
        // Days header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: _getDaysOfWeek()
                .map(
                  (day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        if (infoMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              infoMessage!,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        // Calendar Grid
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 300),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
              ),
              itemCount: _getDaysInMonth(currentDate).length,
              itemBuilder: (context, index) {
                final day = _getDaysInMonth(currentDate)[index];
                final status = _getAttendanceStatus(day);
                final isToday =
                    day.day == DateTime.now().day &&
                    day.month == DateTime.now().month &&
                    day.year == DateTime.now().year;

                return Container(
                  margin: const EdgeInsets.all(2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: isToday
                              ? Provider.of<AppConfigProvider>(context).secondaryColorObj.withValues(alpha: 0.2)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              fontWeight: isToday
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isToday ? Provider.of<AppConfigProvider>(context).primaryColorObj : Colors.black,
                            ),
                          ),
                        ),
                      ),
                      if (status != null)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 3),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status),
                            shape: BoxShape.circle,
                          ),
                        )
                      else
                        const SizedBox(height: 11), // 8 (dot) + 3 (margin) placeholder
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        // Legend - One line
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _legend(Colors.green, 'Present'),
              _legend(Colors.red, 'Absent'),
              _legend(Colors.yellow[700]!, 'Late'),
              _legend(Colors.orange, 'Half Day'),
              _legend(Colors.grey, 'Holiday'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _legend(Color color, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 2),
      TranslatedText(
        text,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
      ),
    ],
  );

  Widget _summaryLegend(Color color, String text, int count) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 2),
      Text(
        '$text: $count',
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
      ),
    ],
  );

  Widget _errorView() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, color: Colors.red[400], size: 64),
        const SizedBox(height: 16),
        TranslatedText(
          error ?? 'Error loading data',
          style: const TextStyle(color: Colors.red, fontSize: 16),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _loadAttendanceData,
          child: const TranslatedText('Retry'),
        ),
      ],
    ),
  );

  Widget _attendanceSummary() {
    final totals = _getAttendanceTotals();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          // Legend-style summary - wraps to multiple lines if needed
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _summaryLegend(Colors.green, 'Present', totals['present']!),
              _summaryLegend(Colors.red, 'Absent', totals['absent']!),
              _summaryLegend(Colors.yellow[700]!, 'Late', totals['late']!),
              _summaryLegend(Colors.orange, 'Half Day', totals['half_day']!),
              _summaryLegend(Colors.grey, 'Holiday', totals['holiday']!),
              _summaryLegend(Provider.of<AppConfigProvider>(context).primaryColorObj, 'Total', totals['total']!),
            ],
          ),
          if (totals['total']! > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.analytics, color: Provider.of<AppConfigProvider>(context).primaryColorObj, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Attendance Rate: ${(((totals['present']! + totals['late']! + totals['half_day']!) / (totals['total']! - totals['holiday']!)) * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Provider.of<AppConfigProvider>(context).primaryColorObj,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

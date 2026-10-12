import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/cbse_exam.dart';
import '../widgets/translated_text.dart';

class CBSEExamSchedulePage extends StatefulWidget {
  final List<CBSEExam> exams;

  const CBSEExamSchedulePage({super.key, required this.exams});

  @override
  State<CBSEExamSchedulePage> createState() => _CBSEExamSchedulePageState();
}

class _CBSEExamSchedulePageState extends State<CBSEExamSchedulePage> {
  CBSEExam? _selectedExam;

  @override
  void initState() {
    super.initState();
    if (widget.exams.isNotEmpty) {
      _selectedExam = widget.exams.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const TranslatedText(
          'CBSE Exam Schedule',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.grey[800],
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: widget.exams.isEmpty
          ? _buildEmptyState(
              icon: Icons.assignment_outlined,
              title: 'No CBSE exams found',
              subtitle: 'Exam schedule will be available soon',
            )
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const TranslatedText(
                        'Plan your preparation!',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TranslatedText(
                        'Select an exam to view its schedule',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 16),
                      _buildExamDropdown(),
                    ],
                  ),
                ),
                Expanded(
                  child: _selectedExam == null
                      ? _buildEmptyState(
                          icon: Icons.schedule_outlined,
                          title: 'Select an exam',
                          subtitle: 'Pick an exam from the dropdown above',
                        )
                      : _selectedExam!.subjects.isEmpty
                      ? _buildEmptyState(
                          icon: Icons.event_busy,
                          title: 'No schedule found',
                          subtitle:
                              'Exam timetable details will be published soon for ${_selectedExam!.name}',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                          itemCount: _selectedExam!.subjects.length,
                          itemBuilder: (context, index) {
                            final subject = _selectedExam!.subjects[index];
                            return _buildSubjectCard(subject);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildExamDropdown() {
    if (widget.exams.length == 1) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Text(
          _selectedExam?.name ?? 'CBSE Exam',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<CBSEExam>(
              value: _selectedExam,
              isExpanded: true,
              borderRadius: BorderRadius.circular(10),
              items: widget.exams
                  .map(
                    (exam) => DropdownMenuItem(
                      value: exam,
                      child: Text(
                        exam.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedExam = value;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_resolveExamDownloadUrl() != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _downloadExamSchedule,
              icon: const Icon(Icons.download, size: 18),
              label: const TranslatedText('Download schedule'),
            ),
          ),
      ],
    );
  }

  Widget _buildSubjectCard(CBSEExamSubject subject) {
    final downloadUrl = _resolveDownloadUrl(subject);
    return Column(
      children: [
        Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject.subjectName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subject.subjectCode,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                _buildScheduleRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Date',
                  value: subject.formattedDate,
                ),
                const SizedBox(height: 10),
                _buildScheduleRow(
                  icon: Icons.access_time_outlined,
                  label: 'Time',
                  value: _formatTimeRange(subject),
                ),
                const SizedBox(height: 10),
                _buildScheduleRow(
                  icon: Icons.timelapse_outlined,
                  label: 'Duration',
                  value: subject.duration.isEmpty
                      ? '-'
                      : '${subject.duration} mins',
                ),
                const SizedBox(height: 10),
                _buildScheduleRow(
                  icon: Icons.meeting_room_outlined,
                  label: 'Room',
                  value: subject.roomNo.isEmpty ? '-' : subject.roomNo,
                ),
                if (subject.isPractical == 'yes' ||
                    subject.practicalMaximumMark != null) ...[
                  const Divider(height: 24),
                  _buildAssessmentChips(subject),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
    if (downloadUrl != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _launchUrl(downloadUrl),
                icon: const Icon(Icons.download, size: 18),
                label: const TranslatedText('Download'),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildScheduleRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.green[400], size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TranslatedText(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAssessmentChips(CBSEExamSubject subject) {
    final chips = <Widget>[];

    if (subject.isWritten == 'yes' && subject.writtenMaximumMarks.isNotEmpty) {
      chips.add(_buildChip('Theory Max: ${subject.writtenMaximumMarks}'));
    }

    if (subject.isPractical == 'yes' &&
        (subject.practicalMaximumMark?.isNotEmpty ?? false)) {
      chips.add(
        _buildChip(
          'Practical Max: ${subject.practicalMaximumMark}',
          color: Colors.orange[100],
          textColor: Colors.orange[800],
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips.isEmpty
          ? [
              _buildChip(
                'No assessment details available',
                color: Colors.grey[100],
                textColor: Colors.grey[600],
              ),
            ]
          : chips,
    );
  }

  Widget _buildChip(String label, {Color? color, Color? textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color ?? Colors.green[50],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textColor ?? Colors.green[800],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: Colors.grey[400]),
          const SizedBox(height: 12),
          TranslatedText(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          TranslatedText(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  String _formatTimeRange(CBSEExamSubject subject) {
    if (subject.timeFrom.isEmpty) return '-';
    final formattedStart = _formatTime(subject.timeFrom);

    String formattedEnd = '??';
    final startDateTime = _tryParseDateTime(subject.date, subject.timeFrom);
    final durationMinutes = int.tryParse(subject.duration) ?? 0;

    if (durationMinutes > 0 && startDateTime != null) {
      final endDateTime = startDateTime.add(Duration(minutes: durationMinutes));
      formattedEnd = DateFormat('hh:mm a').format(endDateTime);
    } else if (subject.timeTo.isNotEmpty) {
      formattedEnd = _formatTimeWithDate(subject.date, subject.timeTo);
    }

    return '$formattedStart - $formattedEnd';
  }

  String _formatTime(String time) {
    final parsed = _parseTimeOnly(time);
    if (parsed != null) {
      return DateFormat('hh:mm a').format(parsed);
    }
    return time;
  }

  String _formatTimeWithDate(String date, String time) {
    final dt = _tryParseDateTime(date, time);
    if (dt != null) {
      return DateFormat('hh:mm a').format(dt);
    }
    return _formatTime(time);
  }

  DateTime? _parseTimeOnly(String time) {
    final parts = time.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return DateTime(2000, 1, 1, hour, minute);
  }

  DateTime? _tryParseDateTime(String date, String time) {
    if (date.isEmpty || time.isEmpty) return null;
    String normalizedDate = date;
    if (date.contains('/')) {
      final parts = date.split('/');
      if (parts.length == 3) {
        normalizedDate = '${parts[2]}-${parts[0].padLeft(2, '0')}-${parts[1].padLeft(2, '0')}';
      }
    }
    final combined = '$normalizedDate $time';
    return DateTime.tryParse(combined);
  }

  Future<void> _downloadExamSchedule() async {
    final url = _resolveExamDownloadUrl();
    if (url == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: TranslatedText('No schedule download link available')),
      );
      return;
    }
    await _launchUrl(url);
  }

  String? _resolveExamDownloadUrl() {
    if (_selectedExam == null) return null;
    for (final subject in _selectedExam!.subjects) {
      final download = _resolveDownloadUrl(subject);
      if (download != null) return download;
    }
    return null;
  }

  String? _resolveDownloadUrl(CBSEExamSubject subject) {
    final candidateKeys = [
      'download_link',
      'downloadUrl',
      'download_url',
      'file',
      'url',
      'link',
      'schedule_download',
    ];
    final map = subject.raw;
    for (final key in candidateKeys) {
      final value = map[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        final url = value.toString().trim();
        if (url.startsWith('http')) {
          return url;
        }
        final base = Uri.parse('https://demo.smart-school.in');
        return base.resolve(url).toString();
      }
    }
    return null;
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: TranslatedText('Invalid download link')),
      );
      return;
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: TranslatedText('Unable to open download link')),
      );
    }
  }
}

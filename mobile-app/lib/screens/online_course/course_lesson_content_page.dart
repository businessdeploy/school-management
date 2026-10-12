import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../utils/url_manager.dart';
import '../../providers/app_config_provider.dart';

class CourseLessonContentPage extends StatefulWidget {
  final Map<String, dynamic> item;
  final String courseId;
  final String courseTitle;

  const CourseLessonContentPage({
    super.key,
    required this.item,
    required this.courseId,
    required this.courseTitle,
  });

  @override
  State<CourseLessonContentPage> createState() => _CourseLessonContentPageState();
}

class _CourseLessonContentPageState extends State<CourseLessonContentPage> {
  List<Map<String, dynamic>> _attachments = [];
  bool _isLoadingAttachments = false;
  bool _isMarkingComplete = false;

  @override
  void initState() {
    super.initState();
    _fetchAttachments();
  }

  Future<void> _fetchAttachments() async {
    final lessonId = widget.item['id']?.toString() ?? '';
    if (lessonId.isEmpty) return;

    setState(() => _isLoadingAttachments = true);

    try {
      final response = await ApiService.getLessonAttachments(lessonId);
      List<Map<String, dynamic>> attachmentsList = [];
      
      if (response['attachments'] != null) {
        attachmentsList = List<Map<String, dynamic>>.from(response['attachments']);
      } else if (response['data'] != null && response['data'] is List) {
        attachmentsList = List<Map<String, dynamic>>.from(response['data']);
      }

      final sectionId = widget.item['section_id']?.toString() ?? '';
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

      if (mounted) {
        setState(() {
          _attachments = attachmentsList;
          _isLoadingAttachments = false;
        });
      }
    } catch (e) {
      
      if (mounted) setState(() => _isLoadingAttachments = false);
    }
  }

  Future<void> _toggleCompletion() async {
    final lessonId = widget.item['id']?.toString() ?? '';
    if (lessonId.isEmpty) return;

    setState(() => _isMarkingComplete = true);

    try {
      final studentId = await AuthService.getStudentId();
      final currentStatus = widget.item['status'];
      final newStatus = (currentStatus == 1 || currentStatus == '1' || currentStatus == true) ? 0 : 1;

      final sectionId = widget.item['section_id']?.toString();
      final lessonQuizType = widget.item['raw']?['lesson_quiz_type']?.toString() ?? '1';

      final response = await ApiService.updateCourseProgress(
        courseId: widget.courseId,
        studentId: studentId,
        lessonId: lessonId,
        sectionId: sectionId,
        lessonQuizType: lessonQuizType,
        status: newStatus,
      );

      if (mounted) {
        if (response['status'] == 1 || response['status'] == '1' || response['success'] == true) {
          setState(() {
            widget.item['status'] = newStatus;
            _isMarkingComplete = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(newStatus == 1 ? 'Lesson marked as complete!' : 'Lesson marked as incomplete'),
              backgroundColor: newStatus == 1 ? Colors.green : Colors.orange,
            ),
          );
        } else {
          setState(() => _isMarkingComplete = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response['message'] ?? 'Failed to update status'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      
      if (mounted) {
        setState(() => _isMarkingComplete = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appConfig = Provider.of<AppConfigProvider>(context);
    final primaryColor = appConfig.primaryColorObj;
    
    final raw = widget.item['raw'] ?? {};
    final content = raw['summary'] ?? raw['content'] ?? raw['description'] ?? 'No content available for this lesson.';
    final title = widget.item['title'] ?? 'Lesson Content';
    final isCompleted = widget.item['status'] == 1 || widget.item['status'] == '1' || widget.item['status'] == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.courseTitle,
                    style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildVideoButton(primaryColor),
                  const Divider(height: 32),
                  Html(
                    data: content,
                    style: {
                      "body": Style(
                        fontSize: FontSize(16),
                        lineHeight: LineHeight(1.5),
                        margin: Margins.zero,
                        padding: HtmlPaddings.zero,
                      ),
                    },
                  ),
                  if (_attachments.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    const Text('Attachments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: _attachments.length,
                      itemBuilder: (context, index) => _buildAttachmentItem(_attachments[index]),
                    ),
                  ],
                  if (_isLoadingAttachments)
                    const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
                ],
              ),
            ),
          ),
          _buildActionBottomBar(primaryColor, isCompleted),
        ],
      ),
    );
  }

  Widget _buildActionBottomBar(Color primaryColor, bool isCompleted) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isMarkingComplete ? null : _toggleCompletion,
            style: ElevatedButton.styleFrom(
              backgroundColor: isCompleted ? Colors.grey : primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _isMarkingComplete
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(
                    isCompleted ? 'Mark as Incomplete' : 'Complete and Continue',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentItem(Map<String, dynamic> attachment) {
    final fileName = attachment['attachment']?.toString() ?? 'File';
    final fileUrl = attachment['attachment_url']?.toString() ?? '';
    
    return InkWell(
      onTap: () {
        if (fileUrl.isNotEmpty) {
           _launchContent(fileUrl);
        }
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: const Icon(Icons.description, color: Colors.red, size: 36),
          ),
          const SizedBox(height: 8),
          Text(
            fileName,
            style: const TextStyle(fontSize: 11),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _launchContent(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildVideoButton(Color primaryColor) {
    // Basic detection for video URL in item or raw
    final raw = widget.item['raw'] ?? {};
    final lessonType = (widget.item['lesson_type'] ?? raw['lesson_type'])?.toString().toLowerCase() ?? '';
    final duration = (widget.item['duration'] ?? raw['duration'])?.toString() ?? '';
    
    final videoUrl = widget.item['url'] ?? 
                     widget.item['video_url'] ??
                     widget.item['video_link'] ??
                     widget.item['video'] ??
                     widget.item['video_id'] ??
                     widget.item['link'] ??
                     widget.item['lesson_url'] ??
                     widget.item['course_url'] ??
                     widget.item['course_link'] ??
                     widget.item['file'] ??
                     widget.item['video_file'] ??
                     widget.item['videoPath'] ??
                     widget.item['videoName'] ??
                     raw['video_url'] ?? 
                     raw['video_id'] ?? 
                     raw['video_link'];

    bool hasVideoSignal = (videoUrl != null && videoUrl.toString().trim().isNotEmpty && videoUrl.toString() != 'null') ||
                          (lessonType == 'video' || lessonType == 'video-link') ||
                          (duration.isNotEmpty && duration != '00:00:00' && duration != '0');

    if (!hasVideoSignal) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton.icon(
        onPressed: () {
          if (videoUrl != null && videoUrl.toString().trim().isNotEmpty && videoUrl.toString() != 'null') {
             _launchContent(videoUrl.toString());
          } else {
             // If no specific URL but it's a video, fallback could go here
             // But for now, we just try to launch whatever we have
             _launchContent(videoUrl?.toString() ?? '');
          }
        },
        icon: const Icon(Icons.play_circle_fill, color: Colors.green),
        label: const Text('Watch Lesson Video', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.green, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
      ),
    );
  }
}

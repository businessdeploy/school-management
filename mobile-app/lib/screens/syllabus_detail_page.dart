import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/translated_text.dart';
import '../widgets/enterprise_ui_components.dart';
import 'package:provider/provider.dart';
import '../providers/app_config_provider.dart';

class SyllabusDetailPage extends StatefulWidget {
  final String subjectSyllabusId;
  final String lessonName;
  final String topicName;

  const SyllabusDetailPage({
    super.key,
    required this.subjectSyllabusId,
    required this.lessonName,
    required this.topicName,
  });

  @override
  State<SyllabusDetailPage> createState() => _SyllabusDetailPageState();
}

class _SyllabusDetailPageState extends State<SyllabusDetailPage> {
  Map<String, dynamic>? syllabusData;
  List<Map<String, dynamic>> comments = [];
  bool isLoading = true;
  String? errorMessage;
  final TextEditingController _commentController = TextEditingController();
  YoutubePlayerController? _ytController;

  @override
  void initState() {
    super.initState();
    loadSyllabusData();
    loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _ytController?.dispose();
    super.dispose();
  }

  Future<void> loadSyllabusData() async {
    try {
      
      final data = await ApiService.getSyllabus(widget.subjectSyllabusId);

      
      if (!mounted) return;

      if (data['data'] != null) {
        final content = data['data'];
        
        if (content is Map) {
          final videoKeys = ['lacture_youtube_url', 'lecture_youtube_url', 'youtube_url', 'video_url', 'video_id', 'url'];
          for (var k in videoKeys) {
            if (content[k] != null && content[k].toString().isNotEmpty) {
              
            }
          }
        }

        setState(() {
          syllabusData = data['data'];
          isLoading = false;
        });

        // Initialize YouTube Controller if URL or ID is found
        final videoSource = _getYoutubeUrl();
        if (videoSource.isNotEmpty) {
           // Try to convert URL to ID. If it's already an ID, it might return null, so we check both.
           String? videoId = YoutubePlayer.convertUrlToId(videoSource);
           
           // If direct ID was used (11 chars) and convert failed, use the source directly
           if (videoId == null && videoSource.length == 11) {
              videoId = videoSource;
           }

           if (videoId != null && videoId.isNotEmpty) {
              _ytController = YoutubePlayerController(
                initialVideoId: videoId,
                flags: const YoutubePlayerFlags(
                  autoPlay: false,
                  mute: false,
                  disableDragSeek: false,
                  loop: false,
                  isLive: false,
                  forceHD: false,
                  enableCaption: true,
                ),
              );
              
           } else {
              
           }
        }
      } else {
        setState(() {
          errorMessage = 'No syllabus data found';
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = 'Error loading syllabus data: $e';
        isLoading = false;
      });
    }
  }

  Future<void> loadComments() async {
    try {
      final data = await ApiService.getForumMessage(widget.subjectSyllabusId);

      if (!mounted) return;

      if (data['syllabus'] != null) {
        setState(() {
          comments = List<Map<String, dynamic>>.from(data['syllabus']);
        });
      }
    } catch (e) {
      // Comments loading error is not critical, so we don't show error
      
    }
  }

  Future<void> saveComment() async {
    if (_commentController.text.trim().isEmpty) return;

    try {
      // Get dynamic student ID from authentication service
      final studentId = await AuthService.getStudentId();

      await ApiService.saveComment(
        studentId,
        _commentController.text.trim(),
      );

      _commentController.clear();
      loadComments(); // Reload comments

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: TranslatedText('Comment saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: TranslatedText('Error saving comment: $e')));
      }
    }
  }

  Future<void> _launchURL(String url) async {
    try {
      String finalUrl = url;
      // If it's a plain ID (11 chars) and doesn't contain a domain
      if (url.length == 11 && !url.contains('.') && !url.contains('/') && !url.contains(':')) {
        finalUrl = 'https://www.youtube.com/watch?v=$url';
      }
      
      final Uri uri = Uri.parse(finalUrl);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open the video link')),
          );
        }
      }
    } catch (e) {
      
    }
  }

  String _getYoutubeUrl() {
    if (syllabusData == null) return '';

    final videoKeys = ['lacture_youtube_url', 'lecture_youtube_url', 'youtube_url', 'video_url', 'video_id', 'url'];
    for (var k in videoKeys) {
      final value = syllabusData![k];
      if (value != null && value.toString().isNotEmpty) {
        return value.toString();
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final appConfigProvider = Provider.of<AppConfigProvider>(context);
    final primaryColor = appConfigProvider.primaryColorObj;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const TranslatedText('Syllabus Details'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Sticky Header
                EnterpriseUIComponents.buildHeaderWithIllustration(
                  title: 'Syllabus Detail',
                  subtitle: 'Explore your curriculum details',
                  illustration: Image.asset(
                    'assets/images/lessonplanpage.jpg',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.menu_book_outlined,
                      color: primaryColor,
                      size: 40,
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          if (errorMessage != null)
                             Padding(
                               padding: const EdgeInsets.all(32),
                               child: Text(errorMessage!, style: const TextStyle(color: Colors.red)),
                             )
                          else ...[
                            _buildYoutubeVideoCheck(),
                            const SizedBox(height: 16),
                            _buildSyllabusDetails(),
                            const SizedBox(height: 16),
                            _buildCommentsSection(),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildYoutubeVideoCheck() {
    final videoSource = _getYoutubeUrl();
    if (videoSource.isNotEmpty && _ytController != null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: YoutubePlayer(
            controller: _ytController!,
            showVideoProgressIndicator: true,
            progressIndicatorColor: Colors.blueAccent,
            onReady: () {
              
            },
            bottomActions: [
              CurrentPosition(),
              ProgressBar(
                isExpanded: true,
                colors: const ProgressBarColors(
                  playedColor: Colors.blueAccent,
                  handleColor: Colors.blueAccent,
                ),
              ),
              RemainingDuration(),
              FullScreenButton(),
            ],
          ),
        ),
      );
    } else if (videoSource.isNotEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            const Icon(Icons.videocam, size: 40, color: Colors.red),
            const SizedBox(height: 8),
            const TranslatedText(
              'Video Available',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TranslatedText(
              'Click to open: $videoSource',
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _launchURL(videoSource),
              icon: const Icon(Icons.play_arrow),
              label: const TranslatedText('Watch Video'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildSyllabusDetails() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Lesson Plan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildDetailRow('Class', '${syllabusData!['created_for'] ?? ''}'),
          _buildDetailRow('Subject', '${syllabusData!['topic_name'] ?? ''}'),
          _buildDetailRow(
            'Date',
            '${syllabusData!['date'] ?? ''} ${syllabusData!['time_from'] ?? ''}-${syllabusData!['time_to'] ?? ''}',
          ),
          _buildDetailRow('Lesson', '${syllabusData!['lesson_name'] ?? ''}'),
          _buildDetailRow('Topic', '${syllabusData!['topic_name'] ?? ''}'),
          _buildDetailRow('Sub Topic', '${syllabusData!['sub_topic'] ?? ''}'),
          _buildDetailRow(
            'General Objectives',
            '${syllabusData!['general_objectives'] ?? ''}',
          ),
          _buildDetailRow(
            'Teaching Method',
            '${syllabusData!['teaching_method'] ?? ''}',
          ),
          _buildDetailRow(
            'Previous Knowledge',
            '${syllabusData!['previous_knowledge'] ?? ''}',
          ),
          _buildDetailRow(
            'Comprehensive Questions',
            '${syllabusData!['comprehensive_questions'] ?? ''}',
          ),
          _buildDetailRow(
            'Presentation',
            '${syllabusData!['presentation'] ?? ''}',
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TranslatedText(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          TranslatedText(
            value.isEmpty ? 'Not available' : value,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TranslatedText(
            'Comments',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          // Comment input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: const InputDecoration(
                    hintText: 'Comments',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: saveComment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                child: const TranslatedText(
                  'Send',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Comments list
          if (comments.isEmpty)
            const TranslatedText(
              'No comments yet',
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            )
          else
            ...comments.map((comment) => _buildCommentCard(comment)),
        ],
      ),
    );
  }

  Widget _buildCommentCard(Map<String, dynamic> comment) {
    final message = comment['message'] ?? '';
    final createdDate = comment['created_date'] ?? '';
    final firstName = comment['firstname'] ?? '';
    final lastName = comment['lastname'] ?? '';
    final type = comment['type'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: type == 'student'
                    ? Colors.blue[100]
                    : Colors.green[100],
                child: Text(
                  '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}',
                  style: TextStyle(
                    color: type == 'student'
                        ? Colors.blue[700]
                        : Colors.green[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$firstName $lastName',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      createdDate,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: type == 'student'
                      ? Colors.blue[100]
                      : Colors.green[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  type.toUpperCase(),
                  style: TextStyle(
                    color: type == 'student'
                        ? Colors.blue[700]
                        : Colors.green[700],
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

}

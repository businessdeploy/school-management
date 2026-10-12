import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/timeline.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/url_manager.dart';
import '../widgets/translated_text.dart';
import '../widgets/enterprise_ui_components.dart';
import 'add_timeline_page.dart';
import 'edit_timeline_page.dart';

class TimelinePage extends StatefulWidget {
  const TimelinePage({super.key});

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  List<Timeline> timelineList = [];
  bool isLoading = true;
  String? error;
  bool _canAddTimeline = false;
  bool _isCheckingPermission = true;

  @override
  void initState() {
    super.initState();
    _loadTimeline();
    _checkTimelinePermission();
  }

  Future<void> _checkTimelinePermission() async {
    try {
      setState(() {
        _isCheckingPermission = true;
      });

      final studentId = await AuthService.getStudentId();
      final response = await ApiService.getTimeLineStatus(studentId);
      
      
      
      // Trust the can_add field from the API response
      // The API already checks status: 1 and student_timeline: enabled
      bool canAdd = response['can_add'] == true;
      
      

      setState(() {
        _canAddTimeline = canAdd;
        _isCheckingPermission = false;
      });
      
      
    } catch (e) {
      
      setState(() {
        _canAddTimeline = false;
        _isCheckingPermission = false;
      });
    }
  }

  Future<void> _loadTimeline() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final studentId = await AuthService.getStudentId();

      final timelineData = await ApiService.getTimeline(studentId);
      
      setState(() {
        if (timelineData['timeline'] != null) {
          final rawList = List<Map<String, dynamic>>.from(timelineData['timeline']);
          timelineList = rawList
              .map((item) => Timeline.fromJson(item))
              .toList();
          
          for (var item in rawList) {
             
          }

          // Sort by date (newest first)
          timelineList.sort((a, b) {
            try {
              final dateA = DateTime.parse(a.timelineDate);
              final dateB = DateTime.parse(b.timelineDate);
              return dateB.compareTo(dateA);
            } catch (e) {
              return 0;
            }
          });
          
          
        } else {
          timelineList = [];
          
        }
        isLoading = false;
      });
    } catch (e) {
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
          'Student Timeline',
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
      ),
      body: Column(
        children: [
          EnterpriseUIComponents.buildHeaderWithIllustration(
            title: 'Timeline',
            subtitle: 'Track your academic milestones',
            illustration: Image.asset(
              'assets/images/timelinepage.jpg',
              fit: BoxFit.contain,
            ),
          ),
          // Timeline Content
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
                              const TranslatedText(
                                'Failed to load timeline',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadTimeline,
                                child: const TranslatedText('Retry'),
                              ),
                            ],
                          ),
                        )
                      : timelineList.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.timeline_outlined,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  const TranslatedText(
                                    'No timeline entries found',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: timelineList.length,
                              itemBuilder: (context, index) {
                                return _buildTimelineCard(timelineList[index], index);
                              },
                            ),
            ),
          ),
        ],
      ),
      // Show FAB only if admin allows students to add timeline
      floatingActionButton: _canAddTimeline && !_isCheckingPermission
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddTimelinePage(),
                  ),
                );
                if (result == true) {
                  _loadTimeline();
                }
              },
              backgroundColor: Colors.green[600],
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildTimelineCard(Timeline timeline, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          Column(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.green[300],
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.access_time,
                  color: Colors.white,
                  size: 12,
                ),
              ),
              if (index < timelineList.length - 1)
                Container(
                  width: 2,
                  height: 60,
                  color: Colors.green[200],
                ),
            ],
          ),
          const SizedBox(width: 16),
          // Timeline card
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with title and actions (Edit/Delete buttons only if allowed)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            timeline.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        if (_canAddTimeline)
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                                onPressed: () async {
                                  // Navigate to EditTimelinePage and reload on update
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => EditTimelinePage(timeline: timeline),
                                    ),
                                  );
                                  if (result == true) {
                                    _loadTimeline();
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                onPressed: () => _showDeleteDialog(timeline),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Date
                    Text(
                      timeline.formattedDate,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Description
                    Text(
                      timeline.description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                    // File attachment (if exists)
                    if (timeline.document.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.attach_file,
                              size: 20,
                              color: Colors.blue[700],
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _getFileName(timeline.document),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.blue[900],
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _launchDocument(timeline.document),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue[600],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.download,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 4),
                                    const TranslatedText(
                                      'Open',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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

  String _getFileName(String documentPath) {
    if (documentPath.isEmpty) return '';
    
    // Extract filename from path
    final parts = documentPath.split('/');
    return parts.isNotEmpty ? parts.last : documentPath;
  }

  Future<void> _launchDocument(String documentPath) async {
    if (documentPath.isEmpty) return;
    
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: TranslatedText('Opening document...'),
          duration: Duration(seconds: 1),
        ),
      );

      // Resolve the full URL for the document
      final baseUrl = await UrlManager.getBaseUrl();
      String documentUrl;
      
      // Check if it's already a full URL
      if (documentPath.toLowerCase().startsWith('http://') || 
          documentPath.toLowerCase().startsWith('https://')) {
        documentUrl = documentPath;
      } else {
        // Construct URL - timeline documents are typically in uploads/student_timeline/
        String normalizedPath = documentPath;
        
        // Remove leading slash if present
        if (normalizedPath.startsWith('/')) {
          normalizedPath = normalizedPath.substring(1);
        }
        
        // If path doesn't start with 'uploads/', add the timeline upload prefix
        if (!normalizedPath.startsWith('uploads/')) {
          normalizedPath = 'uploads/student_timeline/$normalizedPath';
        }
        
        documentUrl = '$baseUrl/$normalizedPath';
      }
      
      
      
      final uri = Uri.parse(documentUrl);

      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (!await launchUrl(uri, mode: LaunchMode.platformDefault)) {
          throw 'Could not launch $documentUrl';
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: TranslatedText('Could not open document: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildTimelineIllustration() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          // Large clock
          Positioned(
            top: 10,
            left: 20,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.blue[400]!, width: 3),
              ),
              child: Center(
                child: Text(
                  '10:10',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
              ),
            ),
          ),
          // Small stopwatch
          Positioned(
            top: 5,
            right: 15,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.pink[300],
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.timer,
                color: Colors.white,
                size: 12,
              ),
            ),
          ),
          // Person
          Positioned(
            bottom: 15,
            left: 10,
            child: Container(
              width: 25,
              height: 35,
              decoration: BoxDecoration(
                color: Colors.orange[200],
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          // Calendar
          Positioned(
            bottom: 20,
            right: 10,
            child: Icon(
              Icons.calendar_today,
              color: Colors.blue[600],
              size: 16,
            ),
          ),
          // Envelope
          Positioned(
            top: 30,
            left: 5,
            child: Icon(
              Icons.mail,
              color: Colors.green[600],
              size: 12,
            ),
          ),
          // Document
          Positioned(
            bottom: 5,
            right: 5,
            child: Icon(
              Icons.description,
              color: Colors.grey[600],
              size: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(Timeline timeline) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const TranslatedText('Delete Timeline'),
        content: const TranslatedText('Are you sure you want to delete this timeline?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const TranslatedText('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteTimeline(timeline.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const TranslatedText('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTimeline(String id) async {
    try {
      setState(() {
        isLoading = true;
      });

      final result = await ApiService.deleteTimeline(id);
      
      if (result['status'] == '1' || result['status'] == 1 || result['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: TranslatedText('Timeline deleted successfully')),
          );
          _loadTimeline();
        }
      } else {
        throw Exception(result['message'] ?? 'Failed to delete timeline');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: TranslatedText('Error: $e'), backgroundColor: Colors.red),
        );
        setState(() {
          isLoading = false;
        });
      }
    }
  }
}
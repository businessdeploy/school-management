import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../models/gmeet_class.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../config/app_config.dart';
import '../providers/app_config_provider.dart';
import '../widgets/translated_text.dart';
import '../widgets/enterprise_ui_components.dart';

class GmeetLiveClassesPage extends StatefulWidget {
  const GmeetLiveClassesPage({super.key});

  @override
  State<GmeetLiveClassesPage> createState() => _GmeetLiveClassesPageState();
}

class _GmeetLiveClassesPageState extends State<GmeetLiveClassesPage> {
  List<GmeetClass> gmeetClasses = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadGmeetClasses();
  }

  Future<void> loadGmeetClasses() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // Get dynamic student ID from authentication service
      final studentId = await AuthService.getStudentId();

      final response = await ApiService.getGmeetLiveClasses(studentId);

      List<dynamic> lessonItems = [];
      
      // Check multiple possible keys for the data
      if (response['live_classes'] != null) {
        lessonItems = response['live_classes'];
      } else if (response['classes'] != null) {
        lessonItems = response['classes'];
      } else if (response['data'] != null && response['data'] is List) {
        lessonItems = response['data'];
      } else if (response['gmeet_classes'] != null) {
        lessonItems = response['gmeet_classes'];
      }

      if (!mounted) return;

      if (lessonItems.isEmpty) {
        setState(() {
          gmeetClasses = [];
          isLoading = false;
          errorMessage =
              'No Gmeet classes available. Please check with your teacher.';
        });
        return;
      }

      final convertedClasses = lessonItems
          .map((item) => GmeetClass.fromJson(item as Map<String, dynamic>))
          .toList();

      setState(() {
        gmeetClasses = convertedClasses;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        gmeetClasses = [];
        isLoading = false;
        errorMessage =
            'Failed to load Gmeet classes. Please check your internet connection and try again.';
      });
    }
  }

  String _formatDateTime(String dateTimeStr) {
    if (dateTimeStr.isEmpty) return '';
    try {
      // Try parsing with multiple formats to handle server time correctly
      DateTime dateTime;
      
      // Try standard ISO format first
      try {
        dateTime = DateTime.parse(dateTimeStr);
      } catch (_) {
        // Try formats like "YYYY-MM-DD HH:MM:SS" or "YYYY-MM-DD HH:MM"
        try {
          // Replace common separators
          String normalized = dateTimeStr.replaceAll('/', '-').trim();
          // Try adding time if missing
          if (normalized.split(' ').length == 1) {
            normalized = '$normalized 00:00:00';
          }
          dateTime = DateTime.parse(normalized);
        } catch (_) {
          // Try parsing as timestamp if it's a number
          try {
            final timestamp = int.tryParse(dateTimeStr);
            if (timestamp != null) {
              dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
            } else {
              return dateTimeStr; // Return original if all parsing fails
            }
          } catch (_) {
            return dateTimeStr; // Return original if all parsing fails
          }
        }
      }
      
      // Debug: Log the parsed time to verify correct parsing
      
      
      // Format using 12-hour format with correct AM/PM
      // Use 'hh' for 12-hour format (01-12) and 'a' for AM/PM
      final formatted = DateFormat('dd/MM/yyyy hh:mm a').format(dateTime);
      
      // Verify the conversion is correct
      
      
      return formatted;
    } catch (e) {
      
      return dateTimeStr;
    }
  }

  Color _statusBadgeColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'live':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  Future<void> _joinMeeting(String joinUrl) async {
    final formatted = joinUrl.trim();
    if (formatted.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: TranslatedText('Meeting link missing')),
      );
      return;
    }

    final webUri = _normalizeMeetUri(formatted);
    final appUri = _buildAppUri(webUri);

    if (await _tryLaunchUri(appUri)) return;
    if (await _tryLaunchUri(webUri)) return;

    final playStoreUri = Uri.parse('market://details?id=com.google.android.apps.meetings');
    if (await _tryLaunchUri(playStoreUri)) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: TranslatedText('Unable to open Google Meet. Please install the Meet app or try again later.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool> _tryLaunchUri(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: TranslatedText('Launching: $uri'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
    return false;
  }

  Uri _normalizeMeetUri(String raw) {
    var formatted = raw;
    if (!formatted.startsWith('http://') && !formatted.startsWith('https://')) {
      formatted = 'https://$formatted';
    }
    return Uri.parse(formatted);
  }

  Uri _buildAppUri(Uri webUri) {
    if (!webUri.host.contains('meet.google.com')) {
      return webUri;
    }
    final code = webUri.pathSegments.join('/');
    if (code.isEmpty) return webUri;
    return Uri.parse('googlemeet://$code');
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const TranslatedText(
          'Gmeet Live Classes',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: Provider.of<AppConfigProvider>(context).primaryColorObj,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: isLoading
          ? EnterpriseUIComponents.buildLoadingIndicator(
              message: 'Loading Gmeet classes...',
            )
          : errorMessage != null
              ? EnterpriseUIComponents.buildErrorState(
                  error: errorMessage!,
                  onRetry: loadGmeetClasses,
                )
              : Column(
                  children: [
                    // Enterprise Header (Sticky)
                    EnterpriseUIComponents.buildHeaderWithIllustration(
                      title: 'Your Gmeet Live Classes!',
                      subtitle: 'Join your virtual classrooms',
                      illustration: Image.asset(
                        "assets/images/liveclasspage.jpg",
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.video_camera_front,
                          color: Colors.blue[600],
                          size: 40,
                        ),
                      ),
                    ),
                    Expanded(
                      child: gmeetClasses.isEmpty
                          ? EnterpriseUIComponents.buildEmptyState(
                              title: 'No Live Classes',
                              message: 'You have no upcoming Gmeet classes at the moment.',
                              icon: Icons.video_camera_front_outlined,
                            )
                          : RefreshIndicator(
                              onRefresh: loadGmeetClasses,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: gmeetClasses.length,
                                itemBuilder: (context, index) {
                                  return _buildGmeetClassCard(
                                    gmeetClasses[index],
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildGmeetClassCard(GmeetClass gmeetClass) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.blueGrey[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TranslatedText(
                    gmeetClass.className,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                // Only show Join button if class is not completed
                if (gmeetClass.status.toLowerCase() != 'completed')
                  GestureDetector(
                    onTap: () => _joinMeeting(gmeetClass.joinUrl),
                    child: const TranslatedText(
                      "Join",
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Class Duration with status
                Row(
                  children: [
                    const SizedBox(
                      width: 160,
                      child: TranslatedText(
                        "Class Duration (Minutes)",
                        style: TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        gmeetClass.classDuration.toString(),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _statusBadgeColor(gmeetClass.status),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: TranslatedText(
                        gmeetClass.status,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                _buildDetailRow("Class", gmeetClass.classCode),
                _buildDetailRow("Date Time", _formatDateTime(gmeetClass.dateTime)),
                _buildDetailRow(
                  "Class Host",
                  "${gmeetClass.teacherName}(Teacher: ${gmeetClass.teacherId})",
                ),
                _buildDetailRow("Description", gmeetClass.description),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: TranslatedText(
              label,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
          Expanded(
            child: TranslatedText(
              value.isEmpty ? 'Not available' : value,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

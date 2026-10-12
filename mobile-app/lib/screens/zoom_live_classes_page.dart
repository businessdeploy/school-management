import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/translated_text.dart';
import '../widgets/enterprise_ui_components.dart';

class ZoomLiveClassesPage extends StatefulWidget {
  const ZoomLiveClassesPage({super.key});

  @override
  State<ZoomLiveClassesPage> createState() => _ZoomLiveClassesPageState();
}

class _ZoomLiveClassesPageState extends State<ZoomLiveClassesPage> {
  List<Map<String, dynamic>> zoomClasses = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadZoomClasses();
  }

  Future<void> loadZoomClasses() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // Get dynamic student ID from authentication service
      final studentId = await AuthService.getStudentId();

      
      

      try {
        // Call the actual API
        var response = await ApiService.getZoomLiveClasses(studentId);

        // Check if we got valid data
        if (response['data'] != null && response['data'] is List) {
          final dataLength = (response['data'] as List).length;
          
        } else {
          
        }

        
        
        
        
        
        

        // Handle different possible response structures
        List<dynamic> classesData = [];

        

        // Check for live_classes key first (as per API specification)
        if (response['live_classes'] != null) {
          classesData = response['live_classes'];
          
        } else if (response['classes'] != null) {
          classesData = response['classes'];
          
        } else if (response['data'] != null && response['data'] is List) {
          classesData = response['data'];
          
        } else if (response['liveclasses'] != null) {
          classesData = response['liveclasses'];
          
        } else if (response['zoom_classes'] != null) {
          classesData = response['zoom_classes'];
          
        } else if (response['data'] != null && response['data'] is Map) {
          
          
          if (response['data']['live_classes'] != null) {
            classesData = response['data']['live_classes'];
            
          } else if (response['data']['classes'] != null) {
            classesData = response['data']['classes'];
            
          } else if (response['data']['liveclasses'] != null) {
            classesData = response['data']['liveclasses'];
            
          }
        } else {
          
        }

        // Check for other possible response structures
        if (classesData.isEmpty) {
          

          // Response is always a Map, so skip this check

          // Check for common API response patterns
          final possibleKeys = [
            'result',
            'results',
            'items',
            'records',
            'list',
            'array',
            'zoom_classes',
            'live_classes',
            'online_classes',
            'meetings',
            'sessions',
            'events',
            'schedules',
          ];

          for (String key in possibleKeys) {
            if (response[key] != null && response[key] is List) {
              classesData = response[key];
              
              break;
            }
          }
        }

        

        if (classesData.isNotEmpty) {
          
        }

        // Check if there might be pagination or additional data
        if (classesData.length < 15) {
          
          

          // Check for pagination info
          if (response['pagination'] != null) {
            
          }
          if (response['total'] != null) {
            
          }
          if (response['page'] != null) {
            
          }
          if (response['per_page'] != null) {
            
          }

          // Check if there are more pages or additional data
          if (response['next_page'] != null) {
            
          }
          if (response['has_more'] != null) {
            
          }
        }

        if (classesData.isNotEmpty) {
          setState(() {
            zoomClasses = List<Map<String, dynamic>>.from(classesData);
            isLoading = false;
          });
          
          return;
        } else {
          
          
        }
      } catch (apiError) {
        
        
        // Continue to fallback data
      }

      // If API fails or returns no data, show error instead of sample data
      
      setState(() {
        errorMessage =
            'No Zoom classes found. Please check your connection and try again.';
        isLoading = false;
      });
    } catch (e) {
      
      setState(() {
        errorMessage = 'Error loading Zoom classes: $e';
        isLoading = false;
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

  DateTime? _parseClassDateTime(String dateTimeStr) {
    if (dateTimeStr.isEmpty) return null;
    try {
      // Try standard ISO format first
      try {
        return DateTime.parse(dateTimeStr);
      } catch (_) {
        // Try formats like "YYYY-MM-DD HH:MM:SS" or "YYYY-MM-DD HH:MM"
        try {
          // Replace common separators
          String normalized = dateTimeStr.replaceAll('/', '-').trim();
          // Try adding time if missing
          if (normalized.split(' ').length == 1) {
            normalized = '$normalized 00:00:00';
          }
          return DateTime.parse(normalized);
        } catch (_) {
          // Try parsing as timestamp if it's a number
          try {
            final timestamp = int.tryParse(dateTimeStr);
            if (timestamp != null) {
              return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
            }
          } catch (_) {
            // Ignore
          }
        }
      }
    } catch (e) {
      
    }
    return null;
  }

  String _determineClassStatus(Map<String, dynamic> data) {
    final now = DateTime.now();
    final dateTimeStr = data['date']?.toString() ?? data['date_time']?.toString() ?? '';
    final durationStr = data['duration']?.toString() ?? '0';
    final endTimeStr = data['end_time']?.toString() ?? data['end_date']?.toString() ?? '';
    
    // API status check - prioritize explicit statuses from server
    final apiStatus = data['status']?.toString() ?? '';
    if (apiStatus == '0' || apiStatus.toLowerCase() == 'live') {
      return 'Live';
    } else if (apiStatus == '1' || apiStatus == '2' || apiStatus.toLowerCase() == 'completed') {
      return 'Completed';
    } else if (apiStatus.toLowerCase() == 'awaited') {
      return 'Awaited';
    }

    // Parse the class start time
    final startTime = _parseClassDateTime(dateTimeStr);
    if (startTime == null) {
      // Default to upcoming/awaited if we can't determine
      return 'Awaited';
    }
    
    // Try to get end time from API, otherwise calculate from duration
    DateTime? endTime;
    if (endTimeStr.isNotEmpty) {
      endTime = _parseClassDateTime(endTimeStr);
    }
    
    // If end time not available, calculate from start time + duration
    if (endTime == null) {
      final durationMinutes = int.tryParse(durationStr) ?? 0;
      endTime = startTime.add(Duration(minutes: durationMinutes));
    }
    
    // Determine status based on current time
    if (now.isBefore(startTime)) {
      // Class hasn't started yet
      
      return 'Awaited';
    } else if (now.isAfter(startTime) && now.isBefore(endTime)) {
      // Class is currently happening
      
      return 'Live';
    } else {
      // Class has ended
      
      return 'Completed';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'upcoming':
      case 'awaited':
      case 'scheduled':
        return Colors.orange;
      case 'live':
        return Colors.red;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const TranslatedText(
          "Zoom Live Classes",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.grey[900],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    TranslatedText(
                      'Unable to load Zoom classes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TranslatedText(
                      'Please check your internet connection and try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        loadZoomClasses();
                      },
                      child: const TranslatedText('Retry'),
                    ),
                  ],
                ),
              ),
            )
          :           Column(
            children: [
              EnterpriseUIComponents.buildHeaderWithIllustration(
                title: 'Your Zoom Live Classes!',
                subtitle: 'Join your Zoom virtual classes',
                illustration: Image.asset(
                  "assets/images/zoom-icon.png",
                  width: 100,
                  height: 100,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.video_camera_front,
                    color: Colors.blue[600],
                    size: 40,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: zoomClasses.length,
                  itemBuilder: (context, index) {
                    return _buildClassCard(zoomClasses[index]);
                  },
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildClassCard(Map<String, dynamic> data) {
    // Determine status based on date/time and duration, not just API status
    final status = _determineClassStatus(data);
    final isCompleted = status.toLowerCase() == 'completed';
    
    
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        crossAxisAlignment: CrossAxisAlignment.start,
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
                  child: Text(
                    data['title'] ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!isCompleted)
                  InkWell(
                    onTap: () => _joinZoomClass(data),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const TranslatedText(
                        "Join",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetail(
                  "Class",
                  "${data['class'] ?? ''} ${data['section'] ?? ''}",
                ),
                _buildDetail("Date Time", _formatDateTime(data['date'] ?? '')),
                _buildDetail("Class Duration", "${data['duration']} Minutes"),
                _buildDetail(
                  "Class Host",
                  "${data['create_for_name'] ?? ''} ${data['create_for_surname'] ?? ''} (${data['for_create_role_name'] ?? ''}: ${data['for_create_employee_no'] ?? data['for_create_staff_no'] ?? data['for_create_employee_id'] ?? data['employee_no'] ?? data['staff_no'] ?? ''})",
                ),
                if (data['description'] != null &&
                    data['description'].toString().isNotEmpty)
                  _buildDetail("Description", data['description']),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _getStatusColor(status).withOpacity(0.5),
                      ),
                    ),
                    child: TranslatedText(
                      status,
                      style: TextStyle(
                        color: _getStatusColor(status),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
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

  Widget _buildDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: TranslatedText(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: TranslatedText(
              value,
              style: const TextStyle(fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _joinZoomClass(Map<String, dynamic> classData) async {
    final joinUrl = classData['join_url']?.toString().trim() ?? '';
    classData['title']; // keep for future logs if needed
    if (joinUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: TranslatedText("No join URL available for this class."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final formattedUrl = _normalizeZoomUrl(joinUrl);
    final webUri = Uri.parse(formattedUrl);
    final appUri = _buildZoomAppUri(webUri);

    if (await _tryLaunchUri(appUri)) return;
    if (await _tryLaunchUri(webUri)) return;

    final playStoreUri = Uri.parse('market://details?id=com.zoom.us');
    if (await _tryLaunchUri(playStoreUri)) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: TranslatedText("Unable to open Zoom link. Please install Zoom or try again later."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _normalizeZoomUrl(String raw) {
    var formatted = raw;
    if (!formatted.startsWith('http://') && !formatted.startsWith('https://')) {
      formatted = 'https://$formatted';
    }
    return formatted;
  }

  Uri _buildZoomAppUri(Uri webUri) {
    final confno = webUri.pathSegments.isNotEmpty ? webUri.pathSegments.last : '';
    if (confno.isEmpty) return webUri;
    final pwd = webUri.queryParameters['pwd'];
    final buffer = StringBuffer('zoomus://zoom.us/join?confno=$confno');
    if (pwd != null && pwd.isNotEmpty) {
      buffer.write('&pwd=${Uri.encodeComponent(pwd)}');
    }
    return Uri.parse(buffer.toString());
  }

  Future<bool> _tryLaunchUri(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: TranslatedText('Launching Zoom link via ${uri.scheme}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
    return false;
  }
}

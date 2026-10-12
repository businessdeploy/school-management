import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/url_manager.dart';
import '../config/app_config.dart';
import '../widgets/translated_text.dart';
import 'pdf_viewer_page.dart';
import 'document_viewer_page.dart';

class DownloadCenterPage extends StatefulWidget {
  const DownloadCenterPage({super.key});

  @override
  State<DownloadCenterPage> createState() => _DownloadCenterPageState();
}

class _DownloadCenterPageState extends State<DownloadCenterPage> {
  int _selectedTab = 0; // 0 for Contents, 1 for Video Tutorial
  List<dynamic> contents = [];
  List<dynamic> videoTutorials = [];
  bool isLoading = true;
  String? errorMessage;
  Color? secondaryColor = Colors.yellow[100]; // Initialize with fallback

  @override
  void initState() {
    super.initState();
    _loadSecondaryColor();
    loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Always reload color to ensure we have the latest from API
    _loadSecondaryColor();
  }

  Future<void> _loadSecondaryColor() async {
    try {
      final colorString = await AppConfig.getSecondaryColor();
      

      if (colorString.isNotEmpty && colorString.trim().isNotEmpty) {
        final parsedColor = _parseColor(colorString);
        
        setState(() {
          secondaryColor = parsedColor;
        });
      } else {
        
        setState(() {
          secondaryColor = Colors.yellow[100];
        });
      }
    } catch (e) {
      
      setState(() {
        secondaryColor = Colors.yellow[100];
      });
    }
  }

  Color _parseColor(String colorString) {
    try {
      // Trim whitespace
      String trimmed = colorString.trim();
      

      // Remove # if present
      String hex = trimmed.replaceAll('#', '').toUpperCase();
      

      // Handle 6-digit hex (RRGGBB)
      if (hex.length == 6) {
        final color = Color(int.parse('FF$hex', radix: 16));
        
        return color;
      }
      // Handle 8-digit hex (AARRGGBB)
      else if (hex.length == 8) {
        final color = Color(int.parse(hex, radix: 16));
        
        return color;
      }
      // Handle 3-digit hex (RGB)
      else if (hex.length == 3) {
        final r = hex[0];
        final g = hex[1];
        final b = hex[2];
        final color = Color(int.parse('FF$r$r$g$g$b$b', radix: 16));
        
        return color;
      } else {
        
      }
    } catch (e) {
      
    }
    // Fallback to yellow if parsing fails
    
    return Colors.yellow[100]!;
  }

  Future<void> loadData() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // Use dynamic student id
      final studentId = await AuthService.getStudentId();

      
      
      
      

      // Load contents from API - using correct parameters
      final contentsData = await ApiService.getDownloadsLinks(studentId);

      // Load video tutorials from API - using correct parameters
      final videoData = await ApiService.getVideoTutorial(studentId);

      
      

      // Enhanced video tutorial debugging
      
      
      
      
      if (videoData['result'] is List) {
        final resultList = videoData['result'] as List;
        
        if (resultList.isNotEmpty) {
          
        }
      }

      if (!mounted) return;

      setState(() {
        // Handle contents data - Smart School API returns array directly in 'data' key
        if (contentsData['data'] is List) {
          contents = contentsData['data'];
          
        } else {
          contents = [];
          
        }

        // Handle video tutorials data - Smart School API returns object with 'result' array
        if (videoData['result'] is List) {
          videoTutorials = videoData['result'];
          
        } else {
          videoTutorials = [];
          
        }

        // No sample data - use only real API data
        if (contents.isEmpty) {
          
        }

        if (videoTutorials.isEmpty) {
          
        }

        isLoading = false;
      });

      
      
    } catch (e) {
      
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to load data. Please try again.';
        // No mock data - show error instead
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const TranslatedText(
          'Download Center',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.grey[800],
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [],
      ),
      body: Column(
        children: [
          // ✅ Header with text + image
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TranslatedText(
                        "Your Download Center is here!",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TranslatedText(
                        "Download and view all your school documents and video tutorials.",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Image.asset(
                  "assets/images/downloadpage.jpg", // <-- use your downloadpage.jpg
                  height: 70,
                  width: 70,
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ),

          // ✅ Tabs
          Container(
            color: Colors.white,
            child: Row(
              children: [
                Expanded(child: _buildTab("CONTENTS", 0)),
                Expanded(child: _buildTab("VIDEO TUTORIAL", 1)),
              ],
            ),
          ),

          // Content area
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(color: Colors.white),
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : errorMessage != null && contents.isEmpty
                  ? Center(
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    )
                  : _selectedTab == 0
                  ? _buildContentsList()
                  : _buildVideoTutorialsList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String title, int index) {
    final bool isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedTab = index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: isSelected
              ? const Border(bottom: BorderSide(color: Colors.black, width: 2))
              : null,
        ),
        child: TranslatedText(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.grey,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildContentsList() {
    if (contents.isEmpty) {
      return const Center(
        child: TranslatedText(
          'No contents available',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: contents.length,
      itemBuilder: (context, index) {
        final item = contents[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title section with dynamic secondary color background + Attachment button
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: secondaryColor ?? Colors.yellow[100]!,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item['title'] ?? 'Content',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    _buildAttachmentButton(item),
                  ],
                ),
              ),
              // Content section with padding
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _detail("Share Date", _formatDate(item['share_date'])),
                    _detail("Valid Upto", _formatDate(item['valid_upto'])),
                    _detail(
                      "Shared By",
                      "${item['name']} ${item['surname']} (${item['employee_id']})",
                    ),
                    _detail("Description", item['description'] ?? ''),
                    _detail("Created At", _formatDateTime(item['created_at'])),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: TranslatedText(
              "$label:",
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoTutorialsList() {
    if (videoTutorials.isEmpty) {
      return const Center(
        child: TranslatedText(
          'No video tutorials available',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: videoTutorials.length,
      itemBuilder: (context, index) {
        final item = videoTutorials[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 1,
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Video thumbnail - clickable to play
              GestureDetector(
                onTap: () => _playVideo(item),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  child: Container(
                    height: 180,
                    width: double.infinity,
                    color: Colors.grey[300],
                    child: Stack(
                      children: [
                        FutureBuilder<String>(
                          future: _buildThumbnailUrl(item),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return Image.network(
                                snapshot.data!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      color: Colors.grey[300],
                                      child: const Center(
                                        child: Icon(
                                          Icons.video_library,
                                          size: 40,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                              );
                            } else {
                              return Container(
                                color: Colors.grey[300],
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                          },
                        ),
                        // Play button overlay
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow,
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Video details section
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title'] ?? 'Video Tutorial',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _detail("Description", item['description'] ?? ''),
                    const SizedBox(height: 4),
                    _detail(
                      "Created By",
                      "${item['name']} ${item['surname']} (${item['employee_id']})",
                    ),
                    const SizedBox(height: 4),
                    _detail("Class", "${item['class']} - ${item['section']}"),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return 'N/A';
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeStr;
    }
  }

  Future<String> _buildThumbnailUrl(Map<String, dynamic> item) async {
    final baseUrl = await UrlManager.getBaseUrl();
    final thumbPath = item['thumb_path'] ?? '';
    final imgName = item['img_name'] ?? '';
    final thumbName = item['thumb_name'] ?? '';

    
    
    
    

    // Try to build thumbnail URL
    if (thumbPath.isNotEmpty && thumbName.isNotEmpty) {
      // Use thumb_name if available (preferred)
      final url = '$baseUrl/$thumbPath$thumbName';
      
      return url;
    } else if (thumbPath.isNotEmpty && imgName.isNotEmpty) {
      // Fallback to img_name if thumb_name not available
      final url = '$baseUrl/$thumbPath$imgName';
      
      return url;
    }

    // Return a placeholder if no valid thumbnail data
    final placeholderUrl = '$baseUrl/uploads/default_thumbnail.jpg';
    
    return placeholderUrl;
  }

  Widget _buildAttachmentButton(Map<String, dynamic> item) {
    final validUpto = item['valid_upto'];
    final isExpired =
        validUpto != null &&
        validUpto.toString().isNotEmpty &&
        _isLinkExpired(validUpto);

    return GestureDetector(
      onTap: () {
        if (isExpired) {
          // Show alert dialog for expired link
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const TranslatedText('Link Expired'),
              content: const TranslatedText(
                'This link has expired. Please contact the admin.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const TranslatedText('OK'),
                ),
              ],
            ),
          );
        } else {
          _downloadAttachment(item);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isExpired ? Colors.grey : Colors.blue,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(
              isExpired ? Icons.block : Icons.attach_file,
              color: Colors.white,
              size: 14,
            ),
            const SizedBox(width: 4),
            TranslatedText(
              "Attachment",
              style: TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w500,
                decoration: isExpired ? TextDecoration.lineThrough : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isLinkExpired(dynamic validUpto) {
    if (validUpto == null || validUpto.toString().isEmpty) {
      return false; // If no expiry date, consider it as not expired
    }

    try {
      final dateStr = validUpto.toString().trim();
      DateTime? expiryDate;

      // Try to parse the date in various formats
      try {
        // Try ISO format first
        expiryDate = DateTime.parse(dateStr);
      } catch (e) {
        // Try common date formats
        // YYYY-MM-DD
        if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(dateStr)) {
          final parts = dateStr.split(' ');
          if (parts.isNotEmpty) {
            final dateParts = parts[0].split('-');
            if (dateParts.length == 3) {
              expiryDate = DateTime(
                int.parse(dateParts[0]),
                int.parse(dateParts[1]),
                int.parse(dateParts[2]),
              );
            }
          }
        }
        // DD/MM/YYYY
        else if (RegExp(r'^\d{2}/\d{2}/\d{4}').hasMatch(dateStr)) {
          final parts = dateStr.split(' ');
          if (parts.isNotEmpty) {
            final dateParts = parts[0].split('/');
            if (dateParts.length == 3) {
              expiryDate = DateTime(
                int.parse(dateParts[2]),
                int.parse(dateParts[1]),
                int.parse(dateParts[0]),
              );
            }
          }
        }
        // DD-MM-YYYY
        else if (RegExp(r'^\d{2}-\d{2}-\d{4}').hasMatch(dateStr)) {
          final parts = dateStr.split(' ');
          if (parts.isNotEmpty) {
            final dateParts = parts[0].split('-');
            if (dateParts.length == 3) {
              expiryDate = DateTime(
                int.parse(dateParts[2]),
                int.parse(dateParts[1]),
                int.parse(dateParts[0]),
              );
            }
          }
        }
      }

      if (expiryDate != null) {
        // Compare with today's date (only date, not time)
        final today = DateTime.now();
        final todayDateOnly = DateTime(today.year, today.month, today.day);
        final expiryDateOnly = DateTime(
          expiryDate.year,
          expiryDate.month,
          expiryDate.day,
        );

        
        
        
        
        

        // Link is expired if expiry date is before today
        return expiryDateOnly.isBefore(todayDateOnly);
      }

      
      return false; // If we can't parse, don't block access
    } catch (e) {
      
      return false; // If there's an error, don't block access
    }
  }

  Future<void> _downloadAttachment(dynamic content) async {
    try {
      // Get the upload_contents array
      final uploadContents = content['upload_contents'];
      if (uploadContents == null || uploadContents.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: TranslatedText('No file available for download'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final fileData = uploadContents[0];
      final baseUrl = await UrlManager.getBaseUrl();
      final dirPath = fileData['dir_path'] ?? '';
      final imgName = fileData['img_name'] ?? '';

      if (dirPath.isEmpty || imgName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: TranslatedText('File path not available'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Properly construct the URL with correct slashes
      // Remove trailing slash from baseUrl if present
      String cleanBaseUrl = baseUrl.trim();
      if (cleanBaseUrl.endsWith('/')) {
        cleanBaseUrl = cleanBaseUrl.substring(0, cleanBaseUrl.length - 1);
      }

      // Clean and normalize dirPath
      String cleanDirPath = dirPath.trim();
      // Remove leading slash if present (we'll add it back)
      if (cleanDirPath.startsWith('/')) {
        cleanDirPath = cleanDirPath.substring(1);
      }
      // Remove trailing slash if present
      if (cleanDirPath.endsWith('/')) {
        cleanDirPath = cleanDirPath.substring(0, cleanDirPath.length - 1);
      }
      // Always add leading slash
      if (cleanDirPath.isNotEmpty) {
        cleanDirPath = '/$cleanDirPath';
      }

      // Clean imgName - remove leading slash if present
      String cleanImgName = imgName.trim();
      if (cleanImgName.startsWith('/')) {
        cleanImgName = cleanImgName.substring(1);
      }

      // Construct final URL: baseUrl + /dirPath + /imgName
      // Ensure there's always a slash between baseUrl and path
      final fileUrl = cleanDirPath.isNotEmpty
          ? '$cleanBaseUrl$cleanDirPath/$cleanImgName'
          : '$cleanBaseUrl/$cleanImgName';

      
      
      
      
      
      
      
      
      

      // Check file type and open in appropriate viewer
      final isPDF = fileUrl.toLowerCase().endsWith('.pdf');
      final isImage = fileUrl.toLowerCase().endsWith('.jpg') ||
                      fileUrl.toLowerCase().endsWith('.jpeg') ||
                      fileUrl.toLowerCase().endsWith('.png') ||
                      fileUrl.toLowerCase().endsWith('.gif') ||
                      fileUrl.toLowerCase().endsWith('.bmp') ||
                      fileUrl.toLowerCase().endsWith('.webp');

      if (mounted) {
        final fileName = cleanImgName;
        
        if (isPDF) {
          // Use dedicated PDF viewer
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PDFViewerPage(
                documentUrl: fileUrl,
                documentTitle: fileName,
              ),
            ),
          );
          
        } else {
          // Use universal document viewer for images and other documents
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DocumentViewerPage(
                documentUrl: fileUrl,
                documentTitle: fileName,
              ),
            ),
          );
          
        }
      }
    } catch (e) {
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error downloading file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _playVideo(Map<String, dynamic> video) async {
    try {
      final resolvedUrl = await _resolveVideoUrl(video);
      if (resolvedUrl == null) {
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video link not available'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      

      // Convert YouTube embed URLs to watch URLs for direct playback
      // Embed URLs (youtube.com/embed/VIDEO_ID) don't work when opened directly
      // Convert them to watch URLs (youtube.com/watch?v=VIDEO_ID) instead
      String finalUrl = resolvedUrl;
      
      // Check if it's a YouTube embed URL and convert to watch URL
      if (resolvedUrl.contains('youtube.com/embed/')) {
        final embedMatch = RegExp(r'youtube\.com\/embed\/([A-Za-z0-9_-]{11})').firstMatch(resolvedUrl);
        if (embedMatch != null && embedMatch.groupCount >= 1) {
          final videoId = embedMatch.group(1);
          finalUrl = 'https://www.youtube.com/watch?v=$videoId';
          
        }
      } else if (resolvedUrl.contains('youtu.be/')) {
        // Convert youtu.be short URLs to watch URLs
        final shortMatch = RegExp(r'youtu\.be\/([A-Za-z0-9_-]{11})').firstMatch(resolvedUrl);
        if (shortMatch != null && shortMatch.groupCount >= 1) {
          final videoId = shortMatch.group(1);
          finalUrl = 'https://www.youtube.com/watch?v=$videoId';
          
        }
      }

      

      final uri = Uri.parse(finalUrl);
      bool launched = false;

      Future<void> tryLaunch(LaunchMode mode, String label) async {
        if (launched) return;
        try {
          final success = await launchUrl(uri, mode: mode);
          if (success) {
            launched = true;
            
          }
        } catch (e) {
          
        }
      }

      // Try all launch modes for all videos (original behavior)
      await tryLaunch(LaunchMode.externalApplication, 'externalApplication');
      await tryLaunch(LaunchMode.inAppBrowserView, 'inAppBrowserView');
      await tryLaunch(LaunchMode.inAppWebView, 'inAppWebView');
      await tryLaunch(LaunchMode.platformDefault, 'platformDefault');

      if (mounted) {
        if (launched) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Opening video...'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Could not open video link. Please try manually: $finalUrl',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening video: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String?> _resolveVideoUrl(Map<String, dynamic> video) async {
    final baseUrl = await UrlManager.getBaseUrl();

    String? normalizeUrl(String? raw) {
      if (raw == null) return null;
      var url = raw.trim();
      if (url.isEmpty || url.toLowerCase() == 'null') return null;

      // Already absolute HTTP(S)
      if (url.startsWith('http://') || url.startsWith('https://')) {
        return url;
      }

      // Protocol-relative (//example.com)
      if (url.startsWith('//')) {
        return 'https:${url.substring(2)}';
      }

      // Common cases missing protocol (e.g., www.youtube.com)
      if (url.startsWith('www.')) {
        return 'https://$url';
      }

      // YouTube IDs or partial links
      if (url.contains('youtu.be') || url.contains('youtube.com')) {
        return url.startsWith('http') ? url : 'https://$url';
      }

      // If URL looks like a plain YouTube ID
      final youtubeIdRegex = RegExp(r'^[A-Za-z0-9_-]{10,}$');
      if (youtubeIdRegex.hasMatch(url)) {
        return 'https://www.youtube.com/watch?v=$url';
      }

      // Treat as relative path using base URL
      if (baseUrl.isEmpty) return null;
      var cleanBase = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;
      if (!url.startsWith('/')) {
        url = '/$url';
      }
      final resolved = '$cleanBase$url';
      
      return resolved;
    }

    // Primary fields to check
    final primaryKeys = [
      'video_link',
      'video_url',
      'video',
      'url',
      'link',
      'file',
      'video_file',
      'videoPath',
      'videoName',
    ];

    for (final key in primaryKeys) {
      final value = video[key]?.toString();
      final resolved = normalizeUrl(value);
      if (resolved != null) {
        
        return resolved;
      }
    }

    // Construct from dir/path + filename combinations
    String? fromParts(String? dir, String? name) {
      if (name == null || name.trim().isEmpty) return null;
      final dirValue = (dir ?? '').trim();
      final fileValue = name.trim();

      if ((dirValue.startsWith('http://') || dirValue.startsWith('https://')) &&
          !fileValue.startsWith('http')) {
        final separator = dirValue.endsWith('/') ? '' : '/';
        return '$dirValue$separator$fileValue';
      }

      if (fileValue.startsWith('http://') || fileValue.startsWith('https://')) {
        return fileValue;
      }

      if (dirValue.isNotEmpty) {
        final normalizedDir = dirValue.endsWith('/') ? dirValue : '$dirValue/';
        return '$normalizedDir$fileValue';
      }

      return fileValue;
    }

    final dirKeys = [
      'dir_path',
      'path',
      'video_path',
      'video_dir',
      'upload_path',
    ];
    final fileKeys = [
      'video_link',
      'video',
      'video_name',
      'videoFile',
      'file',
      'videoFileName',
    ];

    for (final dirKey in dirKeys) {
      for (final fileKey in fileKeys) {
        final candidate = fromParts(
          video[dirKey]?.toString(),
          video[fileKey]?.toString(),
        );
        final resolved = normalizeUrl(candidate);
        if (resolved != null) {
          
          return resolved;
        }
      }
    }

    
    return null;
  }
}

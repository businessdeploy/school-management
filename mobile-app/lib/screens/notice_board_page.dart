import 'package:flutter/material.dart';
import '../widgets/enterprise_ui_components.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../config/app_config.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/url_manager.dart';
import '../providers/app_config_provider.dart';
import 'package:provider/provider.dart';
import '../widgets/translated_text.dart';

class NoticeBoardPage extends StatefulWidget {
  const NoticeBoardPage({super.key});

  @override
  State<NoticeBoardPage> createState() => _NoticeBoardPageState();
}

class _NoticeBoardPageState extends State<NoticeBoardPage> {
  List<Map<String, dynamic>> notices = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadNotices();
  }

  /// Build the "By: <Staff Name> (ID: 1234)" row for each notice.
  Widget _buildStaffInfoRow(Map<String, dynamic> notice) {
    // Staff name from various possible fields
    String staffName =
        (notice['created_by'] ?? notice['staff_name'] ?? notice['name'] ?? '')
            .toString()
            .trim();
    if (staffName.isEmpty) {
      staffName = 'Staff';
    }

    // Staff ID from various possible fields
    String staffId = '';
    const idKeys = [
      'employee_no',
      'staff_no',
      'staff_number',
      'staff_id',
      'staffId',
      'employee_id',
      'employeeId',
      'user_id',
      'userId',
      'created_by_id',
      'createdById',
    ];

    for (final key in idKeys) {
      final value = notice[key];
      if (value != null) {
        final str = value.toString().trim();
        if (str.isNotEmpty && str.toLowerCase() != 'null') {
          staffId = str;
          break;
        }
      }
    }

    

    return Row(
      children: [
        Icon(
          Icons.person,
          size: 16,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Row(
            children: [
              const TranslatedText(
                'By',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              Text(
                staffId.isNotEmpty ? ': $staffName ($staffId)' : ': $staffName',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> loadNotices() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final response = await ApiService.getNoticeBoard();

      List<dynamic> noticeItems = [];

      // Check for data key first (as per API specification)
      if (response['data'] != null && response['data'] is List) {
        noticeItems = response['data'];
      } else if (response['notices'] != null) {
        noticeItems = response['notices'];
      } else if (response['notice_board'] != null) {
        noticeItems = response['notice_board'];
      } else if (response['announcements'] != null) {
        noticeItems = response['announcements'];
      }

      if (noticeItems.isNotEmpty) {
        
      }

      if (!mounted) return;

      if (noticeItems.isEmpty) {
        setState(() {
          notices = [];
          isLoading = false;
          errorMessage = 'No notices available at the moment.';
        });
        return;
      }

      final convertedNotices = noticeItems
          .map((item) => item as Map<String, dynamic>)
          .toList();

      setState(() {
        notices = convertedNotices;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        notices = [];
        isLoading = false;
        errorMessage =
            'Failed to load notices. Please check your internet connection and try again.';
      });
    }
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return dateStr;
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (_) {
      // Try to parse formats like dd-MM-yyyy or dd/MM/yyyy
      final cleaned = dateStr.replaceAll('/', '-');
      final parts = cleaned.split('-');
      if (parts.length == 3) {
        try {
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2]);
          final parsedDate = DateTime(year, month, day);
          return '${parsedDate.day.toString().padLeft(2, '0')}/${parsedDate.month.toString().padLeft(2, '0')}/${parsedDate.year}';
        } catch (_) {
          return dateStr;
        }
      }
      return dateStr;
    }
  }

  String? _getPublishDate(Map<String, dynamic> notice) {
    const publishKeys = [
      'publish_date',
      'publishDate',
      'publish_on',
      'publishOn',
      'publish_datetime',
      'publishdatetime',
      'published_at',
      'publishedAt',
    ];
    return _extractDateFromKeys(notice, publishKeys);
  }

  String? _getNoticeDate(Map<String, dynamic> notice) {
    const possibleKeys = [
      'notice_date',
      'noticeDate',
      'date',
      'notice_date_from',
      'noticeDateFrom',
      'created_at',
      'createdAt',
    ];
    final resolved = _extractDateFromKeys(notice, possibleKeys);
    if (resolved != null) {
      return resolved;
    }
    
    return null;
  }

  String? _extractDateFromKeys(Map<String, dynamic> notice, List<String> keys) {
    for (final key in keys) {
      final value = notice[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        final raw = value.toString().trim();
        final formatted = _formatDate(raw);
        
        return formatted;
      }
    }
    return null;
  }

  Widget _buildDateBadge(String label, String date) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
            Icon(
              Icons.event,
              size: 14,
              color: Provider.of<AppConfigProvider>(context).primaryColorObj,
            ),
            const SizedBox(width: 4),
            TranslatedText(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Provider.of<AppConfigProvider>(context).primaryColorObj,
              ),
            ),
            Text(
              ': $date',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Provider.of<AppConfigProvider>(context).primaryColorObj,
              ),
            ),
          ],
        ),
      );
    }

  String _stripHtml(String htmlString) {
    // Simple HTML tag removal
    return htmlString
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }

  String _normalizeNoticeText(String? rawText) {
    if (rawText == null) return '';
    final cleaned = _stripHtml(rawText);
    return cleaned.replaceAll(RegExp(r'\s+'), ' ');
  }

  String _getNoticeTitle(Map<String, dynamic> notice) {
    final rawTitle = notice['notification_title']?.toString() ??
        notice['title']?.toString() ??
        notice['notice_title']?.toString() ??
        notice['subject']?.toString() ??
        notice['title_name']?.toString() ??
        '';
        
    final normalized = _normalizeNoticeText(rawTitle);
    if (normalized.isNotEmpty) {
      return normalized;
    }
    
    // If title is missing, try to use a snippet of the body
    final body = _getNoticeBody(notice);
    if (body.isNotEmpty) {
      return body.length > 30 ? '${body.substring(0, 30)}...' : body;
    }
    
    return 'Notification';
  }

  String _getNoticeBody(Map<String, dynamic> notice) {
    return _normalizeNoticeText(
      notice['msg']?.toString() ??
      notice['message']?.toString() ??
      notice['notification_body']?.toString() ??
      notice['body']?.toString() ??
      notice['text']?.toString() ??
      notice['note']?.toString()
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const TranslatedText('Notice Board'),
        backgroundColor: Provider.of<AppConfigProvider>(context).primaryColorObj,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: loadNotices),
        ],
      ),
      body: Column(
        children: [
          EnterpriseUIComponents.buildHeaderWithIllustration(
            title: 'Notice Board',
            subtitle: 'Stay updated with latest announcements',
            illustration: Icon(
              Icons.notifications,
              size: 60,
              color: Provider.of<AppConfigProvider>(context).primaryColorObj,
            ),
          ),
          // Content
          Expanded(
            child: Container(
              color: Colors.grey[100],
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : errorMessage != null
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
                          Text(
                            errorMessage!,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: loadNotices,
                            child: const TranslatedText('Retry'),
                          ),
                        ],
                      ),
                    )
                  : notices.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_none,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          TranslatedText(
                            'No notices available',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          TranslatedText(
                            'Check back later for updates',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: loadNotices,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: notices.length,
                        itemBuilder: (context, index) {
                          final notice = notices[index];
                          final noticeDate = _getNoticeDate(notice);
                          final publishDate = _getPublishDate(notice);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header - Light blue background
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(16),
                                      topRight: Radius.circular(16),
                                    ),
                                  ),
                                  child: Text(
                                    _getNoticeTitle(notice),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // Body
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _getNoticeBody(notice),
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[700],
                                          height: 1.5,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          if (publishDate != null)
                                            _buildDateBadge(
                                              'Publish',
                                              publishDate,
                                            ),
                                          if (noticeDate != null)
                                            _buildDateBadge(
                                              'Notice',
                                              noticeDate,
                                            ),
                                        ],
                                      ),
                                      if (notice['created_by'] != null)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 12),
                                          child: _buildStaffInfoRow(notice),
                                        ),
                                      _buildAttachmentSection(notice),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isImage(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext);
  }

  Widget _buildAttachmentSection(Map<String, dynamic> notice) {
    final attachmentPath = _getNoticeAttachmentPath(notice);
    
    if (attachmentPath.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<String>(
      future: _resolveNoticeUrl(attachmentPath),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
        
        final fullUrl = snapshot.data!;
        final fileName = attachmentPath.split('/').last;
        final isImg = _isImage(fileName);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isImg)
              GestureDetector(
                onTap: () => _downloadNoticeAttachment(attachmentPath),
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  constraints: const BoxConstraints(maxHeight: 200),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      fullUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 100,
                          alignment: Alignment.center,
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        
                        return Container(
                          padding: const EdgeInsets.all(20),
                          color: Colors.grey[100],
                          child: Column(
                            children: [
                              const Icon(Icons.broken_image, color: Colors.grey),
                              const SizedBox(height: 4),
                              Text('Could not load image', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            TextButton.icon(
              onPressed: () => _downloadNoticeAttachment(attachmentPath),
              icon: Icon(isImg ? Icons.image : Icons.download, size: 18, color: Provider.of<AppConfigProvider>(context).primaryColorObj),
              label: Text(
                fileName,
                style: TextStyle(color: Provider.of<AppConfigProvider>(context).primaryColorObj, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Try multiple possible keys to find the attached document for a notice.
  /// Returns empty string if no attachment found (which hides the attachment section).
  String _getNoticeAttachmentPath(Map<String, dynamic> notice) {
    
    

    const attachmentKeys = [
      'attachment',
      'attach_document',
      'document',
      'notice_file',
      'file',
      'file_name',
      'upload_file',
      'attached_file',
      'doc',
      'doc_url',
      'attachment_url',
      'file_url',
      'document_url',
      'notice_attachment',
      'notice_document',
      'attachment_path',
      'file_path',
      'document_path',
      'image',
      'url',
      'path',
      'download_url',
      'file_path_url',
    ];

    // Priority 1: Direct fields (highest priority keys first)
    for (final key in attachmentKeys) {
      final value = notice[key];
      if (value != null) {
        final str = value.toString().trim();
        if (str.isNotEmpty && str.toLowerCase() != 'null') {
          
          return str;
        }
      }
    }

    // Priority 2: Nested fields (attachment_data, file_info, etc.)
    const nestedKeys = ['attachment_data', 'file_info', 'notice_data', 'attachment_obj'];
    for (final nKey in nestedKeys) {
      if (notice[nKey] is Map) {
        final data = notice[nKey] as Map;
        for (final key in attachmentKeys) {
          final value = data[key];
          if (value != null) {
            final str = value.toString().trim();
            if (str.isNotEmpty && str.toLowerCase() != 'null') {
              
              return str;
            }
          }
        }
      } else if (notice[nKey] is List && (notice[nKey] as List).isNotEmpty) {
        // Handle list of attachments (take first)
        final firstItem = (notice[nKey] as List).first;
        if (firstItem is String) return firstItem;
        if (firstItem is Map) {
          for (final key in attachmentKeys) {
            if (firstItem[key] != null) return firstItem[key].toString();
          }
        }
      }
    }

    // Priority 3: Heuristic scan - look for anything that looks like a file path
    final RegExp fileRegExp = RegExp(r'\.(pdf|jpg|jpeg|png|gif|webp|doc|docx|xls|xlsx|txt|zip|rar)$', caseSensitive: false);
    for (final entry in notice.entries) {
      final value = entry.value;
      if (value is String && value.length > 3) {
        if (fileRegExp.hasMatch(value)) {
          
          return value;
        }
      }
    }

    
    
    return '';
  }

  Future<void> _downloadNoticeAttachment(String rawPath) async {
    try {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preparing notice attachment...'),
          duration: Duration(seconds: 2),
        ),
      );

      final urlString = await _resolveNoticeUrl(rawPath);
      if (urlString.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Notice attachment not available. Please contact school admin.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final uri = Uri.tryParse(urlString);
      if (uri == null || !uri.hasScheme || !uri.scheme.startsWith('http')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid notice attachment URL: $urlString'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final launched = await launchUrlString(
        urlString,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open notice attachment. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening notice attachment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String> _resolveNoticeUrl(String path) async {
    try {
      var trimmed = path.trim();
      if (trimmed.isEmpty) return '';

      // Clean the attachment path
      String cleanPath = trimmed.replaceAll('\\', '/').trim();
      if (cleanPath.startsWith('/')) {
        cleanPath = cleanPath.substring(1);
      }

      // Already a full URL?
      if (cleanPath.startsWith('http://') || cleanPath.startsWith('https://')) {
        return cleanPath;
      }

      final baseUrl = await UrlManager.getBaseUrl();
      if (baseUrl.isEmpty) return '';

      // Clean the base URL
      String cleanBaseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;

      // If it already contains 'uploads/', trust the path but ensure it's absolute
      if (cleanPath.contains('uploads/')) {
        return '$cleanBaseUrl/$cleanPath';
      }

      // Extract filename for fallback
      final fileName = cleanPath.split('/').last;

      // Smart School common notice paths
      final possiblePaths = [
        'uploads/notice_board_images/$fileName',
        'uploads/school_images/$fileName',
        'uploads/notice_board/$fileName',
        'uploads/announcements/$fileName',
        'uploads/frontend/notice_board/$fileName',
        'uploads/syllabus/$fileName', // Occasionally mixed
      ];

      // Return the first one for now (usually notice_board_images is correct)
      // In a real app, we might check which one is reachable, but for now we follow convention
      final finalUrl = '$cleanBaseUrl/${possiblePaths.first}';
      
      
      return finalUrl;
    } catch (e) {
      
      return '';
    }
  }
}

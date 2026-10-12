import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api/enterprise_api_service.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/enterprise_ui_components.dart';
import '../widgets/translated_text.dart';

class EnterpriseDownloadCenterPage extends StatefulWidget {
  const EnterpriseDownloadCenterPage({super.key});

  @override
  State<EnterpriseDownloadCenterPage> createState() => _EnterpriseDownloadCenterPageState();
}

class _EnterpriseDownloadCenterPageState extends State<EnterpriseDownloadCenterPage> {
  int _selectedTab = 0; // 0 = Contents, 1 = Video Tutorials
  List<Map<String, dynamic>> contents = [];
  List<Map<String, dynamic>> videoTutorials = [];
  bool isLoading = true;
  String? error;

  List<Map<String, dynamic>> _extractList(dynamic data, List<String> preferredKeys) {
    try {
      if (data == null) return [];
      // If response itself is a list
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }
      if (data is Map<String, dynamic>) {
        // Direct keys
        for (final key in preferredKeys) {
          if (data[key] is List) {
            return List<Map<String, dynamic>>.from(data[key]);
          }
        }
        // Nested one-level under 'data' key
        if (data['data'] is Map<String, dynamic>) {
          final inner = data['data'] as Map<String, dynamic>;
          for (final key in preferredKeys) {
            if (inner[key] is List) {
              return List<Map<String, dynamic>>.from(inner[key]);
            }
          }
        }
        // Sometimes array is directly under 'data'
        if (data['data'] is List) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
        // Fallback: look for first List value in map
        for (final entry in data.entries) {
          if (entry.value is List) {
            try {
              return List<Map<String, dynamic>>.from(entry.value);
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      
    }
    return [];
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final studentId = await AuthService.getStudentId();
      

      // Load both contents and video tutorials
      final results = await Future.wait([
        EnterpriseApiService.getDownloadsLinks(studentId),
        EnterpriseApiService.getVideoTutorial(studentId),
      ]);

      if (!mounted) return;

      final contentsResponse = results[0];
      final videoResponse = results[1];

      // First pass parse
      List<Map<String, dynamic>> parsedContents = contentsResponse.success
          ? _extractList(contentsResponse.data, ['data', 'downloads', 'contents'])
          : [];
      List<Map<String, dynamic>> parsedVideos = videoResponse.success
          ? _extractList(videoResponse.data, ['result', 'tutorials', 'data', 'videos'])
          : [];

      // Fallback: try legacy ApiService if empty
      if (parsedContents.isEmpty) {
        try {
          final legacy = await ApiService.getDownloadsLinks(studentId);
          parsedContents = _extractList(legacy, ['data', 'downloads', 'contents']);
          
        } catch (e) {
          
        }
      }
      if (parsedVideos.isEmpty) {
        try {
          final legacyV = await ApiService.getVideoTutorial(studentId);
          parsedVideos = _extractList(legacyV, ['result', 'tutorials', 'data', 'videos']);
          
        } catch (e) {
          
        }
      }

      setState(() {
        contents = parsedContents;
        videoTutorials = parsedVideos;
        
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        error = 'Error loading download center data: $e';
      });
      
    }
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not launch $url'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error launching URL: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Download Center'),
        backgroundColor: Colors.grey[800],
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Sticky Header
                  EnterpriseUIComponents.buildHeaderWithIllustration(
                    title: 'Your Downloads are here!',
                    subtitle: 'Access your documents and study materials',
                    illustration: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(Icons.download, color: Colors.blue[400], size: 32),
                          Positioned(
                            bottom: 10,
                            right: 10,
                            child: Icon(Icons.description, color: Colors.green[400], size: 20),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: EnterpriseUIComponents.buildTabBar(
                              tabs: const ['Download Contents', 'Video Tutorials'],
                              selectedIndex: _selectedTab,
                              onTap: (index) => setState(() => _selectedTab = index),
                              colors: [Colors.blue[400]!, Colors.red[400]!],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildContent(),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedTab) {
      case 0:
        return _buildContentsTab();
      case 1:
        return _buildVideoTutorialsTab();
      default:
        return _buildContentsTab();
    }
  }

  Widget _buildContentsTab() {
    if (contents.isEmpty) {
      return EnterpriseUIComponents.buildEmptyState(
        title: 'No Download Contents',
        message: 'There are no download contents available at the moment.',
        icon: Icons.download_outlined,
        action: ElevatedButton.icon(
          onPressed: _loadData,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[600],
            foregroundColor: Colors.white,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: contents.length,
      itemBuilder: (context, index) {
        final content = contents[index];
        return _buildContentCard(content);
      },
    );
  }

  Widget _buildVideoTutorialsTab() {
    if (videoTutorials.isEmpty) {
      return EnterpriseUIComponents.buildEmptyState(
        title: 'No Video Tutorials',
        message: 'There are no video tutorials available at the moment.',
        icon: Icons.video_library_outlined,
        action: ElevatedButton.icon(
          onPressed: _loadData,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red[600],
            foregroundColor: Colors.white,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: videoTutorials.length,
      itemBuilder: (context, index) {
        final tutorial = videoTutorials[index];
        return _buildVideoTutorialCard(tutorial);
      },
    );
  }

  Widget _buildContentCard(Map<String, dynamic> content) {
    final title = content['title'] ?? content['name'] ?? 'Download Content';
    final description = content['description'] ?? content['details'] ?? '';
    final downloadUrl = content['download_url'] ?? content['url'] ?? content['link'] ?? '';
    final fileSize = content['file_size'] ?? content['size'] ?? '';
    final uploadDate = content['upload_date'] ?? content['created_at'] ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (fileSize.isNotEmpty)
                  Text(
                    fileSize,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.bold,
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.description,
                        color: Colors.blue[600],
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (description.isNotEmpty) ...[
                            Text(
                              description,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                          ],
                          Row(
                            children: [
                              Icon(Icons.calendar_today,
                                  size: 14, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Text(
                                uploadDate,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _downloadFile(downloadUrl, title),
                    icon: const Icon(Icons.download, size: 18),
                    label: const TranslatedText('Download'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
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

  Widget _buildVideoTutorialCard(Map<String, dynamic> tutorial) {
    final title = tutorial['title'] ?? tutorial['name'] ?? 'Video Tutorial';
    final description = tutorial['description'] ?? tutorial['details'] ?? '';
    final videoUrl = tutorial['video_url'] ?? tutorial['url'] ?? tutorial['link'] ?? '';
    final duration = tutorial['duration'] ?? tutorial['length'] ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (duration.isNotEmpty)
                  Text(
                    duration,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.red[700],
                      fontWeight: FontWeight.bold,
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.play_circle_outline,
                        color: Colors.red[600],
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (description.isNotEmpty) ...[
                            Text(
                              description,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                          ],
                          Row(
                            children: [
                              Icon(Icons.video_library,
                                  size: 14, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Text(
                                'Video Lesson',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _launchUrl(videoUrl),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const TranslatedText('Watch Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
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

  Future<void> _downloadFile(String url, String title) async {
    _launchUrl(url);
  }
}

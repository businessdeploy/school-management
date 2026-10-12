import 'package:flutter/material.dart';
import '../services/api/document_api.dart';
import '../services/auth_service.dart';
import '../config/app_config.dart';
import '../utils/url_manager.dart';
import '../widgets/translated_text.dart';
import '../widgets/enterprise_ui_components.dart';
import 'pdf_viewer_page.dart';
import 'document_viewer_page.dart';
import 'add_document_page.dart';

class MyDocumentsPage extends StatefulWidget {
  const MyDocumentsPage({super.key});

  @override
  State<MyDocumentsPage> createState() => _MyDocumentsPageState();
}

class _MyDocumentsPageState extends State<MyDocumentsPage> {
  List<Map<String, dynamic>> documents = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final studentId = await AuthService.getStudentId();
      if (studentId.isEmpty) {
        throw Exception('No student ID found. Please login again.');
      }
      

      final documentsList = await DocumentApi.getDocuments(studentId);
      

      if (!mounted) return;

      setState(() {
        documents = documentsList['documents'] != null
            ? List<Map<String, dynamic>>.from(documentsList['documents'])
            : [];
        isLoading = false;
      });

      
    } catch (e) {
      
      if (!mounted) return;
      setState(() {
        isLoading = false;
        error = e.toString();
      });
    }
  }

  Future<void> _downloadDocument(Map<String, dynamic> document) async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                TranslatedText('Preparing document...'),
              ],
            ),
            duration: Duration(seconds: 1),
          ),
        );
      }

      String docUrl = await _resolveDocumentUrl(document);

      if (docUrl.isEmpty || docUrl == 'null' || docUrl == 'N/A') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: TranslatedText('Document URL not available. Please check the document data.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        
        return;
      }

      

      // Validate and parse URL
      Uri url;
      try {
        url = Uri.parse(docUrl);
      } catch (e) {
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: TranslatedText('Invalid document URL format: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Check file type and open in appropriate viewer
      final isPDF = docUrl.toLowerCase().endsWith('.pdf');

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        
        final fileName = document['title'] ?? document['file_name'] ?? document['doc'] ?? 'Document';
        
        if (isPDF) {
          // Use dedicated PDF viewer
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PDFViewerPage(
                documentUrl: docUrl,
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
                documentUrl: docUrl,
                documentTitle: fileName,
              ),
            ),
          );
          
        }
      }
    } catch (e, stackTrace) {
      
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: TranslatedText('Error opening document: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
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
        title: const TranslatedText(
          'My Documents',
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
      body: Column(
        children: [
          // Header section
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
                        'Your My Documents is here!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TranslatedText(
                        'Manage and view all your uploaded documents.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Image.asset(
                  "assets/images/documentpage.jpg",
                  height: 70,
                  width: 70,
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ),

          // Documents list
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : error != null && documents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TranslatedText(
                              'Error loading documents: $error',
                              style: const TextStyle(color: Colors.red),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadDocuments,
                              child: const TranslatedText('Retry'),
                            ),
                          ],
                        ),
                      )
                    : documents.isEmpty
                        ? const Center(
                            child: TranslatedText(
                              'No documents available',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : _buildDocumentsList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddDocumentPage()),
          ).then((_) => _loadDocuments()); // Refresh the list after adding
        },
        backgroundColor: Colors.grey[800],
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildDocumentsIllustration() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          // Person with folder
          Positioned(
            top: 10,
            left: 15,
            child: Column(
              children: [
                // Person
                Container(
                  width: 20,
                  height: 25,
                  decoration: BoxDecoration(
                    color: Colors.blue[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 2),
                // Folder
                Container(
                  width: 25,
                  height: 15,
                  decoration: BoxDecoration(
                    color: Colors.red[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
          // Document icons
          Positioned(
            top: 5,
            right: 10,
            child: Column(
              children: [
                Container(
                  width: 8,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  width: 8,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  width: 8,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ),
          ),
          // PDF, DOC, XLS labels
          Positioned(
            bottom: 5,
            left: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PDF',
                  style: TextStyle(
                    fontSize: 6,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                Text(
                  'DOC',
                  style: TextStyle(
                    fontSize: 6,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                Text(
                  'XLS',
                  style: TextStyle(
                    fontSize: 6,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: documents.length,
      itemBuilder: (context, index) {
        final document = documents[index];
        return _buildDocumentCard(document);
      },
    );
  }

  Future<String> _resolveDocumentUrl(Map<String, dynamic> document) async {
    
    
    

    // Get the file path from document
    final filePath = _buildDocumentPath(
      document,
      [
        'doc_url',
        'download',
        'file_url',
        'doc',
        'document',
        'file',
        'file_path',
        'attachment',
        'url',
        'path',
        'doc_path',
        'file_name',
        'document_path',
        'document_url',
        'download_url',
        'file_link',
        'doc_file',
        'document_file',
      ],
    );

    if (filePath.isEmpty) {
      
      return '';
    }

    // If it's already a full URL, return it
    if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
      
      return filePath;
    }

    // Get student ID
    final studentId = await AuthService.getStudentId();
    if (studentId.isEmpty) {
      
      return '';
    }

    // Extract filename from path (get the last part after /)
    final pathParts = filePath.split('/');
    final fileName = pathParts.isNotEmpty ? pathParts.last : filePath;
    
    // If fileName is empty, use the original filePath
    final exactFileName = fileName.isNotEmpty ? fileName : filePath;

    
    

    // Force path to: uploads/student_documents/$student_id/{filename}
    final forcedPath = 'uploads/student_documents/$studentId/$exactFileName';

    

    // Get base URL
    final baseUrl = await _resolveBaseUrl();
    if (baseUrl.isEmpty) {
      
      return '';
    }

    // Build full URL
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    final fullUrl = '$normalizedBase/$forcedPath';
    
    return Uri.encodeFull(fullUrl);
  }

  Future<String> _resolveBaseUrl() async {
    var baseUrl = await UrlManager.getBaseUrl();
    if (baseUrl.isEmpty) {
      baseUrl = await AppConfig.getBaseUrl();
    }
    if (baseUrl.isNotEmpty && baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }
    return baseUrl;
  }

  String _buildDocumentPath(
    Map<String, dynamic> document,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = document[key];
      if (value != null) {
        final str = value.toString().trim();
        if (str.isNotEmpty &&
            str.toLowerCase() != 'null' &&
            str.toLowerCase() != 'n/a') {
          return str;
        }
      }
    }
    return '';
  }


  Widget _buildDocumentCard(Map<String, dynamic> document) {
    final docId =
        document['doc_id'] ??
        '${document['id'] ?? ''}-${document['student_id'] ?? ''}';
    final docHash =
        document['doc_hash'] ??
        '${document['created_at']?.toString().substring(0, 10) ?? ''}${document['student_id'] ?? ''}';
    final fileName = document['file_name'] ?? document['doc'] ?? 'document.pdf';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Padding(
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
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Stack(
                    children: [
                      const Icon(
                        Icons.description,
                        color: Colors.white,
                        size: 20,
                      ),
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: const TranslatedText(
                            'FILE',
                            style: TextStyle(
                              fontSize: 6,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        document['title'] ?? 'Document',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        docId,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.insert_drive_file,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              fileName,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _downloadDocument(document),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.download, size: 18),
                label: const TranslatedText(
                  'Download',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

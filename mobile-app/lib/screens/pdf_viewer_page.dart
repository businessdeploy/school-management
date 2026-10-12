import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

class PDFViewerPage extends StatefulWidget {
  final String documentUrl;
  final String documentTitle;

  const PDFViewerPage({
    super.key,
    required this.documentUrl,
    this.documentTitle = 'Document',
  });

  @override
  State<PDFViewerPage> createState() => _PDFViewerPageState();
}

class _PDFViewerPageState extends State<PDFViewerPage> {
  String? localFilePath;
  bool isLoading = true;
  String? errorMessage;
  int totalPages = 0;
  int currentPage = 0;

  @override
  void initState() {
    super.initState();
    _downloadAndLoadPDF();
  }

  Future<void> _downloadAndLoadPDF() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      

      // Download the file
      final response = await http.get(Uri.parse(widget.documentUrl));

      if (response.statusCode != 200) {
        throw Exception('Failed to download file: ${response.statusCode}');
      }

      // Get temporary directory
      final dir = await getTemporaryDirectory();
      
      // Extract filename from URL or use a default
      String filename = p.basename(Uri.parse(widget.documentUrl).path);
      if (filename.isEmpty || !filename.contains('.')) {
        filename = 'document_${DateTime.now().millisecondsSinceEpoch}.pdf';
      }

      // Ensure .pdf extension
      if (!filename.toLowerCase().endsWith('.pdf')) {
        filename = '$filename.pdf';
      }

      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(response.bodyBytes);

      

      if (mounted) {
        setState(() {
          localFilePath = file.path;
          isLoading = false;
        });
      }
    } catch (e) {
      
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'Failed to load document: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.documentTitle,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Save/Share',
            onPressed: () => _downloadFile(context),
          ),
          if (totalPages > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '${currentPage + 1} / $totalPages',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Future<void> _downloadFile(BuildContext context) async {
    try {
      if (localFilePath != null) {
        final file = XFile(localFilePath!);
        // Share the file - this opens the system share sheet
        // on iOS: "Save to Files" is an option
        // on Android: specific apps or file managers can be selected
        await Share.shareXFiles([file], text: 'Download ${widget.documentTitle}');
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File not loaded yet. Please wait.')),
          );
        }
      }
    } catch (e) {
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing file: $e')),
        );
      }
    }
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading document...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _downloadAndLoadPDF,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (localFilePath == null) {
      return const Center(
        child: Text('No document to display'),
      );
    }

    return PDFView(
      filePath: localFilePath!,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: true,
      pageFling: true,
      pageSnap: true,
      defaultPage: 0,
      fitPolicy: FitPolicy.BOTH,
      preventLinkNavigation: false,
      onRender: (pages) {
        setState(() {
          totalPages = pages ?? 0;
        });
      },
      onError: (error) {
        
        setState(() {
          errorMessage = 'Error displaying PDF: $error';
        });
      },
      onPageError: (page, error) {
        
      },
      onViewCreated: (PDFViewController pdfViewController) {
        
      },
      onPageChanged: (int? page, int? total) {
        if (page != null) {
          setState(() {
            currentPage = page;
          });
        }
      },
    );
  }
}

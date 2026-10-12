import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;

class DocumentViewerPage extends StatefulWidget {
  final String documentUrl;
  final String documentTitle;

  const DocumentViewerPage({
    super.key,
    required this.documentUrl,
    this.documentTitle = 'Document',
  });

  @override
  State<DocumentViewerPage> createState() => _DocumentViewerPageState();
}

class _DocumentViewerPageState extends State<DocumentViewerPage> {
  late final WebViewController? _controller;
  bool isLoading = true;
  String? errorMessage;
  bool isImage = false;

  @override
  void initState() {
    super.initState();
    _checkFileType();
  }

  void _checkFileType() {
    // Check file type and open in appropriate viewer
    // Remove query parameters for extension check
    final cleanUrl = widget.documentUrl.split('?').first.toLowerCase();
    
    isImage = cleanUrl.endsWith('.jpg') || 
              cleanUrl.endsWith('.jpeg') || 
              cleanUrl.endsWith('.png') || 
              cleanUrl.endsWith('.gif') || 
              cleanUrl.endsWith('.bmp') || 
              cleanUrl.endsWith('.webp');

    if (!isImage) {
      _initializeWebView();
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _initializeWebView() {
    try {
      // Use Google Docs Viewer for document files only
      final encodedUrl = Uri.encodeComponent(widget.documentUrl);
      final viewerUrl = 'https://docs.google.com/viewer?url=$encodedUrl&embedded=true';

      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              if (mounted) {
                setState(() {
                  isLoading = true;
                  errorMessage = null;
                });
              }
            },
            onPageFinished: (String url) {
              if (mounted) {
                setState(() {
                  isLoading = false;
                });
              }
            },
            onWebResourceError: (WebResourceError error) {
              
              if (mounted) {
                setState(() {
                  isLoading = false;
                  errorMessage = 'Failed to load document: ${error.description}';
                });
              }
            },
          ),
        )
        ..loadRequest(Uri.parse(viewerUrl));
    } catch (e) {
      
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'Failed to initialize viewer: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
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
          if (!isImage)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                _controller?.reload();
              },
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Future<void> _downloadFile(BuildContext context) async {
    try {
      setState(() {
        isLoading = true;
      });

      // Download file to temporary directory
      final response = await http.get(Uri.parse(widget.documentUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to download file: ${response.statusCode}');
      }

      final dir = await getTemporaryDirectory();
      String filename = p.basename(Uri.parse(widget.documentUrl).path);
      if (filename.isEmpty || !filename.contains('.')) {
         filename = 'document_${DateTime.now().millisecondsSinceEpoch}';
         // Add extension based on content-type if possible, or default
      }

      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(response.bodyBytes);

      setState(() {
        isLoading = false;
      });

      // Share the downloaded file
      final xFile = XFile(file.path);
      await Share.shareXFiles([xFile], text: 'Download ${widget.documentTitle}');

    } catch (e) {
      
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing file: $e')),
        );
      }
    }
  }

  Widget _buildBody() {
    if (isImage) {
      return _buildImageViewer();
    }

    return Stack(
      children: [
        if (errorMessage == null && _controller != null)
          WebViewWidget(controller: _controller)
        else if (errorMessage != null)
          _buildErrorView(),
        if (isLoading)
          const Center(
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
          ),
      ],
    );
  }

  Widget _buildImageViewer() {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: CachedNetworkImage(
          imageUrl: widget.documentUrl,
          placeholder: (context, url) => const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Loading image...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          errorWidget: (context, url, error) => Center(
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
                  'Failed to load image',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildErrorView() {
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
              errorMessage ?? 'Failed to load document',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  errorMessage = null;
                });
                _initializeWebView();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'payment_success_page.dart';

class PaymentWebViewPage extends StatefulWidget {
  final String url;
  final String title;
  final double? amount;

  const PaymentWebViewPage({
    super.key,
    required this.url,
    this.title = 'Payment Gateway',
    this.amount,
  });

  @override
  State<PaymentWebViewPage> createState() => _PaymentWebViewPageState();
}

class _PaymentWebViewPageState extends State<PaymentWebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() => _isLoading = true);
            
            if (_isSuccessUrl(url)) {
               _navigateToSuccess(url);
            }
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
            
            
            // REDESIGN: Look for success flags to show native professional screen
            if (_isSuccessUrl(url)) {
              
              _navigateToSuccess(url);
            }
          },
          onWebResourceError: (WebResourceError error) {
            
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;
            
            
            if (_isSuccessUrl(url)) {
              
              _navigateToSuccess(url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  bool _isSuccessUrl(String url) {
    final lowerUrl = url.toLowerCase();
    return lowerUrl.contains('success') || 
           lowerUrl.contains('callback') || 
           lowerUrl.contains('complete') || 
           lowerUrl.contains('thanks') || 
           lowerUrl.contains('thank_you') ||
           lowerUrl.contains('payment_success') ||
           lowerUrl.contains('gateway/success');
  }

  void _navigateToSuccess(String url) {
    if (!mounted) return;
    
    // Attempt to extract amount or reference from URL if present
    double? amt = widget.amount; // Default to passed amount
    String? ref;
    try {
      final uri = Uri.parse(url);
      
      // If no passed amount, try to extract
      if (amt == null) {
          final amtParam = uri.queryParameters['amount'] ?? uri.queryParameters['total'];
          if (amtParam != null) amt = double.tryParse(amtParam);
      }
      
      ref = uri.queryParameters['reference'] ?? uri.queryParameters['transaction_id'] ?? uri.queryParameters['order_id'];
    } catch (_) {}

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => PaymentSuccessPage(
          amount: amt,
          reference: ref,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.grey[800],
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context, true), // Return true to trigger refresh
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../services/auth_service.dart';
import '../utils/url_manager.dart';
import '../config/app_config.dart';
import '../utils/api_image_manager.dart';
import 'payment_webview_page.dart';

class CoursePaymentPage extends StatefulWidget {
  final Map<String, dynamic> course;

  const CoursePaymentPage({super.key, required this.course});

  @override
  State<CoursePaymentPage> createState() => _CoursePaymentPageState();
}

class _CoursePaymentPageState extends State<CoursePaymentPage> {
  final TextEditingController _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _emailController.text = 'nathan455@gmail.com'; // Default email
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final course = widget.course;

    double parseAmount(dynamic value) {
      if (value == null) return 0.0;
      final str = value.toString().replaceAll(RegExp(r'[^0-9.]'), '');
      return double.tryParse(str) ?? 0.0;
    }

    // Base course amount: prefer discounted/final amounts from API
    double baseAmount = 0.0;
    final baseCandidates = [
      course['discounted_price'],
      course['final_amount'],
      course['final_price'],
      course['course_amount'],
      course['price'],
      course['original_price'],
    ];
    


    // Processing fees: prefer dynamic value from API if available
    double processingFees = 0.0;
    final feeCandidates = [
      course['processing_fee'],
      course['processing_fees'],
      course['gateway_charge'],
      course['gateway_processing_charge'],
    ];
    


    // Fallback to previous fixed fee if API doesn't send anything
    // Fallback to previous fixed fee if API doesn't send anything
    if (processingFees <= 0) {
      processingFees = 18.0;
    }

    final totalAmount = baseAmount + processingFees;


    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Course Payment',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.grey[800],
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height - kToolbarHeight - MediaQuery.of(context).padding.top,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Main white card
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Paystack header
                    Container(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Paystack logo
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: Colors.blue[600],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Stack(
                                  children: [
                                    // Three bars
                                    Positioned(
                                      top: 8,
                                      left: 6,
                                      child: Container(
                                        width: 18,
                                        height: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Positioned(
                                      top: 12,
                                      left: 8,
                                      child: Container(
                                        width: 14,
                                        height: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Positioned(
                                      top: 16,
                                      left: 10,
                                      child: Container(
                                        width: 10,
                                        height: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'paystack',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[800],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Paystack Payment Gateway',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Course purchase details
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Course Purchase Details',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    // Course illustration and details
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        children: [
                          // Course uploaded image / thumbnail (falls back to illustration)
                          SizedBox(
                            height: 100,
                            child: FutureBuilder<String>(
                              future: ApiImageManager.getCourseThumbnailUrl(
                                course['course_thumbnail']?.toString(),
                              ),
                              builder: (context, snapshot) {
                                final hasThumbnail = snapshot.hasData &&
                                    snapshot.data != null &&
                                    snapshot.data!.isNotEmpty &&
                                    snapshot.data != 'null';

                                if (hasThumbnail) {
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      snapshot.data!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        // If network image fails, show math illustration
                                        return _buildMathIllustration();
                                      },
                                    ),
                                  );
                                }

                                // While loading or if no thumbnail, show math illustration
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  );
                                }

                                return _buildMathIllustration();
                              },
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Course title
                          Text(
                            course['title'] ?? 'Course Title',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),

                          // Email input
                          TextField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              labelText: 'Email Address',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.blue[600]!),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Base course price
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue[100]!),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Course Price:',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  '\$${baseAmount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[900],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Processing fees
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Processing Fees:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                '\$${processingFees.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Payment button
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(20),
                child: ElevatedButton(
                  onPressed: _processPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Pay With Paystack \$${totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMathIllustration() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          // Top row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMathSymbol('a² + b² = c²', Colors.black),
              _buildMathSymbol('sin²α + cos²β = 1', Colors.black),
            ],
          ),
          const SizedBox(height: 8),
          // Bottom row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMathSymbol('√X', Colors.black),
              _buildMathSymbol('?', Colors.black),
              _buildMathSymbol('85%', Colors.black),
              _buildMathSymbol('15%', Colors.black),
            ],
          ),
          const SizedBox(height: 8),
          // Visual elements
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Icon(Icons.straighten, size: 16, color: Colors.grey[600]), // Ruler
              Icon(Icons.calculate, size: 16, color: Colors.grey[600]), // Calculator
              Icon(Icons.quiz, size: 16, color: Colors.grey[600]), // Quiz
              Icon(Icons.assignment, size: 16, color: Colors.grey[600]), // Assignment
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMathSymbol(String symbol, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        symbol,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Future<void> _processPayment() async {
    final course = widget.course;
    final title = course['title'] ?? 'the course';
    
    setState(() {
      // We could use a loading state here if needed, 
      // but the dialog handles it.
    });

    try {
      // 1. Get Student ID
      final studentId = await AuthService.getStudentId();
      if (studentId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to determine student ID. Please re-login.')),
          );
        }
        return;
      }

      // 2. Get Course ID
      final courseId = course['id']?.toString() ??
          course['course_id']?.toString() ??
          course['courseId']?.toString() ??
          '';
      
      if (courseId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Course ID is missing.')),
          );
        }
        return;
      }

      // 3. Get Base URL
      var baseUrl = await UrlManager.getBaseUrl();
      if (baseUrl.isEmpty) {
        baseUrl = await AppConfig.getBaseUrl();
      }

      if (baseUrl.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Server URL is not configured.')),
          );
        }
        return;
      }

      // 4. Construct Payment URL
      final cleanBaseUrl = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;
      final paymentUrl =
          '$cleanBaseUrl/api/course_payment/course_payment/payment/$courseId/$studentId';
      final encodedUrl = Uri.encodeFull(paymentUrl);

      // Show processing dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                const Text(
                  'Redirecting to Gateway',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  'Opening Paystack for "$title"...',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      }

      // 5. Navigate to In-App WebView instead of launching external browser
      if (mounted) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentWebViewPage(
              url: encodedUrl,
              title: 'Course Payment',
            ),
          ),
        );

        if (result == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Returning to course details. Please refresh if needed.'),
              backgroundColor: Colors.blue,
            ),
          );
          Navigator.pop(context, true); // Return success to detail page
        }
      }
    } catch (e) {
      if (mounted) {
        if (Navigator.canPop(context)) Navigator.pop(context); // Close loading if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

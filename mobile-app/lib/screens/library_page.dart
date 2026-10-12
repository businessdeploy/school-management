import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/translated_text.dart';
import '../services/api/library_api.dart';
import '../services/auth_service.dart';
import '../providers/app_config_provider.dart';
import '../widgets/enterprise_ui_components.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  List<Map<String, dynamic>> issuedBooks = [];
  List<Map<String, dynamic>> topBooks = [];
  bool isLoading = true;
  String? error;
  int selectedTab = 0; // 0 = Books Issued, 1 = Top Books

  @override
  void initState() {
    super.initState();
    _loadLibraryData();
  }

  Future<void> _loadLibraryData() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final studentId = await AuthService.getStudentId();
      

      // Load issued books for "Books Issued" tab
      final issuedBooksData = await LibraryApi.getIssuedBooks(studentId);
      
      
      
      

      // Load all books for "Top Books" tab
      final allBooksData = await LibraryApi.getBooks(studentId);
      
      
      
      

      if (!mounted) return;

      // Process issued books
      List<Map<String, dynamic>> issuedBooksList = [];
      if (issuedBooksData['books'] != null && issuedBooksData['books'] is List) {
        issuedBooksList = (issuedBooksData['books'] as List).map((item) {
          return Map<String, dynamic>.from(item as Map);
        }).toList();
      }

      // Process all books and sort/filter for top books
      List<Map<String, dynamic>> allBooksList = [];
      if (allBooksData['books'] != null && allBooksData['books'] is List) {
        allBooksList = (allBooksData['books'] as List).map((item) {
          return Map<String, dynamic>.from(item as Map);
        }).toList();
      }

      // Sort books by popularity/rating for top books
      // Check for rating, popularity, or issue_count fields
      final topBooksList = _getTopBooks(allBooksList);

      setState(() {
        issuedBooks = issuedBooksList;
        topBooks = topBooksList;

        if (issuedBooks.isEmpty) {
          
        }
        if (topBooks.isEmpty) {
          
        }

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

  // Get top books by sorting based on available metrics
  List<Map<String, dynamic>> _getTopBooks(List<Map<String, dynamic>> allBooks) {
    if (allBooks.isEmpty) return [];

    // Try to sort by rating, popularity, or issue count
    final sortedBooks = List<Map<String, dynamic>>.from(allBooks);

    sortedBooks.sort((a, b) {
      // Priority 1: Check for rating field
      final ratingA = _getNumericValue(a, [
        'rating',
        'book_rating',
        'rate',
        'score',
      ]);
      final ratingB = _getNumericValue(b, [
        'rating',
        'book_rating',
        'rate',
        'score',
      ]);
      if (ratingA != null && ratingB != null) {
        return ratingB.compareTo(ratingA); // Descending order
      }

      // Priority 2: Check for popularity/issue count
      final popularityA = _getNumericValue(a, [
        'popularity',
        'issue_count',
        'issued_count',
        'total_issues',
        'borrow_count',
      ]);
      final popularityB = _getNumericValue(b, [
        'popularity',
        'issue_count',
        'issued_count',
        'total_issues',
        'borrow_count',
      ]);
      if (popularityA != null && popularityB != null) {
        return popularityB.compareTo(popularityA); // Descending order
      }

      // Priority 3: Check for views/read count
      final viewsA = _getNumericValue(a, [
        'views',
        'view_count',
        'read_count',
        'reads',
      ]);
      final viewsB = _getNumericValue(b, [
        'views',
        'view_count',
        'read_count',
        'reads',
      ]);
      if (viewsA != null && viewsB != null) {
        return viewsB.compareTo(viewsA); // Descending order
      }

      return 0; // Keep original order if no sortable field found
    });

    // Return top 20 books (or all if less than 20)
    return sortedBooks.take(20).toList();
  }

  // Helper to extract numeric value from multiple possible keys
  double? _getNumericValue(Map<String, dynamic> book, List<String> keys) {
    for (final key in keys) {
      final value = book[key];
      if (value != null) {
        if (value is num) {
          return value.toDouble();
        } else if (value is String) {
          final parsed = double.tryParse(value);
          if (parsed != null) return parsed;
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final appConfigProvider = Provider.of<AppConfigProvider>(context);
    final primaryColor = appConfigProvider.primaryColorObj;
    final secondaryColor = appConfigProvider.secondaryColorObj;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: TranslatedText(
          selectedTab == 0 ? 'Books Issued' : 'Top Books',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Icon(Icons.library_books, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          const TranslatedText(
            'Books',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(width: 16),
        ],
        centerTitle: true,
      ),
      body: Column(
        children: [
          EnterpriseUIComponents.buildHeaderWithIllustration(
            title: 'Library',
            subtitle: 'View issued and available books',
            illustration: Image.asset(
              'assets/images/librarypage.jpg',
              fit: BoxFit.contain,
            ),
            illustrationWidth: 100,
            illustrationHeight: 80,
          ),
          // Tab selector
          Container(
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedTab = 0;
                      });
                      // Reload data if needed when switching tabs
                      if (issuedBooks.isEmpty && !isLoading) {
                        _loadLibraryData();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: selectedTab == 0
                            ? Colors.grey[200]
                            : Colors.transparent,
                        border: Border(
                          bottom: BorderSide(
                            color: selectedTab == 0
                                ? primaryColor
                                : Colors.grey[300]!,
                            width: 2,
                          ),
                        ),
                      ),
                      child: TranslatedText(
                        'Books Issued',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selectedTab == 0
                              ? primaryColor
                              : Colors.grey[600],
                          fontWeight: selectedTab == 0
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedTab = 1;
                      });
                      // Reload data if needed when switching tabs
                      if (topBooks.isEmpty && !isLoading) {
                        _loadLibraryData();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: selectedTab == 1
                            ? Colors.grey[200]
                            : Colors.transparent,
                        border: Border(
                          bottom: BorderSide(
                            color: selectedTab == 1
                                ? primaryColor
                                : Colors.grey[300]!,
                            width: 2,
                          ),
                        ),
                      ),
                      child: TranslatedText(
                        'Top Books',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selectedTab == 1
                              ? primaryColor
                              : Colors.grey[600],
                          fontWeight: selectedTab == 1
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),



          // Content section
          Expanded(
            child: Container(
              color: Colors.grey[100],
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : error != null
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
                          TranslatedText(
                            'Error loading library data: $error',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadLibraryData,
                            child: const TranslatedText('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _buildContent(secondaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLibraryIllustration() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          // Bookshelf
          Positioned(
            top: 10,
            left: 20,
            child: Container(
              width: 60,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.green[300],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.green[400]!, width: 2),
              ),
              child: Stack(
                children: [
                  // Books on shelf
                  Positioned(
                    top: 5,
                    left: 5,
                    child: Container(
                      width: 8,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.red[400],
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 5,
                    left: 15,
                    child: Container(
                      width: 8,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.yellow[400],
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 5,
                    left: 25,
                    child: Container(
                      width: 8,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.blue[400],
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 5,
                    left: 35,
                    child: Container(
                      width: 8,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.green[400],
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 5,
                    left: 45,
                    child: Container(
                      width: 8,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.purple[400],
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Ladder
          Positioned(
            bottom: 10,
            left: 10,
            child: Container(
              width: 8,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.brown[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Desk
          Positioned(
            bottom: 10,
            right: 20,
            child: Container(
              width: 40,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.blue[600],
                borderRadius: BorderRadius.circular(2),
              ),
              child: Stack(
                children: [
                  // Chair
                  Positioned(
                    top: -5,
                    right: 5,
                    child: Container(
                      width: 8,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.yellow[400],
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                  // Lamp
                  Positioned(
                    top: 2,
                    left: 5,
                    child: Container(
                      width: 4,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.green[400],
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                  // Books on desk
                  Positioned(
                    top: 5,
                    left: 10,
                    child: Container(
                      width: 6,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.red[300],
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Library sign
          Positioned(
            top: 5,
            right: 10,
            child: Container(
              width: 30,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.orange[400],
                borderRadius: BorderRadius.circular(2),
              ),
              child: Center(
                child: const TranslatedText(
                  'LIBRARY',
                  style: TextStyle(
                    fontSize: 4,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(Color secondaryColor) {
    if (selectedTab == 0) {
      // Books Issued tab
      return issuedBooks.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.book_online, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  TranslatedText(
                    'No issued books available',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : _buildIssuedBooksList(secondaryColor);
    } else {
      // Top Books tab
      return topBooks.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.library_books, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  TranslatedText(
                    'No top books available',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : _buildTopBooksList(secondaryColor);
    }
  }

  Widget _buildIssuedBooksList(Color secondaryColor) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: issuedBooks.length,
      itemBuilder: (context, index) {
        final book = issuedBooks[index];
        return _buildIssuedBookCard(book, secondaryColor);
      },
    );
  }

  Widget _buildTopBooksList(Color secondaryColor) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: topBooks.length,
      itemBuilder: (context, index) {
        final book = topBooks[index];
        return _buildTopBookCard(book, secondaryColor);
      },
    );
  }

  Widget _buildIssuedBookCard(Map<String, dynamic> book, Color headerColor) {
    final isReturned =
        book['return_date'] != null &&
        book['return_date'].toString().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with status
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TranslatedText(
                    book['book_title'] ?? book['title'] ?? 'Book Title',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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
                    color: isReturned ? Colors.green[600] : Colors.red[600],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: TranslatedText(
                    isReturned ? 'Returned' : 'Not Returned',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildDetailRow('Author', book['author'] ?? 'N/A'),
                _buildDetailRow(
                  'Book No.',
                  book['book_no'] ?? book['book_number'] ?? 'N/A',
                ),
                _buildDetailRow('Issue Date', _formatDate(book['issue_date'])),
                _buildDetailRow('Return Date', _formatDate(book['return_date'])),
                _buildDetailRow(
                  'Due Return Date',
                  _formatDate(book['due_return_date']),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null || date.toString().isEmpty || date.toString() == 'N/A') {
      return 'N/A';
    }
    try {
      // If date is already in DD/MM/YYYY format, return as is
      if (RegExp(r'^\d{2}/\d{2}/\d{4}').hasMatch(date.toString())) {
        return date.toString();
      }
      
      // Parse YYYY-MM-DD
      final parts = date.toString().split('-');
      if (parts.length == 3) {
        return '${parts[2]}/${parts[1]}/${parts[0]}';
      }
      
      // Try parsing as DateTime
      final dateTime = DateTime.tryParse(date.toString());
      if (dateTime != null) {
        return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
      }
    } catch (e) {
      
    }
    return date.toString();
  }

  Widget _buildTopBookCard(Map<String, dynamic> book, Color headerColor) {
    // Debug: Log book data to identify publisher key
    
    
    
    
    
    
    
    
    
    // Get rating or popularity for display
    final rating = _getNumericValue(book, [
      'rating',
      'book_rating',
      'rate',
      'score',
    ]);
    final popularity = _getNumericValue(book, [
      'popularity',
      'issue_count',
      'issued_count',
      'total_issues',
      'borrow_count',
    ]);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with rating/popularity badge
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: headerColor, // Match the screenshot color (light green)
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TranslatedText(
                    book['book_title'] ?? book['title'] ?? 'Book Title',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                if (rating != null || popularity != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber[600],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          rating != null
                              ? rating.toStringAsFixed(1)
                              : popularity != null
                              ? popularity.toStringAsFixed(0)
                              : '',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildDetailRow('Author', book['author']),
                _buildDetailRow(
                  'Subject',
                  book['subject'] ?? book['subject_name'],
                ),
                _buildDetailRow(
                  'Publisher',
                  book['publisher'] ?? 
                  book['publisher_name'] ?? 
                  book['published_by'] ?? 
                  book['publish_by'] ?? 
                  book['publish_by_name'] ??
                  book['book_publisher'] ??
                  book['publish'] ??
                  book['publishing_house'] ??
                  book['publication'] ??
                  book['publisher_name'],
                ),
                _buildDetailRow(
                  'Rack No.',
                  book['rack_no'] ?? book['rack_number'],
                ),
                _buildDetailRow(
                  'Quantity',
                  book['qty']?.toString() ??
                      book['quantity']?.toString(),
                ),
                _buildDetailRow(
                  'Book Price',
                  _formatPrice(book['perunitcost'] ?? book['book_price'] ?? book['price']),
                ),
                _buildDetailRow(
                  'Post Date',
                  _formatDate(book['postdate'] ?? book['post_date']),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(dynamic price) {
    if (price == null) return 'N/A';
    try {
      final value = double.tryParse(price.toString());
      if (value != null) {
        return '\$${value.toStringAsFixed(1)}';
      }
    } catch (e) {
      
    }
    return price.toString();
  }

  Widget _buildDetailRow(String label, String? value) {
    if (value == null || value.isEmpty || value == 'N/A' || value == '\$0.0') {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: TranslatedText(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: TranslatedText(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

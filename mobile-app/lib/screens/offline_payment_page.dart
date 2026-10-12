import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../services/api/fees_api.dart';
import '../utils/url_manager.dart';
import 'fees/fee_logic.dart';
import 'package:provider/provider.dart';
import '../providers/app_config_provider.dart';
import '../models/fee_model.dart';
import '../widgets/translated_text.dart';
import 'pdf_viewer_page.dart';
import 'document_viewer_page.dart';

class OfflinePaymentPage extends StatefulWidget {
  final Map<String, dynamic> fee;
  final String currencySymbol;
  final String studentId;
  final String studentSessionId;
  final String studentFeesMasterId;
  final String feeGroupsFeetypeId;
  final String? studentTransportFeeId;
  final Future<void> Function() onSubmitted;
  final Map<String, dynamic>? existingPayment;

  const OfflinePaymentPage({
    super.key,
    required this.fee,
    required this.currencySymbol,
    required this.studentId,
    required this.studentSessionId,
    required this.studentFeesMasterId,
    required this.feeGroupsFeetypeId,
    this.studentTransportFeeId,
    required this.onSubmitted,
    this.existingPayment,
  });

  @override
  State<OfflinePaymentPage> createState() => _OfflinePaymentPageState();
}

class _OfflinePaymentPageState extends State<OfflinePaymentPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _paymentModeController = TextEditingController();
  final TextEditingController _paymentFromController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _commentsController = TextEditingController();

  bool _submitting = false;
  final ImagePicker _imagePicker = ImagePicker();

  final _paymentModes = const [
    'Cash',
    'Cheque',
    'DD',
    'Bank Transfer',
    'Online',
    'UPI',
  ];
  DateTime? _selectedDate;
  String? _pickedAttachmentPath;
  String? _pickedAttachmentName;
  String? _existingAttachmentUrl;
  String? _existingAttachmentName;
  bool _shouldRemoveAttachment = false;

  // Discount Logic
  bool _isLoadingDiscounts = false;
  List<dynamic> _availableDiscounts = [];
  final List<String> _selectedDiscountIds = [];
  double _basePayableAmount = 0.0; // Amount + Fine - Paid - (Already Applied Discounts)

  @override
  void initState() {
    super.initState();
    _prefillDefaults();
    _fetchDiscounts();
  }

  void _prefillDefaults() {
    final existing = widget.existingPayment;
    
    // CRITICAL: Calculate total payable amount including fine
    // Formula: Total = (Amount + Fine) - (Discount + Paid)
    double amount = 0.0;
    double fine = 0.0;
    double discount = 0.0;
    double paid = 0.0;
    
    // Extract amount
    for (final key in ['amount', 'fees', 'total_amount', 'fee_amount']) {
      if (widget.fee.containsKey(key) && widget.fee[key] != null) {
        amount = FeeLogic.parseDouble(widget.fee[key]);
        if (amount != 0) break;
      }
    }
    
    // Extract fine
    for (final key in ['amount_fine', 'fine_amount', 'total_amount_fine', 'fee_fine', 'fine']) {
      if (widget.fee.containsKey(key) && widget.fee[key] != null) {
        fine = FeeLogic.parseDouble(widget.fee[key]);
        if (fine != 0) break;
      }
    }
    
    // Extract discount
    for (final key in ['discount_amount', 'total_amount_discount', 'amount_discount', 'discount']) {
      if (widget.fee.containsKey(key) && widget.fee[key] != null) {
        discount = FeeLogic.parseDouble(widget.fee[key]);
        if (discount != 0) break;
      }
    }
    
    // Extract paid amount
    for (final key in ['paid_amount', 'total_amount_paid', 'amount_paid', 'paid']) {
      if (widget.fee.containsKey(key) && widget.fee[key] != null) {
        paid = FeeLogic.parseDouble(widget.fee[key]);
        if (paid != 0) break;
      }
    }
    
    // Calculate total payable (including fine!)
    final calculatedTotal = (amount + fine) - (discount + paid);
    _basePayableAmount = calculatedTotal;
    


    final totalAmount = FeeLogic.parseDouble(existing?['amount'] ?? calculatedTotal);
    _amountController.text = totalAmount > 0 ? totalAmount.toStringAsFixed(2) : '';
    _paymentModeController.text = existing?['payment_mode'] ??
        existing?['mode'] ??
        _paymentModes.first;
    _paymentFromController.text = existing?['payment_from'] ?? '';
    _referenceController.text = existing?['reference'] ?? '';
    _commentsController.text = existing?['comments'] ??
        existing?['note'] ??
        existing?['description'] ??
        '';

    final rawDate = existing?['payment_date'] ??
        existing?['date'] ??
        existing?['submit_date'];
    _selectedDate = _parseRawDate(rawDate) ?? DateTime.now();
    _dateController.text = _formatDateForDisplay(_selectedDate);
    final attachmentInfo = _resolveAttachmentInfo(existing);
    _existingAttachmentUrl = attachmentInfo['url'];
    _existingAttachmentName = attachmentInfo['name'] ??
        attachmentInfo['url']?.split('/').last.split('?').first;
  }


  @override
  void dispose() {
    _dateController.dispose();
    _paymentModeController.dispose();
    _paymentFromController.dispose();
    _referenceController.dispose();
    _amountController.dispose();
    _commentsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text(
          'Offline Payment',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                // Form Card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Payment Details Section
                      _buildSectionTitle('Payment Details', Icons.payment),
                      const SizedBox(height: 20),
                      _buildTextField(
                        label: 'Date of Payment',
                        controller: _dateController,
                        readOnly: true,
                        onTap: _pickDate,
                        validator: _requiredValidator,
                        prefixIcon: Icons.calendar_today,
                      ),
                      const SizedBox(height: 16),
                      _buildDropdownField(
                        label: 'Payment Mode',
                        value: _paymentModeController.text,
                        items: _paymentModes,
                        onChanged: (value) => setState(() => _paymentModeController.text = value ?? ''),
                        icon: Icons.account_balance_wallet,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        label: 'Payment From',
                        controller: _paymentFromController,
                        validator: _requiredValidator,
                        prefixIcon: Icons.business,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        label: 'Reference',
                        controller: _referenceController,
                        prefixIcon: Icons.receipt_long,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        label: 'Amount Paid',
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: _requiredValidator,
                        prefixIcon: Icons.payments,
                        currencySymbol: widget.currencySymbol,
                        readOnly: false,
                      ),
                      
                      // Discount Section
                      if (_isLoadingDiscounts)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_availableDiscounts.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),
                            _buildSectionTitle('Available Discounts', Icons.percent),
                            const SizedBox(height: 10),
                            ..._availableDiscounts.map((discount) {
                              final id = discount['id'].toString();
                              final name = discount['name'] ?? 'Discount';
                              final code = discount['code'] ?? '';
                              final amount = FeeLogic.parseDouble(discount['amount']);
                              final percentage = FeeLogic.parseDouble(discount['percentage']);
                              
                              String subtitle = '';
                              if (percentage > 0) {
                                subtitle = '$percentage% off';
                              } else {
                                subtitle = '${widget.currencySymbol} ${amount.toStringAsFixed(2)} off';
                              }
                              
                              final isSelected = _selectedDiscountIds.contains(id);
                              
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: CheckboxListTile(
                                  value: isSelected,
                                  onChanged: (val) => _toggleDiscount(id, val ?? false),
                                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('$code • $subtitle'),
                                  activeColor: Colors.green,
                                  secondary: const Icon(Icons.local_offer, color: Colors.orange),
                                ),
                              );
                            }).toList(),
                          ],
                        ),

                      // Additional Information Section
                      _buildSectionTitle('Additional Information', Icons.info_outline),
                      const SizedBox(height: 20),
                      _buildTextField(
                        label: 'Comments',
                        controller: _commentsController,
                        maxLines: 3,
                        prefixIcon: Icons.comment,
                      ),
                      const SizedBox(height: 24),
                      // Attachment Section
                      _buildSectionTitle('Supporting Documents', Icons.attach_file),
                      const SizedBox(height: 20),
                      _buildAttachmentSection(),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Submit Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  widget.existingPayment != null
                                      ? Icons.update
                                      : Icons.check_circle_outline,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  widget.existingPayment != null
                                      ? 'Update Request'
                                      : 'Submit Payment',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Offline Bank\nPayments',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                        height: 1.1,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Instructions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Offline mode of payment are Cash, DD, Online and Cheques',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Header Illustration
              _buildIllustration(
                '/Users/dheerajraikwar/.gemini/antigravity/brain/4377a918-7d85-48ec-8f61-97cb6512e9d8/offline_payment_header_illustration_1767870942017.png',
                width: 120,
                height: 120,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIllustration(String path, {double width = 100, double height = 100}) {
    // For local development and demonstration, we use File image. 
    // In production, these should be in assets/images/
    try {
      return Image.file(
        File(path),
        width: width,
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Icon(Icons.account_balance_wallet, size: width / 2, color: Colors.blue[100]);
        },
      );
    } catch (e) {
      return Icon(Icons.account_balance_wallet, size: width / 2, color: Colors.blue[100]);
    }
  }



  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: Colors.blue[700],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
    TextInputType? keyboardType,
    FormFieldValidator<String>? validator,
    bool readOnly = false,
    VoidCallback? onTap,
    ValueChanged<String>? onChanged,
    Widget? suffix,
    IconData? prefixIcon,
    String? currencySymbol,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      readOnly: readOnly,
      onTap: onTap,
      onChanged: onChanged,
      style: const TextStyle(
        fontSize: 15,
        color: Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.grey[600],
          fontSize: 14,
        ),
        prefixIcon: prefixIcon != null
            ? Icon(
                prefixIcon,
                size: 20,
                color: Colors.grey[600],
              )
            : null,
        prefixText: currencySymbol != null && currencySymbol.isNotEmpty
            ? '$currencySymbol '
            : null,
        prefixStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
        suffixIcon: suffix,
        filled: true,
        fillColor: readOnly ? Colors.grey[50] : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    IconData? icon,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.grey[600],
          fontSize: 14,
        ),
        prefixIcon: icon != null
            ? Icon(
                icon,
                size: 20,
                color: Colors.grey[600],
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value.isEmpty ? null : value,
          isExpanded: true,
          style: const TextStyle(
            fontSize: 15,
            color: Colors.black87,
          ),
          hint: Text(
            'Select payment mode',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 15,
            ),
          ),
          items: items
              .map((item) => DropdownMenuItem(
                    value: item,
                    child: Text(item),
                  ))
              .toList(),
          onChanged: onChanged,
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: Colors.grey[600],
          ),
        ),
      ),
    );
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required';
    }
    return null;
  }

  Future<void> _pickDate() async {
    final initialDate = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(initialDate.year - 5),
      lastDate: DateTime(initialDate.year + 5),
    );

    if (picked != null) {
      _selectedDate = picked;
      _dateController.text = _formatDateForDisplay(picked);
    }
  }

  String _formatDateForDisplay(DateTime? date) {
    if (date == null) return '';
    final format = Provider.of<AppConfigProvider>(context, listen: false).dateFormat;
    return FeeLogic.formatDate(date, format: format);
  }

  String _formatDateForApi(DateTime date) {
    // Manual format to avoid any DateFormat localization issues
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  DateTime? _parseRawDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String && raw.trim().isNotEmpty) {
      final trimmed = raw.trim();
      final parsed = DateTime.tryParse(trimmed);
      if (parsed != null) return parsed;
      final formats = [
        'dd/MM/yyyy',
        'dd-MM-yyyy',
        'MM/dd/yyyy',
        'yyyy/MM/dd',
        'yyyy-MM-dd',
      ];
      for (final format in formats) {
        try {
          return DateFormat(format).parseStrict(trimmed);
        } catch (_) {}
      }
    }
    return null;
  }
  
  Future<void> _fetchDiscounts() async {
    if (!mounted) return;
    setState(() => _isLoadingDiscounts = true);

    try {

      // We need to fetch discounts to see what can be applied
      final response = await FeesApi.getFeesDiscount(
        studentSessionId: widget.studentSessionId,
        studentFeesMasterId: widget.studentFeesMasterId,
        feeGroupsFeetypeId: widget.feeGroupsFeetypeId,
        feeCategory: 'fees', 
      );
      
      if (!mounted) return;
      
      if (response['status'] == 1) {
        setState(() {
          _availableDiscounts = response['discount_not_applied'] ?? [];
          _isLoadingDiscounts = false;
        });

      } else {
         setState(() => _isLoadingDiscounts = false);
      }
    } catch (e) {
      
      if (mounted) setState(() => _isLoadingDiscounts = false);
    }
  }

  void _toggleDiscount(String id, bool selected) {
    setState(() {
      if (selected) {
        if (!_selectedDiscountIds.contains(id)) {
          _selectedDiscountIds.add(id);
        }
      } else {
        _selectedDiscountIds.remove(id);
      }
      _recalculateTotal();
    });
  }

  void _recalculateTotal() {
    double currentTotal = _basePayableAmount;
    
    for (var dis in _availableDiscounts) {
      if (_selectedDiscountIds.contains(dis['id'].toString())) {
        final amount = FeeLogic.parseDouble(dis['amount']);
        final percentage = FeeLogic.parseDouble(dis['percentage']);
        
        if (percentage > 0) {
          // Percentage of the original FEE amount (not base which includes fine)
          // Since we don't have pure fee amount easily here, we use the amount from widget.fee
          double feeAmount = FeeLogic.parseDouble(widget.fee['amount'] ?? widget.fee['total_amount'] ?? widget.fee['fee_amount'] ?? 0);
          double discountAmt = (feeAmount * percentage) / 100;
          currentTotal -= discountAmt;
        } else {
          currentTotal -= amount;
        }
      }
    }
    
    if (currentTotal < 0) currentTotal = 0;
    _amountController.text = currentTotal.toStringAsFixed(2);
  }

  Map<String, String?> _resolveAttachmentInfo(Map<String, dynamic>? data) {
    if (data == null) return {'url': null, 'name': null};
    String? url;
    for (final key in [
      'attachment',
      'attachment_url',
      'file',
      'file_url',
      'document',
      'document_url',
      'attach',
      'file_path',
    ]) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        url = value.toString().trim();
        break;
      }
    }
    String? name;
    for (final key in [
      'attachment_name',
      'file_name',
      'document_name',
      'name',
    ]) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        name = value.toString().trim();
        break;
      }
    }
    return {'url': url, 'name': name};
  }

  /// Validate attachment file before upload
  /// Returns error message if invalid, null if valid
  Future<String?> _validateAttachment(String filePath, String fileName) async {
    try {

      
      // Check if file exists
      final file = File(filePath);
      if (!await file.exists()) {

        return 'Selected file not found. Please try again.';
      }
      
      // Check file size (limit: 10MB)
      final fileSize = await file.length();
      const maxSize = 10 * 1024 * 1024; // 10MB in bytes

      
      if (fileSize > maxSize) {

        return 'File size exceeds 10MB limit. Please choose a smaller file.';
      }
      
      if (fileSize == 0) {

        return 'Selected file is empty. Please choose a valid file.';
      }
      
      // Check file extension
      final extension = fileName.toLowerCase().split('.').last;
      const allowedExtensions = ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'];

      
      if (!allowedExtensions.contains(extension)) {

        return 'Invalid file type. Allowed: JPG, PNG, PDF, DOC';
      }
      

      return null; // Valid
      
    } catch (e) {
      
      return 'Error validating file. Please try again.';
    }
  }

  // Pick from system file picker (PDFs, docs, any file)
  void _selectAttachmentFromFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      dialogTitle: 'Select document or image',
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;
    
    // Validate file
    final validationError = await _validateAttachment(file.path!, file.name);
    if (validationError != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(validationError), backgroundColor: Colors.red),
        );
      }
      return;
    }
    
    setState(() {
      _pickedAttachmentPath = file.path;
      _pickedAttachmentName = file.name;
      _existingAttachmentUrl = null;
      _existingAttachmentName = null;
      _shouldRemoveAttachment = false;
    });
  }

  // Capture photo from camera
  void _selectAttachmentFromCamera() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (picked == null) return;
    
    // Validate file
    final validationError = await _validateAttachment(picked.path, picked.name);
    if (validationError != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(validationError), backgroundColor: Colors.red),
        );
      }
      return;
    }
    
    setState(() {
      _pickedAttachmentPath = picked.path;
      _pickedAttachmentName = picked.name;
      _existingAttachmentUrl = null;
      _existingAttachmentName = null;
      _shouldRemoveAttachment = false;
    });
  }

  // Pick photo from gallery / photo library
  void _selectAttachmentFromGallery() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;
    
    // Validate file
    final validationError = await _validateAttachment(picked.path, picked.name);
    if (validationError != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(validationError), backgroundColor: Colors.red),
        );
      }
      return;
    }
    
    setState(() {
      _pickedAttachmentPath = picked.path;
      _pickedAttachmentName = picked.name;
      _existingAttachmentUrl = null;
      _existingAttachmentName = null;
      _shouldRemoveAttachment = false;
    });
  }

  Future<void> _selectAttachment() async {
    // Let user choose Camera, Photo Library, or Files in a bottom sheet
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _selectAttachmentFromCamera();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Photo Library'),
                onTap: () {
                  Navigator.pop(context);
                  _selectAttachmentFromGallery();
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder),
                title: const Text('Browse Files'),
                onTap: () {
                  Navigator.pop(context);
                  _selectAttachmentFromFiles();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _removeAttachment() {
    setState(() {
      _pickedAttachmentPath = null;
      _pickedAttachmentName = null;
      if (_existingAttachmentUrl != null || _existingAttachmentName != null) {
        _existingAttachmentUrl = null;
        _existingAttachmentName = null;
        _shouldRemoveAttachment = true;
      }
    });
  }

  Future<void> _downloadAttachment(String url) async {
    if (url.isEmpty) return;

    String resolvedUrl = url;
    if (!url.toLowerCase().startsWith('http')) {
      final baseUrl = await UrlManager.getBaseUrl();
      resolvedUrl = FeeLogic.resolveAttachmentUrl(baseUrl, url);
    }

    // Determine name from URL or existing name
    final name = _existingAttachmentName ?? resolvedUrl.split('/').last.split('?').first;
    
    if (resolvedUrl.toLowerCase().endsWith('.pdf')) {
       Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PDFViewerPage(
            documentUrl: resolvedUrl,
            documentTitle: name,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DocumentViewerPage(
            documentUrl: resolvedUrl,
            documentTitle: name,
          ),
        ),
      );
    }
  }

  Widget _buildAttachmentSection() {
    final hasNewFile = _pickedAttachmentName != null;
    final hasExisting = _existingAttachmentUrl != null && _existingAttachmentUrl!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey[200]!,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasNewFile || hasExisting)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.green[200]!,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          hasNewFile ? Icons.insert_drive_file : Icons.file_present,
                          color: Colors.green[700],
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hasNewFile ? 'New File Selected' : 'Existing File',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.green[900],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              hasNewFile
                                  ? (_pickedAttachmentName ?? '')
                                  : (_existingAttachmentName ??
                                      _existingAttachmentUrl!.split('/').last),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (hasExisting) ...[
                        IconButton(
                          icon: Icon(Icons.download, color: Colors.blue[700], size: 20),
                          tooltip: 'Download',
                          onPressed: () => _downloadAttachment(_existingAttachmentUrl!),
                        ),
                      ],
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.red[600], size: 20),
                        tooltip: 'Remove',
                        onPressed: _removeAttachment,
                      ),
                    ],
                  ),
                )
              else ...[
                Center(
                  child: _buildIllustration(
                    '/Users/dheerajraikwar/.gemini/antigravity/brain/4377a918-7d85-48ec-8f61-97cb6512e9d8/offline_payment_footer_illustration_1767870959204.png',
                    width: 180,
                    height: 180,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: (Colors.blue[50] ?? Colors.blue).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue[700],
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Please attach receipt/photo for offline payment',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue[900],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _selectAttachment,
                  icon: Icon(
                    hasNewFile || hasExisting ? Icons.change_circle : Icons.attach_file,
                    size: 20,
                  ),
                  label: Text(
                    hasNewFile || hasExisting ? 'Change File' : 'Choose File',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(
                      color: Colors.blue[600]!,
                      width: 1.5,
                    ),
                    foregroundColor: Colors.blue[700],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Supported formats: PDF, JPG, PNG',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dateController.text.isEmpty) {
      setState(() {});
      return;
    }

    // Attachment is mandatory (either existing or newly picked)
    final hasNewFile =
        _pickedAttachmentPath != null && _pickedAttachmentPath!.trim().isNotEmpty;
    final hasExistingFile = _existingAttachmentUrl != null &&
        _existingAttachmentUrl!.trim().isNotEmpty &&
        !_shouldRemoveAttachment;
    if (!hasNewFile && !hasExistingFile) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please attach receipt/photo for offline payment')),
      );
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final paymentDate = _selectedDate != null
          ? _formatDateForApi(_selectedDate!)
          : (_parseRawDate(_dateController.text) != null
              ? _formatDateForApi(_parseRawDate(_dateController.text)!)
              : '');
      if (paymentDate.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid payment date')),
        );
        return;
      }
      final requestId = widget.existingPayment?['request_id']?.toString() ??
          widget.existingPayment?['id']?.toString();


      final cleanAmountStr = _amountController.text.replaceAll(RegExp(r'[^0-9\.]'), '');

      
      // Pre-submission validation: Re-validate attachment if it's a new file
      if (hasNewFile) {

        final validationError = await _validateAttachment(_pickedAttachmentPath!, _pickedAttachmentName ?? 'unknown');
        if (validationError != null) {
          setState(() {
            _submitting = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Attachment validation failed: $validationError'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
          return;
        }

      }

      final response = await FeesApi.submitOfflinePayment(
        studentFeesMasterId: widget.studentFeesMasterId,
        feeGroupsFeetypeId: widget.feeGroupsFeetypeId,
        studentId: widget.studentId,
        studentSessionId: widget.studentSessionId,
        paymentDate: paymentDate,
        paymentMode: _paymentModeController.text,
        paymentFrom: _paymentFromController.text,
        reference: _referenceController.text,
        amount: cleanAmountStr,
        note: _commentsController.text,
        attachmentPath: _pickedAttachmentPath,
        removeAttachment: _shouldRemoveAttachment,
        requestId: requestId,
        studentTransportFeeId: widget.studentTransportFeeId,
        feeDiscountGroup: _selectedDiscountIds,
      );

      if (!mounted) return;

      final status = response['status'];
      final message = (response['message'] ?? 'Unable to submit payment').toString();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: (status == 1 || status == '1') ? Colors.green : Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );

      if (status == 1 || status == '1') {
        await widget.onSubmitted();
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to submit offline payment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }
}

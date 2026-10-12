import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:ui' as ui;
import '../services/api_service.dart';
import '../services/api/profile_api.dart';
import '../models/student.dart';
import '../providers/app_config_provider.dart';
import 'package:provider/provider.dart';
import '../widgets/translated_text.dart';
import 'edit_profile_page.dart';
import '../widgets/enterprise_ui_components.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  Student? student;
  Map<String, dynamic>? parentData;
  bool isLoading = true;
  String? errorMessage;
  late TabController _tabController;
  int _selectedTab = 0; // 0 = Personal, 1 = Parents, 2 = Other

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedTab = _tabController.index;
      });
    });
    loadProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> loadProfile() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // Get student profile data from getStudentProfile API
      final profileData = await ProfileApi.getUserProfile();

      if (!mounted) return;

      // Handle the new response structure with 'student_result'
      if (profileData['student_result'] != null) {
        final studentData = profileData['student_result'];
        
        setState(() {
          student = Student.fromJson(studentData);
          isLoading = false;
        });

        // Load parent data from the student's data
        await _loadParentDataFromChild(studentData);
      } else {
        setState(() {
          errorMessage = 'No student data found';
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = 'Error loading profile: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _loadParentDataFromChild(Map<String, dynamic> childData) async {
    try {
      if (mounted) {
        setState(() {
          parentData = {
            'father_name': childData['father_name'] ?? 'N/A',
            'father_occupation': childData['father_occupation'] ?? 'N/A',
            'father_phone': childData['father_phone'] ?? 'N/A',
            'father_email': childData['guardian_email'] ?? 'N/A',
            'mother_name': childData['mother_name'] ?? 'N/A',
            'mother_occupation': childData['mother_occupation'] ?? 'N/A',
            'mother_phone': childData['mother_phone'] ?? 'N/A',
            'mother_email': childData['guardian_email'] ?? 'N/A',
            'address': childData['current_address'] ?? 'N/A',
            'emergency_contact': childData['guardian_phone'] ?? 'N/A',
          };
        });
      }
    } catch (e) {

    }
  }

  Widget _buildProfileIllustration() {
    return FutureBuilder<String>(
      future: Future.value(student?.image != null && student!.image!.isNotEmpty
          ? ApiService.getImageUrl(student!.image!)
          : ''),
      builder: (context, snapshot) {
        return Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey[300]!, width: 2),
          ),
          child: CircleAvatar(
            radius: 34,
            backgroundImage: student?.image != null &&
                    student!.image!.isNotEmpty &&
                    snapshot.hasData &&
                    snapshot.data!.isNotEmpty
                ? NetworkImage(snapshot.data!)
                : null,
            child: student?.image == null ||
                    student!.image!.isEmpty ||
                    !snapshot.hasData ||
                    snapshot.data!.isEmpty
                ? const Icon(Icons.person, size: 40, color: Colors.grey)
                : null,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const TranslatedText('Profile', style: TextStyle(color: Colors.white)),
        backgroundColor: Provider.of<AppConfigProvider>(context).primaryColorObj,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: const [],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: Provider.of<AppConfigProvider>(context).primaryColorObj))
          : errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Error loading profile',
                    style: TextStyle(color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: loadProfile,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : student == null
          ? const Center(child: Text('No profile data available', style: TextStyle(color: Colors.black87)))
          : SingleChildScrollView(
              child: Column(
                children: [
                  EnterpriseUIComponents.buildHeaderWithIllustration(
                    title: 'Student Profile',
                    subtitle: 'View and manage your academic profile',
                  ),
                  // Main white card
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header section with name, class info, and profile picture
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left side: Name and details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Student name - Large and bold
                                    Text(
                                      student?.fullName ?? 'Student Name',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                        height: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    // Class info
                                    Text(
                                      '${student?.classSection ?? 'N/A'} (2025-26)',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    // Admission number
                                    Text(
                                      'Adm. No. ${student?.admissionNo ?? 'N/A'}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    // Roll number
                                    Text(
                                      'Roll Number ${student?.rollNo ?? 'N/A'}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              _buildProfileIllustration(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Barcode, QR Code, and Behaviour Score in a row
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _buildBarcodeSection(),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildQRCodeSection(),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildBehaviourScoreSection(),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        // Tabs
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildTabButton('PERSONAL', 0),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildTabButton('PARENTS', 1),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildTabButton('OTHER', 2),
                              ),
                            ],
                          ),
                        ),
                        
                        // PRINT button
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _printProfile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[300],
                                foregroundColor: Colors.black87,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                              child: const TranslatedText(
                                'PRINT',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Tab content
                        _buildTabContent(),
                        
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = index;
          _tabController.animateTo(index);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Provider.of<AppConfigProvider>(context).primaryColorObj : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: TranslatedText(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildBarcodeSection() {
    final admissionNo = student?.admissionNo ?? '120020';
    if (admissionNo.isEmpty || admissionNo == 'N/A') {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const TranslatedText(
            'Barcode',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          // Real barcode widget
          Container(
            height: 45,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
            child: BarcodeWidget(
              barcode: Barcode.code128(),
              data: admissionNo,
              color: Colors.black,
              height: 52,
              drawText: true,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQRCodeSection() {
    final admissionNo = student?.admissionNo ?? '120020';
    if (admissionNo.isEmpty || admissionNo == 'N/A') {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const TranslatedText(
            'QR Code',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          // Real QR code widget
          Container(
            height: 45,
            width: 45,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
            child: QrImageView(
              data: admissionNo,
              version: QrVersions.auto,
              size: 52,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBehaviourScoreSection() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const TranslatedText(
            'Behaviour Score',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 45,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                '60',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Provider.of<AppConfigProvider>(context).primaryColorObj,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildPersonalTab();
      case 1:
        return _buildParentsTab();
      case 2:
        return _buildOtherTab();
      default:
        return _buildPersonalTab();
    }
  }

  Widget _buildPersonalTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Two-column layout for better organization
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Admission Date', _formatDate(student?.admissionDate)),
                    _buildInfoRow('Date Of Birth', _formatDate(student?.dob)),
                    _buildInfoRow('Gender', student?.gender ?? 'N/A'),
                    _buildInfoRow('Category', student?.cast ?? 'N/A'),
                    _buildInfoRow('Mobile Number', student?.mobileno ?? 'N/A'),
                    _buildInfoRow('Caste', student?.cast ?? 'N/A'),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Religion', student?.religion ?? 'N/A'),
                    _buildInfoRow('Email', student?.email ?? 'N/A'),
                    _buildInfoRow('Blood Group', student?.bloodGroup ?? 'N/A'),
                    _buildInfoRow('Height', student?.height ?? 'N/A'),
                    _buildInfoRow('Weight', student?.weight ?? 'N/A'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Full-width fields for addresses
          _buildInfoRow('Current Address', student?.currentAddress ?? 'N/A', fullWidth: true),
          _buildInfoRow('Permanent Address', student?.permanentAddress ?? 'N/A', fullWidth: true),
        ],
      ),
    );
  }

  Widget _buildParentsTab() {
    if (parentData == null) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: Text('Parent information not available')),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Father Information
          const TranslatedText(
            'Father',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Name', parentData!['father_name'] ?? 'N/A'),
                    _buildInfoRow('Occupation', parentData!['father_occupation'] ?? 'N/A'),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Phone', parentData!['father_phone'] ?? 'N/A'),
                    _buildInfoRow('Email', parentData!['father_email'] ?? 'N/A'),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          
          // Mother Information
          const TranslatedText(
            'Mother',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Name', parentData!['mother_name'] ?? 'N/A'),
                    _buildInfoRow('Occupation', parentData!['mother_occupation'] ?? 'N/A'),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Phone', parentData!['mother_phone'] ?? 'N/A'),
                    _buildInfoRow('Email', parentData!['mother_email'] ?? 'N/A'),
                  ],
                ),
              ),
            ],
          ),
          
          if (student?.guardianName != null && student!.guardianName.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),
            const TranslatedText(
              'Guardian',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Name', student!.guardianName),
            _buildInfoRow('Relation', student!.guardianRelation),
            _buildInfoRow('Phone', student!.guardianPhone),
            _buildInfoRow('Email', student!.guardianEmail),
          ],
        ],
      ),
    );
  }

  Widget _buildOtherTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
                    _buildInfoRow('National Identification Number', student?.adharNo ?? 'N/A'),
                    _buildInfoRow('Local Identification Number', student?.samagraId ?? 'N/A'),
                    _buildInfoRow('Bank Account No', student?.bankAccountNo ?? 'N/A'),
                    _buildInfoRow('Bank Name', student?.bankName ?? 'N/A'),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('IFSC Code', student?.ifscCode ?? 'N/A'),
                    _buildInfoRow('Previous School', student?.previousSchool ?? 'N/A'),
                    _buildInfoRow('RTE', student?.rte ?? 'N/A'),
                  ],
                ),
              ),
            ],
          ),
          if (student?.note != null && student!.note.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildInfoRow('Note', student!.note, fullWidth: true),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool fullWidth = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: fullWidth
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 140,
                  child: TranslatedText(
                    '$label:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    value.isEmpty ? 'N/A' : value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TranslatedText(
                  '$label:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? 'N/A' : value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
    );
  }

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return 'N/A';
    try {
      // Try to parse and format the date
      // Assuming format might be YYYY-MM-DD or DD/MM/YYYY
      if (date.contains('/')) {
        return date; // Already formatted
      }
      final parts = date.split('-');
      if (parts.length == 3) {
        return '${parts[2]}/${parts[1]}/${parts[0]}';
      }
      return date;
    } catch (e) {
      return date;
    }
  }

  Future<void> _printProfile() async {
    if (student == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No profile data available to print'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Generate QR code image
      final qrImage = await _generateQRCodeImage(student?.admissionNo ?? '');
      
      // Generate barcode image
      final barcodeImage = await _generateBarcodeImage(student?.admissionNo ?? '');

      // Fetch student image
      pw.MemoryImage? studentImage;
      if (student?.image != null && student!.image!.isNotEmpty) {
        try {
          final imageUrl = await ApiService.getImageUrl(student!.image!);
          final response = await http.get(Uri.parse(imageUrl));
          if (response.statusCode == 200) {
            studentImage = pw.MemoryImage(response.bodyBytes);
          }
        } catch (e) {
          // Fallback to no image if fetch fails
        }
      }

      // Create PDF document
      final pdf = pw.Document();
      
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return [
              // Header
              pw.Header(
                level: 0,
                child: pw.Text(
                  'Student Profile',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              
              // Student Information Section
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          student?.fullName ?? 'Student Name',
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 10),
                        pw.Text('Class ${student?.className ?? 'N/A'}-${student?.section ?? 'N/A'} (2025-26)'),
                        pw.Text('Adm. No. ${student?.admissionNo ?? 'N/A'}'),
                        pw.Text('Roll Number ${student?.rollNo ?? 'N/A'}'),
                      ],
                    ),
                  ),
                  if (studentImage != null) ...[
                    pw.SizedBox(width: 20),
                    pw.Container(
                      width: 80,
                      height: 80,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                      ),
                      child: pw.Image(studentImage, fit: pw.BoxFit.cover),
                    ),
                  ],
                ],
              ),
              
              pw.SizedBox(height: 20),
              
              // Barcode, QR Code, and Behaviour Score
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                children: [
                  // Barcode
                  if (barcodeImage != null)
                    pw.Column(
                      children: [
                        pw.Text('Barcode', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 5),
                        pw.Image(barcodeImage, width: 150, height: 60),
                        pw.Text(student?.admissionNo ?? ''),
                      ],
                    ),
                  
                  // QR Code
                  if (qrImage != null)
                    pw.Column(
                      children: [
                        pw.Text('QR Code', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 5),
                        pw.Image(qrImage, width: 60, height: 60),
                      ],
                    ),
                  
                  // Behaviour Score
                  pw.Column(
                    children: [
                      pw.Text('Behaviour Score', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 5),
                      pw.Container(
                        width: 100,
                        height: 60,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.blue),
                        ),
                        child: pw.Center(
                          child: pw.Text(
                            '60',
                            style: pw.TextStyle(
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              pw.SizedBox(height: 30),
              
              // Personal Information
              pw.Header(level: 1, child: pw.Text('Personal Information')),
              pw.SizedBox(height: 10),
              _buildPdfInfoRow('Admission Date', _formatDate(student?.admissionDate)),
              _buildPdfInfoRow('Date Of Birth', _formatDate(student?.dob)),
              _buildPdfInfoRow('Gender', student?.gender ?? 'N/A'),
              _buildPdfInfoRow('Category', student?.cast ?? 'N/A'),
              _buildPdfInfoRow('Mobile Number', student?.mobileno ?? 'N/A'),
              _buildPdfInfoRow('Caste', student?.cast ?? 'N/A'),
              _buildPdfInfoRow('Religion', student?.religion ?? 'N/A'),
              _buildPdfInfoRow('Email', student?.email ?? 'N/A'),
              _buildPdfInfoRow('Blood Group', student?.bloodGroup ?? 'N/A'),
              _buildPdfInfoRow('Height', student?.height ?? 'N/A'),
              _buildPdfInfoRow('Weight', student?.weight ?? 'N/A'),
              _buildPdfInfoRow('Current Address', student?.currentAddress ?? 'N/A'),
              _buildPdfInfoRow('Permanent Address', student?.permanentAddress ?? 'N/A'),
              
              // Parents Information
              if (parentData != null) ...[
                pw.SizedBox(height: 20),
                pw.Header(level: 1, child: pw.Text('Parents Information')),
                pw.SizedBox(height: 10),
                pw.Text('Father', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                pw.SizedBox(height: 5),
                _buildPdfInfoRow('Name', parentData!['father_name'] ?? 'N/A'),
                _buildPdfInfoRow('Occupation', parentData!['father_occupation'] ?? 'N/A'),
                _buildPdfInfoRow('Phone', parentData!['father_phone'] ?? 'N/A'),
                _buildPdfInfoRow('Email', parentData!['father_email'] ?? 'N/A'),
                pw.SizedBox(height: 10),
                pw.Text('Mother', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                pw.SizedBox(height: 5),
                _buildPdfInfoRow('Name', parentData!['mother_name'] ?? 'N/A'),
                _buildPdfInfoRow('Occupation', parentData!['mother_occupation'] ?? 'N/A'),
                _buildPdfInfoRow('Phone', parentData!['mother_phone'] ?? 'N/A'),
                _buildPdfInfoRow('Email', parentData!['mother_email'] ?? 'N/A'),
              ],
            ];
          },
        ),
      );

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Show print dialog
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) Navigator.of(context).pop();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  pw.Widget _buildPdfInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(
            child: pw.Text(value.isEmpty ? 'N/A' : value),
          ),
        ],
      ),
    );
  }

  Future<pw.ImageProvider?> _generateQRCodeImage(String data) async {
    if (data.isEmpty) return null;
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final painter = QrPainter(
        data: data,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        color: Colors.black,
        emptyColor: Colors.white,
      );
      
      painter.paint(canvas, const Size(200, 200));
      final picture = recorder.endRecording();
      final image = await picture.toImage(200, 200);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData?.buffer.asUint8List();
      
      if (pngBytes != null) {
        return pw.MemoryImage(pngBytes);
      }
    } catch (e) {
      
    }
    return null;
  }

  Future<pw.ImageProvider?> _generateBarcodeImage(String data) async {
    if (data.isEmpty) return null;
    try {
      // Create a simple barcode representation
      // For a proper barcode, we'd need to render it to an image
      // This is a simplified version
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      
      // Draw a simple barcode representation
      // In a real implementation, you'd use a barcode library to render
      // For now, we'll create a placeholder
      final paint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.fill;
      
      const barWidth = 2.0;
      const barHeight = 50.0;
      double x = 0;
      
      // Simple barcode pattern (this is just a visual representation)
      for (int i = 0; i < 20; i++) {
        canvas.drawRect(
          Rect.fromLTWH(x, 0, barWidth, barHeight),
          paint,
        );
        x += barWidth * 2;
      }
      
      final picture = recorder.endRecording();
      final image = await picture.toImage(200, 60);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData?.buffer.asUint8List();
      
      if (pngBytes != null) {
        return pw.MemoryImage(pngBytes);
      }
    } catch (e) {
      
    }
    return null;
  }
}

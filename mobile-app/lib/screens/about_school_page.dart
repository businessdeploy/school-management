import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_service.dart';
import '../config/app_config.dart';
import '../services/api/enterprise_api_service.dart';
import '../utils/url_manager.dart';
import '../widgets/translated_text.dart';

class AboutSchoolPage extends StatefulWidget {
  const AboutSchoolPage({super.key});

  @override
  State<AboutSchoolPage> createState() => _AboutSchoolPageState();
}

class _AboutSchoolPageState extends State<AboutSchoolPage> {
  Map<String, dynamic>? schoolInfo;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadSchoolInfo();
  }

  Future<void> _loadSchoolInfo() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      // Fetch school info from API
      final response = await EnterpriseApiService.getSchoolDetails();
      
      if (response.success && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        
        // Resolve image URL
        String logoUrl = '';
        if (data['image'] != null && data['image'].toString().isNotEmpty) {
          final baseUrl = await UrlManager.getBaseUrl();
          // Adjust path if needed. Usually images are in uploads/school_content/logo/app_logo/
          // The Postman shows "image": "167555679-40786394863d7523fe8c91!1.png"
          // Let's check how AppConfig.getAppLogo() does it.
          logoUrl = '$baseUrl/uploads/school_content/logo/app_logo/${data['image']}';
        }

        // Persist to SharedPreferences for other app parts to use
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('school_name', data['name']?.toString() ?? '');
        await prefs.setString('school_address', data['address']?.toString() ?? '');
        await prefs.setString('school_phone', data['phone']?.toString() ?? '');
        await prefs.setString('school_email', data['email']?.toString() ?? '');
        await prefs.setString('school_code', data['dise_code']?.toString() ?? '');
        await prefs.setString('current_session', data['session']?.toString() ?? '');
        if (data['image'] != null) {
          await prefs.setString('app_logo', data['image'].toString());
        }

        setState(() {
          schoolInfo = {
            'name': data['name'] ?? 'Prime School',
            'logo': logoUrl,
            'address': data['address'] ?? 'Address not available',
            'phone': data['phone'] ?? 'Phone not available',
            'email': data['email'] ?? 'Email not available',
            'school_code': data['dise_code'] ?? 'N/A',
            'current_session': data['session'] ?? 'N/A',
            'website': data['website'] ?? '',
          };
          isLoading = false;
        });
      } else {
        // Fallback to local prefs if API fails
        final prefs = await SharedPreferences.getInstance();
        final schoolName = prefs.getString('school_name') ?? '';
        final schoolLogo = await AppConfig.getAppLogo();
        final schoolAddress = prefs.getString('school_address') ?? '';
        final schoolPhone = prefs.getString('school_phone') ?? '';
        final schoolEmail = prefs.getString('school_email') ?? '';
        final schoolCode = prefs.getString('school_code') ?? '';
        final currentSession = prefs.getString('current_session') ?? '';
        final startMonth = prefs.getString('session_start_month') ?? '';
        final schoolWebsite = prefs.getString('school_website') ?? '';

        setState(() {
          schoolInfo = {
            'name': schoolName.isNotEmpty ? schoolName : 'Prime School',
            'logo': schoolLogo,
            'address': schoolAddress.isNotEmpty ? schoolAddress : 'Address not available',
            'phone': schoolPhone.isNotEmpty ? schoolPhone : 'Phone not available',
            'email': schoolEmail.isNotEmpty ? schoolEmail : 'Email not available',
            'school_code': schoolCode.isNotEmpty ? schoolCode : 'N/A',
            'current_session': currentSession.isNotEmpty ? currentSession : 'N/A',
            'website': schoolWebsite.isNotEmpty ? schoolWebsite : '',
          };
          isLoading = false;
        });
      }
    } catch (e) {
      
      if (!mounted) return;
      setState(() {
        isLoading = false;
        error = e.toString();
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
            SnackBar(content: Text('Could not launch $url')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
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
          'About School',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.grey[800],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      body: isLoading
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
                        'Error loading school information',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadSchoolInfo,
                        child: const TranslatedText('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // Header Section
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(20),
                            bottomRight: Radius.circular(20),
                          ),
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
                            // School Logo
                            if (schoolInfo!['logo'] != null &&
                                schoolInfo!['logo'].toString().isNotEmpty) ...[
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 500),
                                child: CachedNetworkImage(
                                  key: ValueKey(schoolInfo!['logo']),
                                  imageUrl: schoolInfo!['logo'],
                                  imageBuilder: (context, imageProvider) => Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.blue.shade50,
                                      border: Border.all(
                                        color: Colors.blue.shade200,
                                        width: 3,
                                      ),
                                      image: DecorationImage(
                                        image: imageProvider,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  placeholder: (context, url) => const SizedBox.shrink(),
                                  errorWidget: (context, url, error) => const SizedBox.shrink(),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            // School Name
                            Text(
                              schoolInfo!['name'],
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      // Information Cards
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // Address Card
                            _buildInfoCard(
                              icon: Icons.location_on,
                              title: 'Address',
                              content: schoolInfo!['address'],
                              color: Colors.blue,
                              translateTitle: true,
                            ),
                            const SizedBox(height: 16),

                            // Phone Card
                            _buildInfoCard(
                              icon: Icons.phone,
                              title: 'Phone',
                              content: schoolInfo!['phone'],
                              color: Colors.green,
                              translateTitle: true,
                              onTap: schoolInfo!['phone'] != 'Phone not available'
                                  ? () {
                                      final phone = schoolInfo!['phone']
                                          .toString()
                                          .replaceAll(RegExp(r'[^\d+]'), '');
                                      _launchUrl('tel:$phone');
                                    }
                                  : null,
                            ),
                            const SizedBox(height: 16),

                            // Email Card
                            _buildInfoCard(
                              icon: Icons.email,
                              title: 'Email',
                              content: schoolInfo!['email'],
                              color: Colors.orange,
                              translateTitle: true,
                              onTap: schoolInfo!['email'] != 'Email not available' &&
                                      schoolInfo!['email'].toString().contains('@')
                                  ? () {
                                      _launchUrl('mailto:${schoolInfo!['email']}');
                                    }
                                  : null,
                            ),
                            const SizedBox(height: 16),

                            // School Code Card
                            _buildInfoCard(
                              icon: Icons.code,
                              title: 'School Code',
                              content: schoolInfo!['school_code'],
                              color: Colors.red,
                              translateTitle: true,
                            ),
                            const SizedBox(height: 16),

                            // Current Session Card
                            _buildInfoCard(
                              icon: Icons.calendar_today,
                              title: 'Current Session',
                              content: schoolInfo!['current_session'],
                              color: Colors.indigo,
                              translateTitle: true,
                            ),
                            const SizedBox(height: 16),


                            // Website Card
                            if (schoolInfo!['website'] != null &&
                                schoolInfo!['website'].toString().isNotEmpty)
                              _buildInfoCard(
                                icon: Icons.language,
                                title: 'Website',
                                content: schoolInfo!['website'],
                                color: Colors.purple,
                                translateTitle: true,
                                onTap: () {
                                  String url = schoolInfo!['website'].toString();
                                  if (!url.startsWith('http://') &&
                                      !url.startsWith('https://')) {
                                    url = 'https://$url';
                                  }
                                  _launchUrl(url);
                                },
                              ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
    required Color color,
    bool translateTitle = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
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
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  translateTitle
                      ? TranslatedText(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      : Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                  const SizedBox(height: 4),
                  Text(
                    content,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
          ],
        ),
      ),
    );
  }
}


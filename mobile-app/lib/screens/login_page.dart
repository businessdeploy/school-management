import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../utils/url_manager.dart';
import 'dashboard_page.dart';
import 'url_page.dart';
import 'forgot_password_page.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../widgets/child_selection_dialog.dart';
import 'dart:convert';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../providers/app_config_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

class LoginPageUI extends StatefulWidget {
  const LoginPageUI({super.key});

  @override
  State<LoginPageUI> createState() => _LoginPageUIState();
}

class _LoginPageUIState extends State<LoginPageUI> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController otpController = TextEditingController();
  int _selectedTabIndex = 0; // 0 for Password, 1 for SMS OTP
  bool _isOtpSent = false;
  bool _isSendingOtp = false;
  int _resendCountdown = 0;
  Timer? _resendTimer;
  bool isLoading = false;
  bool _obscurePassword = true;
  String schoolName = '';
  String schoolLogo = '';

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    phoneController.dispose();
    otpController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).clearSnackBars();
    });
    loadSchoolInfo();
    _clearInvalidTokens();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload school info when page becomes visible (e.g., after URL configuration)
    loadSchoolInfo();
  }

  Future<void> _clearInvalidTokens() async {
    try {
      final isLoggedIn = await AuthService.isLoggedIn();
      if (!isLoggedIn) {
         // Logic to clear tokens if needed
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> loadSchoolInfo() async {
    try {
      // Use Provider to get the current cached config
      final appConfigProvider = Provider.of<AppConfigProvider>(context, listen: false);
      
      // Load basic info from AppConfig (central source of truth)
      final schoolNameValue = await AppConfig.getSchoolName();
      final schoolLogoValue = await AppConfig.getAppLogo();

      if (mounted) {
        setState(() {
          // Priority: Provider > AppConfig > Default
          schoolName = appConfigProvider.schoolName != 'Prime School' 
              ? appConfigProvider.schoolName 
              : (schoolNameValue.isNotEmpty ? schoolNameValue : 'Prime School');
          
          schoolLogo = appConfigProvider.appLogo.isNotEmpty 
              ? appConfigProvider.appLogo 
              : schoolLogoValue;
        });
      }

      // If logo is still empty OR we want to ensure fresh data, trigger a refresh in the provider
      // This happens in background and won't clear existing state if it fails
      if (schoolLogo.isEmpty) {
        appConfigProvider.loadAppConfig().then((_) {
          if (mounted) {
            setState(() {
              schoolName = appConfigProvider.schoolName;
              schoolLogo = appConfigProvider.appLogo;
            });
          }
        });
      }
    } catch (e) {
      // On error, DO NOT clear the logo. Keep whatever was last known.
    }
  }

  Future<void> loginUser() async {
    if (usernameController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both username and password'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    // Show loading message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attempting login...'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
        ),
      );
    }

    try {


      // Get base URL from common URL manager
      final baseUrl = await UrlManager.getBaseUrl();

      
      String loginEndpoint;
      if (baseUrl.isEmpty) {
        // 
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please configure your school URL first'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      } else {
        loginEndpoint = '$baseUrl/api/webservice/login';
      }
      
      // Try multiple login endpoints if the first one fails
      final loginEndpoints = [
        loginEndpoint,
        '$baseUrl/api/webservice/auth/login',
        '$baseUrl/api/auth/login',
        '$baseUrl/api/login',
        '$baseUrl/auth/login',
        '$baseUrl/login',
      ];


      
      for (int i = 0; i < loginEndpoints.length; i++) {
        final endpoint = loginEndpoints[i];
        // 
        
        try {
          final response = await http.post(
            Uri.parse(endpoint),
            headers: {
              'Auth-Key': AppConfig.authKey,
              'Client-Service': AppConfig.clientService,
              'Content-Type': AppConfig.contentType,
              'User-Agent': 'SmartSchool-Mobile/1.0',
              'Accept': 'application/json',
              'Connection': 'keep-alive',
            },
            body: jsonEncode({
              'username': usernameController.text.trim(),
              'password': passwordController.text.trim(),
              'deviceToken': await AppConfig.getDeviceToken(),
            }),
          ).timeout(AppConfig.requestTimeout);



          if (response.statusCode == 200) {
            // Check if response is HTML (error page)
            if (response.body.contains('<html>') || response.body.contains('<!DOCTYPE')) {

              continue;
            }

            try {
              final responseData = jsonDecode(response.body);
              if (responseData['status'] == 1 || responseData['status'] == 200) {
                await _handleLoginSuccess(responseData);
                return;
              } else {
                final errorMessage = responseData['message'] ?? 'Login failed';
                // 
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(errorMessage),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
                return;
              }
            } catch (parseError) {

              continue;
            }
          } else {
            // 
            continue;
          }
        } catch (e) {
          // 
          continue;
        }
      }
      
      // If all endpoints failed
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login failed. Please check your credentials and try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } on http.ClientException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection error: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Login failed. Please try again.';
        final errorStr = e.toString();
        
        if (errorStr.contains('Timeout')) {
          errorMessage = 'Connection timeout. The server is taking too long to respond.';
        } else if (errorStr.contains('SocketException') || errorStr.contains('Connection refused')) {
          errorMessage = 'Network error. Please check your internet connection.';
        } else if (errorStr.contains('HandshakeException')) {
          errorMessage = 'Security error (SSL). Please check your internet.';
        } else {
          errorMessage = 'Login failed: $errorStr';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _handleLoginSuccess(Map<String, dynamic> responseData) async {
    await _saveUserData(responseData);

    // Explicitly register device token for notifications after login
    NotificationService.registerCurrentToken(force: true).catchError((e) => {});

    if (!mounted) return;

    final record = responseData['record'];
    final String role = (responseData['role'] ?? '').toString().toLowerCase();

    List<dynamic>? children;
    if (record is Map && record['parent_childs'] != null) {
      children = record['parent_childs'];
    } else if (record is List) {
      // In some API versions, record itself is the child list
      children = record;
    }

    if (role == 'parent' && children != null && children.isNotEmpty) {
      if (children.length > 1) {
        // Show child selection dialog for parents with multiple children
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => ChildSelectionDialog(
            children: List<Map<String, dynamic>>.from(children!),
            onChildSelected: (child) async {
              try {
                Navigator.pop(context); // Close dialog
                await AuthService.switchChild(child);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Login successful!'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 1),
                    ),
                  );

                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const DashboardPage()),
                  );

                  // Refresh provider in background after navigation starts
                  Provider.of<AppConfigProvider>(context, listen: false).loadAppConfig();
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const DashboardPage()),
                  );
                }
              }
            },
          ),
        );
      } else {
        // Auto-select the only child for parents with one child
        final child = Map<String, dynamic>.from(children[0]);
        await AuthService.switchChild(child);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Login successful!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1),
            ),
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DashboardPage()),
          );

          // Refresh provider in background
          Provider.of<AppConfigProvider>(context, listen: false).loadAppConfig();
        }
      }
    } else if (role == 'parent') {
      // Parent login without children
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login failed: No children found for this parent account.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    } else {
      // Standard student login flow
      try {
        Provider.of<AppConfigProvider>(context, listen: false).loadAppConfig();
      } catch (e) {
        // ignore
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login successful!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardPage()),
      );
    }
  }

  Future<void> _sendPhoneOtp() async {
    final phone = phoneController.text.trim();
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final last10 = cleanPhone.length >= 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;

    if (last10.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 10-digit mobile number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSendingOtp = true;
    });

    try {
      final baseUrl = await UrlManager.getBaseUrl();
      if (baseUrl.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please configure your school URL first'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final endpoints = [
        '$baseUrl/api/webservice/send_phone_otp',
        '$baseUrl/api/auth/send_phone_otp',
      ];

      bool sent = false;
      String message = '';

      for (final endpoint in endpoints) {
        try {
          final response = await http.post(
            Uri.parse(endpoint),
            headers: {
              'Auth-Key': AppConfig.authKey,
              'Client-Service': AppConfig.clientService,
              'Content-Type': AppConfig.contentType,
              'User-Agent': 'SmartSchool-Mobile/1.0',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'phone': last10,
            }),
          ).timeout(AppConfig.requestTimeout);

          if (response.statusCode == 200 && !response.body.contains('<html>')) {
            final res = jsonDecode(response.body);
            if (res['status'] == 1 || res['status'] == 200) {
              sent = true;
              message = res['message'] ?? 'OTP sent successfully to +91 $last10';
              break;
            } else {
              message = res['message'] ?? 'Failed to send OTP';
            }
          }
        } catch (_) {}
      }

      if (mounted) {
        if (sent) {
          setState(() {
            _isOtpSent = true;
            _resendCountdown = 30;
          });
          _startResendTimer();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message.isNotEmpty ? message : 'Failed to send OTP. Please check the mobile number.'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingOtp = false;
        });
      }
    }
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCountdown > 0) {
        setState(() {
          _resendCountdown--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _verifyOtpAndLogin() async {
    final phone = phoneController.text.trim();
    final otp = otpController.text.trim();

    if (otp.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the verification code sent to your phone'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final baseUrl = await UrlManager.getBaseUrl();
      if (baseUrl.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please configure your school URL first'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final endpoints = [
        '$baseUrl/api/webservice/phone_login',
        '$baseUrl/api/auth/phone_login',
      ];

      bool loggedIn = false;
      String errorMessage = 'Login failed';

      for (final endpoint in endpoints) {
        try {
          final response = await http.post(
            Uri.parse(endpoint),
            headers: {
              'Auth-Key': AppConfig.authKey,
              'Client-Service': AppConfig.clientService,
              'Content-Type': AppConfig.contentType,
              'User-Agent': 'SmartSchool-Mobile/1.0',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'phone': phone,
              'otp': otp,
              'deviceToken': await AppConfig.getDeviceToken(),
            }),
          ).timeout(AppConfig.requestTimeout);

          if (response.statusCode == 200 && !response.body.contains('<html>')) {
            final responseData = jsonDecode(response.body);
            if (responseData['status'] == 1 || responseData['status'] == 200) {
              await _handleLoginSuccess(responseData);
              loggedIn = true;
              break;
            } else {
              errorMessage = responseData['message'] ?? 'Invalid verification code';
            }
          }
        } catch (_) {}
      }

      if (!loggedIn && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _saveUserData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();

    final token = data['token'] ?? '';
    final userId = data['id'] ?? '';
    


    // Save token to both keys for compatibility
    await prefs.setString('token', token); // 'token' - for AuthService
    await prefs.setString('auth_token', token); // 'auth_token' - for AppConfig
    await prefs.setString('user_id', userId);
    await prefs.setString('role', data['role'] ?? '');
    await prefs.setBool('isLoggedIn', true);

    // CRITICAL: Save full login_data JSON for AuthService.switchChild and DashboardPage
    await prefs.setString('login_data', jsonEncode(data));

    if (data['record'] != null && data['record'] is Map) {
      final record = data['record'];
      
      await prefs.setString('student_name', record['username'] ?? '');
      await prefs.setString('email', record['email'] ?? '');
      await prefs.setString('class', record['class'] ?? '');
      await prefs.setString('image', record['image'] ?? '');
      await prefs.setString('admission_no', record['admission_no'] ?? '');
      await prefs.setString('section', record['section'] ?? '');
      await prefs.setString('student_id', record['student_id']?.toString() ?? '');
      await prefs.setString('student_session_id', record['student_session_id']?.toString() ?? '');
      
      // Save parent children if available as legacy key
      if (record['parent_childs'] != null) {
        await prefs.setString('parent_childs', jsonEncode(record['parent_childs']));
      }
    } else if (data['record'] is List) {
       // Save parent children list directly if record is a list
       await prefs.setString('parent_childs', jsonEncode(data['record']));
    }
  }

  Widget _fallbackLogo(bool isTablet) {
    return SizedBox(
      height: isTablet ? 100 : 65,
      width: isTablet ? 200 : 150,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/img_login_background.png'),
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final screenWidth = constraints.maxWidth;
                  final screenHeight = constraints.maxHeight;
                  final isLandscape = screenWidth > screenHeight;
                  // Use width-based breakpoint for tablet detection (standard Flutter/Material practice)
                  // Height should not trigger tablet layout as it squishes forms on modern tall phones
                  final isTablet = screenWidth >= 600;
                  final isTabletOrLandscape = isTablet || isLandscape;
                                   // Dynamic spacing based on device size
                  final spacingSmall = (screenHeight * 0.015).clamp(8.0, 16.0);
                  final spacingMedium = (screenHeight * 0.03).clamp(16.0, 32.0);
                  final spacingLarge = (screenHeight * 0.04).clamp(20.0, 40.0);
                  
                  // Adaptive scaling for avatar and logo
                  // Reduced scaling on tall phones to prevent vertical cramping
                  final avatarSize = isTabletOrLandscape ? 80.0 : (screenHeight * 0.09).clamp(60.0, 85.0);
                  final horizontalPadding = isTabletOrLandscape ? screenWidth * 0.15 : screenWidth * 0.06;
                  final formMaxWidth = isTabletOrLandscape ? 450.0 : screenWidth * 0.9;

                  return Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: spacingSmall,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: formMaxWidth,
                          minHeight: isTabletOrLandscape 
                              ? screenHeight - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom
                              : 0,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(height: isTabletOrLandscape ? 0 : spacingSmall),
                            _buildAvatar(avatarSize),
                            SizedBox(height: spacingSmall),
                            _buildLogoSection(constraints, isTabletOrLandscape, screenHeight),
                            SizedBox(height: spacingMedium),
                            _buildForm(constraints, isTabletOrLandscape, screenHeight),
                            SizedBox(height: isTabletOrLandscape ? 0 : spacingLarge),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              _buildBottomNav(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(double size) {
    return Center(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Icon(
          Icons.person,
          color: Colors.white.withOpacity(0.8),
          size: size * 0.5,
        ),
      ),
    );
  }

  Widget _buildLogoSection(BoxConstraints constraints, bool isTablet, double screenHeight) {
    final logoMaxHeight = isTablet ? 100.0 : (screenHeight * 0.08).clamp(40.0, 65.0);
    
    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: isTablet ? 350.0 : constraints.maxWidth * 0.65,
          maxHeight: logoMaxHeight,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: schoolLogo.isNotEmpty
              ? CachedNetworkImage(
                  key: ValueKey(schoolLogo),
                  imageUrl: schoolLogo,
                  fit: BoxFit.contain,
                  fadeInDuration: const Duration(milliseconds: 300),
                  placeholder: (context, url) => SizedBox(
                    height: logoMaxHeight,
                    width: isTablet ? 200 : constraints.maxWidth * 0.4,
                  ),
                  errorWidget: (context, url, error) => _fallbackLogo(isTablet),
                )
              : _fallbackLogo(isTablet),
        ),
      ),
    );
  }

  Widget _buildForm(BoxConstraints constraints, bool isTablet, double screenHeight) {
    final fieldSpacing = isTablet ? 24.0 : (screenHeight * 0.02).clamp(12.0, 20.0);
    final buttonSpacing = (screenHeight * 0.025).clamp(12.0, 24.0);
    
    return Column(
      children: [
        _buildTabSwitch(isTablet),
        if (_selectedTabIndex == 0) ...[
          _buildInputField(
            icon: Icons.person_outline,
            hint: 'Username',
            controller: usernameController,
            constraints: constraints,
            isTablet: isTablet,
          ),
          SizedBox(height: fieldSpacing),
          _buildInputField(
            icon: Icons.lock_outline,
            hint: 'Password',
            controller: passwordController,
            constraints: constraints,
            obscureText: _obscurePassword,
            isTablet: isTablet,
            suffix: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: const Color(0xFF666666),
                size: isTablet ? 28 : 22.0,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          SizedBox(height: fieldSpacing),
          Align(
            alignment: Alignment.centerLeft,
            child: _buildForgotPassword(constraints, isTablet),
          ),
          SizedBox(height: buttonSpacing),
          Align(
            alignment: Alignment.centerRight,
            child: _buildLoginButton(constraints, isTablet),
          ),
        ] else ...[
          _buildSmsOtpForm(constraints, isTablet, fieldSpacing, buttonSpacing),
        ],
      ],
    );
  }

  Widget _buildTabSwitch(bool isTablet) {
    final fontSize = isTablet ? 16.0 : 13.5;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withOpacity(0.25),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_selectedTabIndex != 0) {
                  setState(() {
                    _selectedTabIndex = 0;
                  });
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: _selectedTabIndex == 0
                      ? const LinearGradient(
                          colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        )
                      : null,
                  color: _selectedTabIndex == 0 ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: _selectedTabIndex == 0
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFF6B35).withOpacity(0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: isTablet ? 20 : 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Password',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: fontSize,
                        fontWeight: _selectedTabIndex == 0 ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_selectedTabIndex != 1) {
                  setState(() {
                    _selectedTabIndex = 1;
                  });
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: _selectedTabIndex == 1
                      ? const LinearGradient(
                          colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        )
                      : null,
                  color: _selectedTabIndex == 1 ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: _selectedTabIndex == 1
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFF6B35).withOpacity(0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.phone_android_outlined,
                      size: isTablet ? 20 : 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'SMS OTP',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: fontSize,
                        fontWeight: _selectedTabIndex == 1 ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmsOtpForm(BoxConstraints constraints, bool isTablet, double fieldSpacing, double buttonSpacing) {
    final fontSize = isTablet ? 17.0 : 14.0;

    return Column(
      children: [
        _buildInputField(
          icon: Icons.phone_android_outlined,
          hint: '10-digit Mobile Number',
          controller: phoneController,
          constraints: constraints,
          keyboardType: TextInputType.phone,
          enabled: !_isOtpSent,
          isTablet: isTablet,
          prefix: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Text(
              '+91 ',
              style: TextStyle(
                fontSize: isTablet ? 18.0 : 15.0,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF333333),
              ),
            ),
          ),
          suffix: _isOtpSent
              ? IconButton(
                  icon: const Icon(Icons.edit, size: 20, color: Color(0xFFFF6B35)),
                  tooltip: 'Change mobile number',
                  onPressed: () {
                    setState(() {
                      _isOtpSent = false;
                      otpController.clear();
                      _resendCountdown = 0;
                      _resendTimer?.cancel();
                    });
                  },
                )
              : null,
        ),
        SizedBox(height: fieldSpacing),
        if (!_isOtpSent) ...[
          Align(
            alignment: Alignment.centerRight,
            child: _buildSendOtpButton(constraints, isTablet),
          ),
        ] else ...[
          _buildInputField(
            icon: Icons.pin_outlined,
            hint: 'Enter 6-digit OTP',
            controller: otpController,
            constraints: constraints,
            keyboardType: TextInputType.number,
            isTablet: isTablet,
          ),
          SizedBox(height: fieldSpacing),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isOtpSent = false;
                    otpController.clear();
                    _resendCountdown = 0;
                    _resendTimer?.cancel();
                  });
                },
                child: Text(
                  'Change Number',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              _resendCountdown > 0
                  ? Text(
                      'Resend in ${_resendCountdown}s',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: fontSize,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  : GestureDetector(
                      onTap: _isSendingOtp ? null : _sendPhoneOtp,
                      child: Text(
                        'Resend OTP',
                        style: TextStyle(
                          color: const Color(0xFFFFD166),
                          fontSize: fontSize,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
            ],
          ),
          SizedBox(height: buttonSpacing),
          Align(
            alignment: Alignment.centerRight,
            child: _buildVerifyOtpButton(constraints, isTablet),
          ),
        ],
      ],
    );
  }

  Widget _buildSendOtpButton(BoxConstraints constraints, bool isTablet) {
    final fontSize = isTablet ? 20.0 : 16.0;
    final iconSize = isTablet ? 22.0 : 18.0;
    final horizontalPadding = isTablet ? 48.0 : 24.0;
    final verticalPadding = isTablet ? 18.0 : 12.0;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B35).withOpacity(0.3),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: _isSendingOtp ? null : _sendPhoneOtp,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            child: _isSendingOtp
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Send OTP',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: fontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: isTablet ? 12 : constraints.maxWidth * 0.02),
                      Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: iconSize,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerifyOtpButton(BoxConstraints constraints, bool isTablet) {
    final fontSize = isTablet ? 20.0 : 16.0;
    final iconSize = isTablet ? 22.0 : 18.0;
    final horizontalPadding = isTablet ? 48.0 : 24.0;
    final verticalPadding = isTablet ? 18.0 : 12.0;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B35).withOpacity(0.3),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: isLoading ? null : _verifyOtpAndLogin,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            child: isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Verify & Sign In',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: fontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: isTablet ? 12 : constraints.maxWidth * 0.02),
                      Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                        size: iconSize,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required IconData icon,
    required String hint,
    required TextEditingController controller,
    required BoxConstraints constraints,
    bool obscureText = false,
    Widget? suffix,
    Widget? prefix,
    bool isTablet = false,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
  }) {
    final fieldHeight = isTablet ? 65.0 : 56.0;
    final iconSize = isTablet ? 26.0 : 22.0;
    final fontSize = isTablet ? 18.0 : 15.0;
    final horizontalPadding = isTablet ? 24.0 : 20.0;
    
    return Container(
      height: fieldHeight,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      decoration: BoxDecoration(
        color: enabled ? Colors.white : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF666666), size: iconSize),
          const SizedBox(width: 12),
          if (prefix != null) prefix,
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscureText,
              keyboardType: keyboardType,
              enabled: enabled,
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                hintStyle: TextStyle(
                  color: const Color(0xFF999999),
                  fontSize: fontSize,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
              ),
              style: TextStyle(fontSize: fontSize, color: Colors.black),
            ),
          ),
          if (suffix != null) suffix,
        ],
      ),
    );
  }

  Widget _buildForgotPassword(BoxConstraints constraints, bool isTablet) {
    final fontSize = isTablet ? 17.0 : 14.0;
    final iconSize = isTablet ? 20.0 : 16.0;
    
    return GestureDetector(
      onTap: _showForgotPasswordDialog,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_rounded,
            color: const Color(0xFF666666),
            size: iconSize,
          ),
          const SizedBox(width: 6),
          Text(
            'Forgot Password?',
            style: TextStyle(
              color: Colors.black87,
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton(BoxConstraints constraints, bool isTablet) {
    final fontSize = isTablet ? 20.0 : 16.0;
    final iconSize = isTablet ? 22.0 : 18.0;
    final horizontalPadding = isTablet ? 48.0 : 24.0;
    final verticalPadding = isTablet ? 18.0 : 12.0;
    
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B35).withOpacity(0.3),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: isLoading ? null : loginUser,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            child: isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Login',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: fontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: isTablet ? 12 : constraints.maxWidth * 0.02),
                      Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                        size: iconSize,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Privacy Policy - Bottom Left, No Background
          GestureDetector(
            onTap: _launchPrivacyPolicy,
            child: const Text(
              'Privacy Policy',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          // Action Icons - Bottom Right
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (AppConfig.adminEnabled) ...[
                _buildAdminIcon(),
                const SizedBox(width: 12),
              ],
              _buildUrlIcon(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdminIcon() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.indigo,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(25),
          onTap: _launchAdminUrl,
          child: const Padding(
            padding: EdgeInsets.all(15),
            child: Icon(Icons.admin_panel_settings, color: Colors.white, size: 30),
          ),
        ),
      ),
    );
  }

  Widget _buildUrlIcon() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.8),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(25),
          onTap: () async {
            final shouldProceed = await showDialog<bool>(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Change School URL'),
                  content: const Text(
                    'This will clear the current school URL and redirect you to the URL configuration page. You will need to enter the new school URL.',
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Continue')),
                  ],
                );
              },
            );
            if (shouldProceed == true) {
              await AppConfig.clearBaseUrl();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const UrlPage()),
                (route) => false,
              );
            }
          },
          child: const Padding(
            padding: EdgeInsets.all(15),
            child: Icon(Icons.language, color: Colors.white, size: 30),
          ),
        ),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ForgotPasswordPage()),
    );
  }

  Future<void> _launchPrivacyPolicy() async {
    try {
      final baseUrl = await AppConfig.getBaseUrl();
      if (baseUrl.isNotEmpty) {
        // Ensure standard URL format
        final cleanBaseUrl = baseUrl.endsWith('/') 
            ? baseUrl.substring(0, baseUrl.length - 1) 
            : baseUrl;
            
        final Uri url = Uri.parse('$cleanBaseUrl/privacy-policy/');
        
        if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not launch Privacy Policy')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('School URL not set')),
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

  Future<void> _launchAdminUrl() async {
    String baseUrl = AppConfig.adminUrl;
    
    // If adminUrl is empty, fallback to the current school base URL
    if (baseUrl.isEmpty) {
      baseUrl = await AppConfig.getBaseUrl();
    }

    if (baseUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Admin URL not configured')),
        );
      }
      return;
    }

    try {
      // Clean base URL (remove trailing slashes)
      String cleanBase = baseUrl.trim();
      while (cleanBase.endsWith('/')) {
        cleanBase = cleanBase.substring(0, cleanBase.length - 1);
      }
      
      // Ensure it doesn't already have /site/login
      String finalUrl = cleanBase;
      if (!finalUrl.endsWith('/site/login')) {
        finalUrl = '$finalUrl/site/login';
      }

      final Uri url = Uri.parse(finalUrl);
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch Admin URL')),
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
}
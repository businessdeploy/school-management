import 'package:flutter/material.dart';
import '../services/api/auth_api.dart';
import '../config/app_config.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  String _selectedUserType = 'student'; // 'student' or 'parent'
  
  bool _isLoading = false;
  String schoolLogo = '';

  @override
  void initState() {
    super.initState();
    _loadSchoolLogo();
  }

  Future<void> _loadSchoolLogo() async {
    final logo = await AppConfig.getAppLogo();
    if (mounted) {
      setState(() {
        schoolLogo = logo;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    final email = _emailController.text.trim();
    
    // Manual validation to match login_page.dart style and avoid UI shifting
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await AuthApi.forgotPassword(
        email,
        usertype: _selectedUserType,
      );

      if (mounted) {
        if (response['status'] == 'success' || 
            response['status'] == 1 || 
            response['status'] == '1' || 
            response['status'] == 200 || 
            response['status'] == '200' || 
            response['success'] == true) {
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Password reset email sent successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          // Wait a bit then pop
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) Navigator.of(context).pop();
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Failed to send reset email'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        height: double.infinity,
        width: double.infinity,
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
                  final isTablet = screenWidth > 600 || screenHeight > 800;
                  final isTabletOrLandscape = isTablet || isLandscape;
                  
                  // Match login screen's form width and padding logic
                  final horizontalPadding = isTabletOrLandscape ? screenWidth * 0.2 : screenWidth * 0.08;
                  final formMaxWidth = isTabletOrLandscape ? 500.0 : screenWidth.clamp(340.0, 640.0);
                  
                  return Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: isTabletOrLandscape ? 8.0 : screenHeight * 0.04,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: formMaxWidth,
                          minHeight: isTabletOrLandscape 
                              ? screenHeight - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom
                              : 0,
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 120),
                              
                              _buildAvatar(),
                              
                              const SizedBox(height: 10),
                              
                              // Use BoxConstraints matching the login screen's LayoutBuilder
                              _buildLogoSection(constraints, isTabletOrLandscape),
                              
                              const SizedBox(height: 30),
                              
                              // Email Input Field
                              _buildEmailField(),
                              
                              const SizedBox(height: 25),
                              
                              // User type selector (with "I am" label)
                              _buildUserTypeSelector(),
                              
                              const SizedBox(height: 30),
                              
                              // Submit Button
                              _buildSubmitButton(),
                              
                              const SizedBox(height: 40),
                              
                              // Bottom Illustration
                              _buildBottomIllustration(screenWidth),
                              
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              // Back Button
              Positioned(
                top: 10,
                left: 10,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return const SizedBox(height: 100); // Keep spacing but remove circles
  }

  Widget _buildLogoSection(BoxConstraints constraints, bool isTablet) {
    final logoMaxHeight = isTablet ? 100.0 : 65.0; // Standardize with login screen logic
    
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

  Widget _fallbackLogo(bool isTablet) {
    return SizedBox(
      height: isTablet ? 100 : 65,
      width: isTablet ? 200 : 150,
    );
  }

  Widget _buildEmailField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(
          hintText: "Email",
          prefixIcon: Icon(Icons.email, color: Colors.black),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _buildUserTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
          child: Text(
            "I am",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.black.withOpacity(0.8),
            ),
          ),
        ),
        Row(
          children: [
            _buildUserTypeButton("Student"),
            const SizedBox(width: 20),
            _buildUserTypeButton("Parent"),
          ],
        ),
      ],
    );
  }

  Widget _buildUserTypeButton(String type) {
    bool isSelected = _selectedUserType.toLowerCase() == type.toLowerCase();
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedUserType = type.toLowerCase();
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.orange : Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
          child: Center(
            child: Text(
              type,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[600],
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        GestureDetector(
          onTap: _isLoading ? null : _sendResetEmail,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF7941D), Color(0xFFF15A24)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _isLoading 
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "SUBMIT",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                  ],
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomIllustration(double screenWidth) {
    return Container(
      width: screenWidth * 0.8,
      height: 200,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/img_forgot_password_illustration.png'), // Placeholder or actual if exists
          fit: BoxFit.contain,
        ),
      ),
      child: Center(
        child: Visibility(
          visible: true, // Show icon if image fails
          child: Icon(Icons.lock_reset, size: 100, color: Colors.blue.withOpacity(0.1)),
        ),
      ),
    );
  }
}


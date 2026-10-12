import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../utils/session_manager.dart';
import '../services/api_service.dart';
import 'login_page.dart';

class UrlPage extends StatefulWidget {
  const UrlPage({super.key});

  @override
  State<UrlPage> createState() => _UrlPageState();
}

class _UrlPageState extends State<UrlPage> {
  final TextEditingController urlController = TextEditingController();
  bool isLoading = false;
  bool isValidUrl = false;
  String validationMessage = '';

  @override
  void initState() {
    super.initState();
    // Load any existing URL if available
    _loadExistingUrl();
  }

  Future<void> _loadExistingUrl() async {
    try {
      // Check if session is active and load existing URL
      final isSessionActive = await SessionManager.isSessionActive();
      
      if (isSessionActive) {
        final existingUrl = await SessionManager.getSchoolUrl();
        if (existingUrl.isNotEmpty) {
          urlController.text = existingUrl;
          _validateUrlInput(existingUrl);
          
          
          // Show session info
          final sessionInfo = await SessionManager.getSessionInfo();
          
          
          
          
        }
      } else {
        
      }
    } catch (e) {
      
    }
  }

  void _validateUrlInput(String input) {
    String enteredUrl = input.trim();
    
    if (enteredUrl.isEmpty) {
      setState(() {
        isValidUrl = false;
        validationMessage = '';
      });
      return;
    }

    // Check if URL starts with proper protocol
    if (!enteredUrl.startsWith("http://") && !enteredUrl.startsWith("https://")) {
      setState(() {
        isValidUrl = false;
        validationMessage = 'URL must start with http:// or https://';
      });
      return;
    }

    // Validate URL format
    bool isValid = _isValidUrl(enteredUrl);
    setState(() {
      isValidUrl = isValid;
      if (isValid) {
        validationMessage = '✓ Valid URL format';
      } else {
        validationMessage = 'Please enter a valid URL format (e.g., https://your-school.com)';
      }
    });
  }

  Future<void> handleSubmit() async {
    String enteredUrl = urlController.text.trim();

    if (enteredUrl.isEmpty) {
      showError("Please enter your school URL");
      return;
    }

    // Check if URL starts with proper protocol
    if (!enteredUrl.startsWith("http://") && !enteredUrl.startsWith("https://")) {
      showError("URL must start with http:// or https://. Example: https://your-school.com");
      return;
    }

    // Validate URL format
    if (!_isValidUrl(enteredUrl)) {
      showError("Please enter a valid URL format. Example: https://your-school.com");
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Test URL connectivity first (more lenient)
      
      bool isUrlValid = await _testUrlConnectivity(enteredUrl);
      
      if (!isUrlValid) {
        
        // Don't block the process - let the user proceed and test during login
        showError("Warning: Could not verify URL connectivity. You can still proceed, but please ensure the URL is correct.");
        // Continue anyway - don't return here
      } else {
        
      }

      // Internal deployment - school registration automatically verified
      await ApiService.verifySchoolRegistration(enteredUrl);

      

      // Remove trailing slash from URL before saving (if present)
      String urlToSave = enteredUrl;
      if (urlToSave.endsWith('/')) {
        urlToSave = urlToSave.substring(0, urlToSave.length - 1);
        
      }

      // Save URL to AppConfig first (without trailing slash)
      final urlSaved = await AppConfig.setBaseUrl(urlToSave);
      if (!urlSaved) {
        showError("Failed to save URL. Please try again.");
        return;
      }
      
      
      
      // Initialize session with school URL (without trailing slash)
      final sessionInitialized = await SessionManager.initializeSession(urlToSave);
      
      if (!sessionInitialized) {
        
        // Continue anyway as URL is saved
      } else {
        
      }

      // Fetch app configuration from API
      try {
        
        final appConfig = await ApiService.getAppConfiguration();

        // Save app configuration using common config
        await AppConfig.saveAppConfiguration(appConfig);

        
        
        
        
        
        
        // Verify logo was saved
        final savedLogo = await AppConfig.getAppLogo();
        

        showSuccess("URL configured successfully! App settings loaded.");
        
        // Navigate to login page after successful URL configuration
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPageUI()),
        );
      } catch (configError) {
        
        
        
        showSuccess("URL configured successfully! You can now proceed to login.");
        
        // Navigate to login page even if app config failed
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPageUI()),
        );
      }
    } catch (e) {
      showError("Connection error. Please check the URL and try again.");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      
      // Check if URL has proper scheme
      if (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
        return false;
      }
      
      // Check if URL has a valid host (domain)
      if (uri.host.isEmpty) {
        return false;
      }
      
      // Check if host contains at least one dot (basic domain validation)
      if (!uri.host.contains('.')) {
        return false;
      }
      
      // Check if host doesn't end with a dot
      if (uri.host.endsWith('.')) {
        return false;
      }
      
      // Check if host doesn't start with a dot
      if (uri.host.startsWith('.')) {
        return false;
      }
      
      // Check for valid domain pattern (letters, numbers, dots, hyphens)
      final domainPattern = RegExp(r'^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$');
      if (!domainPattern.hasMatch(uri.host)) {
        return false;
      }
      
      // Check if port is valid (if specified)
      if (uri.port != 0 && (uri.port < 1 || uri.port > 65535)) {
        return false;
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _testUrlConnectivity(String url) async {
    try {
      
      
      // Test multiple endpoints to ensure server is reachable
      final testEndpoints = [
        '$url/api/test',
        '$url/api/webservice/test',
        '$url/app',
        '$url/api/webservice/getlessonplan', // Try a real API endpoint
        url, // Test base URL directly
      ];
      
      for (String endpoint in testEndpoints) {
        try {
          
          final uri = Uri.parse(endpoint);
          
          // Try GET request first (simpler)
          var response = await http.get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Auth-Key': AppConfig.authKey,
              'Client-Service': AppConfig.clientService,
            },
          ).timeout(Duration(seconds: 10));
          
          
          
          // If GET works, we're good
          if (response.statusCode >= 200 && response.statusCode < 600) {
            
            return true;
          }
          
          // If GET returns 405 (Method Not Allowed), try POST
          if (response.statusCode == 405) {
            
            response = await http.post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'Auth-Key': AppConfig.authKey,
                'Client-Service': AppConfig.clientService,
              },
              body: '{}', // Empty JSON body
            ).timeout(Duration(seconds: 10));
            
            
            
            if (response.statusCode >= 200 && response.statusCode < 600) {
              
              return true;
            }
          }
          
        } catch (e) {
          
          continue; // Try next endpoint
        }
      }
      
      // If all endpoints fail, try a simple ping to the base URL
      try {
        
        final uri = Uri.parse(url);
        final response = await http.get(uri).timeout(Duration(seconds: 5));
        
        
        if (response.statusCode >= 200 && response.statusCode < 600) {
          
          return true;
        }
      } catch (e) {
        
      }
      
      
      return false;
    } catch (e) {
      
      return false;
    }
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }



  @override
  void dispose() {
    urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/img_login_background.png'),
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenHeight = constraints.maxHeight;
              final screenWidth = constraints.maxWidth;
              final horizontalPadding = screenWidth * 0.06;
              
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: screenHeight - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Top spacing
                      SizedBox(height: screenHeight * 0.1),
                      
                      // Book icon just above text box
                      _buildBookIcon(),
                      SizedBox(height: screenHeight * 0.04),
                      
                      // URL input and button section
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildUrlField(),
                            const SizedBox(height: 16),
                            _buildConnectButton(),
                            const SizedBox(height: 12),
                            const Text(
                              'We will verify the provided URL and store it for future logins.',
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      
                      // Bottom spacing
                      SizedBox(height: screenHeight * 0.1),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBookIcon() {
    return SizedBox(
      width: 80,
      height: 80,
      child: Image.asset(
        'assets/images/school_logo.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          
          // Fallback to icon if image not found
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9), // Light green background
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.menu_book,
              size: 40,
              color: Color(0xFF4CAF50), // Solid green
            ),
          );
        },
      ),
    );
  }




  Widget _buildUrlField() {
    return TextField(
      controller: urlController,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        prefixIcon: const Icon(
          Icons.language,
          color: Colors.black87,
        ),
        hintText: 'https://your-school.com',
        hintStyle: TextStyle(
          color: Colors.grey[500],
          fontSize: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.done,
      onChanged: _validateUrlInput,
      style: const TextStyle(fontSize: 15, color: Colors.black87),
    );
  }
  
  Widget _buildConnectButton() {
    final isEnabled = !isLoading && isValidUrl;
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: isEnabled 
            ? const Color(0xFF4CAF50) // Green button when enabled
            : Colors.grey[300], // Grey when disabled
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isEnabled ? handleSubmit : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                const Icon(
                  Icons.arrow_forward,
                  size: 20,
                  color: Colors.white,
                ),
              const SizedBox(width: 8),
              Text(
                isLoading ? "Connecting..." : "Connect to School",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isEnabled 
                      ? Colors.white 
                      : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


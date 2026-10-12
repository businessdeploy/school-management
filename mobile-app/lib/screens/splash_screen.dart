import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';
import 'dashboard_page.dart';
import 'url_page.dart';
import '../services/auth_service.dart';
import '../config/app_config.dart';
import '../providers/app_config_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Create fade animation
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    // Start animation
    _fadeController.forward();

    // Navigate after delay
    _navigateToNextScreen();
  }

  Future<void> _navigateToNextScreen() async {
    final startTime = DateTime.now();

    try {
      // Parallelize base URL and login checks
      final results = await Future.wait([
        AppConfig.getBaseUrl(),
        AuthService.isLoggedIn(),
      ]);

      final String baseUrl = results[0] as String;
      final bool isLoggedIn = results[1] as bool;

      // Calculate remaining time to show splash for at least 1.2s for branding
      final elapsed = DateTime.now().difference(startTime);
      const minimumDisplayTime = Duration(milliseconds: 1200);
      if (elapsed < minimumDisplayTime) {
        await Future.delayed(minimumDisplayTime - elapsed);
      }

      if (!mounted) return;

      if (baseUrl.isEmpty) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const UrlPage()),
        );
      } else if (isLoggedIn) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardPage()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPageUI()),
        );
      }
    } catch (e) {
      
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const UrlPage()),
      );
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppConfigProvider>(
      builder: (context, appConfigProvider, child) {
        return Scaffold(
          body: Stack(
            children: [
              // Background image - full screen with error handling
              Positioned.fill(
                child: Image.asset(
                  'assets/images/img_login_background.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    
                    return Container(color: Colors.blue.shade50);
                  },
                ),
              ),

              // Centered logo - always show book icon
              Center(
                child: AnimatedBuilder(
                  animation: _fadeController,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: Image.asset(
                        'assets/images/splash.jpg',
                        width: 120,
                        height: 120,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          
                          return const Icon(Icons.menu_book, size: 120, color: Colors.orange);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/cbse_exam_result_page.dart';
import 'screens/splash_screen.dart';
import 'screens/url_page.dart';
import 'screens/login_page.dart';
import 'widgets/book_icon_widget.dart';
import 'utils/url_auto_config.dart';
import 'services/notification_service.dart';
import 'providers/app_config_provider.dart';
import 'providers/translation_provider.dart';
import 'screens/notification_page.dart';
import 'screens/notification_debug_page.dart';
import 'screens/notice_board_page.dart';


// Global navigator key for NotificationService
final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Firebase first (required for many services)
  try {
    await Firebase.initializeApp();
  } catch (e) {
    
  }

  // 2. Run the main app immediately to avoid white screen
  runApp(MyApp(navigatorKey: _navigatorKey));

  // 3. Initialize background services WITHOUT blocking startup
  // This ensures the UI is displayed as soon as possible
  UrlAutoConfig.ensureBaseUrl().catchError((e) => {});
  NotificationService.initialize(_navigatorKey).catchError((e) => {});
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.navigatorKey});

  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) {
            final provider = AppConfigProvider();
            provider.loadAppConfig();
            provider.loadCurrencyOptions();
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (context) {
            final provider = TranslationProvider();
            provider.initialize();
            return provider;
          },
        ),
      ],
      child: Consumer<AppConfigProvider>(
        builder: (context, appConfigProvider, child) {
          return MaterialApp(
            title: 'Prime School',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              primaryColor: appConfigProvider.primaryColorObj,
              colorScheme: ColorScheme.fromSwatch(
                primarySwatch: Colors.blue,
              ).copyWith(
                primary: appConfigProvider.primaryColorObj,
                secondary: appConfigProvider.secondaryColorObj,
              ),
              visualDensity: VisualDensity.adaptivePlatformDensity,
            ),
            navigatorKey: widget.navigatorKey,
            // Temporary SplashScreen fallback in case of errors
            home: const SplashScreen(),
            routes: {
              '/url': (context) => const UrlPage(),
              '/login': (context) => const LoginPageUI(),
              '/cbse-exam-result': (context) => const CBSEExamResultPage(),
              '/book-icon': (context) => const Scaffold(
                    body: Center(
                      child: BookIconWidget(size: 200),
                    ),
                  ),
              '/notifications': (context) => const NotificationPage(),
              '/notification_debug': (context) => const NotificationDebugPage(),
              '/notice_board': (context) => const NoticeBoardPage(),
            },
          );
        },
      ),
    );
  }
}

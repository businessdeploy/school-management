import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api/profile_api.dart';
import '../services/api/module_api.dart';
import '../widgets/translated_text.dart';
import 'package:provider/provider.dart';
import '../models/student.dart';
import '../services/auth_service.dart';
import '../widgets/app_header.dart';
import '../widgets/student_profile.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/navigation_drawer.dart';
import '../providers/app_config_provider.dart';
import 'online_exam_page.dart';
import 'daily_assignment_page.dart';
import 'student_behaviour_page.dart';
import 'my_documents_page.dart';
import 'notice_board_page.dart';
import 'notification_page.dart';
import 'fees_page.dart';
import 'timeline_page.dart';
import 'library_page.dart';
import 'hostel_page.dart';
import 'transport_routes_page.dart';
import 'leave_list_page.dart';
import 'timetable_page.dart';
import 'visitor_book_page.dart';
import 'homework_page.dart';
import 'lesson_page.dart';
import 'zoom_live_classes_page.dart';
import 'gmeet_live_classes_page.dart';
import 'download_center_page.dart';
import 'online_course_page.dart';
import 'syllabus_status_page.dart';
import 'attendance_page.dart';
import 'pending_tasks_page.dart';
import 'teacher_review_page.dart';
import 'examination_page.dart';
import 'cbse_exam_result_page.dart';
import 'settings_page.dart';
import 'profile_page.dart';
import 'about_school_page.dart';
import 'login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../config/app_config.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<Student> students = [];
  Student? selectedStudent;
  bool isLoading = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _unreadNotifications = 0;
  Map<String, bool> _modulePermissions = {};

  @override
  void initState() {
    super.initState();
    _initDashboard();
  }

  Future<void> _initDashboard() async {
    // 1. Load cached permissions immediately for instant UI filtering
    await _loadCachedPermissions();

    // 2. Load students (local/fast) first to show the profile immediately
    await _loadStudents();
    
    // 3. Sync live permissions from Web Admin Panel in background
    _syncModulePermissions();

    // 4. Load unread notifications in the background (non-blocking)
    _loadUnreadNotifications();
  }

  Future<void> _loadCachedPermissions() async {
    final cached = await ModuleApi.getCachedPermissions();
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _modulePermissions = cached;
      });
    }
  }

  Future<void> _syncModulePermissions() async {
    try {
      final perms = await ModuleApi.getModulePermissions();
      if (perms.isNotEmpty && mounted) {
        setState(() {
          _modulePermissions = perms;
        });
      }
    } catch (_) {}
  }

  bool _isItemEnabled(DashboardItem item) {
    if (item.shortCode == null || item.shortCode!.isEmpty) return true;
    if (_modulePermissions.isNotEmpty) {
      return _modulePermissions[item.shortCode] == true;
    }
    return true;
  }


  Future<void> _loadStudents() async {
    try {
      setState(() {
        isLoading = true;
      });

      // Get student data from login session (stored in SharedPreferences)
      final prefs = await SharedPreferences.getInstance();
      final loginDataStr = prefs.getString('login_data');
      
      Student? loadedStudent;

      if (loginDataStr != null && loginDataStr.isNotEmpty) {
        try {
          final loginData = jsonDecode(loginDataStr);
          if (loginData['record'] != null) {
            loadedStudent = Student.fromJson(loginData['record']);
          }
        } catch (e) {
        }
      }

      // Fallback to individual keys if full data unavailable or failed
      if (loadedStudent == null) {
        final id = prefs.getString('student_id') ?? '';
        final firstName = prefs.getString('student_name') ?? 'Student';
        final className = prefs.getString('class') ?? 'N/A';
        final sectionName = prefs.getString('section') ?? 'N/A';
        final admissionNo = prefs.getString('admission_no') ?? 'N/A';
        final image = prefs.getString('image') ?? '';

        if (id.isNotEmpty) {
          loadedStudent = Student(
            id: id,
            parentId: prefs.getString('parent_id') ?? '',
            admissionNo: admissionNo,
            rollNo: prefs.getString('roll_no') ?? '',
            admissionDate: prefs.getString('admission_date') ?? '',
            firstname: firstName,
            lastname: '',
            rte: prefs.getString('rte') ?? 'No',
            image: image,
            mobileno: prefs.getString('mobile_no') ?? '',
            email: prefs.getString('email') ?? '',
            religion: prefs.getString('religion') ?? '',
            cast: prefs.getString('cast') ?? '',
            dob: prefs.getString('dob') ?? '',
            gender: prefs.getString('gender') ?? '',
            currentAddress: prefs.getString('current_address') ?? '',
            permanentAddress: prefs.getString('permanent_address') ?? '',
            categoryId: prefs.getString('category_id') ?? '',
            schoolHouseId: prefs.getString('school_house_id') ?? '',
            bloodGroup: prefs.getString('blood_group') ?? '',
            hostelRoomId: prefs.getString('hostel_room_id') ?? '',
            adharNo: prefs.getString('adhar_no') ?? '',
            samagraId: prefs.getString('samagra_id') ?? '',
            bankAccountNo: prefs.getString('bank_account_no') ?? '',
            bankName: prefs.getString('bank_name') ?? '',
            ifscCode: prefs.getString('ifsc_code') ?? '',
            guardianIs: prefs.getString('guardian_is') ?? '',
            fatherName: prefs.getString('father_name') ?? '',
            fatherPhone: prefs.getString('father_phone') ?? '',
            fatherOccupation: prefs.getString('father_occupation') ?? '',
            motherName: prefs.getString('mother_name') ?? '',
            motherPhone: prefs.getString('mother_phone') ?? '',
            motherOccupation: prefs.getString('mother_occupation') ?? '',
            guardianName: prefs.getString('guardian_name') ?? '',
            guardianRelation: prefs.getString('guardian_relation') ?? '',
            guardianPhone: prefs.getString('guardian_phone') ?? '',
            guardianOccupation: prefs.getString('guardian_occupation') ?? '',
            guardianAddress: prefs.getString('guardian_address') ?? '',
            guardianEmail: prefs.getString('guardian_email') ?? '',
            fatherPic: prefs.getString('father_pic') ?? '',
            motherPic: prefs.getString('mother_pic') ?? '',
            guardianPic: prefs.getString('guardian_pic') ?? '',
            isActive: 'yes',
            previousSchool: '',
            height: '',
            weight: '',
            measurementDate: '',
            disReason: '',
            note: '',
            disNote: '',
            about: prefs.getString('about') ?? '',
            designation: prefs.getString('designation') ?? 'Student',
            appKey: '',
            parentAppKey: '',
            createdBy: '',
            createdAt: '',
            updatedAt: '',
            classId: prefs.getString('class_id') ?? '',
            className: className,
            sectionId: prefs.getString('section_id') ?? '',
            section: sectionName,
            studentSessionId: prefs.getString('student_session_id') ?? '',
          );
        }
      }

      if (mounted) {
        setState(() {
          students = loadedStudent != null ? [loadedStudent] : [];
          selectedStudent = loadedStudent;
          isLoading = false;
        });

        // Fetch fresh profile data in background if we have a student
        if (loadedStudent != null) {
          _fetchProfileInBackground();
        }

        if (loadedStudent == null) {
          // If no login data, show error
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: TranslatedText('No student data found. Please login again.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: TranslatedText('Error loading student data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _fetchProfileInBackground() async {
    try {
      final profileData = await ProfileApi.getUserProfile();
      if (profileData['student_result'] != null) {
        final studentData = profileData['student_result'];
        final updatedStudent = Student.fromJson(studentData);
        
        final prefs = await SharedPreferences.getInstance();
        // Update login_data with fresh record
        final loginDataStr = prefs.getString('login_data');
        if (loginDataStr != null) {
          try {
            final loginData = jsonDecode(loginDataStr);
            loginData['record'] = studentData;
            await prefs.setString('login_data', jsonEncode(loginData));
          } catch (e) {
          }
        }

        if (mounted) {
          setState(() {
            students = [updatedStudent];
            selectedStudent = updatedStudent;
          });
        }
      }
    } catch (e) {
    }
  }

  Future<void> _loadUnreadNotifications() async {
    try {
      final response = await ApiService.getNoticeBoard();

      List<dynamic> items = [];
      if (response['data'] != null && response['data'] is List) {
        items = response['data'];
      } else if (response['notices'] != null && response['notices'] is List) {
        items = response['notices'];
      } else if (response['notice_board'] != null &&
          response['notice_board'] is List) {
        items = response['notice_board'];
      } else if (response['announcements'] != null &&
          response['announcements'] is List) {
        items = response['announcements'];
      }

      int unread = 0;
      for (final item in items) {
        if (item is Map<String, dynamic>) {
          final raw = (item['is_read'] ??
                  item['read'] ??
                  item['is_viewed'] ??
                  item['view_status'])
              ?.toString()
              .trim()
              .toLowerCase();

          // Consider unread when flag is missing or explicitly 0/false
          if (raw == null ||
              raw.isEmpty ||
              raw == '0' ||
              raw == 'false' ||
              raw == 'no') {
            unread++;
          }
        }
      }

      if (mounted) {
        setState(() {
          _unreadNotifications = unread;
        });
      }
    } catch (e) {
    }
  }

  Future<void> _verifyAndNavigate({
    required String addonType,
    required Widget page,
  }) async {
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => page),
      );
    }
  }

  void _onMenuTap() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void _onNotificationTap() {
    // Open the new Notification Page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NotificationPage(),
      ),
    );
  }

  Future<void> _onDrawerItemTap(String item) async {
    Navigator.pop(context); // Close drawer

    switch (item) {
      case 'home':
        // Already on home
        break;
      case 'profile':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ProfilePage()),
        );
        break;
      case 'settings':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SettingsPage()),
        );
        break;
      case 'about':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AboutSchoolPage()),
        );
        break;
      case 'logout':
        // Clear session using centralized logout that preserves branding
        await AuthService.logout();
        
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginPageUI()),
            (route) => false,
          );
        }
        break;
    }
  }

  List<DashboardItem> _getElearningItems() {
    final items = [
      DashboardItem(
        title: 'Homework',
        shortCode: 'homework',
        imagePath: 'assets/images/ic_dashboard_homework.png',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const HomeworkPage()),
        ),
      ),
      DashboardItem(
        title: 'Daily Assignment',
        shortCode: 'daily_assignment',
        imagePath: 'assets/images/assignment.png',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const DailyAssignmentPage()),
        ),
      ),
      DashboardItem(
        title: 'Lesson Plan',
        shortCode: 'lesson_plan',
        imagePath: 'assets/images/lesson plan.png',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LessonPage()),
        ),
      ),
      DashboardItem(
        title: 'Online Exam',
        shortCode: 'online_examination',
        imagePath: 'assets/images/online-test.png',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const OnlineExamPage()),
        ),
      ),
      DashboardItem(
        title: 'Download Center',
        shortCode: 'download_center',
        imagePath: 'assets/images/ic_nav_download.png',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const DownloadCenterPage()),
        ),
      ),
      DashboardItem(
        title: 'Online Course',
        shortCode: 'online_course',
        imagePath: 'assets/images/online-course.png',
        onTap: () => _verifyAndNavigate(
          addonType: 'ssoclc',
          page: const OnlineCoursePage(),
        ),
      ),
      DashboardItem(
        title: 'Zoom Live Classes',
        shortCode: 'live_classes',
        imagePath: 'assets/images/zoom-icon.png',
        onTap: () => _verifyAndNavigate(
          addonType: 'sszlc',
          page: const ZoomLiveClassesPage(),
        ),
      ),
      DashboardItem(
        title: 'Gmeet Live Classes',
        shortCode: 'gmeet_live_classes',
        imagePath: 'assets/images/google_meet.png',
        onTap: () => _verifyAndNavigate(
          addonType: 'ssglc',
          page: const GmeetLiveClassesPage(),
        ),
      ),
    ];
    return items.where(_isItemEnabled).toList();
  }

  List<DashboardItem> _getAcademicsItems() {
    final items = [
      DashboardItem(
        title: 'Class Timetable',
        shortCode: 'class_timetable',
        imagePath: 'assets/images/study-time.png',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const TimetablePage()),
        ),
      ),
      DashboardItem(
        title: 'Syllabus Status',
        shortCode: 'syllabus_status',
        imagePath: 'assets/images/syllabus.png',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SyllabusStatusPage()),
        ),
      ),
      DashboardItem(
        title: 'Attendance',
        shortCode: 'attendance',
        imagePath: 'assets/images/ic_dashboard_attendance.png',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AttendancePage()),
        ),
      ),
      DashboardItem(
        title: 'Student Timeline',
        shortCode: 'student_timeline',
        imagePath: 'assets/images/timeline.png',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const TimelinePage()),
        ),
      ),
      DashboardItem(
        title: 'Behaviour Records',
        shortCode: 'behaviour_records',
        imagePath: 'assets/images/pending-tasks.png',
        onTap: () => _verifyAndNavigate(
          addonType: 'ssbr',
          page: const StudentBehaviourPage(),
        ),
      ),
      DashboardItem(
        title: 'Teacher Review',
        shortCode: 'teachers_rating',
        imagePath: 'assets/images/teacher review.png',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const TeacherReviewPage()),
        ),
      ),
      DashboardItem(
        title: 'Examination',
        shortCode: 'examinations',
        imagePath: 'assets/images/ic_nav_examination.png',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ExaminationPage()),
        ),
      ),
      DashboardItem(
        title: 'CBSE Examination',
        shortCode: 'cbseexam',
        imagePath: 'assets/images/online-test.png',
        onTap: () => _verifyAndNavigate(
          addonType: 'sscbse',
          page: const CBSEExamResultPage(),
        ),
      ),
      DashboardItem(
        title: 'My Documents',
        shortCode: 'mydocuments',
        imagePath: 'assets/images/documentation.png',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MyDocumentsPage()),
        ),
      ),
    ];
    return items.where(_isItemEnabled).toList();
  }

  List<DashboardItem> _getCommunicateItems() {
    final items = [
      DashboardItem(
        title: 'Notice Board',
        shortCode: 'notice_board',
        imagePath: 'assets/images/ic_notice.png',
        imageSize: 30, // Reduced size for visual consistency
        icon: Icons.notifications,
        iconColor: Colors.blue.shade100,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const NoticeBoardPage()),
        ),
      ),
    ];
    return items.where(_isItemEnabled).toList();
  }

  List<DashboardItem> _getOthersItems() {
    final items = [
      DashboardItem(
        title: 'Fees',
        shortCode: 'fees',
        imagePath: 'assets/images/fee.png',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const FeesPage()),
        ),
      ),
      DashboardItem(
        title: 'Apply Leave',
        shortCode: 'apply_leave',
        imagePath: 'assets/images/leave.png',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LeaveListPage()),
        ),
      ),
      DashboardItem(
        title: 'Visitor Book',
        shortCode: 'visitor_book',
        imagePath: 'assets/images/ic_visitors.png',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const VisitorBookPage()),
        ),
      ),
      DashboardItem(
        title: 'Transport Routes',
        shortCode: 'transport_routes',
        imagePath: 'assets/images/transport.png',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const TransportRoutesPage()),
        ),
      ),
      DashboardItem(
        title: 'Hostel Rooms',
        shortCode: 'hostel_rooms',
        imagePath: 'assets/images/hostel.png',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const HostelPage()),
        ),
      ),
      DashboardItem(
        title: 'Calendar To Do List',
        shortCode: 'calendar_to_do_list',
        imagePath: 'assets/images/pending-tasks.png',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PendingTasksPage()),
        ),
      ),
      DashboardItem(
        title: 'Library',
        shortCode: 'library',
        imagePath: 'assets/images/ic_library.png',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LibraryPage()),
        ),
      ),
    ];
    return items.where(_isItemEnabled).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppConfigProvider>(
      builder: (context, appConfigProvider, child) {
        if (isLoading) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (selectedStudent == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const TranslatedText(
                    'No student data available',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadStudents,
                    child: const TranslatedText('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: const Color(0xFFF5F8F5), // Light minty/grey background from image
      drawer: AppNavigationDrawer(
        student: selectedStudent!,
        onHomeTap: () => _onDrawerItemTap('home'),
        onProfileTap: () => _onDrawerItemTap('profile'),
        onSettingsTap: () => _onDrawerItemTap('settings'),
        onAboutTap: () => _onDrawerItemTap('about'),
        onLogoutTap: () => _onDrawerItemTap('logout'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // App Header
            Container(
              color: Colors.white,
              child: AppHeader(
                onMenuTap: _onMenuTap,
                onNotificationTap: _onNotificationTap,
                unreadCount: _unreadNotifications,
              ),
            ),

            // Main Content
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  children: [
                    // Student Profile Section
                    StudentProfile(student: selectedStudent!),

                    // E-Learning Section
                    if (_getElearningItems().isNotEmpty)
                      DashboardCard(
                        title: 'E-Learning',
                        items: _getElearningItems(),
                      ),

                    // Academics Section
                    if (_getAcademicsItems().isNotEmpty)
                      DashboardCard(
                        title: 'Academics',
                        items: _getAcademicsItems(),
                      ),

                    // Communicate Section
                    if (_getCommunicateItems().isNotEmpty)
                      DashboardCard(
                        title: 'Communicate',
                        items: _getCommunicateItems(),
                      ),

                    // Others Section
                    if (_getOthersItems().isNotEmpty)
                      DashboardCard(
                        title: 'Others',
                        items: _getOthersItems(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
      },
    );
  }
}

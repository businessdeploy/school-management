import 'package:flutter/material.dart';
import 'translated_text.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/student.dart';
import '../services/api_service.dart';
import '../providers/app_config_provider.dart';
import 'package:provider/provider.dart';
import 'child_selection_dialog.dart';
import '../services/auth_service.dart';
import '../screens/dashboard_page.dart';

class AppNavigationDrawer extends StatelessWidget {
  final Student student;
  final VoidCallback? onHomeTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onAboutTap;
  final VoidCallback? onLogoutTap;

  const AppNavigationDrawer({
    super.key,
    required this.student,
    this.onHomeTap,
    this.onProfileTap,
    this.onSettingsTap,
    this.onAboutTap,
    this.onLogoutTap,
  });

  @override
  Widget build(BuildContext context) {
    final appConfigProvider = Provider.of<AppConfigProvider>(context);
    final primaryColor = appConfigProvider.primaryColorObj;
    final secondaryColor = appConfigProvider.secondaryColorObj;

    return Drawer(
      child: Column(
        children: [
          // Header with student profile
          Container(
            decoration: BoxDecoration(color: secondaryColor.withOpacity(0.3)),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Student Image
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primaryColor.withOpacity(0.1),
                        border: Border.all(color: primaryColor.withOpacity(0.2), width: 1),
                      ),
                      child: student.image != null && student.image!.isNotEmpty
                          ? ClipOval(
                              child: FutureBuilder<String>(
                                future: ApiService.getImageUrl(student.image ?? ''),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData) {
                                    return CachedNetworkImage(
                                      imageUrl: snapshot.data!,
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        color: primaryColor.withOpacity(0.1),
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            color: primaryColor,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        color: primaryColor.withOpacity(0.1),
                                        child: Icon(
                                          Icons.person,
                                          size: 20,
                                          color: primaryColor,
                                        ),
                                      ),
                                    );
                                  } else {
                                    return Container(
                                      color: primaryColor.withOpacity(0.1),
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          color: primaryColor,
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            )
                          : Icon(Icons.person, size: 30, color: primaryColor),
                    ),
                    const SizedBox(width: 16),
                    // Student Information
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              student.fullName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Flexible(
                            child: Text(
                              student.classSection,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Switch Child Button for Parents
                          FutureBuilder<List<dynamic>>(
                            future: Future.wait([
                              AuthService.getParentChilds(),
                              AuthService.getUserRole(),
                            ]),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                final List<Map<String, dynamic>> children = snapshot.data![0] as List<Map<String, dynamic>>;
                                final String? role = snapshot.data![1] as String?;

                                if (role == 'parent' && children.length > 1) {
                                  return InkWell(
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => ChildSelectionDialog(
                                          children: children,
                                          onChildSelected: (child) async {
                                            Navigator.pop(context); // Close dialog
                                            Navigator.pop(context); // Close drawer
                                            await AuthService.switchChild(child);
                                            // Refresh Dashboard
                                            Navigator.pushReplacement(
                                              context,
                                              MaterialPageRoute(builder: (context) => const DashboardPage()),
                                            );
                                          },
                                        ),
                                      );
                                    },
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TranslatedText(
                                          'Switch Child',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: primaryColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(Icons.swap_horiz, size: 14, color: primaryColor),
                                      ],
                                    ),
                                  );
                                }
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Navigation Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  icon: Icons.home,
                  title: 'Home',
                  onTap: onHomeTap,
                  selectedColor: primaryColor,
                ),
                _buildDrawerItem(
                  icon: Icons.person,
                  title: 'Profile',
                  onTap: onProfileTap,
                  selectedColor: primaryColor,
                ),
                _buildDrawerItem(
                  icon: Icons.settings,
                  title: 'Settings',
                  onTap: onSettingsTap,
                  selectedColor: primaryColor,
                ),
                _buildDrawerItem(
                  icon: Icons.info_outline,
                  title: 'About School',
                  onTap: onAboutTap,
                  selectedColor: primaryColor,
                ),
                _buildDrawerItem(
                  icon: Icons.logout,
                  title: 'Logout',
                  onTap: onLogoutTap,
                  selectedColor: Colors.red,
                ),
              ],
            ),
          ),
          // Version Info
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            width: double.infinity,
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                const Text(
                  'Mobile Version: 5.0',
                  style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w500),
                ),
                if (appConfigProvider.appVersion.isNotEmpty) ...[
                  const Text(
                    '|',
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  Text(
                    'School Version: ${appConfigProvider.appVersion}',
                    style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    VoidCallback? onTap,
    Color? selectedColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: selectedColor ?? Colors.black87, size: 24),
      title: TranslatedText(
        title,
        style: TextStyle(
          color: selectedColor ?? Colors.black87,
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
      ),
      onTap: onTap,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      visualDensity: const VisualDensity(vertical: -2),
    );
  }
}

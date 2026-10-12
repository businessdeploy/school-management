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

class StudentProfile extends StatelessWidget {
  final Student student;

  const StudentProfile({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    Provider.of<AppConfigProvider>(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Student Image with Online Indicator
          Stack(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.grey[200],
                ),
                child: student.image != null && student.image!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: FutureBuilder<String>(
                          future: ApiService.getImageUrl(student.image ?? ''),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return CachedNetworkImage(
                                imageUrl: snapshot.data!,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.blue,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.grey[200],
                                  child: const Icon(
                                    Icons.person,
                                    size: 40,
                                    color: Colors.grey,
                                  ),
                                ),
                              );
                            } else {
                              return Container(
                                color: Colors.grey[200],
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.blue,
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      )
                    : const Icon(Icons.person, size: 40, color: Colors.grey),
              ),
              // Online Indicator
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          // Student Information
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Student Name
                Text(
                  student.fullName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                // Admission Number
                Text(
                  'Admission No. ${student.admissionNo}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 6),
                // Class Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${student.className} (${student.section})',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Switch Child Button for Parents (if applicable)
          FutureBuilder<List<dynamic>>(
            future: Future.wait([
              AuthService.getParentChilds(),
              AuthService.getUserRole(),
            ]),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final List<Map<String, dynamic>> children =
                    snapshot.data![0] as List<Map<String, dynamic>>;
                final String? role = snapshot.data![1] as String?;

                if (role == 'parent' && children.length > 1) {
                  return IconButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => ChildSelectionDialog(
                          children: children,
                          onChildSelected: (child) async {
                            Navigator.pop(context);
                            await AuthService.switchChild(child);
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const DashboardPage()),
                            );
                          },
                        ),
                      );
                    },
                    icon: Icon(Icons.swap_horiz,
                        color: Colors.grey[700], size: 22),
                    tooltip: 'Switch Child',
                  );
                }
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}

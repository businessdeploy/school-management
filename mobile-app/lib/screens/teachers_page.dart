import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/url_manager.dart';
import '../widgets/enterprise_ui_components.dart';

class TeachersPage extends StatefulWidget {
  const TeachersPage({super.key});

  @override
  State<TeachersPage> createState() => _TeachersPageState();
}

class _TeachersPageState extends State<TeachersPage> {
  List<Map<String, dynamic>> teachers = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadTeachers();
  }

  Future<void> loadTeachers() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final studentId = await AuthService.getStudentId();
      if (studentId.isEmpty) {
        throw Exception('No student ID found. Please login again.');
      }
      
      
      
      final classId = await AuthService.getClassId();
      final sectionId = await AuthService.getSectionId();
      final userId = await AuthService.getUserId();
      if (userId == null || userId.isEmpty) {
        throw Exception('No user ID found. Please login again.');
      }
      final data = await ApiService.getTeachersList(classId, sectionId, userId);
      
      if (!mounted) return;
      
      setState(() {
        teachers = data['teachers'] != null 
            ? List<Map<String, dynamic>>.from(data['teachers'])
            : [];
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        errorMessage = 'Failed to load teachers. Please try again.';
        teachers = [];
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teachers'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading data',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        errorMessage!,
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: loadTeachers,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (teachers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No teachers found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        EnterpriseUIComponents.buildHeaderWithIllustration(
          title: 'Teachers',
          subtitle: 'Learn and connect with your teachers',
          illustration: const Icon(
            Icons.people,
            size: 60,
            color: Colors.blue,
          ),
        ),
        // Teachers list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: teachers.length,
            itemBuilder: (context, index) {
              final teacher = teachers[index];
              return _buildTeacherCard(teacher);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTeacherCard(Map<String, dynamic> teacher) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FutureBuilder<String>(
                  future: teacher['image'] != null && teacher['image'].toString().isNotEmpty && !teacher['image'].toString().contains('default')
                      ? UrlManager.getSiteAsset('uploads/teacher_image/${teacher['image']}')
                      : Future.value('assets/images/default_female.jpg'),
                  builder: (context, snapshot) {
                    return CircleAvatar(
                      radius: 30,
                      backgroundImage: snapshot.hasData 
                          ? (snapshot.data!.startsWith('http') 
                              ? NetworkImage(snapshot.data!) 
                              : AssetImage(snapshot.data!) as ImageProvider)
                          : const AssetImage('assets/images/default_female.jpg'),
                      onBackgroundImageError: (exception, stackTrace) {
                        // Handle image loading error
                      },
                      child: teacher['image'] == null || teacher['image'].toString().contains('default')
                          ? Text(
                              teacher['name']?.toString().substring(0, 1).toUpperCase() ?? 'T',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    );
                  },
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teacher['name'] ?? 'Unknown Teacher',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        teacher['subject'] ?? 'Subject Not Specified',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.school, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            teacher['qualification'] ?? 'Qualification not specified',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Contact Information
            _buildInfoSection('Contact Information', [
              _buildInfoRow('Email', teacher['email'] ?? 'Not provided'),
              _buildInfoRow('Phone', teacher['phone'] ?? 'Not provided'),
            ]),
            
            const SizedBox(height: 12),
            
            // Professional Information
            _buildInfoSection('Professional Information', [
              _buildInfoRow('Experience', teacher['experience'] ?? 'Not specified'),
              _buildInfoRow('Office Hours', teacher['office_hours'] ?? 'Not specified'),
              _buildInfoRow('Room', teacher['room'] ?? 'Not specified'),
            ]),
            
            const SizedBox(height: 12),
            
            // Bio
            if (teacher['bio'] != null && teacher['bio'].toString().isNotEmpty)
              _buildInfoSection('About', [
                Text(
                  teacher['bio'],
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ]),
            
            const SizedBox(height: 12),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _showContactDialog(teacher);
                    },
                    icon: const Icon(Icons.email, size: 16),
                    label: const Text('Contact'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _showTeacherDetails(teacher);
                    },
                    icon: const Icon(Icons.info, size: 16),
                    label: const Text('Details'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  void _showContactDialog(Map<String, dynamic> teacher) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Contact ${teacher['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (teacher['email'] != null)
              ListTile(
                leading: const Icon(Icons.email, color: Colors.blue),
                title: const Text('Email'),
                subtitle: Text(teacher['email']),
                onTap: () {
                  // TODO: Implement email functionality
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Email: ${teacher['email']}')),
                  );
                  Navigator.pop(context);
                },
              ),
            if (teacher['phone'] != null)
              ListTile(
                leading: const Icon(Icons.phone, color: Colors.green),
                title: const Text('Phone'),
                subtitle: Text(teacher['phone']),
                onTap: () {
                  // TODO: Implement phone functionality
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Phone: ${teacher['phone']}')),
                  );
                  Navigator.pop(context);
                },
              ),
            ListTile(
              leading: const Icon(Icons.schedule, color: Colors.orange),
              title: const Text('Office Hours'),
              subtitle: Text(teacher['office_hours'] ?? 'Not specified'),
            ),
            ListTile(
              leading: const Icon(Icons.room, color: Colors.purple),
              title: const Text('Room'),
              subtitle: Text(teacher['room'] ?? 'Not specified'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTeacherDetails(Map<String, dynamic> teacher) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${teacher['name']} - Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (teacher['bio'] != null && teacher['bio'].toString().isNotEmpty) ...[
                Text(
                  'About',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(teacher['bio']),
                const SizedBox(height: 16),
              ],
              Text(
                'Professional Information',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _buildInfoRow('Subject', teacher['subject'] ?? 'Not specified'),
              _buildInfoRow('Qualification', teacher['qualification'] ?? 'Not specified'),
              _buildInfoRow('Experience', teacher['experience'] ?? 'Not specified'),
              _buildInfoRow('Office Hours', teacher['office_hours'] ?? 'Not specified'),
              _buildInfoRow('Room', teacher['room'] ?? 'Not specified'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
} 

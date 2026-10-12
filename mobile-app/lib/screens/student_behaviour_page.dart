import 'package:flutter/material.dart';
import '../models/behaviour.dart';
import '../services/api/student_behaviour_api.dart';
import '../services/auth_service.dart';
import 'behaviour_comments_page.dart';
import '../widgets/translated_text.dart';
import '../widgets/enterprise_ui_components.dart';

class StudentBehaviourPage extends StatefulWidget {
  const StudentBehaviourPage({super.key});

  @override
  State<StudentBehaviourPage> createState() => _StudentBehaviourPageState();
}

class _StudentBehaviourPageState extends State<StudentBehaviourPage> {
  List<BehaviourRecord> behaviourRecords = [];
  String behaviourScore = '0';
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadBehaviourData();
  }

  Future<void> _loadBehaviourData() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final studentId = await AuthService.getStudentId();
      if (studentId.isEmpty) {
        throw Exception('No student ID found. Please login again.');
      }
      

      final behaviourData = await StudentBehaviourApi.getStudentBehaviour(
        studentId,
      );

      
      
      
      

      // Check both 'behaviour' (mapped) and 'assigned_incident' (original API key)
      List<dynamic>? incidents = behaviourData['behaviour'] as List<dynamic>?;
      if (incidents == null || incidents.isEmpty) {
        incidents = behaviourData['assigned_incident'] as List<dynamic>?;
        
      } else {
        
      }

      if (incidents != null && incidents.isNotEmpty) {
        
      }

      setState(() {
        behaviourScore = behaviourData['behaviour_score']?.toString() ?? '0';
        behaviourRecords = (incidents ?? []).map((incident) {
          try {
            return BehaviourRecord.fromJson(incident);
          } catch (e) {
            
            
            rethrow;
          }
        }).toList();
        isLoading = false;
      });

      
    } catch (e) {
      
      
      setState(() {
        isLoading = false;
        error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const TranslatedText(
          'Student Behaviour',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.grey[800],
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Main white card
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
              child: Column(
                children: [
                  EnterpriseUIComponents.buildHeaderWithIllustration(
                    title: 'Behaviour Records',
                    subtitle: 'Review student conduct and feedback',
                    illustration: Image.asset(
                      'assets/images/behaviour.jpg',
                      fit: BoxFit.contain,
                    ),
                  ),

                  // Behaviour records list
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : error != null && behaviourRecords.isEmpty
                            ? Center(
                                child: TranslatedText(
                                  'Error loading behaviour records: $error',
                                  style: const TextStyle(color: Colors.red),
                                ),
                              )
                            : behaviourRecords.isEmpty
                                ? const Center(
                                    child: TranslatedText(
                                      'No behaviour records available',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  )
                                : _buildBehaviourRecordsList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBehaviourIllustration() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Image.asset(
          "assets/images/pending-tasks.png",
          width: 60,
          height: 60,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.person, color: Colors.blue, size: 30),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBehaviourRecordsList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: behaviourRecords.length,
      itemBuilder: (context, index) {
        final record = behaviourRecords[index];
        return _buildBehaviourRecordCard(record);
      },
    );
  }

  Widget _buildBehaviourRecordCard(BehaviourRecord record) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with title and comment count
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.green[50], // Light green background
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                // Title
                Expanded(
                  child: TranslatedText(
                    record.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ),
                // Comment count
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                        Text(
                          record.commentCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Content section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date
                _buildDetailRow('Date', record.formattedDate),
                const SizedBox(height: 8),
                // Point
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 100,
                      child: const Text(
                        'Point:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        record.point,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: record.isPositive
                              ? Colors.green[600]
                              : Colors.red[600],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Description
                _buildDetailRow('Description', record.description),
                const SizedBox(height: 8),
                // Assigned By
                _buildDetailRow('Assigned By', record.assignedBy),
                const SizedBox(height: 12),
                // Comments button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BehaviourCommentsPage(
                            incidentId: record.id,
                            incidentTitle: record.title,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const TranslatedText('View Comments'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: TranslatedText(
            '$label:',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ),
      ],
    );
  }
}

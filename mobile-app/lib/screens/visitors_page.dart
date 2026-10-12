import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class VisitorsPage extends StatefulWidget {
  const VisitorsPage({super.key});

  @override
  State<VisitorsPage> createState() => _VisitorsPageState();
}

class _VisitorsPageState extends State<VisitorsPage> {
  List<Map<String, dynamic>> visitors = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadVisitors();
  }

  Future<void> loadVisitors() async {
    try {
      // Get dynamic student ID from authentication service
      final studentId = await AuthService.getStudentId();

      final data = await ApiService.getVisitors(studentId);
      
      if (!mounted) return;
      
      if (data['result'] != null) {
        setState(() {
          visitors = List<Map<String, dynamic>>.from(data['result']);
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'No visitors found';
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        errorMessage = 'Error loading visitors: $e';
        isLoading = false;
      });
    }
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      DateTime? date;
      try {
        date = DateTime.parse(dateStr);
      } catch (_) {}
      
      if (date == null) {
        try {
          date = DateFormat('MM/dd/yyyy').parse(dateStr);
        } catch (_) {}
      }
      
      if (date != null) {
        return DateFormat('MM/dd/yyyy').format(date);
      }
    } catch (e) {
      
    }
    return dateStr;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visitor Book', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.grey[900],
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : errorMessage != null
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        margin: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              errorMessage!,
                              style: TextStyle(color: Colors.grey[600], fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: loadVisitors,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : visitors.isEmpty
                      ? Center(
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            margin: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.95),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  'No visitors found',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: visitors.length,
                          itemBuilder: (context, index) {
                            final visitor = visitors[index];
                            return _buildVisitorCard(visitor);
                          },
                        ),
      ),
    );
  }

  Widget _buildVisitorCard(Map<String, dynamic> visitor) {
    final name = visitor['name'] ?? 'Unknown';
    final purpose = visitor['purpose'] ?? 'Unknown Purpose';
    final contact = visitor['contact'] ?? 'N/A';
    final date = visitor['date'] ?? '';
    final inTime = visitor['in_time'] ?? '';
    final outTime = visitor['out_time'] ?? '';
    final noOfPeople = visitor['no_of_people'] ?? '1';
    final idProof = visitor['id_proof'] ?? 'N/A';
    final meetingWith = visitor['meeting_with'] ?? 'N/A';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with name and purpose
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    purpose,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Details
            _buildDetailRow('Contact', contact),
            _buildDetailRow('Date', _formatDate(date)),
            _buildDetailRow('In Time', inTime),
            _buildDetailRow('Out Time', outTime),
            _buildDetailRow('No. of People', noOfPeople),
            _buildDetailRow('ID Proof', idProof),
            _buildDetailRow('Meeting With', meetingWith),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 

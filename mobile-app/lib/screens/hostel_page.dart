import 'package:flutter/material.dart';
import '../services/api/hostel_api.dart';
import '../services/auth_service.dart';
import '../widgets/translated_text.dart';
import '../widgets/enterprise_ui_components.dart';

class HostelPage extends StatefulWidget {
  const HostelPage({super.key});

  @override
  State<HostelPage> createState() => _HostelPageState();
}

class _HostelPageState extends State<HostelPage> {
  List<Map<String, dynamic>> hostels = [];
  bool isLoading = true;
  String? error;
  String? currentStudentId;

  @override
  void initState() {
    super.initState();
    _loadHostelData();
  }

  Future<void> _loadHostelData() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final studentId = await AuthService.getStudentId();
      

      final hostelData = await HostelApi.getHostelList(studentId);
      
      

      if (!mounted) return;

      // Check multiple possible keys for hostel data
      List<dynamic>? hostelsList;

      // Priority: hostelarray (actual API response key) first
      if (hostelData['hostelarray'] != null &&
          hostelData['hostelarray'] is List) {
        hostelsList = hostelData['hostelarray'] as List;
        
      } else if (hostelData['hostels'] != null &&
          hostelData['hostels'] is List) {
        hostelsList = hostelData['hostels'] as List;
        
      } else if (hostelData['hostel_array'] != null &&
          hostelData['hostel_array'] is List) {
        hostelsList = hostelData['hostel_array'] as List;
        
      } else if (hostelData['rooms'] != null && hostelData['rooms'] is List) {
        hostelsList = hostelData['rooms'] as List;
        
      } else if (hostelData['data'] != null && hostelData['data'] is List) {
        hostelsList = hostelData['data'] as List;
        
      } else if (hostelData['result'] != null && hostelData['result'] is List) {
        hostelsList = hostelData['result'] as List;
        
      }

      setState(() {
        currentStudentId = studentId;
        if (hostelsList != null && hostelsList.isNotEmpty) {
          try {
            hostels = hostelsList
                .map((item) {
                  if (item is Map<String, dynamic>) {
                    return item;
                  } else if (item is Map) {
                    return Map<String, dynamic>.from(item);
                  } else {
                    
                    return <String, dynamic>{};
                  }
                })
                .where((item) => item.isNotEmpty)
                .toList()
                .cast<Map<String, dynamic>>();
          } catch (e) {
            
            hostels = [];
          }
        } else {
          hostels = [];
        }
        isLoading = false;
      });

      
      if (hostels.isNotEmpty) {
        
      }
    } catch (e) {
      
      if (!mounted) return;
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
          'Hostel Rooms',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.grey[800],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          EnterpriseUIComponents.buildHeaderWithIllustration(
            title: 'Your Hostel',
            subtitle: 'Manage your hostel details',
            illustration: Icon(
              Icons.hotel,
              size: 60,
              color: Colors.grey[800]?.withOpacity(0.8),
            ),
          ),

          // Content section
          Expanded(
            child: Container(
              color: Colors.grey[100],
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          TranslatedText(
                            'Error loading hostel data: $error',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadHostelData,
                             child: const TranslatedText('Retry'),
                          ),
                        ],
                      ),
                    )
                  : hostels.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.home_work,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          TranslatedText(
                            'No hostel rooms available',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : _buildHostelContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHostelIllustration() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          // Hostel building
          Positioned(
            top: 20,
            left: 20,
            child: Container(
              width: 60,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.brown[300],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.brown[400]!, width: 2),
              ),
              child: Stack(
                children: [
                  // Hostel label
                  Positioned(
                    top: 5,
                    left: 5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: const TranslatedText(
                        'HOSTEL',
                        style: TextStyle(
                          fontSize: 6,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  // Red roof
                  Positioned(
                    top: -2,
                    left: -2,
                    child: Container(
                      width: 64,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.red[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Amenity icons
          Positioned(
            top: 10,
            right: 10,
            child: Column(
              children: [
                // Shower
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.blue[300],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 2),
                // Laptop
                Container(
                  width: 8,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(height: 2),
                // Bed
                Container(
                  width: 8,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.green[300],
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(height: 2),
                // Washing machine
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.purple[300],
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ),
          ),
          // People with luggage
          Positioned(
            bottom: 10,
            right: 20,
            child: Row(
              children: [
                // Person 1
                Container(
                  width: 12,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.blue[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
                // Person 2
                Container(
                  width: 12,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.pink[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
                // Suitcase
                Container(
                  width: 8,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.blue[400],
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ),
          ),
          // Abstract shapes
          Positioned(
            top: 5,
            left: 5,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.blue[200],
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: 5,
            left: 5,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.purple[200],
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHostelContent() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: hostels.length,
      itemBuilder: (context, index) {
        final hostel = hostels[index];
        return _buildHostelCard(hostel);
      },
    );
  }

  Widget _buildHostelCard(Map<String, dynamic> hostel) {
    // Debug: Print the hostel object to see what fields are available
    
    

    // Extract status from multiple possible keys and formats
    final status = _getHostelStatus(hostel, currentStudentId);
    

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with room name and status
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TranslatedText(
                    _getRoomName(hostel),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                // Display status badge if status exists (only show "Assigned" badge)
                if (status != null &&
                    status.isNotEmpty &&
                    status.toLowerCase() == 'assigned')
                  _buildStatusBadge(status),
              ],
            ),
          ),
          // Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildDetailRow('Room Type', hostel['room_type'] ?? 'N/A'),
                _buildDetailRow('Room No.', _getRoomNumber(hostel)),
                _buildDetailRow(
                  'Number of beds',
                  _getNumberOfBeds(hostel),
                ),
                _buildDetailRow(
                  'Cost per Bed',
                  '\$${hostel['cost_per_bed'] ?? '0.0'}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: TranslatedText(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: TranslatedText(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper function to compare student IDs (handles numeric and string formats)
  bool _compareStudentIds(dynamic roomStudentId, String? currentStudentId) {
    if (currentStudentId == null || roomStudentId == null) {
      return false;
    }

    final roomIdStr = roomStudentId.toString().trim();
    final currentIdStr = currentStudentId.trim();

    // Try exact string match first
    if (roomIdStr == currentIdStr) {
      return true;
    }

    // Try numeric comparison if both are numeric
    try {
      final roomIdNum = int.parse(roomIdStr);
      final currentIdNum = int.parse(currentIdStr);
      return roomIdNum == currentIdNum;
    } catch (e) {
      // Not numeric, return false
      return false;
    }
  }

  // Extract room number from multiple possible keys
  String _getRoomNumber(Map<String, dynamic> hostel) {
    final keys = [
      'room_number',
      'room_no',
      'room',
      'roomNumber',
      'roomNo',
      'room_id',
      'roomId',
    ];
    for (final key in keys) {
      final value = hostel[key];
      if (value != null) {
        final strValue = value.toString().trim();
        if (strValue.isNotEmpty && strValue.toLowerCase() != 'null') {
          
          return strValue;
        }
      }
    }
    
    
    return 'N/A';
  }

  // Extract number of beds from multiple possible keys
  String _getNumberOfBeds(Map<String, dynamic> hostel) {
    // Try multiple possible field names for number of beds
    final beds = hostel['number_of_beds'] ??
        hostel['number_of_bed'] ??
        hostel['no_of_beds'] ??
        hostel['no_of_bed'] ??
        hostel['beds'] ??
        hostel['bed_count'] ??
        hostel['total_beds'] ??
        hostel['bed_number'] ??
        hostel['bed_numbers'];
    
    if (beds != null) {
      final bedsStr = beds.toString().trim();
      if (bedsStr.isNotEmpty && bedsStr.toLowerCase() != 'null') {
        return bedsStr;
      }
    }
    
    return 'N/A';
  }

  // Extract room name from multiple possible keys
  String _getRoomName(Map<String, dynamic> hostel) {
    // Try multiple possible keys for room name
    final roomName =
        hostel['room_name'] ??
        hostel['name'] ??
        hostel['hostel_name'] ??
        hostel['room_title'] ??
        hostel['title'] ??
        hostel['hostel_room_name'];

    // If we have a room name, return it
    if (roomName != null && roomName.toString().trim().isNotEmpty) {
      return roomName.toString().trim();
    }

    // Try to construct from hostel name and room number
    final hostelName =
        hostel['hostel_name'] ??
        hostel['hostel'] ??
        hostel['hostel_type'] ??
        '';
    final roomNumber =
        hostel['room_number'] ?? hostel['room_no'] ?? hostel['room'] ?? '';

    if (hostelName.toString().trim().isNotEmpty &&
        roomNumber.toString().trim().isNotEmpty) {
      return '${hostelName.toString().trim()} ${roomNumber.toString().trim()}';
    } else if (hostelName.toString().trim().isNotEmpty) {
      return hostelName.toString().trim();
    } else if (roomNumber.toString().trim().isNotEmpty) {
      return 'Hostel Room ${roomNumber.toString().trim()}';
    }

    return 'Hostel Room';
  }

  // Extract status from multiple possible keys and formats
  String? _getHostelStatus(
    Map<String, dynamic> hostel,
    String? currentStudentId,
  ) {
    
    
    
    
    
    

    // Check if student is assigned to this room - check multiple possible keys
    final roomStudentId =
        hostel['student_id'] ??
        hostel['studentId'] ??
        hostel['student_Id'] ??
        hostel['assigned_student_id'] ??
        hostel['assigned_studentId'] ??
        hostel['assigned_student_Id'] ??
        hostel['user_id'] ??
        hostel['userId'] ??
        hostel['user_Id'];

    

    // If there's a student_id in the room data and it matches current student, it's assigned
    if (_compareStudentIds(roomStudentId, currentStudentId)) {
      
      
      
      return 'Assigned';
    } else if (currentStudentId != null && roomStudentId != null) {
      
      
      
    }

    // Check multiple possible status fields from API
    // Priority: Check 'assig' field first (as per user requirement: assig=1 means assigned)
    // Check multiple possible keys for assig field
    final assigValue =
        hostel['assig'] ??
        hostel['assig_status'] ??
        hostel['assigned'] ??
        hostel['is_assigned'] ??
        hostel['assign'] ??
        hostel['assignment'];

    if (assigValue != null) {
      final assigStr = assigValue.toString().trim().toLowerCase();
      

      // Check for all possible "assigned" values
      if (assigStr == '1' ||
          assigStr == 'true' ||
          assigStr == 'yes' ||
          assigStr == 'assigned' ||
          assigValue == 1 ||
          assigValue == true) {
        
        return 'Assigned';
      } else {
        
      }
    } else {
      
      
    }

    final statusValue =
        hostel['status'] ??
        hostel['room_status'] ??
        hostel['assignment_status'] ??
        hostel['hostel_status'] ??
        hostel['is_assigned'] ??
        hostel['assigned'] ??
        hostel['isAssigned'] ??
        hostel['is_assign'] ??
        hostel['assign_status'] ??
        hostel['assignStatus'] ??
        hostel['room_assigned'] ??
        hostel['roomAssigned'];

    

    // If statusValue exists, process it
    if (statusValue != null) {
      // Convert to string and normalize
      String statusStr = statusValue.toString().trim();

      // Handle different formats
      if (statusStr.isEmpty ||
          statusStr == 'null' ||
          statusStr == 'NULL' ||
          statusStr == 'N/A') {
        // If status is null but student_id exists and matches, it's assigned
        if (_compareStudentIds(roomStudentId, currentStudentId)) {
          return 'Assigned';
        }
        return null;
      }

      // Handle numeric status codes
      if (statusStr == '1' ||
          statusStr == 1 ||
          statusStr == 'true' ||
          statusStr == true) {
        return 'Assigned';
      } else if (statusStr == '0' ||
          statusStr == 0 ||
          statusStr == 'false' ||
          statusStr == false) {
        // If status is 0/false but student_id exists and matches, still show assigned
        if (_compareStudentIds(roomStudentId, currentStudentId)) {
          return 'Assigned';
        }
        return null; // Don't show "Not Assigned", just don't show badge
      }

      // Handle string status values (normalize case)
      statusStr = statusStr.toLowerCase();
      if (statusStr == 'assigned' ||
          statusStr == 'assign' ||
          statusStr == 'active' ||
          statusStr == 'yes') {
        return 'Assigned';
      } else if (statusStr == 'not assigned' ||
          statusStr == 'unassigned' ||
          statusStr == 'available' ||
          statusStr == 'inactive' ||
          statusStr == 'no') {
        // If status says not assigned but student_id matches, still show assigned
        if (_compareStudentIds(roomStudentId, currentStudentId)) {
          return 'Assigned';
        }
        return null; // Don't show "Not Assigned", just don't show badge
      } else if (statusStr == 'pending' || statusStr == 'waiting') {
        return 'Pending';
      }

      // Return capitalized version if it's a valid string
      if (statusStr.isNotEmpty) {
        return statusStr[0].toUpperCase() + statusStr.substring(1);
      }
    }

    // If no explicit status but student_id exists and matches, consider it assigned
    if (_compareStudentIds(roomStudentId, currentStudentId)) {
      
      return 'Assigned';
    }

    // Check if there's any indication of assignment in other fields
    final hasAssignment =
        hostel['has_assignment'] ??
        hostel['hasAssignment'] ??
        hostel['is_occupied'] ??
        hostel['isOccupied'];

    if (hasAssignment != null) {
      final hasAssignmentStr = hasAssignment.toString().trim().toLowerCase();
      if (hasAssignmentStr == '1' ||
          hasAssignmentStr == 'true' ||
          hasAssignmentStr == 'yes') {
        // Only show assigned if student_id matches
        if (_compareStudentIds(roomStudentId, currentStudentId)) {
          return 'Assigned';
        }
      }
    }

    
    
    
    
    
    
    
    return null;
  }

  // Build status badge with appropriate color - matching image design
  Widget _buildStatusBadge(String status) {
    Color badgeColor;

    // Determine badge color based on status
    // For "Assigned" status, use green as shown in image
    switch (status.toLowerCase()) {
      case 'assigned':
        badgeColor = Colors.green[600]!; // Green rectangular label as in image
        break;
      case 'not assigned':
      case 'unassigned':
        badgeColor = Colors.grey[600]!;
        break;
      case 'pending':
      case 'waiting':
        badgeColor = Colors.orange[600]!;
        break;
      default:
        badgeColor =
            Colors.green[600]!; // Default to green for assigned-like statuses
    }

    // Match the image: green rectangular label with white text
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(4), // Slightly rounded corners
      ),
      child: TranslatedText(
        status,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white, // White text as shown in image
        ),
      ),
    );
  }
}

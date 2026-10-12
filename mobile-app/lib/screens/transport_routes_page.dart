import 'package:flutter/material.dart';
import '../services/api/transport_api.dart';
import '../services/auth_service.dart';
import '../utils/api_image_manager.dart';
import '../widgets/translated_text.dart';
import '../widgets/enterprise_ui_components.dart';
import 'package:provider/provider.dart';
import '../providers/app_config_provider.dart';

class TransportRoutesPage extends StatefulWidget {
  const TransportRoutesPage({super.key});

  @override
  State<TransportRoutesPage> createState() => _TransportRoutesPageState();
}

class _TransportRoutesPageState extends State<TransportRoutesPage> {
  List<Map<String, dynamic>> pickupPoints = [];
  Map<String, dynamic>? routeDetails;
  List<Map<String, dynamic>> routesWithVehicles = []; // Routes with vehicles array
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadTransportRoutes();
  }

  Future<void> _loadTransportRoutes() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final studentId = await AuthService.getStudentId();
      if (studentId.isEmpty) {
        setState(() {
          error = 'Student information missing. Please login again.';
          isLoading = false;
        });
        return;
      }

      final routesData = await TransportApi.getTransportRoutes(studentId);

      // Extract pickup points
      List<dynamic>? pickupPointsList;
      if (routesData['pickup_point'] != null && routesData['pickup_point'] is List) {
        pickupPointsList = routesData['pickup_point'] as List;
      }

      // Extract route details
      Map<String, dynamic>? routeData;
      if (routesData['route'] != null && routesData['route'] is Map) {
        routeData = Map<String, dynamic>.from(routesData['route']);
      }

      // Check if response contains routes with vehicles array (new API structure)
      List<Map<String, dynamic>> convertedRoutesWithVehicles = [];
      if (routesData['routes'] != null && routesData['routes'] is List) {
        final routesList = routesData['routes'] as List;
        
        
        // Check if first item has 'vehicles' array
        if (routesList.isNotEmpty && routesList[0] is Map) {
          final firstRoute = routesList[0] as Map;
          if (firstRoute.containsKey('vehicles') && firstRoute['vehicles'] is List) {
            // Convert ALL routes in the list, not just the first one
            convertedRoutesWithVehicles = routesList
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
            
            // Log each route for debugging
            for (int i = 0; i < convertedRoutesWithVehicles.length; i++) {
              final route = convertedRoutesWithVehicles[i];
              final routeTitle = route['route_title']?.toString() ?? 'N/A';
              final vehiclesCount = (route['vehicles'] as List?)?.length ?? 0;
              
            }
          } else {
            
          }
        } else {
          
        }
      } else {
        
        
      }

      // Convert pickup points to list of maps
      List<Map<String, dynamic>> convertedPickupPoints = [];
      if (pickupPointsList != null) {
        convertedPickupPoints = pickupPointsList
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      // If no pickup points and no routes with vehicles, show error message
      if (convertedPickupPoints.isEmpty && routeData == null && convertedRoutesWithVehicles.isEmpty) {
        setState(() {
          error = 'No Transport Route Assigned';
          isLoading = false;
        });
        return;
      }

      
      // Use helper to process and filter data
      _processRoutesData(
        convertedPickupPoints,
        routeData,
        convertedRoutesWithVehicles
      );

    } catch (e) {
      setState(() {
        isLoading = false;
        error = 'Failed to load transport routes: $e';
      });
    }
  }

  // Filter and process routes to match dashboard
  void _processRoutesData(
      List<Map<String, dynamic>> pickupPointsList,
      Map<String, dynamic>? initialRouteDetails,
      List<Map<String, dynamic>> allRoutesWithVehicles) {
    
    Map<String, dynamic>? finalRouteDetails = initialRouteDetails;
    List<Map<String, dynamic>> displayRoutes = [];

    // 1. Find the assigned vehicle
    final assignedRoute = allRoutesWithVehicles.firstWhere(
      (r) {
        final vehicles = r['vehicles'] as List?;
        if (vehicles == null) return false;
        return vehicles.any((v) => v['assigned']?.toString().toLowerCase() == 'yes');
      },
      orElse: () => {},
    );

    if (assignedRoute.isNotEmpty) {
      
      
      // If pickup_point is missing, check other potential keys
      if (assignedRoute['pickup_point'] == null) {
         
         for (var k in assignedRoute.keys) {
           if (k.contains('pickup') || k.contains('point')) {
             
           }
         }
      } else {
         
         if (assignedRoute['pickup_point'] is List) {
             
         }
      }

      // If we found a route with an assigned vehicle, that's our focus
      final vehicles = assignedRoute['vehicles'] as List;
      final assignedVehicle = vehicles.firstWhere(
        (v) => v['assigned']?.toString().toLowerCase() == 'yes',
      );

      // Populate routeDetails from this if missing
      if (finalRouteDetails == null) {
        finalRouteDetails = {
          'route_title': assignedRoute['route_title'],
          'vehicle_no': assignedVehicle['vehicle_no'],
          'vehicle_model': assignedVehicle['vehicle_model'],
          'driver_name': assignedVehicle['driver_name'],
          'driver_contact': assignedVehicle['driver_contact'],
          'driver_licence': assignedVehicle['driver_licence'],
          'manufacture_year': assignedVehicle['manufacture_year'], // 'Made' in dashboard
          'vehicle_photo': assignedVehicle['vehicle_photo'],
          // Add other fields as needed
        };
      }
      
      
      // We only show the assigned vehicle/route in the list too, to be clean
      // User requested "all data", so we won't hide the others, just sort them.
      displayRoutes = [assignedRoute]; 
      
      
      
      // Sort the vehicle list inside this route to show the assigned one FIRST
      // UPDATE: User requested to ONLY show the data belonging to the student (assigned vehicle).
      final List<dynamic> allVehicles = List.from(assignedRoute['vehicles']);
      final assignedOnly = allVehicles.where((v) => v['assigned']?.toString().toLowerCase() == 'yes').toList();
      
      if (assignedOnly.isNotEmpty) {
        displayRoutes[0]['vehicles'] = assignedOnly;
      } else {
        // Fallback if somehow no assigned vehicle found despite the check above, show all sorted
        allVehicles.sort((a, b) {
            final aAssigned = a['assigned']?.toString().toLowerCase() == 'yes';
            final bAssigned = b['assigned']?.toString().toLowerCase() == 'yes';
            if (aAssigned && !bAssigned) return -1;
            if (!aAssigned && bAssigned) return 1;
            return 0;
        });
        displayRoutes[0]['vehicles'] = allVehicles;
      }

      // 2. Extract pickup points from the assigned route if not already provided
      if (pickupPointsList.isEmpty) {
        
        
        // Check for common keys
        final pickupKeys = ['pickup_point', 'pickup_points', 'pickup', 'points', 'stops'];
        dynamic foundPoints;
        
        for (var key in pickupKeys) {
          if (assignedRoute[key] != null) {
             foundPoints = assignedRoute[key];
             
             break;
          }
        }
        
        if (foundPoints != null && foundPoints is List) {
           // We found it, but we can't easily update pickupPointsList here without re-assigning
           // We will handle it in the final block below
        }
      }
    } else {
      // Fallback: if no assigned vehicle, maybe show all (or handle empty)
      // For now, let's just show what we have, but cleaned up
      displayRoutes = allRoutesWithVehicles;
    }
    
    // Determine final pickup points
    List<Map<String, dynamic>> finalPickupPoints = pickupPointsList;
    if (finalPickupPoints.isEmpty && assignedRoute.isNotEmpty) {
         // Check again using the logic above
         final pickupKeys = ['pickup_point', 'pickup_points', 'pickup', 'points', 'stops'];
         dynamic foundPoints;
         for (var key in pickupKeys) {
          if (assignedRoute[key] != null) {
             foundPoints = assignedRoute[key];
             break;
          }
        }
        
        if (foundPoints is List) {
           finalPickupPoints = foundPoints.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        }
    }
    
    setState(() {
      pickupPoints = finalPickupPoints;
      routeDetails = finalRouteDetails;
      routesWithVehicles = displayRoutes;
      isLoading = false;
    });
  }

  // Helper to clean HTML entities (basic version since we might not have html_unescape)
  String _cleanText(String? text) {
    if (text == null) return 'N/A';
    var cleaned = text.toString();
    cleaned = cleaned.replaceAll('&amp;', '&')
                     .replaceAll('&quot;', '"')
                     .replaceAll('&lt;', '<')
                     .replaceAll('&gt;', '>')
                     .replaceAll('&#039;', "'");
    // Add more if needed, or regex for &#...;
    return cleaned;
  }

  // Get route field value safely
  String _getRouteField(String key, {String defaultValue = 'N/A'}) {
    if (routeDetails == null) return defaultValue;
    final value = routeDetails![key];
    if (value != null) {
      final s = value.toString().trim();
      if (s.isNotEmpty && s.toLowerCase() != 'null') {
        return _cleanText(s);
      }
    }
    return defaultValue;
  }

  // Get pickup point name
  String _getPickupPointName(Map<String, dynamic> pickupPoint) {
    final keys = ['pickup_point', 'pickup_point_name', 'route_title', 'name'];
    for (final key in keys) {
      if (pickupPoint[key] != null) {
        final value = pickupPoint[key].toString().trim();
        if (value.isNotEmpty && value.toLowerCase() != 'null') {
          return _cleanText(value);
        }
      }
    }
    return 'Route';
  }

  // Get distance
  String _getDistance(Map<String, dynamic> pickupPoint) {
    final keys = ['destination_distance', 'distance', 'dist'];
    for (final key in keys) {
      if (pickupPoint[key] != null) {
        final value = pickupPoint[key].toString().trim();
        if (value.isNotEmpty && value != 'null' && value != '0') {
          return value;
        }
      }
    }
    return '0.0';
  }

  // Get pickup time
  String? _getPickupTime(Map<String, dynamic> pickupPoint) {
    final keys = ['pickup_time', 'time', 'pickup'];
    for (final key in keys) {
      if (pickupPoint[key] != null) {
        final value = pickupPoint[key].toString().trim();
        if (value.isNotEmpty && value.toLowerCase() != 'null') {
          return value;
        }
      }
    }
    return null;
  }

  // Format time from 24h to 12h AM/PM
  String _formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty || timeStr == 'N/A') {
      return 'N/A';
    }

    try {
      // Handle formats like "11:30:00" or "11:30"
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final period = hour >= 12 ? 'PM' : 'AM';
        final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        return '${hour12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
      }
    } catch (e) {
      // If parsing fails, return original
    }
    return timeStr;
  }

  // Check if pickup point is the selected route
  bool _isSelectedRoute(Map<String, dynamic> pickupPoint) {
    if (routeDetails == null) return false;
    
    // Get route identifiers
    final routePickupPoint = _getRouteField('pickup_point');
    final routeTitle = _getRouteField('route_title');
    final currentName = _getPickupPointName(pickupPoint);
    final currentRouteTitle = pickupPoint['route_title']?.toString().trim() ?? '';
    
    // 1. Match by exact Pickup Point ID (Most reliable)
    // The API route object contains 'route_pickup_point_id' which corresponds to the assigned pickup point 'id'
    final assignedId = _getRouteField('route_pickup_point_id', defaultValue: '');
    final currentId = pickupPoint['id']?.toString().trim() ?? '';
    
    if (assignedId.isNotEmpty && assignedId != 'N/A' && currentId.isNotEmpty) {
      if (assignedId == currentId) return true;
    }

    // 2. Match by exact Pickup Point Name (Fallback)
    // The API route object contains 'pickup_point_name'
    final assignedName = _getRouteField('pickup_point_name', defaultValue: '');
    if (assignedName.isNotEmpty && assignedName != 'N/A') {
       if (assignedName == currentName) return true;
    }
    
    // 3. Fallback: Match by 'pickup_point' field in route details
    if (routePickupPoint != 'N/A' && routePickupPoint == currentName) {
      return true;
    }
    // Removed strict route title match because it highlights ALL points if they belong to the same route
    // if (routeTitle != 'N/A' && (routeTitle == currentName || routeTitle == currentRouteTitle)) {
    //   return true;
    // }
    
    // If route details have a matching pickup_point field, check that too
    if (routeDetails!['pickup_point'] != null) {
      final routePickup = routeDetails!['pickup_point'].toString().trim();
      if (routePickup.isNotEmpty && routePickup == currentName) {
        return true;
      }
    }
    
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final appConfig = Provider.of<AppConfigProvider>(context);
    final primaryColor = appConfig.primaryColorObj;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const TranslatedText(
          'Transport Routes',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? _buildErrorView()
              : _buildContent(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.directions_bus, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          TranslatedText(
            error ?? 'Something went wrong',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadTransportRoutes,
            child: const TranslatedText('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        EnterpriseUIComponents.buildHeaderWithIllustration(
          title: 'Transport',
          subtitle: 'Track your school transport routes',
          illustration: _buildBusImage(),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadTransportRoutes,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  if (routeDetails != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildDetailCard(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (pickupPoints.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildPickupPointsList(),
                    ),
                  ],
                  if (routesWithVehicles.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildRoutesWithVehiclesList(),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: const TranslatedText(
              'Your Transport Routes is here!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 86,
            height: 86,
            child: _buildBusImage(),
          ),
        ],
      ),
    );
  }

  Widget _buildBusImage() {
    // Try to get vehicle image from route details
    String? vehicleImageUrl;
    if (routeDetails != null) {
      final keys = ['vehicle_photo', 'vehicle_image', 'bus_image', 'photo'];
      for (final key in keys) {
        if (routeDetails![key] != null) {
          final value = routeDetails![key].toString().trim();
          if (value.isNotEmpty && value.toLowerCase() != 'null') {
            vehicleImageUrl = value;
            break;
          }
        }
      }
    }

    if (vehicleImageUrl != null && vehicleImageUrl.isNotEmpty) {
      return FutureBuilder<String>(
        future: ApiImageManager.getImageWithFallback(vehicleImageUrl, 'vehicle'),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                snapshot.data!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildDefaultBusIcon();
                },
              ),
            );
          }
          return _buildDefaultBusIcon();
        },
      );
    }

    return _buildDefaultBusIcon();
  }

  Widget _buildDefaultBusIcon() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFFFFD700), // Yellow bus color
      ),
      child: const Icon(
        Icons.directions_bus,
        size: 48,
        color: Colors.white,
      ),
    );
  }

  Widget _buildDetailCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Route Title', _getRouteField('route_title')),
          _buildDetailRow('Vehicle Number', _getRouteField('vehicle_no')),
          _buildDetailRow('Vehicle Model', _getRouteField('vehicle_model')),
          _buildDetailRow('Driver Name', _getRouteField('driver_name')),
          _buildDetailRow('Driver Contact', _getRouteField('driver_contact')),
          _buildDetailRow('Driver Licence', _getRouteField('driver_licence')),
          _buildDetailRow('Made', _getRouteField('manufacture_year')),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TranslatedText(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: TranslatedText(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickupPointsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int index = 0; index < pickupPoints.length; index++)
          _buildPickupPointCard(pickupPoints[index], index),
      ],
    );
  }

  Widget _buildPickupPointCard(Map<String, dynamic> pickupPoint, int index) {
    final isSelected = _isSelectedRoute(pickupPoint);
    final routeName = _getPickupPointName(pickupPoint);
    final distance = _getDistance(pickupPoint);
    final pickupTime = _formatTime(_getPickupTime(pickupPoint));

    // Colors matching the reference image "Brooklyn" style
    final selectedColor = const Color(0xFFC6E768); // Bright Lime Green
    final unselectedHeaderColor = const Color(0xFFE0F2F1); // Light Mint/Cyan tint
    final unselectedBodyColor = Colors.white;

    // Background color for the main container
    // Selected: Full Green
    // Unselected: White (header will be painted separately)
    final cardBgColor = isSelected ? selectedColor : unselectedBodyColor;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline Column
          SizedBox(
            width: 40,
            child: Column(
              children: [
                 // Top Line (Fixed height to align dot with header)
                 Container(
                   width: 2,
                   height: 30, // Approx vertical center of header (12 padding + ~24/2 text)
                   color: index == 0 ? Colors.transparent : Colors.grey[300],
                 ),
                 // Dot
                 Container(
                   width: 16,
                   height: 16,
                   decoration: BoxDecoration(
                     color: Colors.black87, 
                     shape: BoxShape.circle,
                     border: Border.all(color: Colors.white, width: 2),
                     boxShadow: [
                       BoxShadow(
                         color: Colors.black.withOpacity(0.1),
                         blurRadius: 4,
                         offset: const Offset(0, 2),
                       )
                     ]
                   ),
                   child: Center(
                     child: Container(
                       width: 6,
                       height: 6,
                       decoration: const BoxDecoration(
                         color: Colors.white, 
                         shape: BoxShape.circle
                       ),
                     ),
                   ),
                 ),
                 // Bottom Line (fills rest of height)
                 Expanded(
                   child: Container(
                     width: 2,
                     color: index == pickupPoints.length - 1 ? Colors.transparent : Colors.grey[300],
                   ),
                 ),
              ],
            ),
          ),
          // Horizontal Connector Line (Overlay or Row item)
          // To align perfectly with the dot center, we can use a Column with offset
          Column(
             children: [
               const SizedBox(height: 37), // 30 (top line) + 16/2 (half dot) - 1 (half line)
               Container(
                 width: 12,
                 height: 2,
                 color: Colors.grey[300],
               ),
             ],
          ),
          const SizedBox(width: 4), // Small gap before card
          // Content Card
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: index < pickupPoints.length - 1 ? 16 : 0),
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header (Stop Name)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      // If unselected, use the mint header color. If selected, transparent (shows cardBgColor)
                      color: isSelected ? Colors.transparent : unselectedHeaderColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TranslatedText(
                            routeName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isSelected) const Divider(height: 1, color: Colors.transparent),
                  // Details Body
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Distance Row
                        Row(
                          children: [
                            Icon(
                              Icons.directions_bus_outlined, // Bus icon style
                              size: 20,
                              color: Colors.black87,
                            ),
                            const SizedBox(width: 12),
                            TranslatedText(
                              'Distance(km)',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                            const Spacer(),
                            TranslatedText(
                              distance,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Time Row
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 20,
                              color: Colors.black87,
                            ),
                            const SizedBox(width: 12),
                            TranslatedText(
                              'Pickup Time',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black54, // Keep text logic simple/clean
                                fontWeight: FontWeight.normal, 
                              ),
                            ),
                            const Spacer(),
                            TranslatedText(
                              pickupTime,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutesWithVehiclesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TranslatedText(
          'Transport Routes',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        for (int i = 0; i < routesWithVehicles.length; i++)
          _buildRouteWithVehiclesCard(routesWithVehicles[i], i),
      ],
    );
  }

  Widget _buildRouteWithVehiclesCard(Map<String, dynamic> route, int index) {
    final routeTitle = route['route_title']?.toString() ?? 'Route ${index + 1}';
    final vehicles = route['vehicles'] as List<dynamic>? ?? [];

    return Container(
      margin: EdgeInsets.only(bottom: index < routesWithVehicles.length - 1 ? 16 : 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Route header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.route, color: Colors.blue, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: TranslatedText(
                    routeTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Vehicles list
          if (vehicles.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: TranslatedText(
                'No vehicles available',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            )
          else
            ...vehicles.asMap().entries.map((entry) {
              final vehicleIndex = entry.key;
              final vehicle = entry.value as Map<String, dynamic>;
              return _buildVehicleCard(vehicle, vehicleIndex, vehicles.length);
            }),
        ],
      ),
    );
  }

  Widget _buildVehicleCard(Map<String, dynamic> vehicle, int index, int totalVehicles) {
    final assigned = vehicle['assigned']?.toString().toLowerCase() ?? 'no';
    final isAssigned = assigned == 'yes';
    
    // Color: Green for assigned="yes", very light grey for others
    final backgroundColor = isAssigned 
        ? Colors.green[50]! 
        : Colors.grey[50]!; // Very light grey
    
    final borderColor = isAssigned 
        ? Colors.green[300]! 
        : Colors.grey[200]!;
    
    final textColor = isAssigned 
        ? Colors.black87 
        : Colors.grey[600]!;

    final vehicleNo = _cleanText(vehicle['vehicle_no']?.toString()) == 'N/A' ? 'N/A' : _cleanText(vehicle['vehicle_no']?.toString());
    final vehicleModel = _cleanText(vehicle['vehicle_model']?.toString());
    final driverName = _cleanText(vehicle['driver_name']?.toString());
    final driverContact = _cleanText(vehicle['driver_contact']?.toString());

    return Container(
      margin: EdgeInsets.only(
        left: 16,
        right: 16,
        top: index == 0 ? 16 : 8,
        bottom: index == totalVehicles - 1 ? 16 : 0,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vehicle number and assigned badge
          Row(
            children: [
              Expanded(
                child: TranslatedText(
                  vehicleNo,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isAssigned ? Colors.green : Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TranslatedText(
                  isAssigned ? 'Assigned' : 'Not Assigned',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isAssigned ? Colors.white : Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildVehicleDetailRow('Model', vehicleModel, textColor),
          _buildVehicleDetailRow('Driver', driverName, textColor),
          if (driverContact != 'N/A')
            _buildVehicleDetailRow('Contact', driverContact, textColor),
        ],
      ),
    );
  }

  Widget _buildVehicleDetailRow(String label, String value, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: TranslatedText(
              '$label:',
              style: TextStyle(
                fontSize: 13,
                color: textColor.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: TranslatedText(
              value,
              style: TextStyle(
                fontSize: 13,
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

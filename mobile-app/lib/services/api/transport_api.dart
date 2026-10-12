import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/url_manager.dart';
import '../../utils/response_validator.dart';
import '../../utils/dynamic_api_headers.dart';
import '../../config/app_config.dart';

class TransportApi {
  // Get transport routes
  static Future<Map<String, dynamic>> getTransportRoutes(String studentId) async {
    try {
      
      final baseUrl = await UrlManager.getBaseUrl();
      
      // If no base URL is configured, return empty data
      if (baseUrl.isEmpty) {
        
        return {
          'status': 0,
          'message': 'Please configure the base URL in settings',
          'pickup_point': [],
          'route': null,
          'routes': [],
        };
      }
      
      // Primary endpoint as per cURL: gettransportroutes (plural)
      final endpoint = await AppConfig.getApiEndpoint('gettransportroutes');
      
      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      // Ensure Content-Type is set to application/json (as per cURL)
      headers['Content-Type'] = 'application/json';
      
      // Add session cookie if available (as per cURL)
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      // Body format as per cURL: {"student_id": "51"}
      final body = jsonEncode({'student_id': studentId});

      
      
      

      try {
        
        final url = Uri.parse(endpoint);

        final response = await http.post(url, headers: headers, body: body);

        
        
        
        
        // Print body in chunks of 800 chars to avoid truncation
        final responseBody = response.body;
        for (int i = 0; i < responseBody.length; i += 800) {
          
        }

        if (response.statusCode == 200 && !ResponseValidator.isHtmlResponse(response.body)) {
          
          
          try {
            final jsonData = jsonDecode(response.body);
            
            
            // Extract data from API response - similar to documents API pattern
            List<dynamic>? pickupPoints;
            Map<String, dynamic>? routeData;
            
            if (jsonData is List) {
              // Response is directly a list
              
              
              // Check if it's routes with vehicles array
              if (jsonData.isNotEmpty && jsonData[0] is Map) {
                final first = jsonData[0] as Map;
                if (first.containsKey('vehicles') && first['vehicles'] is List) {
                  // This is routes with vehicles structure
                  
                  
                  // Log each route for debugging
                  for (int i = 0; i < jsonData.length; i++) {
                    if (jsonData[i] is Map) {
                      final route = jsonData[i] as Map;
                      final routeTitle = route['route_title']?.toString() ?? 'N/A';
                      final vehiclesCount = (route['vehicles'] as List?)?.length ?? 0;
                      
                    }
                  }
                  return {
                    'status': 1,
                    'message': 'Transport routes loaded successfully',
                    'routes': jsonData, // Return ALL routes in the list
                    'pickup_point': [],
                    'route': null,
                  };
                }
              }
              
              // Otherwise treat as pickup points
              pickupPoints = jsonData;
              
              // Log first item structure
              if (pickupPoints.isNotEmpty && pickupPoints[0] is Map) {
                final first = pickupPoints[0] as Map;
                
                
              }
            } else if (jsonData is Map) {
              
              
              
              // Check for pickup_point array (most common)
              final pickupKeys = [
                'pickup_point',
                'pickup_points',
                'pickupPoint',
                'pickupPoints',
                'routes',
                'data',
                'result',
                'transport_routes',
                'transportRoutes',
                'route_list',
                'routeList',
                'student_routes',
                'studentRoutes',
              ];
              
              for (final key in pickupKeys) {
                if (jsonData[key] != null && jsonData[key] is List) {
                  pickupPoints = jsonData[key] as List;
                  
                  break;
                }
              }
              
              // If not found, search all values for lists that look like route data
              if (pickupPoints == null) {
                
                for (final entry in jsonData.entries) {
                  if (entry.value is List && (entry.value as List).isNotEmpty) {
                    final list = entry.value as List;
                    if (list.first is Map) {
                      final firstItem = list.first as Map;
                      final hasRouteFields = firstItem.keys.any((k) => 
                        k.toString().toLowerCase().contains('route') ||
                        k.toString().toLowerCase().contains('pickup') ||
                        k.toString().toLowerCase().contains('vehicle') ||
                        k.toString().toLowerCase().contains('driver') ||
                        k.toString().toLowerCase().contains('student_id')
                      );
                      if (hasRouteFields) {
                        pickupPoints = list;
                        
                        break;
                      }
                    }
                  }
                }
              }
              
              // Check for route details object
              final routeKeys = [
                'route',
                'route_details',
                'routeDetails',
                'selected_route',
                'selectedRoute',
                'current_route',
                'currentRoute',
                'transport_route',
              ];
              
              for (final key in routeKeys) {
                if (jsonData[key] != null && jsonData[key] is Map) {
                  routeData = Map<String, dynamic>.from(jsonData[key]);
                  
                  break;
                }
              }
              
              // If route not found but we have pickup points, use first one as route
              if (routeData == null && pickupPoints != null && pickupPoints.isNotEmpty) {
                final first = pickupPoints[0];
                if (first is Map) {
                  routeData = Map<String, dynamic>.from(first);
                  
                }
              }
              
              // Check if vehicle_photo is at root level
              if (jsonData.containsKey('vehicle_photo') && routeData != null) {
                final rootVehiclePhoto = jsonData['vehicle_photo'];
                if (rootVehiclePhoto != null && 
                    rootVehiclePhoto.toString().trim().isNotEmpty &&
                    rootVehiclePhoto.toString().toLowerCase() != 'null') {
                  routeData['vehicle_photo'] = rootVehiclePhoto.toString().trim();
                  
                }
              }
            }
            
            // Log sample data for debugging
            if (pickupPoints != null && pickupPoints.isNotEmpty) {
              final first = pickupPoints[0];
              if (first is Map) {
                
                
              }
            } else {
              
              
            }
            
            // Return data in format expected by UI
            if (pickupPoints != null && pickupPoints.isNotEmpty) {
              return {
                'status': jsonData is Map ? (jsonData['status'] ?? 1) : 1,
                'message': jsonData is Map ? (jsonData['message'] ?? 'Transport routes loaded successfully') : 'Transport routes loaded successfully',
                'pickup_point': pickupPoints,
                'route': routeData,
                'routes': pickupPoints, // Alias for UI compatibility
              };
            } else {
              
              return {
                'status': jsonData is Map ? (jsonData['status'] ?? 0) : 0,
                'message': jsonData is Map ? (jsonData['message'] ?? 'No transport routes found') : 'No transport routes found',
                'pickup_point': [],
                'route': null,
                'routes': [],
              };
            }
          } catch (e) {
            
            
            return {
              'status': 0,
              'message': 'Error parsing API response: $e',
              'pickup_point': [],
              'route': null,
              'routes': [],
            };
          }
        } else {
          
          return {
            'status': 0,
            'message': 'Failed to load transport routes: ${response.statusCode}',
            'pickup_point': [],
            'route': null,
            'routes': [],
          };
        }
      } catch (e) {
        
        return {
          'status': 0,
          'message': 'Error loading transport routes: $e',
          'pickup_point': [],
          'route': null,
          'routes': [],
        };
      }
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error loading transport routes: $e',
        'pickup_point': [],
        'route': null,
        'routes': [],
      };
    }
  }


  // Get session cookie from SharedPreferences
  static Future<String?> _getSessionCookie() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('session_cookie');
    } catch (e) {
      
      return null;
    }
  }
}

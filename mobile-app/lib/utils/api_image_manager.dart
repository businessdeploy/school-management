import '../config/app_config.dart';
import 'package:flutter/foundation.dart';

/// API Image Manager
/// 
/// This utility class handles all API-based image loading for the app.
/// It provides centralized image URL resolution and error handling.
class ApiImageManager {
  
  /// Get instructor image URL from API
  static Future<String> getInstructorImageUrl(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty || imageUrl == 'null' || imageUrl == 'default_male.jpg') {
      return ''; // Return empty string to show placeholder
    }
    
    // If it's already a full URL, return as is
    if (imageUrl.startsWith('http')) {
      return imageUrl;
    }
    
    // Otherwise, construct the full URL
    final baseUrl = await AppConfig.getBaseUrl();
    final fullUrl = '$baseUrl/uploads/staff_images/$imageUrl';
    return fullUrl;
  }
  
  /// Get course thumbnail URL from API
  static Future<String> getCourseThumbnailUrl(String? thumbnailUrl) async {
    if (thumbnailUrl == null || thumbnailUrl.isEmpty || thumbnailUrl == 'null') {
      return ''; // Return empty string to show placeholder
    }
    
    // If it's already a full URL, return as is
    if (thumbnailUrl.startsWith('http')) {
      return thumbnailUrl;
    }
    
    // Otherwise, construct the full URL
    final baseUrl = await AppConfig.getBaseUrl();
    final fullUrl = '$baseUrl/uploads/course/course_thumbnail/$thumbnailUrl';
    return fullUrl;
  }
  
  /// Get student image URL from API
  static Future<String> getStudentImageUrl(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty || imageUrl == 'null' || imageUrl == 'default_male.jpg') {
      return ''; // Return empty string to show placeholder
    }
    
    // If it's already a full URL, return as is
    if (imageUrl.startsWith('http')) {
      return imageUrl;
    }
    
    // Otherwise, construct the full URL
    final baseUrl = await AppConfig.getBaseUrl();
    final fullUrl = '$baseUrl/uploads/student_images/$imageUrl';
    return fullUrl;
  }
  
  /// Get general asset URL from API
  static Future<String> getAssetUrl(String? assetPath, {String folder = 'uploads'}) async {
    if (assetPath == null || assetPath.isEmpty || assetPath == 'null') {
      return ''; // Return empty string to show placeholder
    }
    
    // If it's already a full URL, return as is
    if (assetPath.startsWith('http')) {
      return assetPath;
    }
    
    // Otherwise, construct the full URL
    final baseUrl = await AppConfig.getBaseUrl();
    final fullUrl = '$baseUrl/$folder/$assetPath';
    return fullUrl;
  }
  
  /// Get school logo URL from API
  static Future<String> getSchoolLogoUrl() async {
    try {
      final logoPath = await AppConfig.getAppLogo();
      if (logoPath.isNotEmpty) {
        return logoPath;
      } else {
        return '';
      }
    } catch (e) {
      
      return '';
    }
  }
  
  /// Check if image URL is valid
  static bool isValidImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty || imageUrl == 'null') {
      return false;
    }
    return true;
  }
  
  /// Get image with fallback
  static Future<String> getImageWithFallback(
    String? imageUrl, 
    String fallbackType, {
    String? customFolder,
  }) async {
    if (!isValidImageUrl(imageUrl)) {
      return '';
    }
    
    // If it's already a full URL, return as is
    if (imageUrl!.startsWith('http')) {
      return imageUrl;
    }
    
    // Determine folder based on type
    String folder = customFolder ?? 'uploads';
    switch (fallbackType.toLowerCase()) {
      case 'instructor':
      case 'staff':
        folder = 'uploads/staff_images';
        break;
      case 'student':
        folder = 'uploads/student_images';
        break;
      case 'vehicle':
        folder = 'uploads/vehicle_photo'; // Corrected path based on user URL
        break;
      case 'course':
      case 'thumbnail':
        folder = 'uploads/course/course_thumbnail';
        break;
      case 'logo':
        folder = 'uploads';
        break;
      default:
        folder = 'uploads';
    }
    
    // Construct the full URL
    final baseUrl = await AppConfig.getBaseUrl();
    final fullUrl = '$baseUrl/$folder/$imageUrl';
    return fullUrl;
  }
  
  /// Get all image URLs for a course
  static Future<Map<String, String>> getCourseImageUrls(Map<String, dynamic> course) async {
    return {
      'instructor_image': await getInstructorImageUrl(course['image']?.toString()),
      'course_thumbnail': await getCourseThumbnailUrl(course['course_thumbnail']?.toString()),
    };
  }
  
  /// Get all image URLs for a student
  static Future<Map<String, String>> getStudentImageUrls(Map<String, dynamic> student) async {
    return {
      'student_image': await getStudentImageUrl(student['image']?.toString()),
    };
  }
  
  /// Debug image loading status
  static void debugImageStatus(String type, String? imageUrl, String resolvedUrl) {
  }
}

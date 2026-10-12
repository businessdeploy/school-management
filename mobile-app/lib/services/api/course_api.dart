import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/url_manager.dart';
import '../../utils/response_validator.dart';
import '../../utils/dynamic_api_headers.dart';
import '../../config/app_config.dart';

class CourseApi {
  // Get course list
  static Future<Map<String, dynamic>> getCourseList(String studentId) async {
    try {
      final baseUrl = await UrlManager.getBaseUrl();
      if (baseUrl.isEmpty) {
        return {'status': 0, 'message': 'Base URL not configured', 'course_list': []};
      }

      final url = Uri.parse('$baseUrl/api/webservice/courselist');
      final headers = await DynamicApiHeaders.getCompleteHeaders();
      final body = jsonEncode({'student_id': studentId});

      final response = await http
          .post(url, headers: headers, body: body)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Request timed out after 30 seconds');
            },
          );

      if (response.statusCode == 200) {
        final cleanedBody = ResponseValidator.cleanJsonResponse(response.body);
        final data = jsonDecode(cleanedBody);
        return {
          'status': 1,
          'message': 'Success',
          'course_list': data['course_list'] ?? [],
        };
      } else {
        
        return {
          'status': 0,
          'message': 'Failed to load course list: ${response.statusCode}',
          'course_list': [],
        };
      }
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error loading course list: $e',
        'course_list': [],
      };
    }
  }

  // Get course details
  static Future<Map<String, dynamic>> getCourseDetails(
    String courseId,
    String studentId,
  ) async {
    final endpoints = [
      'getCourseDetail',
      'coursedetail',
      'course_detail',
      'getcoursedetail',
      'getCourseDetails',
      'coursedetails',
    ];

    for (final endpoint in endpoints) {
      try {
        final url = Uri.parse(await AppConfig.getApiEndpoint(endpoint));
        final headers = await DynamicApiHeaders.getCompleteHeaders();
        final body = jsonEncode({
          'course_id': courseId,
          'student_id': studentId,
        });

        final response = await http.post(url, headers: headers, body: body);

        if (response.statusCode == 200) {
          final cleanedBody = ResponseValidator.cleanJsonResponse(response.body);
          final data = ResponseValidator.validateAndParseJson(
            cleanedBody,
            'course',
          );
          return data;
        }
      } catch (_) {}
    }

    return {
      'status': 0,
      'message': 'Failed to load course details from all endpoints',
      'course': null,
    };
  }

  // Alias for backward compatibility
  static Future<Map<String, dynamic>> getCourseDetail(
    String courseId,
    String studentId,
  ) => getCourseDetails(courseId, studentId);

  // Get course reviews
  static Future<Map<String, dynamic>> getCourseReviews(String courseId) async {
    try {
      final baseUrl = await UrlManager.getBaseUrl();
      if (baseUrl.isEmpty) {
        return {'status': 0, 'message': 'Base URL not configured', 'reviews': []};
      }

      final url = Uri.parse('$baseUrl/api/webservice/coursereviews');
      final headers = await DynamicApiHeaders.getCompleteHeaders();
      final body = jsonEncode({'course_id': courseId});
      
      final curl = ResponseValidator.logAsCurl(url.toString(), headers, body);
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final cleanedBody = ResponseValidator.cleanJsonResponse(response.body);
        final data = jsonDecode(cleanedBody);
        
        // Include debug info for on-screen display
        if (data is Map<String, dynamic>) {
          data['debug_curl'] = curl;
          data['debug_raw_body'] = response.body;
        }
        
        return data;
      } else {
        
        return {
          'status': 0,
          'message': 'Failed to load course reviews: ${response.statusCode}',
          'reviews': [],
        };
      }
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error loading course reviews: $e',
        'reviews': [],
      };
    }
  }

  // Get course curriculum
  static Future<Map<String, dynamic>> getCourseCurriculum(
    String courseId,
    String? studentId,
  ) async {
    final endpoints = [
      'getCourseCurriculum',
      'coursecurriculum',
      'getcoursecurriculum',
      'course_curriculum',
      'getCourseCurriculums',
      'curriculum',
    ];

    for (final endpoint in endpoints) {
      try {
        final url = Uri.parse(await AppConfig.getApiEndpoint(endpoint));
        final headers = await DynamicApiHeaders.getCompleteHeaders();
        final body = jsonEncode({
          'course_id': courseId,
          if (studentId != null) 'student_id': studentId,
        });

        final curl = ResponseValidator.logAsCurl(url.toString(), headers, body);
        final response = await http.post(url, headers: headers, body: body);

        if (response.statusCode == 200) {
          final cleanedBody = ResponseValidator.cleanJsonResponse(response.body);
          final data = ResponseValidator.validateAndParseJson(
            cleanedBody,
            'curriculum',
          );
          data['debug_curl'] = curl;
          data['debug_raw_body'] = response.body;
          return data;
        }
      } catch (_) {}
    }

    return {
      'status': 0,
      'message': 'Failed to load course curriculum from all endpoints',
      'curriculum': [],
    };
  }


  // Add course rating
  static Future<Map<String, dynamic>> addCourseRating({
    required String courseId,
    required String studentId,
    required String rating,
    required String comment,
    String? reviewId,
  }) async {
    final endpoints = [
      'addCourseRatingandReview', // CRITICAL: Added as per user request
      'addCourseRating',
      'add_course_rating',
      'addcourserating',
      'saveCourseRating',
      'courseRating',
      'addCourseReview',
      'add_course_review',
      'rateCourse',
      'rate_course',
    ];

    for (final endpoint in endpoints) {
      try {
        final url = Uri.parse(await AppConfig.getApiEndpoint(endpoint));


        final headers = await DynamicApiHeaders.getCompleteHeaders();

        // Try different payload variants
        final payloads = [
          // CRITICAL: Exact payload format from user cURL
          {
            "review": comment,
            "course_id": courseId,
            "rating": rating,
            "student_id": studentId,
            "id": reviewId ?? "" // Required by some implementations
          },
          // Standard snake_case
          {
             'course_id': courseId,
             'student_id': studentId,
             'rating': rating,
             'comment': comment,
          },
          // Using 'review' instead of 'comment'
          {
             'course_id': courseId,
             'student_id': studentId,
             'rating': rating,
             'review': comment,
          },
          // Using 'rate' instead of 'rating' (like Teacher API)
          {
             'course_id': courseId,
             'student_id': studentId,
             'rate': rating,
             'comment': comment,
          },
          // Using 'rate' and 'review'
          {
             'course_id': courseId,
             'student_id': studentId,
             'rate': rating,
             'review': comment,
          },
          // CamelCase keys
          {
             'courseId': courseId,
             'studentId': studentId,
             'rating': rating,
             'comment': comment,
          },
           // Moodle/LMS style
          {
             'courseid': courseId,
             'userid': studentId,
             'rating': rating,
             'review': comment,
          },
        ];

        for (final payload in payloads) {
            final body = jsonEncode(payload);
            //  // Reduce log noise
            ResponseValidator.logAsCurl(url.toString(), headers, body);

            final response = await http.post(url, headers: headers, body: body);

            if (response.statusCode == 200) {
              try {
                  final cleanedBody = ResponseValidator.cleanJsonResponse(response.body);
                  final data = jsonDecode(cleanedBody);
                  
                  // Flexible success detection
                  final status = data['status'];
                  if (status == 1 || status == '1' || status == 'success' || (data['message']?.toString().toLowerCase().contains('success') ?? false)) {
                     return {'status': 1, 'message': data['message'] ?? 'Rating submitted successfully'};
                  }
                  return data;
              } catch(e) {
                  // If not JSON but 200 OK, assume success
                  return {'status': 1, 'message': 'Rating submitted successfully'};
              }
            }
        }
      } catch (_) {}
    }

    return {
      'status': 0,
      'message': 'Failed to add course rating (Error: endpoints unreachable)',
    };
  }

  // Update course progress (mark lesson as complete)
  static Future<Map<String, dynamic>> updateCourseProgress({
    required String courseId,
    required String studentId,
    required String lessonId,
    String? sectionId,
    String? lessonQuizType,
    int status = 1,
  }) async {
    final endpoints = [
      'markascomplete', // CRITICAL: Added as per user request
      'markLessonComplete',
      'updateCourseProgress',
      'course_progress',
      'mark_lesson_complete',
      'lessonComplete',
      'addLessonProgress',
      'update_class_lesson_completion',
    ];

    for (final endpoint in endpoints) {
      try {
        final url = Uri.parse(await AppConfig.getApiEndpoint(endpoint));


        final headers = await DynamicApiHeaders.getCompleteHeaders();

        // Try different payload variants
        final payloads = [
          // 0. EXACT format from user provided cURL (reference English course)
          {
            "student_id": studentId,
            "section_id": sectionId ?? "",
            "lesson_quiz_type": lessonQuizType ?? "1",
            "lesson_quiz_id": lessonId,
          },
          // 1. EXACT format from user PHP code ($data array)
          if (sectionId != null)
          {
            "student_id": studentId,
            "lesson_quiz_id": lessonId,
            "lesson_quiz_type": lessonQuizType ?? "1",
            "course_section_id": sectionId,
            "section_id": sectionId, 
            "course_id": courseId,
            "status": status.toString(),
          },
          // 2. Simple format from user example cURL
          if (sectionId != null)
          {
            "lesson_quiz_type": lessonQuizType ?? "1",
            "lesson_quiz_id": lessonId,
            "section_id": sectionId,
            "student_id": studentId,
            "status": status.toString(),
          },
          // 3. Variant with explicit status
          {
            'lesson_id': lessonId,
            'student_id': studentId,
            'status': status.toString(),
          },
        ];

        for (final payload in payloads) {
            final body = jsonEncode(payload);
            //  // Reduce log noise
            ResponseValidator.logAsCurl(url.toString(), headers, body);

            final response = await http.post(url, headers: headers, body: body);

            if (response.statusCode == 200) {
              try {
                  return jsonDecode(response.body);
              } catch(e) {
                   return {'status': 1, 'message': 'Progress updated successfully'};
              }
            }
        }
      } catch (_) {}
    }

    return {
      'status': 0,
      'message': 'Failed to update course progress (Error: endpoints unreachable)',
    };
  }

  // Get course quiz questions - specialized endpoint provided by user
  static Future<Map<String, dynamic>> getQuestionByQuizId(
    String studentId,
    String quizId,
  ) async {
    try {
      
      
      final url = Uri.parse(await AppConfig.getApiEndpoint('getquestionbyquizid'));
      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      final body = jsonEncode({
        'student_id': studentId,
        'quiz_id': quizId,
        'lesson_quiz_id': quizId, // Alias for backend compatibility
      });

      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        // Use global ResponseValidator to clean and parse
        final data = ResponseValidator.validateAndParseJson(response.body, 'questionlist');
        
        // Include debug info for on-screen display
        data['debug_curl'] = "curl -X POST \"$url\" -d '$body'";
        data['debug_raw_body'] = response.body;

        List<dynamic> questions = [];
        // CRITICAL: Prioritize 'questionlist' as confirmed in user's cURL output
        if (data['questionlist'] != null && data['questionlist'] is List) {
          questions = data['questionlist'];
        } else if (data['result'] != null && data['result'] is List) {
          questions = data['result'];
        } else if (data['data'] != null && data['data'] is List) {
          questions = data['data'];
        }
        
        return {
          'status': 1,
          'message': 'Success',
          'debug_curl': "curl -X POST \"$url\" -d '$body'",
          'debug_raw_body': response.body,
          'exam': {
            'questions': questions,
            'remaining_duration': '00:00:00',
            'descriptive': '0',
          },
        };
      } else {
        return {
          'status': 0,
          'message': 'API error: ${response.statusCode}',
          'debug_curl': "curl -X POST \"$url\" -d '$body'",
          'debug_raw_body': response.body,
          'exam': {'questions': []},
        };
      }
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error: $e',
        'debug_curl': 'Internal Error during request',
        'debug_raw_body': 'N/A',
        'exam': {'questions': []},
      };
    }
  }

  // Get lesson attachments
  static Future<Map<String, dynamic>> getLessonAttachments(String lessonId) async {
    try {
      final url = Uri.parse(await AppConfig.getApiEndpoint('get_lessonattachments_by_lessonid'));
      final headers = await DynamicApiHeaders.getCompleteHeaders();
      final body = jsonEncode({'lesson_id': lessonId});
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final cleanedBody = ResponseValidator.cleanJsonResponse(response.body);
        final data = jsonDecode(cleanedBody);
        return data;
      } else {
        return {
          'status': 0,
          'message': 'Failed to load attachments: ${response.statusCode}',
          'attachments': [],
        };
      }
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error loading attachments: $e',
        'attachments': [],
      };
    }
  }
  // Submit Course Assignment
  static Future<Map<String, dynamic>> addCourseAssignmentSubmission({
    required String studentId,
    required String assignmentId,
    required String message,
    String? filePath,
  }) async {
    try {
      final baseUrl = await UrlManager.getBaseUrl();
      final url = Uri.parse('$baseUrl/api/webservice/saveCourseAssignment');

      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      // Add session cookie if available
      final request = http.MultipartRequest('POST', url);
      
      // Add headers (excluding Content-Type which will be set by multipart)
      headers.forEach((key, value) {
        if (key != 'Content-Type') {
          request.headers[key] = value;
        }
      });

      request.fields['student_id'] = studentId;
      request.fields['assignmentid'] = assignmentId;
      request.fields['assignment_id'] = assignmentId; // Fallback
      request.fields['message'] = message;

      if (filePath != null && filePath.isNotEmpty) {
        request.files.add(await http.MultipartFile.fromPath('file', filePath));
      }

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200) {
        final cleanedBody = ResponseValidator.cleanJsonResponse(responseBody);
        final data = jsonDecode(cleanedBody);
        return data;
      } else {
        return {
          'status': 0,
          'message': 'Failed to submit assignment: ${streamedResponse.statusCode}',
        };
      }
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error submitting assignment: $e',
      };
    }
  }

  // Download Course Certificate
  static Future<Map<String, dynamic>> downloadCertificate({
    required String studentId,
    required String courseId,
    required String certificateId,
  }) async {
    if (studentId.isEmpty || courseId.isEmpty || certificateId.isEmpty || certificateId == 'null') {
      return {
        'status': 0,
        'message': 'Missing required information (IDs) to generate certificate',
      };
    }

    try {
      final baseUrl = await UrlManager.getBaseUrl();
      // Endpoint: coursedownloadcertificatepdf/{certificate_id}/{student_id}/{course_id}
      final url = Uri.parse('$baseUrl/api/webservice/coursedownloadcertificatepdf/$certificateId/$studentId/$courseId');

      // Use minimal headers for this specific call to match the working cURL exactly
      final headers = await DynamicApiHeaders.getCompleteHeaders();

      final response = await http.post(url, headers: headers, body: '');

      if (response.statusCode == 200) {
        final contentType = response.headers['content-type']?.toLowerCase() ?? '';
        if (contentType.contains('application/json')) {
          final data = jsonDecode(response.body);
          return data;
        } else {
          // If not JSON, it might be the PDF stream itself or raw text
          return {
            'status': 1,
            'is_stream': true,
            'message': 'Success (Stream)',
            'raw_body_bytes': response.bodyBytes,
          };
        }
      } else {
        return {
          'status': 0,
          'message': 'Failed to generate certificate: ${response.statusCode}',
        };
      }
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error generating certificate: $e',
      };
    }
  }

  // Delete Course Certificate File from Server
  static Future<Map<String, dynamic>> deleteCertificateFile(String fileName) async {
    try {
      final baseUrl = await UrlManager.getBaseUrl();
      final url = Uri.parse('$baseUrl/api/webservice/deleteCertificateFile/$fileName');

      final headers = await DynamicApiHeaders.getCompleteHeaders();

      final response = await http.post(url, headers: headers);

      if (response.statusCode == 200) {
        try {
          return jsonDecode(response.body);
        } catch (_) {
          return {'status': 1, 'message': 'Success (Non-JSON response)'};
        }
      } else {
        return {
          'status': 0,
          'message': 'Failed to delete server file: ${response.statusCode}',
        };
      }
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error deleting server file: $e',
      };
    }
  }
}





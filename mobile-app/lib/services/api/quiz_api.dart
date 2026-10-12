import 'dart:convert';
import 'package:http/http.dart' as http;
import '../auth_service.dart';
import '../../utils/url_manager.dart';
import '../../utils/dynamic_api_headers.dart';
import '../../utils/response_validator.dart';

class QuizApi {
  // API-1: Get Course Curriculum with Quiz IDs
  static Future<Map<String, dynamic>> getCourseCurriculum({
    required String courseId,
    required String studentId,
  }) async {
    try {
      final baseUrl = await UrlManager.getBaseUrl();
      if (baseUrl.isEmpty) {
        return {'status': 0, 'message': 'No base URL configured'};
      }

      final url = Uri.parse('$baseUrl/api/webservice/coursecurriculum');
      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      final body = jsonEncode({
        'course_id': courseId,
        'student_id': studentId,
      });

      final response = await http.post(
        url,
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        try {
          final cleanedBody = ResponseValidator.cleanJsonResponse(response.body);
          final jsonData = jsonDecode(cleanedBody);
          
          List<Map<String, dynamic>> quizList = [];
          
          if (jsonData['sectionList'] != null) {
            final sectionList = jsonData['sectionList'] as List;
            
            for (var section in sectionList) {
              if (section is Map && section['lesson_quiz'] != null) {
                final lessonQuiz = section['lesson_quiz'] as List;
                
                for (var quiz in lessonQuiz) {
                  if (quiz is Map && quiz['quiz_id'] != null) {
                    quizList.add({
                      'quiz_id': quiz['quiz_id'].toString(),
                      'quiz_title': quiz['quiz_title']?.toString() ?? 'Untitled Quiz',
                      'section_name': section['section_name']?.toString() ?? 'Unknown Section',
                      'course_id': courseId,
                    });
                  }
                }
              }
            }
          }

          return {
            'status': 1,
            'message': 'Course curriculum fetched successfully',
            'quiz_list': quizList,
            'raw_response': jsonData,
          };
        } catch (e) {
          return {
            'status': 0,
            'message': 'Error parsing course curriculum',
            'raw_response': response.body,
          };
        }
      } else {
        return {
          'status': 0,
          'message': 'Failed to fetch course curriculum',
          'error': response.body,
        };
      }
    } catch (e) {
      return {
        'status': 0,
        'message': 'Connection error: $e',
      };
    }
  }

  // API-2: Get Questions by Quiz ID (SINGLE SOURCE OF TRUTH)
  static Future<Map<String, dynamic>> getQuestionsByQuizId({
    required String quizId,
    required String studentId,
  }) async {
    return _fetchQuestions(
      urlPath: 'api/webservice/getquestionbyquizid',
      payload: {'quiz_id': quizId, 'student_id': studentId},
      logPrefix: '🎯',
    );
  }

  // API-3: Get Online Course Question (New API for Exam Questions)
  static Future<Map<String, dynamic>> getOnlineCourseQuestion({
    required String examId,
    required String studentId,
  }) async {
    return _fetchQuestions(
      urlPath: 'api/webservice/getOnlineCourseQuestion',
      payload: {
        'user_type': 'student',
        'student_id': studentId,
        'exam_id': examId,
      },
      logPrefix: '📝',
      isExamApi: true,
    );
  }

  // Refactored helper to avoid duplication
  static Future<Map<String, dynamic>> _fetchQuestions({
    required String urlPath,
    required Map<String, dynamic> payload,
    required String logPrefix,
    bool isExamApi = false,
  }) async {
    try {
      final baseUrl = await UrlManager.getBaseUrl();
      if (baseUrl.isEmpty) {
        return {'status': 0, 'message': 'No base URL configured'};
      }

      final url = Uri.parse('$baseUrl$urlPath');
      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        try {
          final cleanedBody = ResponseValidator.cleanJsonResponse(response.body);
          final jsonData = jsonDecode(cleanedBody);
          
          List<Map<String, dynamic>> questions = [];
          
          List<dynamic> questionsList = [];
          if (isExamApi) {
             if (jsonData['result'] != null && jsonData['result']['question_list'] != null) {
                questionsList = jsonData['result']['question_list'];
             } else if (jsonData['data'] != null) {
                questionsList = jsonData['data'] is List ? jsonData['data'] : [];
             } else {
                questionsList = jsonData['questions'] ?? [];
             }
          } else {
             questionsList = jsonData['questions'] ?? [];
          }
          
          for (var question in questionsList) {
            if (question is Map) {
              questions.add({
                'question_id': question['question_id']?.toString() ?? question['id']?.toString() ?? '',
                'question_text': question['question']?.toString() ?? question['question_text']?.toString() ?? '',
                'question_type': question['question_type']?.toString() ?? 'multiple_choice',
                'options': question['options'] ?? [],
                'correct_answer': question['correct_answer']?.toString() ?? '',
                'marks': double.tryParse(question['marks']?.toString() ?? '0') ?? 0.0,
              });
            }
          }

          return {
            'status': 1,
            'message': 'Questions fetched successfully',
            'questions': questions,
            'raw_response': jsonData,
          };
        } catch (e) {
           return {
            'status': 0,
            'message': 'Error parsing questions',
            'raw_response': response.body,
          };
        }
      } else {
         return {
          'status': 0,
          'message': 'Failed to fetch questions: ${response.statusCode}',
        };
      }
    } catch (e) {
       return {
        'status': 0,
        'message': 'Connection error: $e',
      };
    }
  }

  // Submit Quiz Answers
  static Future<Map<String, dynamic>> submitQuizAnswers({
    required String quizId,
    required String studentId,
    required List<Map<String, dynamic>> rows,
  }) async {
    try {
      final baseUrl = await UrlManager.getBaseUrl();
      if (baseUrl.isEmpty) {
        return {'status': 0, 'message': 'No base URL configured'};
      }

      final url = Uri.parse('$baseUrl/api/webservice/submitquiz');
      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      final body = jsonEncode({
        'quiz_id': quizId,
        'student_id': studentId,
        'rows': rows,
        'submission_time': DateTime.now().toIso8601String(),
      });

      final response = await http.post(
        url,
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        try {
          final cleanedBody = ResponseValidator.cleanJsonResponse(response.body);
          final jsonData = jsonDecode(cleanedBody);
          
          return {
            'status': jsonData['status'] ?? 1,
            'message': jsonData['message'] ?? 'Quiz submitted successfully',
            'result': jsonData['result'] ?? {},
            'score': jsonData['score'] ?? 0,
            'total_marks': jsonData['total_marks'] ?? 0,
            'percentage': jsonData['percentage'] ?? 0,
            'raw_response': jsonData,
          };
        } catch (e) {
          return {
            'status': 0,
            'message': 'Error parsing submission response',
            'raw_response': response.body,
          };
        }
      } else {
        return {
          'status': 0,
          'message': 'Failed to submit quiz',
          'error': response.body,
        };
      }
    } catch (e) {
      return {
        'status': 0,
        'message': 'Connection error: $e',
      };
    }
  }

  // Get Quiz Results
  static Future<Map<String, dynamic>> getQuizResults({
    required String quizId,
    required String studentId,
  }) async {
    try {
      final baseUrl = await UrlManager.getBaseUrl();
      if (baseUrl.isEmpty) {
        return {'status': 0, 'message': 'No base URL configured'};
      }

      final url = Uri.parse('$baseUrl/api/webservice/quizresults');
      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      final body = jsonEncode({
        'quiz_id': quizId,
        'student_id': studentId,
      });

      final response = await http.post(
        url,
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        try {
          final cleanedBody = ResponseValidator.cleanJsonResponse(response.body);
          final jsonData = jsonDecode(cleanedBody);
          
          return {
            'status': jsonData['status'] ?? 1,
            'message': jsonData['message'] ?? 'Results fetched successfully',
            'result': jsonData['result'] ?? {},
            'raw_response': jsonData,
          };
        } catch (e) {
          return {
            'status': 0,
            'message': 'Error parsing results',
            'raw_response': response.body,
          };
        }
      } else {
        return {
          'status': 0,
          'message': 'Failed to fetch results',
          'error': response.body,
        };
      }
    } catch (e) {
      return {
        'status': 0,
        'message': 'Connection error: $e',
      };
    }
  }

  // API-5: Save Online Course Exam
  static Future<Map<String, dynamic>> saveOnlineCourseExam({
    required String examId,
    required String studentId,
    String usertype = 'student',
    String guestId = '0',
    List<Map<String, dynamic>>? rows,
  }) async {
    try {
      final baseUrl = await UrlManager.getBaseUrl();
      if (baseUrl.isEmpty) {
        return {'status': 0, 'message': 'No base URL configured'};
      }

      final url = Uri.parse('$baseUrl/api/webservice/saveOnlineCourseExam');
      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      // Match exact keys from user's cURL
      final Map<String, dynamic> bodyMap = {
        'student_id': studentId,
        'guest_id': guestId,
        'usertype': usertype,
        'exam_id': examId,
        'rows': rows ?? [],
      };

      final body = jsonEncode(bodyMap);

      final response = await http.post(
        url,
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        try {
          final cleanedBody = ResponseValidator.cleanJsonResponse(response.body);
          final jsonData = jsonDecode(cleanedBody);
          return {
            'status': jsonData['status'] ?? 1,
            'message': jsonData['message'] ?? 'Exam saved successfully',
            'raw_response': jsonData,
          };
        } catch (e) {
          return {
            'status': 0,
            'message': 'Error parsing response',
            'raw_response': response.body,
          };
        }
      } else {
        return {
          'status': 0,
          'message': 'Failed to save exam: ${response.statusCode}',
          'error': response.body,
        };
      }
    } catch (e) {
      return {
        'status': 0,
        'message': 'Connection error: $e',
      };
    }
  }
}

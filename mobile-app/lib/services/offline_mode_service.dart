
class OfflineModeService {
  static bool _isOfflineMode = false;
  
  static bool get isOfflineMode => _isOfflineMode;
  
  static void enableOfflineMode() {
    _isOfflineMode = true;
  }
  
  static void disableOfflineMode() {
    _isOfflineMode = false;
  }
  
  /// Get mock data for different modules
  static Map<String, dynamic> getMockData(String moduleName) {
    switch (moduleName) {
      case 'attendance':
        return {
          'status': 1,
          'message': 'Success (Offline Mode)',
          'data': [
            {'date': '2025-01-15', 'type': 'Present'},
            {'date': '2025-01-16', 'type': 'Present'},
            {'date': '2025-01-17', 'type': 'Late'},
            {'date': '2025-01-18', 'type': 'Present'},
            {'date': '2025-01-19', 'type': 'Absent'},
          ]
        };
        
      case 'examination':
        return {
          'status': 1,
          'message': 'Success (Offline Mode)',
          'exams': [
            {
              'id': '1',
              'exam_name': 'Mid Term Exam',
              'exam_date': '2025-02-15',
              'subject': 'Mathematics',
              'status': 'Upcoming'
            },
            {
              'id': '2', 
              'exam_name': 'Final Exam',
              'exam_date': '2025-03-20',
              'subject': 'Science',
              'status': 'Upcoming'
            }
          ]
        };
        
      case 'homework':
        return {
          'status': 1,
          'message': 'Success (Offline Mode)',
          'homeworklist': [
            {
              'id': '1',
              'title': 'Math Assignment',
              'subject': 'Mathematics',
              'due_date': '2025-01-20',
              'status': 'Pending'
            },
            {
              'id': '2',
              'title': 'Science Project',
              'subject': 'Science', 
              'due_date': '2025-01-25',
              'status': 'Completed'
            }
          ]
        };
        
      case 'timetable':
        return {
          'status': 1,
          'message': 'Success (Offline Mode)',
          'timetable': {
            'Monday': [
              {
                'subject': 'Mathematics',
                'time': '9:00 AM - 10:00 AM',
                'teacher': 'Mr. Smith',
                'room': 'Room 101'
              },
              {
                'subject': 'Science',
                'time': '10:00 AM - 11:00 AM', 
                'teacher': 'Ms. Johnson',
                'room': 'Room 102'
              }
            ],
            'Tuesday': [
              {
                'subject': 'English',
                'time': '9:00 AM - 10:00 AM',
                'teacher': 'Mr. Brown',
                'room': 'Room 103'
              }
            ]
          }
        };
        
      case 'lesson_plan':
        return {
          'status': 1,
          'message': 'Success (Offline Mode)',
          'timetable': {
            'Monday': [
              {
                'subject': 'Mathematics',
                'topic': 'Algebra Basics',
                'time': '9:00 AM - 10:00 AM',
                'description': 'Introduction to algebraic expressions'
              }
            ]
          }
        };
        
      case 'syllabus':
        return {
          'status': 1,
          'message': 'Success (Offline Mode)',
          'data': {
            'subjects': [
              {
                'subject_group_subject_id': '142',
                'subject_name': 'Mathematics',
                'subject_code': '101',
                'total': '10',
                'total_complete': '5'
              },
              {
                'subject_group_subject_id': '143',
                'subject_name': 'Science',
                'subject_code': '102', 
                'total': '8',
                'total_complete': '3'
              }
            ]
          }
        };
        
      case 'student_behaviour':
        return {
          'status': 1,
          'message': 'Success (Offline Mode)',
          'behaviour_records': [
            {
              'id': '1',
              'date': '2025-01-15',
              'incident': 'Good behavior in class',
              'type': 'Positive',
              'points': '+5'
            }
          ]
        };
        
      case 'documents':
        return {
          'status': 1,
          'message': 'Success (Offline Mode)',
          'documents': [
            {
              'id': '1',
              'title': 'Report Card',
              'type': 'PDF',
              'upload_date': '2025-01-15'
            }
          ]
        };
        
      case 'notice_board':
        return {
          'status': 1,
          'message': 'Success (Offline Mode)',
          'data': [
            {
              'id': '1',
              'title': 'School Holiday Notice',
              'message': 'School will be closed on Monday for maintenance',
              'date': '2025-01-20'
            }
          ]
        };
        
      default:
        return {
          'status': 1,
          'message': 'Success (Offline Mode)',
          'data': []
        };
    }
  }
}


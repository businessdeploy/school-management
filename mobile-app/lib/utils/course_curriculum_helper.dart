class CourseCurriculumHelper {
  /// Builds a basic curriculum list that mirrors the Smart School demo data.
  /// Used when the curriculum API is unavailable.
  static List<Map<String, dynamic>> buildFallbackCurriculum({
    String? courseTitle,
  }) {
    final title = (courseTitle != null && courseTitle.isNotEmpty)
        ? courseTitle
        : 'Math Fundamentals';

    return [
      {
        'section': 'Section 1: $title Course',
        'items': [
          {'type': 'lesson', 'title': '$title Course', 'duration': '02:30:00'},
          {'type': 'quiz', 'title': 'Mathematic Quiz'},
          {'type': 'exam', 'title': 'Mathematic Exam'},
          {'type': 'assignment', 'title': 'Mathematic Rule Assignment'},
        ],
      },
      {
        'section': 'Section 2: Order of Operations - PEMDAS',
        'items': [
          {
            'type': 'lesson',
            'title': 'Order of Operations - PEMDAS',
            'duration': '02:30:00',
          },
        ],
      },
    ];
  }
}

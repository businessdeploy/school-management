import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/translated_text.dart';

class ExamResultPage extends StatefulWidget {
  final String examId;
  final String examName;

  const ExamResultPage({
    super.key,
    required this.examId,
    required this.examName,
  });

  @override
  State<ExamResultPage> createState() => _ExamResultPageState();
}

class _ExamResultPageState extends State<ExamResultPage> {
  Map<String, dynamic>? examResult;
  Map<String, dynamic>? fullApiResponse; // Store full API response for consolidated data
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadExamResult();
  }

  Future<void> _loadExamResult() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final studentId = await AuthService.getStudentId();

      final response = await ApiService.getExamResult(studentId, widget.examId);
      
      if (!mounted) return;
      
      // Store full API response for consolidated data access
      fullApiResponse = Map<String, dynamic>.from(response);
      
      
      
      
      
      
      // Check for exam first (as per API spec), then result, then data
      Map<String, dynamic>? resultData;
      if (response['exam'] != null && response['exam'] is Map) {
        resultData = Map<String, dynamic>.from(response['exam']);
        
      } else if (response['result'] != null && response['result'] is Map) {
        resultData = Map<String, dynamic>.from(response['result']);
        
      } else if (response['data'] != null && response['data'] is Map) {
        resultData = Map<String, dynamic>.from(response['data']);
        
      }
      
      // Check for consolidated data immediately after loading
      final hasConsolidated = _hasConsolidatedData();
      
      
      setState(() {
        examResult = resultData;
        isLoading = false;
        if (resultData == null && response['status'] != 1 && response['status'] != '200') {
          error = response['message'] ?? 'Failed to load exam result';
        }
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  // API-DRIVEN: Check for consolidated data ONLY from API response
  bool _hasConsolidatedData() {
    if (fullApiResponse == null) {
      
      return false;
    }
    
    
    
    
    
    
    // Check for consolidated_exam_result with exam_array (as per API structure)
    final consolidatedExamResult = fullApiResponse!['consolidated_exam_result'];
    if (consolidatedExamResult != null) {
      
      
      
      if (consolidatedExamResult is Map) {
        
        final examArray = consolidatedExamResult['exam_array'];
        if (examArray != null && examArray is List && examArray.isNotEmpty) {
          
          return true;
        }
      } else if (consolidatedExamResult is List && consolidatedExamResult.isNotEmpty) {
        
        return true;
      }
    }
    
    // Check for exam_array at root level
    if (fullApiResponse!['exam_array'] != null && 
        fullApiResponse!['exam_array'] is List && 
        (fullApiResponse!['exam_array'] as List).isNotEmpty) {
      
      return true;
    }
    
    // Check for consolidated data in exam result
    if (examResult != null) {
      if (examResult!.containsKey('consolidated_exam_result') ||
          examResult!.containsKey('exam_array') ||
          examResult!.containsKey('consolidated')) {
        
        return true;
      }
    }
    
    // Also check root level for consolidated percentage (indicates consolidation exists)
    if (fullApiResponse!.containsKey('percentage') && 
        (fullApiResponse!.containsKey('consolidated_exam_result') ||
         fullApiResponse!.containsKey('exam_array') ||
         fullApiResponse!.containsKey('consolidate_percentage'))) {
      
      return true;
    }
    
    // Check for consolidate_percentage or consolidate_marks
    if (fullApiResponse!.containsKey('consolidate_percentage') ||
        fullApiResponse!.containsKey('consolidate_marks') ||
        fullApiResponse!.containsKey('consolidate_grade')) {
      
      return true;
    }
    
    
    
    return false;
  }

  // API-DRIVEN: Get consolidated exam array ONLY from API response
  List<Map<String, dynamic>> _getConsolidatedExamArray() {
    if (fullApiResponse == null) {
      
      return [];
    }
    
    
    
    // Extract from consolidated_exam_result.exam_array (as per API structure)
    final consolidatedExamResult = fullApiResponse!['consolidated_exam_result'];
    if (consolidatedExamResult != null) {
      if (consolidatedExamResult is Map) {
        final examArray = consolidatedExamResult['exam_array'];
        if (examArray != null && examArray is List) {
          
          return examArray.map((item) {
            if (item is Map) {
              return Map<String, dynamic>.from(item);
            }
            return <String, dynamic>{};
          }).toList();
        }
      } else if (consolidatedExamResult is List) {
        
        return consolidatedExamResult.map((item) {
          if (item is Map) {
            return Map<String, dynamic>.from(item);
          }
          return <String, dynamic>{};
        }).toList();
      }
    }
    
    // Check for exam_array at root level
    if (fullApiResponse!['exam_array'] != null && fullApiResponse!['exam_array'] is List) {
      final examArray = fullApiResponse!['exam_array'] as List;
      
      return examArray.map((item) {
        if (item is Map) {
          return Map<String, dynamic>.from(item);
        }
        return <String, dynamic>{};
      }).toList();
    }
    
    // Check in exam result
    if (examResult != null) {
      if (examResult!['consolidated_exam_result'] != null && examResult!['consolidated_exam_result'] is Map) {
        final consolidated = examResult!['consolidated_exam_result'] as Map;
        if (consolidated['exam_array'] != null && consolidated['exam_array'] is List) {
          final examArray = consolidated['exam_array'] as List;
          
          return examArray.map((item) {
            if (item is Map) {
              return Map<String, dynamic>.from(item);
            }
            return <String, dynamic>{};
          }).toList();
        }
      }
      if (examResult!['exam_array'] != null && examResult!['exam_array'] is List) {
        final examArray = examResult!['exam_array'] as List;
        
        return examArray.map((item) {
          if (item is Map) {
            return Map<String, dynamic>.from(item);
          }
          return <String, dynamic>{};
        }).toList();
      }
    }
    
    
    return [];
  }

  // Calculate consolidated result from the list of exams
  Map<String, dynamic> _calculateConsolidatedFromExamList(
    List<Map<String, dynamic>> examList, {
    double? baseMaxMarks,
  }) {
    double totalObtained = 0;
    double totalMax = 0;
    
    

    for (var exam in examList) {
      String obtainedStr = exam['get_marks']?.toString() ?? 
                           exam['marks_obtained']?.toString() ?? 
                           exam['percentage']?.toString() ?? 
                           exam['weighted_score']?.toString() ?? '0';
      
      String weightStr = exam['weight']?.toString() ?? 
                         exam['weightage']?.toString() ?? '0';
      
      String maxStr = exam['max_marks']?.toString() ?? '';

      double obtained = double.tryParse(obtainedStr) ?? 0;
      double weight = double.tryParse(weightStr) ?? 0;
      double max = double.tryParse(maxStr) ?? (baseMaxMarks ?? 100);
      
      

      if (weight > 0) {
        totalObtained += obtained;
        totalMax += (max * weight) / 100;
      } else {
        totalObtained += obtained;
        totalMax += max;
      }
    }

    if (totalMax == 0 && totalObtained > 0) totalMax = baseMaxMarks ?? 100;
    
    
    
    double percentageValue = (totalMax > 0) ? (totalObtained / totalMax * 100) : 0;
    String percentage = percentageValue.toStringAsFixed(2);
    
    // Determine Division
    String division = '';
    if (percentageValue >= 60) division = 'First';
    else if (percentageValue >= 45) division = 'Second';
    else if (percentageValue >= 33) division = 'Third';
    else division = 'Fail';
    
    String status = percentageValue >= 33 ? 'Pass' : 'Fail';

    return {
      'percentage': percentage,
      'division': division,
      'result': status,
      'total_max_marks': totalMax,
      'total_get_marks': totalObtained,
    };
  }


  // Client-side calculation fallback
  Map<String, dynamic> _calculateConsolidatedResult(Map<String, dynamic> data) {
    double totalObtained = 0;
    double totalMax = 0;
    bool anyFail = false;

    // Calculate from subject list
    if (data['subject_result'] != null && data['subject_result'] is List) {
       final subjectResults = data['subject_result'] as List;
       for (var subject in subjectResults) {
          if (subject is Map) {
             final obtainedStr = subject['get_marks']?.toString() ?? '0';
             final maxStr = subject['max_marks']?.toString() ?? '0';
             final minStr = subject['min_marks']?.toString() ?? '0';
             
             // Check if absent
             final isAbsent = subject['attendence']?.toString().toLowerCase() == 'absent';
             
             if (!isAbsent) {
               final obtained = double.tryParse(obtainedStr) ?? 0;
               final max = double.tryParse(maxStr) ?? 0;
               final min = double.tryParse(minStr) ?? 0;
               
               totalObtained += obtained;
               totalMax += max;
               
               if (obtained < min) {
                  anyFail = true;
               }
             } else {
               // If absent, add max marks to total but 0 to obtained? 
               // usually yes, or skip? Assuming add to max.
               final max = double.tryParse(maxStr) ?? 0;
               totalMax += max;
               anyFail = true; // Absent usually means fail or zero
             }
          }
       }
    }

    String percentage = '0.00';
    if (totalMax > 0) {
       percentage = ((totalObtained / totalMax) * 100).toStringAsFixed(2);
    }
    
    double marksPerc = double.tryParse(percentage) ?? 0;
    String division = '';
    if (marksPerc >= 60) {
       division = 'First';
    } else if (marksPerc >= 50) {
       division = 'Second';
    } else if (marksPerc >= 33) {
       division = 'Third';
    } else {
       division = 'Fail';
    }
    
    String status = 'Pass';
    if (anyFail) status = 'Fail';
    if (marksPerc < 33) status = 'Fail';

    return {
       'total_max_marks': totalMax,
       'total_get_marks': totalObtained,
       'percentage': percentage,
       'division': division,
       'exam_result_status': status,
       'result': status,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const TranslatedText(
          'Exam Result',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.grey[800],
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // Header with illustration
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
                    child: Row(
                      children: [
                        const Expanded(
                          child: const TranslatedText(
                            'Your Exam Result is here!',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 120,
                          height: 100,
                          child: _buildResultIllustration(),
                        ),
                      ],
                    ),
                  ),

                  // Exam Result Content
                  Expanded(
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
                                      color: Colors.red[300],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Failed to load exam result',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.red[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      error!,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.red[400],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: _loadExamResult,
                                      child: const TranslatedText('Retry'),
                                    ),
                                  ],
                                ),
                              )
                            : examResult == null
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.assessment_outlined,
                                          size: 64,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(height: 16),
                                        TranslatedText(
                                          'No result found',
                                          style: TextStyle(
                                            fontSize: 18,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        TranslatedText(
                                          'Result will be available after the exam',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : SingleChildScrollView(
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    child: Column(
                                      children: [
                                        _buildExamHeader(),
                                        const SizedBox(height: 20),
                                        _buildSubjectResults(),
                                        const SizedBox(height: 20),
                                        _buildOverallResult(),
                                        const SizedBox(height: 20),
                                      ],
                                    ),
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

  Widget _buildExamHeader() {
    final examName = examResult!['exam'] ?? widget.examName;
    final hasConsolidated = _hasConsolidatedData();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              examName.toString().toUpperCase(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (hasConsolidated) ...[
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () => _showConsolidatedResult(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const TranslatedText(
                'Consolidated Result',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubjectResults() {
    final subjectResults = examResult!['subject_result'] ?? [];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TranslatedText(
                    'Subject',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: TranslatedText(
                    'Min Marks',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: TranslatedText(
                    'Marks Obtained',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: TranslatedText(
                    'Result',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: TranslatedText(
                    'Note',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          
          // Table Rows
          ...subjectResults.map<Widget>((subject) => _buildSubjectResultRow(subject)).toList(),
        ],
      ),
    );
  }

  Widget _buildSubjectResultRow(Map<String, dynamic> subject) {
    final name = subject['name'] ?? 'Unknown Subject';
    final code = subject['code'] ?? '';
    final maxMarks = subject['max_marks']?.toString() ?? '0';
    final minMarks = subject['min_marks']?.toString() ?? '0';
    final getMarks = subject['get_marks']?.toString() ?? '0';
    final note = subject['note']?.toString() ?? '';

    final marksObtained = double.tryParse(getMarks.toString()) ?? 0.0;
    final minMarksValue = double.tryParse(minMarks.toString()) ?? 0.0;
    final isPass = marksObtained >= minMarksValue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.toString(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                if (code.toString().isNotEmpty)
                  Text(
                    '($code)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              minMarks,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              '${(double.tryParse(getMarks.toString()) ?? 0.0).toStringAsFixed(2)}/${(double.tryParse(maxMarks.toString()) ?? 0.0).toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: isPass ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TranslatedText(
                  isPass ? 'PASS' : 'FAIL',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  softWrap: false,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              note,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallResult() {
    // Try to get values from API
    dynamic totalMaxMarks = examResult!['total_max_marks'];
    dynamic totalGetMarks = examResult!['total_get_marks'];
    String percentage = examResult!['percentage']?.toString() ?? '';
    String division = examResult!['division']?.toString() ?? '';
    final rank = examResult!['rank']?.toString() ?? '';
    String resultStatus = examResult!['exam_result_status']?.toString() ?? '';

    // Calculate locally if values are missing
    if (percentage.isEmpty || percentage == '0' || division.isEmpty || 
        totalMaxMarks == null || totalMaxMarks == 0) {
      
      final calculated = _calculateConsolidatedResult(examResult!);
      
      if (percentage.isEmpty || percentage == '0') {
        percentage = calculated['percentage']?.toString() ?? '0.00';
      }
      if (division.isEmpty) {
        division = calculated['division']?.toString() ?? '';
      }
      if (resultStatus.isEmpty) {
        resultStatus = calculated['exam_result_status']?.toString() ?? '';
      }
      if (totalMaxMarks == null || totalMaxMarks == 0 || totalMaxMarks.toString() == '0') {
        totalMaxMarks = calculated['total_max_marks'];
      }
      if (totalGetMarks == null || totalGetMarks == 0 || totalGetMarks.toString() == '0') {
        totalGetMarks = calculated['total_get_marks'];
      }
    }


    final isPass = resultStatus.toLowerCase() == 'pass';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          _buildSummaryRow('Grand Total', '$totalGetMarks/$totalMaxMarks'),
          const SizedBox(height: 12),
          _buildSummaryRow('Percentage', percentage),
          const SizedBox(height: 12),
          _buildSummaryRow('Division', division.toUpperCase()),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const TranslatedText(
                'Result',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: isPass ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TranslatedText(
                  resultStatus.isNotEmpty ? resultStatus.toUpperCase() : 'RESULT',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSummaryRow('Rank', rank),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TranslatedText(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  // API-DRIVEN: Show consolidated result popup using ONLY API data
  void _showConsolidatedResult() {
    if (fullApiResponse == null) {
      
      return;
    }

    // Extract consolidated exam array from API
    final consolidatedExamArray = _getConsolidatedExamArray();
    
    // Extract consolidated data (Percentage, Division, Result)
    // First, try to find the consolidated_exam_result object
    Map<String, dynamic>? consolidatedData;
    Map<String, dynamic>? consolidatedSummaryData;
    
    // Check in fullApiResponse (root or data)
    if (fullApiResponse!['consolidated_exam_result'] != null && fullApiResponse!['consolidated_exam_result'] is Map) {
      consolidatedData = fullApiResponse!['consolidated_exam_result'] as Map<String, dynamic>;
    } 
    // Check in fullApiResponse['data'] (Critical path based on logs)
    else if (fullApiResponse!['data'] != null && fullApiResponse!['data'] is Map) {
      final dataMap = fullApiResponse!['data'] as Map<String, dynamic>;
      if (dataMap['consolidated_exam_result'] != null && dataMap['consolidated_exam_result'] is Map) {
        consolidatedData = dataMap['consolidated_exam_result'] as Map<String, dynamic>;
        
      }
    }
    // Check in examResult (which is usually data or data['exam'])
    else if (examResult != null && examResult!['consolidated_exam_result'] != null && examResult!['consolidated_exam_result'] is Map) {
      consolidatedData = examResult!['consolidated_exam_result'] as Map<String, dynamic>;
    }
    
    if (consolidatedData != null) {
      // Look for a nested summary map (common in latest Smart School versions)
      if (consolidatedData['consolidate_result'] != null && consolidatedData['consolidate_result'] is Map) {
        consolidatedSummaryData = consolidatedData['consolidate_result'] as Map<String, dynamic>;
        
      } else if (consolidatedData['result'] != null && consolidatedData['result'] is Map) {
        consolidatedSummaryData = consolidatedData['result'] as Map<String, dynamic>;
      }
    }
    
    // Debug helper - if still null, print top level keys to help debugging
    if (consolidatedData == null) {
       
       
       if (examResult != null) {
         
       }
       // Fallback: Check if consolidated result fields exist directly in fullApiResponse
       if (fullApiResponse?.containsKey('consolidated_result') == true || fullApiResponse?.containsKey('result') == true) {
         
         consolidatedData = fullApiResponse;
       }
    } else {
       
    }
    
    
    if (consolidatedData != null) {
       
       // 
    }
    if (consolidatedSummaryData != null) {
       
       
    }

    // Extract Grade (NEW) - Check summary data first
    String grade = consolidatedSummaryData?['grade']?.toString() ?? 
                  consolidatedSummaryData?['consolidate_grade']?.toString() ?? 
                  fullApiResponse!['consolidate_grade']?.toString() ?? 
                  fullApiResponse!['consolidated_grade']?.toString() ?? 
                  fullApiResponse!['grade']?.toString() ?? '';
                  
    if (grade.isEmpty && consolidatedData != null) {
      grade = consolidatedData['consolidate_grade']?.toString() ?? 
              consolidatedData['grade']?.toString() ?? '';
    }

    // Extract Division (More Keys) - Check summary data first
    String division = consolidatedSummaryData?['division']?.toString() ?? 
                     fullApiResponse!['division']?.toString() ?? 
                     fullApiResponse!['consolidate_division']?.toString() ??
                     fullApiResponse!['consolidated_division']?.toString() ?? '';
                     
    if (division.isEmpty && consolidatedData != null) {
      division = consolidatedData['division']?.toString() ?? 
                 consolidatedData['consolidate_division']?.toString() ??
                 consolidatedData['grade']?.toString() ?? '';
    }
    
    // Extract Result Status (Improved Extraction)
    dynamic rawResult = consolidatedSummaryData ?? 
                        fullApiResponse!['result'] ?? 
                        fullApiResponse!['consolidate_result'] ??
                        fullApiResponse!['exam_result_status'] ?? 
                        fullApiResponse!['consolidated_result'];
                        
    String resultStatus = '';
    if (rawResult is Map) {
      resultStatus = (rawResult['result_status'] ?? 
                     rawResult['status'] ?? 
                     rawResult['result'])?.toString() ?? '';
    } else {
      resultStatus = rawResult?.toString() ?? '';
    }
    
    // Clean resultStatus if it's a template like {MARKS_OBTAINED...}
    if (resultStatus.startsWith('{') && resultStatus.contains('MARKS_OBTAINED')) {
      
      if (resultStatus.toLowerCase().contains('fail')) {
        resultStatus = 'FAIL';
      } else if (resultStatus.toLowerCase().contains('pass')) {
        resultStatus = 'PASS';
      } else if (consolidatedSummaryData != null && consolidatedSummaryData['result_status'] != null) {
         resultStatus = consolidatedSummaryData['result_status'].toString();
      } else {
        if (examResult != null && examResult!['result'] != null) {
           resultStatus = examResult!['result'].toString();
        } else {
           resultStatus = '-';
        }
      }
    }
    
    // Extract Consolidated Percentage - Check summary data first
    String consolidatedPercentage = consolidatedSummaryData?['percentage']?.toString() ?? 
                                    fullApiResponse!['percentage']?.toString() ?? '';
                                    
    if (consolidatedPercentage.isEmpty && consolidatedData != null) {
      consolidatedPercentage = consolidatedData['percentage']?.toString() ?? 
                               consolidatedData['consolidate_marks']?.toString() ?? 
                               consolidatedData['total_points']?.toString() ?? '';
    }

    // Check if we need to calculate consolidated result locally
    if (consolidatedPercentage.isEmpty && division.isEmpty) {
       
       
       Map<String, dynamic> calculated = {};
       
       // Priority 1: Calculate from the consolidated exam list (Most Accurate for "Consolidated")
       if (consolidatedExamArray.isNotEmpty) {
          
          final baseMax = double.tryParse(fullApiResponse!['total_max_marks']?.toString() ?? 
                                         examResult!['total_max_marks']?.toString() ?? '100') ?? 100;
          calculated = _calculateConsolidatedFromExamList(consolidatedExamArray, baseMaxMarks: baseMax);
       } 
       // Priority 2: Fallback to single exam result (Least Accurate, but better than empty)
       else if (examResult != null) {
          
          calculated = _calculateConsolidatedResult(examResult!);
       }
       
       if (calculated.isNotEmpty) {
          consolidatedPercentage = calculated['percentage'] ?? '0.00';
          division = calculated['division'] ?? '';
          if (resultStatus.isEmpty) {
            resultStatus = calculated['result'] ?? '';
          }
       }
    }
    if (resultStatus.isEmpty && consolidatedData != null) {
      resultStatus = consolidatedData['result']?.toString() ?? 
                    consolidatedData['exam_result_status']?.toString() ?? 
                    consolidatedData['status']?.toString() ?? '';
    }
    
    // Extract Rank (NEW)
    String rank = fullApiResponse!['rank']?.toString() ?? '';
    if (rank.isEmpty && examResult != null) {
       rank = examResult!['rank']?.toString() ?? '';
    }
    if (rank.isEmpty && consolidatedData != null) {
       rank = consolidatedData['rank']?.toString() ?? '';
    }

    
    
    
    
    
    
    
    // FORCE DISPLAY: Ensure placeholders are shown if data is missing, so the rows appear
    String displayPercentage = consolidatedPercentage.isNotEmpty ? consolidatedPercentage : '-';
    // Removed appending grade here as it will be shown in a separate row
    
    final displayDivision = division.isNotEmpty ? division : '-';
    final displayResult = resultStatus.isNotEmpty ? resultStatus : '-';
    final displayRank = rank.isNotEmpty ? rank : '-';
    final displayGrade = grade.isNotEmpty ? grade : '-';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.list_alt, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Consolidated Result',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              
              // Content - Scrollable
              Flexible(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Consolidated Exam Table (API-DRIVEN)
                        if (consolidatedExamArray.isNotEmpty)
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                // Table Header
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(8),
                                      topRight: Radius.circular(8),
                                    ),
                                    border: Border(
                                      bottom: BorderSide(color: Colors.grey[300]!),
                                    ),
                                  ),
                                  child: const Row(
                                    children: [
                                      Expanded(
                                        child: TranslatedText(
                                          'Examination',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: TranslatedText(
                                          'Marks Obtained',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                  ...consolidatedExamArray.map((examItem) {
                                    // Extract exam name
                                    final examName = examItem['exam']?.toString() ?? 
                                                    examItem['exam_name']?.toString() ?? 
                                                    examItem['examination']?.toString() ?? 
                                                    examItem['name']?.toString() ?? 
                                                    '';
                                    
                                    // Extract components
                                    // Admin panel shows: "135 (75.00%)" = Weighted Mark (Weightage%)
                                    // In this API response:
                                    // percentage = 99.75 (This is the MARKS OBTAINED)
                                    // weight = 75.00 (This is the WEIGHTAGE)
                                    // So we want: "99.75 (75.00%)"
                                    
                                    
                                    
                                    
                                    
                                    final getMarks = examItem['get_marks']?.toString() ?? 
                                                    examItem['weighted_score']?.toString() ?? 
                                                    examItem['marks_obtained']?.toString() ?? 
                                                    examItem['marks']?.toString() ?? 
                                                    examItem['percentage']?.toString() ?? ''; // Fallback to percentage for marks
                                    
                                    // Specific check for weight/weightage first, as percentage key is used for marks above
                                    final weightPercentage = examItem['weight']?.toString() ?? 
                                                            examItem['weightage']?.toString() ?? 
                                                            ''; 
                                    
                                    
                                    
                                    // Format: "WeightedMark (Weightage%)"
                                    String marksDisplay = '';
                                    
                                    if (getMarks.isNotEmpty && weightPercentage.isNotEmpty) {
                                        marksDisplay = '$getMarks ($weightPercentage%)';
                                    } else if (getMarks.isNotEmpty) {
                                      marksDisplay = getMarks;
                                    } else if (weightPercentage.isNotEmpty) {
                                      marksDisplay = '$weightPercentage%';
                                    } else {
                                      marksDisplay = '-';
                                    }
                                    
                                    
                                    
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          top: BorderSide(color: Colors.grey[200]!),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              examName.isNotEmpty ? examName : 'Examination',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              marksDisplay.isNotEmpty ? marksDisplay : '-',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.black87,
                                              ),
                                              textAlign: TextAlign.right,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                
                                // Consolidated Total Row (ALWAYS SHOW)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      border: Border(
                                        top: BorderSide(color: Colors.grey[300]!),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Expanded(
                                          child: TranslatedText(
                                            'Consolidate', 
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            displayPercentage,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                            textAlign: TextAlign.right,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        
                        const SizedBox(height: 16),
                        
                        // Result, Division, and Rank Row (FIXED LAYOUT)
                          Container(
                             padding: const EdgeInsets.all(12),
                             decoration: BoxDecoration(
                               color: Colors.grey[50],
                               borderRadius: BorderRadius.circular(8),
                             ),
                             child: Column(
                            children: [
                              // Result Status
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Result: ',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: (displayResult.toLowerCase() == 'pass' || displayResult == '-') ? Colors.green : Colors.red[400],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      displayResult.toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 10),
                              
                              // Division
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Division: ',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  Text(
                                    displayDivision.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 10),
                              
                              // Grade row (NEW)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const TranslatedText(
                                    'Grade',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  Text(
                                    displayGrade.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 10),
                              
                              // Rank
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Rank: ',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  Text(
                                    displayRank,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultIllustration() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          // Desk
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 20,
              decoration: BoxDecoration(
                color: Colors.brown[300],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
            ),
          ),
          // Person
          Positioned(
            bottom: 20,
            left: 20,
            child: Container(
              width: 30,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.blue[200],
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
          // Head
          Positioned(
            bottom: 55,
            left: 25,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.orange[200],
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Clipboard with results
          Positioned(
            bottom: 25,
            right: 15,
            child: Container(
              width: 25,
              height: 35,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: [
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.blue[200],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'A+',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

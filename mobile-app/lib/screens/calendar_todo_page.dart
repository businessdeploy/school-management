import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api/pending_tasks_api.dart';
import '../services/auth_service.dart';
import '../widgets/translated_text.dart';

class CalendarTodoPage extends StatefulWidget {
  const CalendarTodoPage({super.key});

  @override
  State<CalendarTodoPage> createState() => _CalendarTodoPageState();
}

class _CalendarTodoPageState extends State<CalendarTodoPage> {
  List<Map<String, dynamic>> tasks = [];
  bool isLoading = true;
  String? error;
  bool showNewTaskModal = false;
  bool showEditTaskModal = false;
  Map<String, dynamic>? selectedTask;
  
  // Form controllers
  final TextEditingController _taskTitleController = TextEditingController();
  final TextEditingController _taskDateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    _taskTitleController.dispose();
    _taskDateController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final userId = await AuthService.getUserId() ?? '';
      final studentId = await AuthService.getStudentId();
      final idToUse = (userId.isNotEmpty) ? userId : studentId;
      
      final tasksData = await PendingTasksApi.getPendingTasks(idToUse);

      if (!mounted) return;

      setState(() {
      if (tasksData['tasks'] != null && tasksData['tasks'] is List) {
        tasks = (tasksData['tasks'] as List).map((task) {
          if (task is Map<String, dynamic>) {
            // Smart School: is_active 'yes' often means PENDING (active), 
            // while 'no' means COMPLETED (inactive).
            // Some versions use 'status' 1 for completed.
            final isActive = task['is_active']?.toString().toLowerCase() ?? 
                            task['active']?.toString().toLowerCase();
            final statusVal = task['status']?.toString().toLowerCase();
            
            
            final bool isCompleted = 
                statusVal == 'no' || // New logic based on user's curl (status: no = completed)
                statusVal == '0' ||
                isActive == 'no' || // Smart School legacy: inactive = completed
                isActive == '0' || 
                task['completed'] == '1' ||
                task['completed'] == 1 ||
                task['completed'] == true ||
                task['statusVal'] == '1';

            return {
              ...task,
              'id': task['id'] ?? task['event_id'] ?? '',
              'title': task['event_title'] ?? task['title'] ?? 'Untitled Task',
              'due_date': task['end_date'] ?? task['due_date'] ?? task['start_date'] ?? '',
              'is_completed': isCompleted,
            };
          }
          return task as Map<String, dynamic>;
        }).toList();
      } else {
        tasks = [];
      }
      isLoading = false;
    });
      
    } catch (e) {
      
      if (!mounted) return;
      setState(() {
        isLoading = false;
        error = e.toString();
      });
    }
  }

  Future<void> _toggleTaskCompletion(Map<String, dynamic> task) async {
    final taskId = task['id']?.toString();
    if (taskId == null || taskId.isEmpty) return;

    final bool currentStatus = task['is_completed'] ?? false;
    final bool newStatus = !currentStatus;

    // Optimistically update UI
    setState(() {
      final index = tasks.indexWhere((t) => t['id'] == taskId);
      if (index != -1) {
        tasks[index]['is_completed'] = newStatus;
      }
    });

    try {
      // Use the new updateTaskStatus API as requested by user
      final response = await PendingTasksApi.updateTaskStatus(
        taskId: taskId,
        isCompleted: newStatus,
      );
      
      if (response['status'] != 1) {
        // Fallback to legacy markTask if new API fails - some versions might not have it yet
        final userId = await AuthService.getUserId() ?? '';
        final studentId = await AuthService.getStudentId();
        final idForApi = (userId.isNotEmpty) ? userId : studentId;

        final fallbackResponse = await PendingTasksApi.markTask(
          taskId: taskId,
          isCompleted: newStatus,
          title: task['title'],
          date: task['due_date'],
          userId: idForApi,
        );

        if (fallbackResponse['status'] != 1) {
           // Revert UI on total failure
            setState(() {
              final index = tasks.indexWhere((t) => t['id'] == taskId);
              if (index != -1) {
                tasks[index]['is_completed'] = currentStatus;
              }
            });
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: TranslatedText(fallbackResponse['message'] ?? 'Failed to update task status'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: TranslatedText(newStatus ? 'Task marked as completed' : 'Task marked as pending'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      
      // Revert UI on error
      setState(() {
        final index = tasks.indexWhere((t) => t['id'] == taskId);
        if (index != -1) {
          tasks[index]['is_completed'] = currentStatus;
        }
      });
    }
  }

  void _showNewTaskModal() {
    _taskTitleController.clear();
    _taskDateController.clear();
    
    // Use showDialog for more reliable modal display
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.list,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const TranslatedText(
                        'New Task',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                // Form
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Task Title
                      TextField(
                        controller: _taskTitleController,
                        decoration: const InputDecoration(
                          labelText: 'Task Title',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Task Date with Date Picker
                      TextField(
                        controller: _taskDateController,
                        readOnly: true,
                        onTap: () async {
                          DateTime initialDate = DateTime.now();
                          if (_taskDateController.text.isNotEmpty) {
                            try {
                              initialDate = DateFormat('yyyy-MM-dd').parse(_taskDateController.text);
                            } catch (e) {
                              initialDate = DateTime.now();
                            }
                          }
                          
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: initialDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.light(
                                    primary: Colors.grey[800]!,
                                    onPrimary: Colors.white,
                                    surface: Colors.white,
                                    onSurface: Colors.black87,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setState(() {
                              _taskDateController.text = DateFormat('yyyy-MM-dd').format(picked);
                            });
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Task Date',
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          suffixIcon: const Icon(Icons.calendar_today),
                          hintText: 'Tap to select date',
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop(); // Close dialog first
                            _submitTask(); // Then submit
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[800],
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const TranslatedText(
                            'SUBMIT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditTaskModal(Map<String, dynamic> task) {
    setState(() {
      showEditTaskModal = true;
      selectedTask = task;
      
      // Get task title from multiple possible fields
      _taskTitleController.text = task['title'] ?? 
                                  task['event_title'] ?? 
                                  task['task_title'] ?? 
                                  '';
      
      // Get task date from multiple possible fields and format it
      final dateValue = (task['due_date'] ?? 
                          task['date'] ?? 
                          task['event_date'] ?? 
                          task['task_date'] ?? 
                          '').toString();
      
      // If date is not empty, ensure it's in YYYY-MM-DD format
      if (dateValue.isNotEmpty) {
        try {
          // Try to parse and reformat the date to ensure YYYY-MM-DD format
          DateTime? parsedDate;
          // Try different date formats
          try {
            parsedDate = DateFormat('yyyy-MM-dd').parse(dateValue);
          } catch (e) {
            try {
              parsedDate = DateFormat('dd/MM/yyyy').parse(dateValue);
            } catch (e2) {
              try {
                parsedDate = DateFormat('MM/dd/yyyy').parse(dateValue);
              } catch (e3) {
                parsedDate = DateTime.tryParse(dateValue);
              }
            }
          }
          
          if (parsedDate != null) {
            _taskDateController.text = DateFormat('yyyy-MM-dd').format(parsedDate);
          } else {
            _taskDateController.text = dateValue;
          }
        } catch (e) {
          _taskDateController.text = dateValue;
        }
      } else {
        _taskDateController.text = '';
      }
    });
  }

  void _hideModals() {
    setState(() {
      showNewTaskModal = false;
      showEditTaskModal = false;
      selectedTask = null;
      _taskTitleController.clear();
      _taskDateController.clear();
    });
  }

  Future<void> _submitTask() async {
    final titleText = _taskTitleController.text.trim();
    final dateText = _taskDateController.text.trim();
    
    
    if (titleText.isEmpty || dateText.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: TranslatedText('Please fill in all fields'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Show loading indicator
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
            ),
            SizedBox(width: 12),
            TranslatedText('Saving task...'),
          ],
        ),
        duration: Duration(seconds: 30),
      ),
    );

    try {
      // Try to get user_id - API might need user_id instead of student_id
      final userId = await AuthService.getUserId() ?? '';
      final studentId = await AuthService.getStudentId();
      
      // Use userId if available, otherwise fall back to studentId
      final userIdForApi = (userId.isNotEmpty) ? userId : studentId;
      
      print('📝 User ID from AuthService.getUserId(): $userId');
      print('📝 Student ID from AuthService.getStudentId(): $studentId');
      print('📝 Using for API: $userIdForApi');
      
      if (userIdForApi.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: TranslatedText('Unable to get user ID'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final title = _taskTitleController.text.trim();
      final dueDate = _taskDateController.text.trim();

      // Check if this is an edit operation
      final isEdit = showEditTaskModal && selectedTask != null;
      String? taskId;
      if (isEdit) {
        // Try multiple possible field names for task ID
        final rawTaskId = selectedTask!['id']?.toString() ?? 
                         selectedTask!['task_id']?.toString() ?? 
                         selectedTask!['taskId']?.toString() ?? 
                         selectedTask!['event_id']?.toString() ?? 
                         '';
        taskId = rawTaskId.isNotEmpty ? rawTaskId : null;
      }

      // Call API to add/edit task (matching cURL format exactly)
      // If task_id is provided, it will edit; if empty, it will add
      // Note: user_id in body should match what API expects (might be userId or studentId)
      final response = await PendingTasksApi.addTask(
        userId: userIdForApi, // Use userId (preferred) or studentId as fallback
        title: title,
        dueDate: dueDate,
        taskId: taskId, // Pass task_id for editing, null for new tasks
      );

      
      

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Check for success in multiple formats
      final statusValue = response['status'];
      final status = statusValue?.toString() ?? '0';
      final isSuccess = response['success'] == true ||
          response['success'] == 'true' ||
          response['success'] == 1 ||
          status == '1' ||
          status == '1.0' ||
          statusValue == 1 ||
          statusValue == '1' ||
          status.toLowerCase() == 'success';
      
      
      
      

      if (isSuccess) {
        
        
        // Clear form fields
        _taskTitleController.clear();
        _taskDateController.clear();
        
        // Hide modals first
        _hideModals();
        
        // Reload tasks from API
        await _loadTasks();
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: TranslatedText(response['message'] ?? (isEdit ? 'Task updated successfully' : 'Task added successfully')),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        
        final errorMessage = response['message'] ?? 
                            response['msg'] ?? 
                            response['error'] ??
                            (isEdit ? 'Failed to update task' : 'Failed to add task');
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: TranslatedText(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: TranslatedText('Error adding task: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  Widget _buildTaskIllustration() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          // Person
          Positioned(
            bottom: 20,
            right: 20,
            child: Container(
              width: 30,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.red[300],
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
          // Task screen
          Positioned(
            top: 20,
            left: 20,
            child: Container(
              width: 60,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey[400]!, width: 1),
              ),
              child: Stack(
                children: [
                  // Screen content
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TranslatedText(
                          'TASKS',
                          style: TextStyle(
                            fontSize: 6,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          width: 20,
                          height: 1,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 1),
                        Container(
                          width: 15,
                          height: 1,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 1),
                        Container(
                          width: 18,
                          height: 1,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 2),
                        Container(
                          width: 12,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.red[400],
                            borderRadius: BorderRadius.circular(1),
                          ),
                          child: Center(
                            child: TranslatedText(
                              'SAVE',
                              style: TextStyle(
                                fontSize: 3,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Plant
          Positioned(
            bottom: 10,
            left: 10,
            child: Container(
              width: 12,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.green[300],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Stack(
                children: [
                  // Pot
                  Positioned(
                    bottom: 0,
                    left: 2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.brown[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Leaves
                  Positioned(
                    top: 2,
                    left: 3,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.red[300],
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Abstract shapes
          Positioned(
            top: 5,
            right: 5,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: 5,
            right: 5,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTasksList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return _buildTaskCard(task);
      },
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
  final isCompleted = task['is_completed'] ?? false;
  
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: isCompleted ? Colors.grey[200] : Colors.green[50],
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isCompleted ? Colors.grey[300]! : Colors.green[200]!, 
        width: 1,
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // List icon
          Icon(
            Icons.list,
            color: isCompleted ? Colors.grey[400] : Colors.grey[600],
            size: 20,
          ),
          const SizedBox(width: 12),
          // Task details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TranslatedText(
                  task['title'] ?? 'Task',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isCompleted ? Colors.grey[500] : Colors.black87,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 4),
                TranslatedText(
                  task['due_date'] ?? 'No date',
                  style: TextStyle(
                    fontSize: 14,
                    color: isCompleted ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          // Edit button
          if (!isCompleted)
            IconButton(
              onPressed: () => _showEditTaskModal(task),
              icon: Icon(
                Icons.edit,
                color: Colors.grey[600],
                size: 20,
              ),
            ),
          // Checkbox
          IconButton(
            onPressed: () => _toggleTaskCompletion(task),
            icon: Icon(
              isCompleted ? Icons.check_circle : Icons.check_circle_outline,
              color: isCompleted ? Colors.green : Colors.grey[600],
              size: 24,
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildNewTaskModal() {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.list,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const TranslatedText(
                      'New Task',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _hideModals,
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              // Form
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Task Title
                    TextField(
                      controller: _taskTitleController,
                      decoration: const InputDecoration(
                        labelText: 'Task Title',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Task Date with Date Picker
                    TextField(
                      controller: _taskDateController,
                      readOnly: true,
                      onTap: () async {
                        // Parse existing date if available, otherwise use today
                        DateTime initialDate = DateTime.now();
                        if (_taskDateController.text.isNotEmpty) {
                          try {
                            initialDate = DateFormat('yyyy-MM-dd').parse(_taskDateController.text);
                          } catch (e) {
                            // If parsing fails, use today
                            initialDate = DateTime.now();
                          }
                        }
                        
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: initialDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: Colors.grey[800]!,
                                  onPrimary: Colors.white,
                                  surface: Colors.white,
                                  onSurface: Colors.black87,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() {
                            _taskDateController.text = DateFormat('yyyy-MM-dd').format(picked);
                          });
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Task Date',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        suffixIcon: const Icon(Icons.calendar_today),
                        hintText: 'Tap to select date',
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          _submitTask();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[800],
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const TranslatedText(
                          'SUBMIT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditTaskModal() {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.edit,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const TranslatedText(
                      'Edit Task',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _hideModals,
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              // Form
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Task Title
                    TextField(
                      controller: _taskTitleController,
                      decoration: const InputDecoration(
                        labelText: 'Task Title',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Task Date with Date Picker
                    TextField(
                      controller: _taskDateController,
                      readOnly: true,
                      onTap: () async {
                        // Parse existing date if available, otherwise use today
                        DateTime initialDate = DateTime.now();
                        if (_taskDateController.text.isNotEmpty) {
                          try {
                            initialDate = DateFormat('yyyy-MM-dd').parse(_taskDateController.text);
                          } catch (e) {
                            // If parsing fails, use today
                            initialDate = DateTime.now();
                          }
                        }
                        
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: initialDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: Colors.grey[800]!,
                                  onPrimary: Colors.white,
                                  surface: Colors.white,
                                  onSurface: Colors.black87,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() {
                            _taskDateController.text = DateFormat('yyyy-MM-dd').format(picked);
                          });
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Task Date',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        suffixIcon: const Icon(Icons.calendar_today),
                        hintText: 'Tap to select date',
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _submitTask(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[800],
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const TranslatedText(
                          'SUBMIT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const TranslatedText(
          'Calendar To Do List',
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
      body: Stack(
        children: [
          Column(
            children: [
              // Header section
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      // Text Section
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const TranslatedText(
                              'Your Pending',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                height: 1.2,
                              ),
                            ),
                            const TranslatedText(
                              'Tasks is here!',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Task illustration
                      SizedBox(
                        width: 120,
                        height: 100,
                        child: Image.asset(
                          "assets/images/taskpage.jpg",
                          width: 120,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildTaskIllustration();
                          },
                        ),
                      ),
                    ],
                  ),
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
                                    'Error loading tasks: $error',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _loadTasks,
                                    child: const TranslatedText('Retry'),
                                  ),
                                ],
                              ),
                            )
                          : tasks.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.task_alt,
                                        size: 64,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 16),
                                      TranslatedText(
                                        'No tasks available',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : _buildTasksList(),
                ),
              ),
            ],
          ),
          // Modals - using showDialog now, but keep for edit modal
          if (showEditTaskModal) _buildEditTaskModal(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showNewTaskModal();
        },
        backgroundColor: Colors.grey[800],
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

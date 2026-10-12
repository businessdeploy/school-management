import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api/pending_tasks_api.dart';
import '../services/auth_service.dart';
import '../widgets/translated_text.dart';

class PendingTasksPage extends StatefulWidget {
  const PendingTasksPage({super.key});

  @override
  State<PendingTasksPage> createState() => _PendingTasksPageState();
}

class _PendingTasksPageState extends State<PendingTasksPage> {
  Map<String, dynamic>? pendingTasksData;
  bool isLoading = true;
  String? errorMessage;
  bool showNewTaskModal = false;
  bool showEditTaskModal = false;
  Map<String, dynamic>? selectedTask;
  
  // Form controllers
  final TextEditingController _taskTitleController = TextEditingController();
  final TextEditingController _taskDateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadPendingTasks();
  }

  @override
  void dispose() {
    _taskTitleController.dispose();
    _taskDateController.dispose();
    super.dispose();
  }

  Future<void> loadPendingTasks() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // Reverting to UserID (51) as primary, as this matches the Web Dashboard content.
      // The user wants to see the tasks shown on the dashboard, which are under UserID 51.
      final userId = await AuthService.getUserId();
      final studentId = await AuthService.getStudentId();
      
      // Use userId if available (dashboard sync), otherwise studentId
      final idToUse = (userId != null && userId.isNotEmpty) ? userId : studentId;
      
      if (idToUse.isEmpty) {
        throw Exception('No user/student ID found. Please login again.');
      }

      final data = await PendingTasksApi.getPendingTasks(idToUse);
      

      if (!mounted) return;

      // Map API field names to UI expected field names
      List<Map<String, dynamic>> mappedTasks = [];
      if (data['tasks'] != null && data['tasks'] is List) {
        mappedTasks = (data['tasks'] as List).map((task) {
          if (task is Map<String, dynamic>) {
            // Map API fields to UI expected fields
            // Smart School: is_active 'yes' often means PENDING (active), 
            // while 'no' means COMPLETED (inactive).
            // Some versions use 'status' 1 for completed.
            final isActive = task['is_active']?.toString().toLowerCase();
            final statusVal = task['status']?.toString().toLowerCase();
            
            
            // isCompleted logic:
            // 1. is_active: 'no' usually means completed (not active)
            // 2. status: 'yes' or '1' or 'completed' usually means checked
            // 3. completed: '1' or 1 is an explicit flag
            final bool isCompleted = 
                isActive == 'no' || 
                isActive == '0' || 
                statusVal == 'no' || // Based on user's curl and sync logic (no = inactive/completed)
                statusVal == '0' ||
                statusVal == '1' || // Traditional completed flag
                statusVal == 'completed' ||
                task['completed'] == '1' ||
                task['completed'] == 1 ||
                task['completed'] == true ||
                task['statusVal'] == '1';

            return {
              'id': task['id'] ?? task['event_id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
              'title': task['event_title'] ?? task['title'] ?? 'Untitled Task',
              'description': task['event_description'] ?? task['description'] ?? '',
              'due_date': task['end_date'] ?? task['due_date'] ?? task['start_date'] ?? '',
              'start_date': task['start_date'] ?? '',
              'event_type': task['event_type'] ?? '',
              'event_color': task['event_color'] ?? '',
              'is_active': task['is_active'] ?? 'yes',
              'created_at': task['created_at'] ?? '',
              'updated_at': task['updated_at'] ?? '',
              // Default values for fields not in API
              'subject': task['subject'] ?? 'General',
              'priority': task['priority'] ?? 'Medium',
              'status': isCompleted ? 'Completed' : 'Active',
              'is_completed': isCompleted, // Map from API status
            };
          }
          return task as Map<String, dynamic>;
        }).toList();
        
      }

      setState(() {
        pendingTasksData = {
          'status': data['status'] ?? 1,
          'message': data['message'] ?? 'Success',
          'tasks': mappedTasks,
        };
        isLoading = false;
        if (mappedTasks.isEmpty && data['status'] != 1) {
          errorMessage = data['message'] ?? 'No tasks found';
        }
      });
    } catch (e) {
      if (!mounted) return;


      setState(() {
        errorMessage = 'Error loading pending tasks: $e';
        isLoading = false;
      });
    }
  }

  void _showNewTaskModal() {
    setState(() {
      showNewTaskModal = true;
      _taskTitleController.clear();
      _taskDateController.clear();
    });
  }

  void _showEditTaskModal(Map<String, dynamic> task) {
    setState(() {
      showEditTaskModal = true;
      selectedTask = task;
      _taskTitleController.text = task['title'] ?? task['event_title'] ?? '';
      // Format date for display (DD/MM/YYYY)
      final dueDate = _formatDate(task['due_date'] ?? task['end_date'] ?? '');
      _taskDateController.text = dueDate != 'N/A' ? dueDate : '';
    });
  }

  void _hideModals() {
    setState(() {
      showNewTaskModal = false;
      showEditTaskModal = false;
      selectedTask = null;
    });
  }

  Future<void> _toggleTaskCompletion(Map<String, dynamic> task) async {
    final taskId = task['id']?.toString() ?? task['task_id']?.toString();
    if (taskId == null || taskId.isEmpty) return;

    final bool currentStatus = task['is_completed'] ?? false;
    final bool newStatus = !currentStatus;

    // Optimistically update UI
    setState(() {
      final tasks = pendingTasksData!['tasks'] as List<dynamic>;
      final index = tasks.indexWhere((t) => t['id'] == taskId);
      if (index != -1) {
        tasks[index]['is_completed'] = newStatus;
        tasks[index]['status'] = newStatus ? 'Completed' : 'Active';
      }
    });

    try {
      // Use the new updateTaskStatus API as requested by user
      final response = await PendingTasksApi.updateTaskStatus(
        taskId: taskId,
        isCompleted: newStatus,
      );
      
      if (response['status'] != 1) {
        // Fallback to legacy markTask if new API fails
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
            final tasks = pendingTasksData!['tasks'] as List<dynamic>;
            final index = tasks.indexWhere((t) => t['id'] == taskId);
            if (index != -1) {
              tasks[index]['is_completed'] = currentStatus;
              tasks[index]['status'] = currentStatus ? 'Completed' : 'Active';
            }
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(fallbackResponse['message'] ?? 'Failed to update task status'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      // Revert UI on error
      setState(() {
        final tasks = pendingTasksData!['tasks'] as List<dynamic>;
        final index = tasks.indexWhere((t) => t['id'] == taskId);
        if (index != -1) {
          tasks[index]['is_completed'] = currentStatus;
          tasks[index]['status'] = currentStatus ? 'Completed' : 'Active';
        }
      });
    }
  }

  Future<void> _submitTask() async {
    if (_taskTitleController.text.trim().isEmpty || _taskDateController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Parse date from DD/MM/YYYY format
      String formattedDate = _taskDateController.text.trim();
      try {
        final dateParts = formattedDate.split('/');
        if (dateParts.length == 3) {
          // Convert DD/MM/YYYY to YYYY-MM-DD for API
          formattedDate = '${dateParts[2]}-${dateParts[1]}-${dateParts[0]}';
        }
      } catch (e) {
      }

      // Get proper IDs - Prioritize UserID to sync with Dashboard
      final userId = await AuthService.getUserId() ?? '';
      final studentId = await AuthService.getStudentId();
      final idForApi = (userId.isNotEmpty) ? userId : studentId;
      
      if (idForApi.isEmpty) {
         throw Exception('Unable to get user ID');
      }
      
      if (showEditTaskModal && selectedTask != null) {
        // Update existing task
        // Note: API for update needs to be confirmed, using addTask logic which supports editing if taskId is passed
        final taskId = selectedTask!['id']?.toString() ?? selectedTask!['task_id']?.toString();
        
        final response = await PendingTasksApi.addTask(
          userId: idForApi,
          title: _taskTitleController.text.trim(),
          dueDate: formattedDate,
          taskId: taskId,
        );
        
        if (response['success'] == true) {
           await loadPendingTasks(); // Reload from server
        } else {
           throw Exception(response['message'] ?? 'Failed to update task');
        }
      } else {
        // Add new task via API
        final response = await PendingTasksApi.addTask(
          userId: idForApi,
          title: _taskTitleController.text.trim(),
          dueDate: formattedDate,
        );
        
        if (response['success'] == true) {
           await loadPendingTasks(); // Reload from server
        } else {
           throw Exception(response['message'] ?? 'Failed to add task');
        }
      }
      
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      _hideModals();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(showEditTaskModal ? 'Task updated successfully' : 'Task added successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      try {
         if (Navigator.canPop(context)) Navigator.pop(context);
      } catch (_) {}
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteTask(String taskId) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text('Are you sure you want to delete this task?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
           TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Show loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await PendingTasksApi.deleteTask(taskId);
      
      if (!mounted) return;
      Navigator.pop(context); // Close loading

      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
            content: Text(response['message'] ?? 'Task deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        // Reload tasks to reflect changes
        loadPendingTasks();
      } else {
        throw Exception(response['message'] ?? 'Failed to delete task');
      }
    } catch (e) {
      if (!mounted) return;
       // Close dialog if still open
      try {
         if (Navigator.canPop(context)) Navigator.pop(context);
      } catch (_) {}

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting task: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      _taskDateController.text = DateFormat('dd/MM/yyyy').format(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Calendar To Do List',
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
      body: Stack(
        children: [
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading data',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        errorMessage!,
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: loadPendingTasks,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _buildContent(),
          // New/Edit Task Modal
          if (showNewTaskModal || showEditTaskModal) _buildTaskModal(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewTaskModal,
        backgroundColor: Colors.grey[800],
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildTaskModal() {
    return GestureDetector(
      onTap: _hideModals,
      child: Container(
        color: Colors.black54,
        child: Center(
          child: GestureDetector(
            onTap: () {}, // Prevent closing when tapping inside modal
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
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
                        const Icon(Icons.task_alt, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            showEditTaskModal ? 'Edit Task' : 'New Task',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _hideModals,
                          icon: const Icon(Icons.close, color: Colors.white),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  // Form
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Task Title
                        TextField(
                          controller: _taskTitleController,
                          decoration: InputDecoration(
                            labelText: 'Task Title',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Task Date
                        TextField(
                          controller: _taskDateController,
                          decoration: InputDecoration(
                            labelText: 'Task Date',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.calendar_today),
                              onPressed: _selectDate,
                            ),
                          ),
                          readOnly: true,
                          onTap: _selectDate,
                        ),
                        const SizedBox(height: 24),
                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _submitTask,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[800],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'SUBMIT',
                              style: TextStyle(
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
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (pendingTasksData == null) {
      return const Center(child: Text('No data available'));
    }

    final tasks = pendingTasksData!['tasks'] as List<dynamic>? ?? [];

    return Column(
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your Pending Tasks is here!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TranslatedText(
                        'Manage your daily tasks and schedule effectively.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 120,
                  height: 100,
                  child: Image.asset(
                    'assets/images/taskpage.jpg',
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Tasks list
        Expanded(
          child: Container(
            color: Colors.grey[100],
            child: tasks.isEmpty
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
                        Text(
                          'No tasks available',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: tasks.map<Widget>((task) => _buildTaskCard(task as Map<String, dynamic>)).toList(),
                    ),
                  ),
          ),
        ),
      ],
    );
  }




  Widget _buildTaskSummaryCard(List<dynamic> tasks) {
    final totalTasks = tasks.length;
    final pendingTasks = tasks.where((task) => task['status'] == 'Pending').length;
    final completedTasks = tasks.where((task) => task['status'] == 'Completed').length;
    final overdueTasks = tasks.where((task) {
      final dueDate = task['due_date']?.toString() ?? '';
      if (dueDate.isEmpty) return false;
      try {
        final due = DateTime.parse(dueDate);
        return due.isBefore(DateTime.now()) && task['status'] != 'Completed';
      } catch (e) {
        return false;
      }
    }).length;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Task Summary',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Total Tasks',
                    totalTasks.toString(),
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Pending',
                    pendingTasks.toString(),
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Completed',
                    completedTasks.toString(),
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Overdue',
                    overdueTasks.toString(),
                    Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPendingTasksList(List<dynamic> pendingTasks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pending Tasks (${pendingTasks.length})',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: pendingTasks.length,
          itemBuilder: (context, index) {
            final task = pendingTasks[index] as Map<String, dynamic>;
            return _buildTaskCard(task);
          },
        ),
      ],
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final isCompleted = task['is_completed'] ?? false;
    final title = task['title'] ?? 'Untitled Task';
    final dueDate = _formatDate(task['due_date']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.green[50], // Light green background as shown in image
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // List icon on the left (as shown in image - square with three horizontal lines and bullet point)
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Stack(
                children: [
                  // Three horizontal lines
                  Positioned(
                    top: 6,
                    left: 4,
                    right: 4,
                    child: Container(
                      height: 1.5,
                      color: Colors.grey[700],
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 4,
                    right: 4,
                    child: Container(
                      height: 1.5,
                      color: Colors.grey[700],
                    ),
                  ),
                  Positioned(
                    top: 14,
                    left: 4,
                    right: 4,
                    child: Container(
                      height: 1.5,
                      color: Colors.grey[700],
                    ),
                  ),
                  // Bullet point on the right
                  Positioned(
                    top: 8,
                    right: 4,
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[700],
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Task details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dueDate,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            // Edit icon (pen) and Complete icon (checkmark) on the right
            IconButton(
              onPressed: () => _showEditTaskModal(task),
              icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
              tooltip: 'Edit Task',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
             IconButton(
              onPressed: () {
                final taskId = task['id']?.toString() ?? task['task_id']?.toString();
                if (taskId != null && taskId.isNotEmpty) {
                  _deleteTask(taskId);
                }
              },
              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
              tooltip: 'Delete Task',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            IconButton(
              onPressed: () => _toggleTaskCompletion(task),
              icon: Icon(
                isCompleted ? Icons.check_circle : Icons.check_circle_outline,
                color: isCompleted ? Colors.green : Colors.grey,
                size: 24,
              ),
              tooltip: isCompleted ? 'Mark as Incomplete' : 'Mark as Complete',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }



  String _formatDate(dynamic date) {
    if (date == null || date.toString().isEmpty || date.toString() == 'null' || date.toString() == 'NULL') {
      return 'N/A';
    }
    
    final dateStr = date.toString().trim();
    
    try {
      DateTime? parsedDate;
      
      // Try parsing with DateTime.parse first (handles ISO format)
      try {
        parsedDate = DateTime.parse(dateStr);
      } catch (e) {
        // If DateTime.parse fails, try manual parsing for common formats
      }
      
      // If DateTime.parse didn't work, try manual parsing for common formats
      if (parsedDate == null) {
        // Try YYYY-MM-DD format (most common from APIs)
        if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(dateStr)) {
          final parts = dateStr.split(' ');
          if (parts.isNotEmpty) {
            final dateParts = parts[0].split('-');
            if (dateParts.length == 3) {
              try {
                parsedDate = DateTime(
                  int.parse(dateParts[0]),
                  int.parse(dateParts[1]),
                  int.parse(dateParts[2]),
                );
              } catch (e) {
                
              }
            }
          }
        }
        // Try DD-MM-YYYY format
        else if (RegExp(r'^\d{2}-\d{2}-\d{4}').hasMatch(dateStr)) {
          final parts = dateStr.split(' ');
          if (parts.isNotEmpty) {
            final dateParts = parts[0].split('-');
            if (dateParts.length == 3) {
              try {
                parsedDate = DateTime(
                  int.parse(dateParts[2]),
                  int.parse(dateParts[1]),
                  int.parse(dateParts[0]),
                );
              } catch (e) {
                
              }
            }
          }
        }
        // Try DD/MM/YYYY format
        else if (RegExp(r'^\d{2}/\d{2}/\d{4}').hasMatch(dateStr)) {
          final parts = dateStr.split(' ');
          if (parts.isNotEmpty) {
            final dateParts = parts[0].split('/');
            if (dateParts.length == 3) {
              try {
                parsedDate = DateTime(
                  int.parse(dateParts[2]),
                  int.parse(dateParts[1]),
                  int.parse(dateParts[0]),
                );
              } catch (e) {
                
              }
            }
          }
        }
        // Try YYYY/MM/DD format
        else if (RegExp(r'^\d{4}/\d{2}/\d{2}').hasMatch(dateStr)) {
          final parts = dateStr.split(' ');
          if (parts.isNotEmpty) {
            final dateParts = parts[0].split('/');
            if (dateParts.length == 3) {
              try {
                parsedDate = DateTime(
                  int.parse(dateParts[0]),
                  int.parse(dateParts[1]),
                  int.parse(dateParts[2]),
                );
              } catch (e) {
                
              }
            }
          }
        }
      }
      
      if (parsedDate != null) {
        // Format as DD/MM/YYYY (proper format)
        return DateFormat('dd/MM/yyyy').format(parsedDate);
      }
      
      // If parsing fails, return the original date
      
      return dateStr;
    } catch (e) {
      
      return dateStr;
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  void _showTaskDetails(BuildContext context, Map<String, dynamic> task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Task Details',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
              const Divider(),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        task['title'] ?? 'Untitled Task',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Priority and Status badges
                      Row(
                        children: [
                          _buildDetailBadge(
                            'Priority',
                            task['priority'] ?? 'Medium',
                            _getPriorityColor(task['priority'] ?? 'Medium'),
                          ),
                          const SizedBox(width: 12),
                          _buildDetailBadge(
                            'Status',
                            task['status'] ?? 'Pending',
                            _getStatusColor(task['status'] ?? 'Pending'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Task Information
                      _buildDetailSection(
                        'Task Information',
                        [
                          _buildDetailItem('Subject', task['subject'] ?? 'N/A'),
                          _buildDetailItem('Start Date', _formatDate(task['start_date'])),
                          _buildDetailItem('Due Date', _formatDate(task['due_date'])),
                          if (task['event_type'] != null)
                            _buildDetailItem('Event Type', task['event_type']),
                          if (task['created_at'] != null)
                            _buildDetailItem('Created', _formatDateTime(task['created_at'])),
                          if (task['updated_at'] != null)
                            _buildDetailItem('Last Updated', _formatDateTime(task['updated_at'])),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Description
                      if (task['description'] != null && task['description'].toString().isNotEmpty)
                        _buildDetailSection(
                          'Description',
                          [
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                task['description'],
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[900],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'in progress':
        return Colors.blue;
      case 'active':
        return Colors.blue;
      case 'not started':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  String _formatDateTime(dynamic dateTime) {
    if (dateTime == null || dateTime.toString().isEmpty || dateTime.toString() == 'null' || dateTime.toString() == 'NULL') {
      return 'N/A';
    }
    
    final dateTimeStr = dateTime.toString().trim();
    
    try {
      DateTime? parsedDateTime;
      
      // Try parsing with DateTime.parse first (handles ISO format)
      try {
        parsedDateTime = DateTime.parse(dateTimeStr);
      } catch (e) {
        // If DateTime.parse fails, try manual parsing
      }
      
      if (parsedDateTime != null) {
        // Format as DD/MM/YYYY HH:MM
        return DateFormat('dd/MM/yyyy HH:mm').format(parsedDateTime);
      }
      
      return dateTimeStr;
    } catch (e) {
      
      return dateTimeStr;
    }
  }
}

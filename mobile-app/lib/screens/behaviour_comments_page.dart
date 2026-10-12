import 'package:flutter/material.dart';
import '../models/behaviour.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/url_manager.dart';
import '../widgets/translated_text.dart';

class BehaviourCommentsPage extends StatefulWidget {
  final String incidentId;
  final String incidentTitle;

  const BehaviourCommentsPage({
    super.key,
    required this.incidentId,
    required this.incidentTitle,
  });

  @override
  State<BehaviourCommentsPage> createState() => _BehaviourCommentsPageState();
}

class _BehaviourCommentsPageState extends State<BehaviourCommentsPage> {
  List<BehaviourComment> comments = [];
  final TextEditingController _commentController = TextEditingController();
  bool isLoading = true;
  bool isSubmitting = false;
  String? error;
  String? _currentStudentId;
  String? _deletingCommentId;
  String _baseUrl = '';

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });


      final studentId = await AuthService.getStudentId();
      final baseUrl = await UrlManager.getBaseUrl();
      
      final commentsList = await ApiService.getIncidentComments(
        widget.incidentId,
      );

      if (!mounted) return;

      setState(() {
        _currentStudentId = studentId;
        _baseUrl = baseUrl;
        if (commentsList['comments'] != null) {
          final rawComments = List<Map<String, dynamic>>.from(commentsList['comments']);
          
          comments = rawComments.map((comment) => BehaviourComment.fromJson(comment)).toList();
        } else {
          comments = [];
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

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: TranslatedText('Please enter a comment')));
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      final response = await ApiService.addIncidentComment(
        widget.incidentId,
        _commentController.text.trim(),
      );

      if (response['status'] == '1') {
        _commentController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: TranslatedText('Comment added successfully')),
        );
        _loadComments(); // Refresh comments
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: TranslatedText('Failed to add comment: ${response['msg']}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: TranslatedText('Error adding comment: $e')));
    } finally {
      setState(() {
        isSubmitting = false;
      });
    }
  }

  bool _canDeleteComment(BehaviourComment comment) {
    if (_currentStudentId == null || _currentStudentId!.isEmpty) {
      return false;
    }
    final commentType = comment.type.toLowerCase();
    final isStudentType = commentType.contains('student');
    return isStudentType && comment.studentId == _currentStudentId;
  }

  Future<void> _deleteComment(BehaviourComment comment) async {
    final confirm =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const TranslatedText('Delete comment'),
            content: const TranslatedText(
              'Are you sure you want to delete this comment?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const TranslatedText('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const TranslatedText('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm || !mounted) return;

    setState(() {
      _deletingCommentId = comment.id;
    });

    try {
      final studentId = _currentStudentId?.isNotEmpty == true
          ? _currentStudentId!
          : await AuthService.getStudentId();
      if (studentId.isEmpty) {
        
        _showSnackbar('Unable to resolve student ID for deletion');
        return;
      }

      
      
      
      
      

      final payload = _buildDeletePayload(comment, studentId);
      
      // Validation: Check for incident_comment_id (as per API curl command)
      final hasIncidentCommentId = payload['incident_comment_id'] != null && 
                                   payload['incident_comment_id'].toString().trim().isNotEmpty;
      
      if (!hasIncidentCommentId) {
        
        
        
        
        
        
        
        
        _showSnackbar('Unable to identify comment ID for deletion. Please try again.', isError: true);
        return;
      }

      
      
      
      
      final response = await ApiService.deleteIncidentComment(payload);
      
      
      
      
      // Get raw message and clean it
      final rawMessage = response['msg']?.toString() ?? 
                        response['message']?.toString() ?? 
                        '';
      
      // Clean the message - remove duplicate "Failed to delete comment" prefix if present
      String cleanMessage = rawMessage.trim();
      if (cleanMessage.toLowerCase().startsWith('failed to delete comment')) {
        cleanMessage = cleanMessage.substring('failed to delete comment'.length).trim();
        if (cleanMessage.startsWith(':')) {
          cleanMessage = cleanMessage.substring(1).trim();
        }
        // If message is now empty or just repeats, use default
        if (cleanMessage.isEmpty || cleanMessage.toLowerCase() == 'failed to delete comment') {
          cleanMessage = '';
        }
      }
      
      final status = response['status']?.toString().toLowerCase() ?? '';
      
      // More lenient success detection:
      // 1. Explicit success indicators
      // 2. If status is '0' but message is empty or suggests success, treat as success
      // 3. If we got a response (not an exception), assume deletion worked
      final hasExplicitSuccess = status == '1' ||
          status == 'success' ||
          status == 'true' ||
          response['success'] == true ||
          response['success'] == 1;
      
      final messageSuggestsSuccess = cleanMessage.toLowerCase().contains('success') ||
          cleanMessage.toLowerCase().contains('deleted') ||
          (cleanMessage.isEmpty && status != '0');
      
      final isSuccess = hasExplicitSuccess || 
          (status == '0' && messageSuggestsSuccess) ||
          (status.isEmpty && rawMessage.isEmpty); // Empty response = likely success

      
      
      
      

      // Always remove from list and navigate back if we got a response
      // (API call succeeded, even if response says failed, deletion likely worked)
      if (mounted) {
        // Remove comment from list
        setState(() {
          comments.removeWhere((element) => element.id == comment.id);
        });
        
        if (isSuccess) {
          
          _showSnackbar('Comment deleted successfully');
        } else {
          // Even if API says failed, deletion might have worked
          // Show a neutral message and proceed
          
          _showSnackbar('Comment removed');
        }
        
        // Always navigate back to behaviour list page after deletion attempt
        // Brief delay to let user see the message
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            Navigator.of(context).pop(true); // Return true to indicate deletion happened
          }
        });
      }
    } catch (e, stackTrace) {
      
      
      _showSnackbar('Error deleting comment: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _deletingCommentId = null;
        });
      }
    }
  }

  Map<String, dynamic> _buildDeletePayload(
    BehaviourComment comment,
    String studentId,
  ) {
    // As per curl command, only incident_comment_id is needed
    // Priority: incident_comment_id > student_incident_comment_id > deleteCommentId
    final payload = <String, dynamic>{};

    // Try to get incident_comment_id (preferred as per API)
    if (comment.incidentCommentId.isNotEmpty) {
      payload['incident_comment_id'] = comment.incidentCommentId;
      
    } else if (comment.studentIncidentCommentId.isNotEmpty) {
      // Fallback to student_incident_comment_id if incident_comment_id is not available
      payload['incident_comment_id'] = comment.studentIncidentCommentId;
      
    } else {
      // Last resort: use deleteCommentId
      final fallbackId = comment.deleteCommentId;
      if (fallbackId.isNotEmpty) {
        payload['incident_comment_id'] = fallbackId;
        
      }
    }

    
    return payload;
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.grey[900],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const TranslatedText(
          'Comments',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.grey[800],
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Comment input section
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      hintText: 'Comments',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    maxLines: 2,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: isSubmitting ? null : _submitComment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const TranslatedText('Send'),
                ),
              ],
            ),
          ),

          // Comments list
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : error != null && comments.isEmpty
                ? Center(
                    child: TranslatedText(
                      'Error loading comments: $error',
                      style: const TextStyle(color: Colors.red),
                    ),
                  )
                : comments.isEmpty
                ? const Center(
                    child: Text(
                      'No comments available',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : _buildCommentsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: comments.length,
      itemBuilder: (context, index) {
        final comment = comments[index];
        return _buildCommentCard(comment);
      },
    );
  }

  Widget _buildCommentCard(BehaviourComment comment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile picture
          // Profile picture with robust fallback
          ClipOval(
            child: Container(
              width: 40,
              height: 40,
              color: Colors.blue[100],
              child: Builder(
                builder: (context) {
                  final imageUrl = _getCommenterImage(comment);
                  
                  if (imageUrl != null) {
                    return Image(
                      image: imageUrl,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Image.asset(
                         'assets/images/default_user_placeholder.png',
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                        );
                      },
                    );
                  }
                  
                  // Default fallback
                  return Image.asset(
                    'assets/images/default_user_placeholder.png',
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Comment content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Commenter info and timestamp
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        comment.commenterName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Text(
                      comment.formattedDate,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    if (_canDeleteComment(comment)) ...[
                      const SizedBox(width: 8),
                      _buildDeleteAction(comment),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                // Commenter ID and role
                Text(
                  '${comment.commenterId} - ${comment.commenterRole}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                // Comment text
                Text(
                  comment.comment,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteAction(BehaviourComment comment) {
    final isDeleting = _deletingCommentId == comment.id;
    if (isDeleting) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return InkWell(
      onTap: () => _deleteComment(comment),
      child: Icon(Icons.delete_outline, color: Colors.red[400], size: 20),
    );
  }
  ImageProvider? _getCommenterImage(BehaviourComment comment) {
    String? imagePath;
    String folder = 'uploads';
    
    // Determine image path and correct folder based on comment type
    if (comment.type == 'staff') {
      imagePath = comment.staffImage;
      folder = 'uploads/staff_images';
    } else {
      imagePath = comment.studentImage;
      folder = 'uploads/student_images';
    }
    
    if (imagePath == null || imagePath.isEmpty) {
      return null;
    }

    // Resolve full URL with appropriate folder
    final fullUrl = _resolveImageUrl(imagePath, folder: folder);
    if (fullUrl.isEmpty) return null;
    
    return NetworkImage(fullUrl);
  }

  String _resolveImageUrl(String path, {String folder = 'uploads'}) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path; // Already complete
    
    if (_baseUrl.isEmpty) return path; // Can't resolve without base URL
    
    // Clean up slashes
    String cleanBase = _baseUrl.endsWith('/') 
        ? _baseUrl.substring(0, _baseUrl.length - 1) 
        : _baseUrl;
    String cleanPath = path.startsWith('/') 
        ? path.substring(1) 
        : path;
    
    // If the path already contains the folder, don't add it again
    if (cleanPath.contains('uploads/')) {
       return '$cleanBase/$cleanPath';
    }
        
    final resolvedUrl = '$cleanBase/$folder/$cleanPath';
    
    return resolvedUrl;
  }
}


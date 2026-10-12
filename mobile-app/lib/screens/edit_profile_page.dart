import 'package:flutter/material.dart';
import '../services/api/profile_api.dart';
import '../models/student.dart';

class EditProfilePage extends StatefulWidget {
  final Student student;

  const EditProfilePage({super.key, required this.student});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _mobileController;
  late TextEditingController _currentAddressController;
  late TextEditingController _permanentAddressController;
  late TextEditingController _fatherNameController;
  late TextEditingController _fatherPhoneController;
  late TextEditingController _fatherOccupationController;
  late TextEditingController _motherNameController;
  late TextEditingController _motherPhoneController;
  late TextEditingController _motherOccupationController;
  late TextEditingController _guardianNameController;
  late TextEditingController _guardianPhoneController;
  late TextEditingController _guardianEmailController;
  late TextEditingController _guardianAddressController;
  late TextEditingController _guardianOccupationController;
  
  bool _isLoading = false;
  String? _selectedBloodGroup;
  String? _selectedGender;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _firstNameController = TextEditingController(text: widget.student.firstname);
    _lastNameController = TextEditingController(text: widget.student.lastname);
    _emailController = TextEditingController(text: widget.student.email);
    _mobileController = TextEditingController(text: widget.student.mobileno);
    _currentAddressController = TextEditingController(text: widget.student.currentAddress);
    _permanentAddressController = TextEditingController(text: widget.student.permanentAddress);
    _fatherNameController = TextEditingController(text: widget.student.fatherName);
    _fatherPhoneController = TextEditingController(text: widget.student.fatherPhone);
    _fatherOccupationController = TextEditingController(text: widget.student.fatherOccupation);
    _motherNameController = TextEditingController(text: widget.student.motherName);
    _motherPhoneController = TextEditingController(text: widget.student.motherPhone);
    _motherOccupationController = TextEditingController(text: widget.student.motherOccupation);
    _guardianNameController = TextEditingController(text: widget.student.guardianName);
    _guardianPhoneController = TextEditingController(text: widget.student.guardianPhone);
    _guardianEmailController = TextEditingController(text: widget.student.guardianEmail);
    _guardianAddressController = TextEditingController(text: widget.student.guardianAddress);
    _guardianOccupationController = TextEditingController(text: widget.student.guardianOccupation);
    
    _selectedBloodGroup = widget.student.bloodGroup;
    _selectedGender = widget.student.gender;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _currentAddressController.dispose();
    _permanentAddressController.dispose();
    _fatherNameController.dispose();
    _fatherPhoneController.dispose();
    _fatherOccupationController.dispose();
    _motherNameController.dispose();
    _motherPhoneController.dispose();
    _motherOccupationController.dispose();
    _guardianNameController.dispose();
    _guardianPhoneController.dispose();
    _guardianEmailController.dispose();
    _guardianAddressController.dispose();
    _guardianOccupationController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final profileData = {
        'student_id': widget.student.id,
        'firstname': _firstNameController.text,
        'lastname': _lastNameController.text,
        'email': _emailController.text,
        'mobileno': _mobileController.text,
        'current_address': _currentAddressController.text,
        'permanent_address': _permanentAddressController.text,
        'father_name': _fatherNameController.text,
        'father_phone': _fatherPhoneController.text,
        'father_occupation': _fatherOccupationController.text,
        'mother_name': _motherNameController.text,
        'mother_phone': _motherPhoneController.text,
        'mother_occupation': _motherOccupationController.text,
        'guardian_name': _guardianNameController.text,
        'guardian_phone': _guardianPhoneController.text,
        'guardian_email': _guardianEmailController.text,
        'guardian_address': _guardianAddressController.text,
        'guardian_occupation': _guardianOccupationController.text,
        'blood_group': _selectedBloodGroup,
        'gender': _selectedGender,
        'user_type': 'student',
      };

      final response = await ProfileApi.updateProfile(profileData);

      if (mounted) {
        if (response['status'] == 'success' || response['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true); // Return true to indicate profile was updated
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Failed to update profile'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _updateProfile,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Personal Information
              _buildSectionHeader('Personal Information'),
              _buildTextField(
                controller: _firstNameController,
                label: 'First Name',
                validator: (value) => value?.isEmpty == true ? 'Please enter first name' : null,
              ),
              _buildTextField(
                controller: _lastNameController,
                label: 'Last Name',
                validator: (value) => value?.isEmpty == true ? 'Please enter last name' : null,
              ),
              _buildTextField(
                controller: _emailController,
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value?.isEmpty == true) return 'Please enter email';
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value!)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              _buildTextField(
                controller: _mobileController,
                label: 'Mobile Number',
                keyboardType: TextInputType.phone,
                validator: (value) => value?.isEmpty == true ? 'Please enter mobile number' : null,
              ),
              
              // Blood Group Dropdown
              _buildDropdown(
                value: _selectedBloodGroup,
                items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
                label: 'Blood Group',
                onChanged: (value) => setState(() => _selectedBloodGroup = value),
              ),
              
              // Gender Dropdown
              _buildDropdown(
                value: _selectedGender,
                items: ['Male', 'Female', 'Other'],
                label: 'Gender',
                onChanged: (value) => setState(() => _selectedGender = value),
              ),

              const SizedBox(height: 24),

              // Address Information
              _buildSectionHeader('Address Information'),
              _buildTextField(
                controller: _currentAddressController,
                label: 'Current Address',
                maxLines: 3,
              ),
              _buildTextField(
                controller: _permanentAddressController,
                label: 'Permanent Address',
                maxLines: 3,
              ),

              const SizedBox(height: 24),

              // Father Information
              _buildSectionHeader('Father Information'),
              _buildTextField(
                controller: _fatherNameController,
                label: 'Father Name',
              ),
              _buildTextField(
                controller: _fatherPhoneController,
                label: 'Father Phone',
                keyboardType: TextInputType.phone,
              ),
              _buildTextField(
                controller: _fatherOccupationController,
                label: 'Father Occupation',
              ),

              const SizedBox(height: 24),

              // Mother Information
              _buildSectionHeader('Mother Information'),
              _buildTextField(
                controller: _motherNameController,
                label: 'Mother Name',
              ),
              _buildTextField(
                controller: _motherPhoneController,
                label: 'Mother Phone',
                keyboardType: TextInputType.phone,
              ),
              _buildTextField(
                controller: _motherOccupationController,
                label: 'Mother Occupation',
              ),

              const SizedBox(height: 24),

              // Guardian Information
              _buildSectionHeader('Guardian Information'),
              _buildTextField(
                controller: _guardianNameController,
                label: 'Guardian Name',
              ),
              _buildTextField(
                controller: _guardianPhoneController,
                label: 'Guardian Phone',
                keyboardType: TextInputType.phone,
              ),
              _buildTextField(
                controller: _guardianEmailController,
                label: 'Guardian Email',
                keyboardType: TextInputType.emailAddress,
              ),
              _buildTextField(
                controller: _guardianAddressController,
                label: 'Guardian Address',
                maxLines: 2,
              ),
              _buildTextField(
                controller: _guardianOccupationController,
                label: 'Guardian Occupation',
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required String label,
    required void Function(String?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        items: items.map((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item),
          );
        }).toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
    );
  }
}

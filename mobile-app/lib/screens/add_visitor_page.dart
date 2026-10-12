import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:io';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/translated_text.dart';

class AddVisitorPage extends StatefulWidget {
  const AddVisitorPage({super.key});

  @override
  State<AddVisitorPage> createState() => _AddVisitorPageState();
}

class _AddVisitorPageState extends State<AddVisitorPage> {
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  final _purposeController = TextEditingController();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _idProofController = TextEditingController();
  final _noOfPeopleController = TextEditingController();
  final _dateController = TextEditingController();
  final _inTimeController = TextEditingController();
  final _outTimeController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _dateController.text = _formatDisplayDate(DateTime.now());
  }

  String _formatApiDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  String _formatDisplayDate(DateTime date) {
    return "${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}";
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _dateController.text = _formatDisplayDate(picked);
      });
    }
  }

  Future<void> _selectTime(TextEditingController controller) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        controller.text = picked.format(context);
      });
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
    });

    try {
      final studentId = await AuthService.getStudentId();
      final response = await ApiService.addVisitor(
        studentId: studentId,
        purpose: _purposeController.text,
        name: _nameController.text,
        contact: _contactController.text,
        idProof: _idProofController.text,
        noOfPeople: _noOfPeopleController.text,
        date: _formatApiDate(DateFormat('MM/dd/yyyy').parse(_dateController.text)),
        inTime: _inTimeController.text,
        outTime: _outTimeController.text,
        note: _noteController.text,
        filePath: _selectedImage?.path,
      );

      if (!mounted) return;

      if (response['status'] == '1' || response['status'] == 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: TranslatedText('Visitor added successfully')),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: TranslatedText(response['message'] ?? 'Failed to add visitor')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: TranslatedText('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const TranslatedText('Add Visitor', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[800],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTextField(_nameController, 'Name', Icons.person),
                    _buildTextField(_purposeController, 'Purpose', Icons.info_outline),
                    _buildTextField(_contactController, 'Contact', Icons.phone, keyboardType: TextInputType.phone),
                    _buildTextField(_idProofController, 'ID Proof', Icons.badge),
                    _buildTextField(_noOfPeopleController, 'No. of People', Icons.people, keyboardType: TextInputType.number),
                    _buildDateField(),
                    Row(
                      children: [
                        Expanded(child: _buildTimeField(_inTimeController, 'In Time')),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTimeField(_outTimeController, 'Out Time')),
                      ],
                    ),
                    _buildTextField(_noteController, 'Note', Icons.note, maxLines: 3),
                    const SizedBox(height: 16),
                    _buildImagePicker(),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const TranslatedText('Submit', style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {TextInputType? keyboardType, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: (value) => value == null || value.isEmpty ? 'Please enter $label' : null,
      ),
    );
  }

  Widget _buildDateField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: _dateController,
        readOnly: true,
        decoration: const InputDecoration(
          labelText: 'Date',
          prefixIcon: Icon(Icons.calendar_today),
          border: OutlineInputBorder(),
        ),
        onTap: _selectDate,
        validator: (value) => value == null || value.isEmpty ? 'Please select date' : null,
      ),
    );
  }

  Widget _buildTimeField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.access_time),
          border: const OutlineInputBorder(),
        ),
        onTap: () => _selectTime(controller),
        validator: (value) => value == null || value.isEmpty ? 'Please select $label' : null,
      ),
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TranslatedText('Attachment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickImage,
          child: Container(
            height: 150,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _selectedImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(_selectedImage!, fit: BoxFit.cover, width: double.infinity),
                  )
                : const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                        TranslatedText('Tap to pick an image', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
          ),
        ),
        if (_selectedImage != null)
          TextButton(
            onPressed: () => setState(() => _selectedImage = null),
            child: const TranslatedText('Remove Image', style: TextStyle(color: Colors.red)),
          ),
      ],
    );
  }
}

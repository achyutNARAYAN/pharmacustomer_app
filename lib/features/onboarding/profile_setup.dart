import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/services/api_service.dart';
import '../../core/providers/profile_notifier.dart';
import '../auth/models/auth_session.dart';
import '../auth/providers/auth_provider.dart';
import '../home/main_nav_wrapper.dart';

class ProfileSetup extends StatefulWidget {
  const ProfileSetup({super.key, this.phoneNumber = ''});
  final String phoneNumber;

  @override
  State<ProfileSetup> createState() => _ProfileSetupState();
}

class _ProfileSetupState extends State<ProfileSetup> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  DateTime? _selectedDobDate;
  XFile? _profileImage;
  String? _selectedGender;
  late String _phoneNumber;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _phoneNumber = widget.phoneNumber;
  }

  static const List<String> _genders = ['Female', 'Male', 'Other', 'Prefer not to say'];

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1995, 1, 1),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDobDate = picked;
        _dobController.text =
            '${picked.day.toString().padLeft(2, '0')} / ${picked.month.toString().padLeft(2, '0')} / ${picked.year}';
      });
    }
  }

  Future<void> _selectProfileImage() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image != null && mounted) setState(() => _profileImage = image);
  }

  Future<void> _completeProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _dobController.text.isEmpty || _selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter your name, date of birth, and gender'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    final dobIso = _selectedDobDate != null
        ? '${_selectedDobDate!.year}-${_selectedDobDate!.month.toString().padLeft(2, '0')}-${_selectedDobDate!.day.toString().padLeft(2, '0')}'
        : '';
    final gender = _selectedGender == 'Female'
        ? 'FEMALE'
        : _selectedGender == 'Male'
            ? 'MALE'
            : 'OTHER';

    setState(() => _isSaving = true);

    try {
      final res = await ApiService.registerCustomer(
        mobileNumber: _phoneNumber.isNotEmpty ? _phoneNumber : '9876543210',
        fullName: name,
        email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
        dob: dobIso.isNotEmpty ? dobIso : null,
        gender: gender.isNotEmpty ? gender : null,
      );

      final token = (res['token'] as String?) ?? ApiService.token;
      final custMap = (res['customer'] is Map ? res['customer'] : res) as Map<String, dynamic>?;
      final rawMongoId = custMap?['_id'] as String? ?? custMap?['id'] as String? ?? custMap?['customerId'] as String? ?? '';
      final customerId = rawMongoId;
      if (customerId.isNotEmpty && customerId != 'u_customer') {
        ApiService.setCustomerId(customerId);
      }

      if (token != null && token.isNotEmpty && mounted) {
        final session = AuthSession(
          accessToken: token,
          refreshToken: token,
          accessExpiresAt: DateTime.now().toUtc().add(const Duration(days: 30)),
          userId: customerId.isNotEmpty ? customerId : 'u_customer',
        );
        await context.read<AuthProvider>().onOtpSuccess(session);
      }

      if (mounted) {
        final profile = context.read<ProfileNotifier>();
        profile.setName(name);
        if (_phoneNumber.isNotEmpty) profile.setPhone(_phoneNumber);
        if (_emailController.text.trim().isNotEmpty) profile.setEmail(_emailController.text.trim());
      }

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => MainNavWrapper(
            name: name,
            phoneNumber: _phoneNumber,
            email: _emailController.text.trim(),
            profileImagePath: _profileImage?.path,
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('ValidationFailure: ', '').replaceAll('NetworkFailure: ', '')),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppTheme.text),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Complete Your Profile',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.text),
              ),
              const SizedBox(height: 8),
              const Text(
                'Help us personalize your medicine delivery and order receipts',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 32),
              Center(
                child: GestureDetector(
                  onTap: _selectProfileImage,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.teal.withValues(alpha: 0.2), width: 4),
                              image: _profileImage == null
                                  ? null
                                  : DecorationImage(
                                      image: FileImage(File(_profileImage!.path)),
                                      fit: BoxFit.cover,
                                    ),
                            ),
                            child: _profileImage == null
                                ? const Icon(Icons.person_outline, size: 48, color: AppTheme.primary)
                                : null,
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text('Add patient profile photo', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              _buildLabel('Full Name *', 'As per Gov ID'),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.badge_outlined),
                  hintText: 'Enter full name',
                ),
              ),
              const SizedBox(height: 20),
              _buildLabel('Date of Birth *', ''),
              TextField(
                controller: _dobController,
                readOnly: true,
                onTap: _selectDate,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                  hintText: 'DD / MM / YYYY',
                ),
              ),
              const SizedBox(height: 20),
              _buildLabel('Email Address (Optional)', ''),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.email_outlined),
                  hintText: 'Enter email address',
                ),
              ),
              const SizedBox(height: 20),
              const Text('Gender', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.text)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _genders.map((gender) {
                  final isSelected = _selectedGender == gender;
                  return SizedBox(
                    width: (MediaQuery.of(context).size.width - 60) / 2,
                    child: OutlinedButton(
                      onPressed: () => setState(() => _selectedGender = gender),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isSelected ? AppTheme.primary : Colors.white,
                        foregroundColor: isSelected ? Colors.white : AppTheme.text,
                        side: BorderSide(color: isSelected ? AppTheme.primary : Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(gender),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: _isSaving ? null : _completeProfile,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Complete Profile'),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 18),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _buildLabel(String main, String sub) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(main, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.text)),
          if (sub.isNotEmpty) Text(sub, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}

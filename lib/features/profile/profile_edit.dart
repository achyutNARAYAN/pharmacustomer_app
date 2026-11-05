import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'customer_address_screen.dart';

import '../../core/theme.dart';

class ProfileDetails {
  const ProfileDetails({
    required this.name,
    required this.phoneNumber,
    required this.email,
    required this.address,
    required this.workAddress,
    required this.parentsAddress,
    required this.profileImagePath,
  });

  final String name;
  final String phoneNumber;
  final String email;
  final String address;
  final String workAddress;
  final String parentsAddress;
  final String? profileImagePath;
}

class ProfileEdit extends StatefulWidget {
  const ProfileEdit({
    super.key,
    required this.details,
  });

  final ProfileDetails details;

  @override
  State<ProfileEdit> createState() => _ProfileEditState();
}

class _ProfileEditState extends State<ProfileEdit> {
  late final _name = TextEditingController(text: widget.details.name);
  late final _phone = TextEditingController(text: widget.details.phoneNumber);
  late final _email = TextEditingController(text: widget.details.email);
  late final _address = TextEditingController(text: widget.details.address);
  late final _workAddress = TextEditingController(text: widget.details.workAddress);
  late final _parentsAddress = TextEditingController(text: widget.details.parentsAddress);
  late String? _imagePath = widget.details.profileImagePath;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _workAddress.dispose();
    _parentsAddress.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image != null && mounted) setState(() => _imagePath = image.path);
  }

  void _save() {
    if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty || _address.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name, phone, and address are required.')),
      );
      return;
    }
    Navigator.pop(context, ProfileDetails(
      name: _name.text.trim(),
      phoneNumber: _phone.text.trim(),
      email: _email.text.trim(),
      address: _address.text.trim(),
      workAddress: _workAddress.text.trim(),
      parentsAddress: _parentsAddress.text.trim(),
      profileImagePath: _imagePath,
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      centerTitle: true,
      title: const Text('Edit profile'),
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              children: [
                Center(
                  child: Column(
                    children: [
                      InkWell(
                        onTap: _pickImage,
                        customBorder: const CircleBorder(),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppTheme.primary.withValues(alpha: .2), width: 2),
                              ),
                              child: CircleAvatar(
                                radius: 46,
                                backgroundColor: AppTheme.primaryContainer,
                                backgroundImage: _imagePath == null ? null : FileImage(File(_imagePath!)),
                                child: _imagePath == null ? const Icon(Icons.person_outline, color: AppTheme.primary, size: 42) : null,
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 2,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppTheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppTheme.background, width: 3),
                                ),
                                child: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 15),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.photo_library_outlined, size: 18),
                        label: const Text('Change profile photo'),
                        style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('Personal details', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text('Keep your contact and delivery information up to date.', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 22),
                _field(_name, 'Full name', Icons.person_outline, textCapitalization: TextCapitalization.words),
                const SizedBox(height: 14),
                _field(_phone, 'Phone number', Icons.phone_outlined, keyboardType: TextInputType.phone),
                const SizedBox(height: 14),
                _field(_email, 'Email address (optional)', Icons.mail_outline, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 14),
                Text('Delivery addresses', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text('Saved addresses available at checkout.', style: Theme.of(context).textTheme.bodyMedium),
                    ),
                    TextButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => CustomerAddressManagementScreen(
                            userName: _name.text,
                            userPhone: _phone.text,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.tune_rounded, size: 16),
                      label: const Text('Manage'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _field(_address, 'Home', Icons.home_outlined, minLines: 2, maxLines: 3),
                const SizedBox(height: 14),
                _field(_workAddress, 'Work', Icons.work_outline, minLines: 2, maxLines: 3),
                const SizedBox(height: 14),
                _field(_parentsAddress, 'Parent’s home', Icons.family_restroom_outlined, minLines: 2, maxLines: 3),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppTheme.outlineBorder.withValues(alpha: .7))),
            ),
            child: ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Save changes'),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(54)),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    int? minLines,
    int? maxLines = 1,
  }) => TextField(
    controller: controller,
    keyboardType: keyboardType,
    textCapitalization: textCapitalization,
    minLines: minLines,
    maxLines: maxLines,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppTheme.mutedText),
      alignLabelWithHint: minLines != null,
    ),
  );
}

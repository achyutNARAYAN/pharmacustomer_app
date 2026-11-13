import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../auth/login.dart';
import '../auth/providers/auth_provider.dart';
import '../orders/order_history.dart';
import '../prescriptions/prescription_vault.dart';
import 'customer_address_screen.dart';
import 'providers/customer_address_provider.dart';
import 'saved_patient_profiles_screen.dart';

class ProfileHome extends StatelessWidget {
  const ProfileHome({
    super.key,
    required this.name,
    required this.phoneNumber,
    required this.email,
    required this.address,
    required this.onEdit,
    this.profileImagePath,
  });
  final String name;
  final String phoneNumber;
  final String email;
  final String address;
  final String? profileImagePath;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    CustomerAddressProvider? addressProvider;
    try {
      addressProvider = Provider.of<CustomerAddressProvider>(context);
    } catch (_) {}
    final resolvedAddress = address.isNotEmpty
        ? address
        : (addressProvider?.defaultAddress?.displayDetails ?? '');

    return Scaffold(
    backgroundColor: AppTheme.background,
    appBar: AppBar(
      automaticallyImplyLeading: false,
      title: const Text('PharmaCustomer'),
      actions: [
        IconButton(
          tooltip: 'Notifications',
          onPressed: () {},
          icon: const Icon(Icons.notifications_none_rounded),
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: [
        _panel(
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, Color(0xFFF5FCFC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.primary.withValues(alpha: .25),
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: AppTheme.surfaceLow,
                    backgroundImage: profileImagePath == null
                        ? null
                        : FileImage(File(profileImagePath!)),
                    child: profileImagePath == null
                        ? const Icon(
                            Icons.person_rounded,
                            color: AppTheme.primary,
                            size: 32,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty ? 'Customer' : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.text,
                        ),
                      ),
                      const SizedBox(height: 5),
                      _ProfileDetail(
                        icon: Icons.phone_outlined,
                        text: phoneNumber.isEmpty
                            ? 'Add phone number'
                            : phoneNumber.startsWith('+')
                            ? phoneNumber
                            : '+91 $phoneNumber',
                      ),
                      if (email.isNotEmpty)
                        _ProfileDetail(
                          icon: Icons.mail_outline_rounded,
                          text: email,
                        ),
                      if (resolvedAddress.isNotEmpty)
                        _ProfileDetail(
                          icon: Icons.location_on_outlined,
                          text: resolvedAddress,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Material(
                  color: AppTheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                  child: IconButton(
                    tooltip: 'Edit profile',
                    onPressed: onEdit,
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 26),
        const _SectionTitle(
          'Account',
          subtitle: 'Manage your care in one place',
        ),
        const SizedBox(height: 12),
        _panel(
          Column(
            children: [
              _AccountRow(
                icon: Icons.people_outline,
                title: 'Saved patient profiles',
                subtitle: 'Self, Father, Mother and more',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => SavedPatientProfilesScreen(
                      userName: name,
                      profileImagePath: profileImagePath,
                    ),
                  ),
                ),
              ),
              const Divider(height: 1, indent: 64),
              _AccountRow(
                icon: Icons.location_on_outlined,
                title: 'Customer address management',
                subtitle: 'Manage HOME, WORK, OTHER delivery addresses',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => CustomerAddressManagementScreen(
                      userName: name,
                      userPhone: phoneNumber,
                    ),
                  ),
                ),
              ),
              const Divider(height: 1, indent: 64),
              _AccountRow(
                icon: Icons.description_outlined,
                title: 'Prescription vault',
                subtitle: 'Your digital prescriptions',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => PrescriptionVault(
                      patientName: name,
                      profileImagePath: profileImagePath,
                    ),
                  ),
                ),
              ),
              const Divider(height: 1, indent: 64),
              _AccountRow(
                icon: Icons.receipt_long_outlined,
                title: 'Order history',
                subtitle: 'Invoices, tracking and refills',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const OrderHistory()),
                ),
              ),
              const Divider(height: 1, indent: 64),
              _AccountRow(
                icon: Icons.logout_rounded,
                title: 'Log out',
                subtitle: 'Sign out of your account',
                onTap: () => _confirmLogout(context),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await context.read<AuthProvider>().logout();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not log out. Please try again.')),
        );
      }
      return;
    }
    if (!context.mounted) return;
    await Navigator.of(context).pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(builder: (_) => const Login()),
      (_) => false,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w700,
          color: AppTheme.text,
        ),
      ),
      if (subtitle != null) ...[
        const SizedBox(height: 3),
        Text(
          subtitle!,
          style: const TextStyle(fontSize: 12, color: AppTheme.mutedText),
        ),
      ],
    ],
  );
}

class _ProfileDetail extends StatelessWidget {
  const _ProfileDetail({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 3),
    child: Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.mutedText),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppTheme.mutedText),
          ),
        ),
      ],
    ),
  );
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    minVerticalPadding: 15,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    leading: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppTheme.primaryContainer.withValues(alpha: .75),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: AppTheme.primary, size: 21),
    ),
    title: Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppTheme.text,
      ),
    ),
    subtitle: Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: AppTheme.mutedText),
      ),
    ),
    trailing: const Icon(
      Icons.chevron_right_rounded,
      color: AppTheme.mutedText,
    ),
    onTap: onTap,
  );
}

Widget _panel(Widget child) => Material(
  color: Colors.white,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(24),
    side: const BorderSide(color: AppTheme.outlineBorder),
  ),
  elevation: 0,
  clipBehavior: Clip.antiAlias,
  child: child,
);

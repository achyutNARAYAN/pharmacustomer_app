import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/customer_support_sheet.dart';
import '../auth/login.dart';
import '../auth/providers/auth_provider.dart';
import '../orders/order_history.dart';
import '../prescriptions/prescription_vault.dart';
import 'customer_address_screen.dart';
import 'models/patient_profile.dart';
import 'providers/customer_address_provider.dart';
import 'providers/patient_profiles_provider.dart';
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

  String _formatDisplayName(String raw) {
    if (raw.trim().isEmpty) return 'Customer';
    final parts = raw.trim().split(' ');
    return parts
        .map((p) => p.isNotEmpty ? '${p[0].toUpperCase()}${p.substring(1)}' : '')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    CustomerAddressProvider? addressProvider;
    try {
      addressProvider = Provider.of<CustomerAddressProvider>(context);
    } catch (_) {}
    final resolvedAddress = address.isNotEmpty
        ? address
        : (addressProvider?.defaultAddress?.displayDetails ?? '');

    PatientProfilesProvider? patientProvider;
    try {
      patientProvider = Provider.of<PatientProfilesProvider>(context);
    } catch (_) {}
    final profiles = patientProvider?.profiles ?? [];

    final displayName = _formatDisplayName(name);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'PharmaCustomer',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.3),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              tooltip: 'Notifications',
              onPressed: () {},
              icon: const Icon(Icons.notifications_none_rounded, size: 20, color: AppTheme.text),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // ── 1. Hero User Profile Card ─────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF055A63), Color(0xFF0A7E8C)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(color: const Color(0xFF99F6E4), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF055A63).withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: profileImagePath != null
                            ? Image.file(File(profileImagePath!), fit: BoxFit.cover)
                            : Center(
                                child: Text(
                                  displayName.isNotEmpty ? displayName[0].toUpperCase() : 'C',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.text,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF0D9488),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check, size: 10, color: Colors.white),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            phoneNumber.isEmpty
                                ? 'Add phone number'
                                : phoneNumber.startsWith('+')
                                ? phoneNumber
                                : '+91 $phoneNumber',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.mutedText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: onEdit,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.18)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_outlined, size: 14, color: AppTheme.primary),
                            SizedBox(width: 4),
                            Text(
                              'Edit',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (resolvedAddress.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_rounded, size: 14, color: AppTheme.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Home: $resolvedAddress',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.text,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => CustomerAddressManagementScreen(
                                userName: name,
                                userPhone: phoneNumber,
                              ),
                            ),
                          ),
                          child: const Text(
                            'CHANGE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primaryDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ── 2. Managing Care For: Family Switcher ──────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'MANAGING CARE FOR:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.mutedText,
                  letterSpacing: 0.6,
                ),
              ),
              InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => SavedPatientProfilesScreen(
                      userName: name,
                      profileImagePath: profileImagePath,
                    ),
                  ),
                ),
                child: const Text(
                  '+ Add Member',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildFamilyChip(
                  label: '${displayName.split(" ").first} (Self)',
                  icon: Icons.person_rounded,
                  isSelected: true,
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
                const SizedBox(width: 8),
                if (profiles.isNotEmpty)
                  ...profiles.where((p) => !p.isSelf).map((p) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildFamilyChip(
                        label: '${p.name} (${p.relation.label})',
                        icon: Icons.family_restroom_rounded,
                        isSelected: false,
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
                    );
                  })
                else ...[
                  _buildFamilyChip(
                    label: 'Father (Diabetes)',
                    icon: Icons.family_restroom_rounded,
                    isSelected: false,
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
                  const SizedBox(width: 8),
                  _buildFamilyChip(
                    label: 'Mother (BP)',
                    icon: Icons.favorite_outline_rounded,
                    isSelected: false,
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
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── 3. Blinkit 3-Widget Quick Actions Grid ────────────────────────
          Row(
            children: [
              Expanded(
                child: _buildQuickWidget(
                  title: 'My Orders',
                  subtitle: '1 In Transit',
                  icon: Icons.local_shipping_outlined,
                  badgeBg: const Color(0xFFCCFBF1),
                  badgeFg: const Color(0xFF0F766E),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const OrderHistory()),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildQuickWidget(
                  title: 'Prescriptions',
                  subtitle: '3 Active',
                  icon: Icons.receipt_long_outlined,
                  badgeBg: const Color(0xFFDCFCE7),
                  badgeFg: const Color(0xFF15803D),
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
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildQuickWidget(
                  title: '24x7 Help',
                  subtitle: 'Instant Chat',
                  icon: Icons.support_agent_rounded,
                  badgeBg: const Color(0xFFE0F2FE),
                  badgeFg: const Color(0xFF0369A1),
                  onTap: () => showCustomerSupportSheet(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // ── 4. Grouped Inset Settings Cards ───────────────────────────────
          const Text(
            'ACCOUNT & PREFERENCES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppTheme.mutedText,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),

          // Card Group 1: Care & Addresses
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
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
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Card Group 2: Support & Logout
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                _AccountRow(
                  icon: Icons.support_agent_rounded,
                  title: '24x7 Customer Support',
                  subtitle: 'Instant WhatsApp chat, toll-free call & FAQs',
                  onTap: () => showCustomerSupportSheet(context),
                ),
                const Divider(height: 1, indent: 64),
                _AccountRow(
                  icon: Icons.logout_rounded,
                  iconColor: const Color(0xFFEF4444),
                  iconBg: const Color(0xFFFEE2E2),
                  title: 'Log out',
                  titleColor: const Color(0xFFDC2626),
                  subtitle: 'Sign out of your account',
                  onTap: () => _confirmLogout(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── 5. App Version Footer ──────────────────────────────────────────
          const Center(
            child: Text(
              'PharmaCustomer App v1.2.4 (Build 42) • 10-Min Delivery Partner',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryDark : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryDark : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : AppTheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : AppTheme.text,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickWidget({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color badgeBg,
    required Color badgeFg,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.025),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: AppTheme.primaryDark),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: AppTheme.text,
              ),
            ),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: badgeFg,
                ),
              ),
            ),
          ],
        ),
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
        AppToast.error(context, 'Could not log out. Please try again.');
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

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconBg,
    this.iconColor,
    this.titleColor,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? iconBg;
  final Color? iconColor;
  final Color? titleColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    minVerticalPadding: 14,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    leading: Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: iconBg ?? AppTheme.primaryContainer.withValues(alpha: .75),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, color: iconColor ?? AppTheme.primary, size: 20),
    ),
    title: Text(
      title,
      style: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.bold,
        color: titleColor ?? AppTheme.text,
      ),
    ),
    subtitle: Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text(
        subtitle,
        style: const TextStyle(fontSize: 11.5, color: AppTheme.mutedText),
      ),
    ),
    trailing: const Icon(
      Icons.chevron_right_rounded,
      size: 18,
      color: AppTheme.mutedText,
    ),
    onTap: onTap,
  );
}

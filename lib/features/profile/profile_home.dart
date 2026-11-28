import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/profile_notifier.dart';
import '../../core/services/api_service.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/customer_support_sheet.dart';
import '../auth/login.dart';
import '../auth/providers/auth_provider.dart';
import '../orders/order_history.dart';
import '../orders/providers/orders_provider.dart';
import '../prescriptions/prescription_vault.dart';
import '../prescriptions/providers/prescription_provider.dart';
import '../prescriptions/repositories/prescription_repository.dart';
import 'customer_address_screen.dart';
import 'models/patient_profile.dart';
import 'providers/customer_address_provider.dart';
import 'providers/patient_profiles_provider.dart';
import 'saved_patient_profiles_screen.dart';
import 'widgets/add_edit_patient_sheet.dart';

class ProfileHome extends StatefulWidget {
  const ProfileHome({
    super.key,
    required this.name,
    required this.phoneNumber,
    required this.email,
    required this.address,
    required this.onEdit,
  });
  final String name;
  final String phoneNumber;
  final String email;
  final String address;
  final VoidCallback onEdit;

  @override
  State<ProfileHome> createState() => _ProfileHomeState();
}

class _ProfileHomeState extends State<ProfileHome> {
  List<PatientProfile> _cachedFamilyMembers = const [];
  PatientProfile? _localSelfProfile;

  @override
  void initState() {
    super.initState();
    _loadCachedFamilyMembers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshBackendData(silent: true);
    });
  }

  static PatientRelation _parseRelation(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'self':
        return PatientRelation.self;
      case 'father':
        return PatientRelation.father;
      case 'mother':
        return PatientRelation.mother;
      case 'son':
        return PatientRelation.son;
      case 'daughter':
        return PatientRelation.daughter;
      default:
        return PatientRelation.other;
    }
  }

  static String _parseGender(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    return switch (raw.trim().toUpperCase()) {
      'MALE' || 'M' => 'Male',
      'FEMALE' || 'F' => 'Female',
      'OTHER' || 'O' => 'Other',
      'PREFER_NOT_TO_SAY' || 'PREFER NOT TO SAY' => 'Prefer not to say',
      _ => raw.trim(),
    };
  }

  void _loadCachedFamilyMembers() {
    final cached = ApiService.cachedCustomerProfile;
    if (cached == null) return;
    final cust = (cached['customer'] is Map ? cached['customer'] : cached)
        as Map<String, dynamic>;
    final rawMembers = cust['familyMembers'] as List<dynamic>? ?? const [];
    final parsed = <PatientProfile>[];
    for (final m in rawMembers) {
      if (m is Map) {
        final memberName =
            (m['fullName'] as String? ?? m['name'] as String? ?? '').trim();
        if (memberName.isEmpty) continue;
        final id = (m['_id'] as String? ?? m['id'] as String? ?? '').trim();
        final rawRel =
            (m['relation'] as String? ?? m['relationship'] as String? ?? '')
                .trim();
        final relation = _parseRelation(rawRel);
        final rawDob = m['dateOfBirth'] as String? ?? m['dob'] as String?;
        final dob = rawDob != null ? DateTime.tryParse(rawDob) : null;
        final conditions = (m['chronicConditions'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList();
        final allergies = (m['allergies'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList();
        parsed.add(
          PatientProfile(
            id: id.isNotEmpty
                ? id
                : '${memberName.toLowerCase()}_${relation.name}',
            name: memberName,
            relation: relation,
            customRelationLabel: relation == PatientRelation.other &&
                    rawRel.isNotEmpty &&
                    rawRel.toUpperCase() != 'OTHER'
                ? '${rawRel[0].toUpperCase()}${rawRel.substring(1).toLowerCase()}'
                : (m['customRelationLabel'] as String?),
            dob: dob,
            gender: _parseGender(m['gender'] as String?),
            phoneNumber:
                (m['phoneNumber'] as String? ?? m['phone'] as String? ?? '')
                    .trim(),
            chronicConditions: conditions,
            allergies: allergies,
            lastUpdated: DateTime.now(),
          ),
        );
      }
    }
    _cachedFamilyMembers = parsed;
  }

  Future<void> _refreshBackendData({bool silent = false}) async {
    OrdersProvider? ordersProvider;
    PrescriptionProvider? rxProvider;
    PatientProfilesProvider? patientProvider;
    try {
      ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    } catch (_) {}
    try {
      rxProvider = Provider.of<PrescriptionProvider>(context, listen: false);
    } catch (_) {}
    try {
      patientProvider = Provider.of<PatientProfilesProvider>(context, listen: false);
    } catch (_) {}

    await Future.wait([
      if (ordersProvider != null) ordersProvider.fetchOrders(silent: true, force: !silent),
      if (rxProvider != null) rxProvider.refresh(force: !silent),
      if (patientProvider != null)
        patientProvider.refresh()
      else if (!silent)
        ApiService.getCustomerProfile(),
    ]);
    if (!mounted) return;
    setState(_loadCachedFamilyMembers);
  }

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
    final resolvedAddress = widget.address.isNotEmpty
        ? widget.address
        : (addressProvider?.defaultAddress?.displayDetails ?? '');

    PatientProfilesProvider? patientProvider;
    try {
      patientProvider = Provider.of<PatientProfilesProvider>(context);
    } catch (_) {}

    OrdersProvider? ordersProvider;
    try {
      ordersProvider = Provider.of<OrdersProvider>(context);
    } catch (_) {}
    final orders = ordersProvider?.orders ?? const <OrderModel>[];

    PrescriptionProvider? rxProvider;
    try {
      rxProvider = Provider.of<PrescriptionProvider>(context);
    } catch (_) {}
    final prescriptions = rxProvider?.prescriptions ?? const <Prescription>[];

    // ── Live Order Metrics ──────────────────────────────────────────────────
    final totalOrdersCount = orders.length;
    final inTransitCount = orders
        .where((o) => o.status == OrderStatus.OUT_FOR_DELIVERY)
        .length;
    final activeOrdersCount = orders.where((o) => o.isActive).length;
    final deliveredCount =
        orders.where((o) => o.status == OrderStatus.DELIVERED).length;

    final String ordersBadge;
    final Color ordersBadgeBg;
    final Color ordersBadgeFg;
    if (inTransitCount > 0) {
      ordersBadge = '$inTransitCount In Transit';
      ordersBadgeBg = const Color(0xFFCCFBF1);
      ordersBadgeFg = const Color(0xFF0F766E);
    } else if (activeOrdersCount > 0) {
      ordersBadge = '$activeOrdersCount Active';
      ordersBadgeBg = const Color(0xFFCCFBF1);
      ordersBadgeFg = const Color(0xFF0F766E);
    } else if (deliveredCount > 0) {
      ordersBadge = '$deliveredCount Delivered';
      ordersBadgeBg = const Color(0xFFDCFCE7);
      ordersBadgeFg = const Color(0xFF15803D);
    } else if (totalOrdersCount > 0) {
      ordersBadge = '$totalOrdersCount Orders';
      ordersBadgeBg = const Color(0xFFF1F5F9);
      ordersBadgeFg = const Color(0xFF475569);
    } else {
      ordersBadge = 'No Orders';
      ordersBadgeBg = const Color(0xFFF1F5F9);
      ordersBadgeFg = const Color(0xFF64748B);
    }

    // ── Live Prescription Metrics ───────────────────────────────────────────
    final approvedRxCount = prescriptions
        .where((p) => p.status == PrescriptionStatus.approved)
        .length;
    final pendingRxCount = prescriptions
        .where((p) =>
            p.status == PrescriptionStatus.underReview ||
            p.status == PrescriptionStatus.uploaded)
        .length;

    final String rxBadge;
    final Color rxBadgeBg;
    final Color rxBadgeFg;
    if (approvedRxCount > 0) {
      rxBadge = '$approvedRxCount Approved';
      rxBadgeBg = const Color(0xFFDCFCE7);
      rxBadgeFg = const Color(0xFF15803D);
    } else if (pendingRxCount > 0) {
      rxBadge = '$pendingRxCount In Review';
      rxBadgeBg = const Color(0xFFFEF3C7);
      rxBadgeFg = const Color(0xFFD97706);
    } else if (prescriptions.isNotEmpty) {
      rxBadge = '${prescriptions.length} Saved';
      rxBadgeBg = const Color(0xFFF1F5F9);
      rxBadgeFg = const Color(0xFF475569);
    } else {
      rxBadge = '0 Approved';
      rxBadgeBg = const Color(0xFFF1F5F9);
      rxBadgeFg = const Color(0xFF64748B);
    }

    // ── Live Family Members ─────────────────────────────────────────────────
    final providerProfiles =
        patientProvider?.profiles ?? const <PatientProfile>[];
    final providerMembers = providerProfiles.where((p) => !p.isSelf).toList();
    final familyMembers = providerMembers.isNotEmpty
        ? providerMembers
        : _cachedFamilyMembers;
    final totalMembersCount = 1 + familyMembers.length;

    final displayName = _formatDisplayName(widget.name);
    final firstName = displayName.split(' ').first;

    final selfProfile = providerProfiles.cast<PatientProfile?>().firstWhere(
          (p) => p?.isSelf == true,
          orElse: () => null,
        ) ??
        _localSelfProfile ??
        PatientProfile(
          id: 'self',
          name: widget.name.isEmpty ? 'You' : widget.name,
          relation: PatientRelation.self,
          phoneNumber: widget.phoneNumber,
          isSelf: true,
          isDefault: true,
          lastUpdated: DateTime.now(),
        );

    final savedProfilesSubtitle = familyMembers.isEmpty
        ? 'Manage patient & family profiles'
        : 'Self, ${familyMembers.map((m) => m.name.split(' ').first).join(', ')}';

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
      body: RefreshIndicator(
        onRefresh: () => _refreshBackendData(),
        color: AppTheme.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
          // ── 1. Gradient Hero Card ─────────────────────────────────────────
          _HeroCard(
            displayName: displayName,
            phoneNumber: widget.phoneNumber,
            resolvedAddress: resolvedAddress,
            totalOrders: totalOrdersCount,
            activeRx: approvedRxCount,
            membersCount: totalMembersCount,
            onEdit: widget.onEdit,
            onChangeAddress: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => CustomerAddressManagementScreen(
                  userName: widget.name,
                  userPhone: widget.phoneNumber,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // ── 2. Managing Care For ──────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'MANAGING CARE FOR',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.mutedText,
                  letterSpacing: 0.8,
                ),
              ),
              InkWell(
                onTap: () => _openPatientSheet(context, existingMembers: familyMembers),
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
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _FamilyPill(
                  label: firstName,
                  tag: 'Self',
                  icon: Icons.person_rounded,
                  isSelected: true,
                  onTap: () => _openPatientSheet(
                    context,
                    current: selfProfile,
                    existingMembers: familyMembers,
                  ),
                ),
                if (familyMembers.isNotEmpty) const SizedBox(width: 8),
                ...familyMembers.map((m) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FamilyPill(
                      label: m.name.split(' ').first,
                      tag: m.relationName,
                      icon: Icons.people_rounded,
                      isSelected: false,
                      onTap: () => _openPatientSheet(
                        context,
                        current: m,
                        existingMembers: familyMembers,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── 3. Quick Actions Grid ─────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  title: 'My Orders',
                  badge: ordersBadge,
                  icon: Icons.local_shipping_outlined,
                  iconBg: ordersBadgeBg,
                  iconColor: ordersBadgeFg,
                  badgeBg: ordersBadgeBg,
                  badgeFg: ordersBadgeFg,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const OrderHistory()),
                  ).then((_) => _refreshBackendData(silent: true)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickAction(
                  title: 'Prescriptions',
                  badge: rxBadge,
                  icon: Icons.receipt_long_outlined,
                  iconBg: rxBadgeBg,
                  iconColor: rxBadgeFg,
                  badgeBg: rxBadgeBg,
                  badgeFg: rxBadgeFg,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => PrescriptionVault(
                        patientName: widget.name,
                      ),
                    ),
                  ).then((_) => _refreshBackendData(silent: true)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickAction(
                  title: '24x7 Help',
                  badge: 'Instant Chat',
                  icon: Icons.support_agent_rounded,
                  iconBg: const Color(0xFFE0F2FE),
                  iconColor: const Color(0xFF0369A1),
                  badgeBg: const Color(0xFFE0F2FE),
                  badgeFg: const Color(0xFF0369A1),
                  onTap: () => showCustomerSupportSheet(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── 4. Account & Preferences ──────────────────────────────────────
          const Text(
            'ACCOUNT & PREFERENCES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppTheme.mutedText,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),

          // Card Group 1
          _SettingsGroup(
            rows: [
              _SettingsRowData(
                icon: Icons.people_outline,
                iconBg: AppTheme.primaryContainer,
                iconColor: AppTheme.primary,
                title: 'Saved patient profiles',
                subtitle: savedProfilesSubtitle,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => SavedPatientProfilesScreen(
                      userName: widget.name,
                    ),
                  ),
                ).then((_) => _refreshBackendData(silent: true)),
              ),
              _SettingsRowData(
                icon: Icons.location_on_outlined,
                iconBg: AppTheme.primaryContainer,
                iconColor: AppTheme.primary,
                title: 'Address management',
                subtitle: 'Manage HOME, WORK, OTHER delivery addresses',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => CustomerAddressManagementScreen(
                      userName: widget.name,
                      userPhone: widget.phoneNumber,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Card Group 2
          _SettingsGroup(
            rows: [
              _SettingsRowData(
                icon: Icons.support_agent_rounded,
                iconBg: AppTheme.infoBg,
                iconColor: AppTheme.infoText,
                title: '24x7 Customer Support',
                subtitle: 'Instant WhatsApp chat, toll-free call & FAQs',
                onTap: () => showCustomerSupportSheet(context),
              ),
              _SettingsRowData(
                icon: Icons.logout_rounded,
                iconBg: AppTheme.errorBg,
                iconColor: AppTheme.error,
                title: 'Log out',
                titleColor: AppTheme.error,
                subtitle: 'Sign out of your account',
                onTap: () => _confirmLogout(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        ),
      ),
    );
  }

  Future<void> _openPatientSheet(
    BuildContext context, {
    PatientProfile? current,
    required List<PatientProfile> existingMembers,
  }) async {
    final value = await showAddEditPatientSheet(context, profile: current);
    if (value == null || !context.mounted) return;

    if (!value.isSelf) {
      final duplicate = existingMembers.any(
        (p) =>
            p.id != value.id &&
            p.name.toLowerCase() == value.name.toLowerCase() &&
            p.relation == value.relation,
      );
      if (duplicate) {
        AppToast.error(
          context,
          'A profile with this name and relation already exists.',
        );
      }
      final occupiedRelation = existingMembers.any(
        (p) =>
            p.id != value.id &&
            p.relation == value.relation &&
            (value.relation == PatientRelation.father ||
                value.relation == PatientRelation.mother),
      );
      if (occupiedRelation) {
        AppToast.error(
          context,
          'Only one ${value.relation.label} profile can be saved.',
        );
        return;
      }
    }

    PatientProfilesProvider? patientProvider;
    try {
      patientProvider = Provider.of<PatientProfilesProvider>(
        context,
        listen: false,
      );
    } catch (_) {}

    if (patientProvider != null) {
      await patientProvider.save(value, add: current == null);
      if (!mounted) return;
      setState(_loadCachedFamilyMembers);
      return;
    }

    if (current == null) {
      setState(() {
        _cachedFamilyMembers = [..._cachedFamilyMembers, value];
      });
      if (ApiService.token != null) {
        final relStr = switch (value.relation) {
          PatientRelation.self => 'SELF',
          PatientRelation.father => 'FATHER',
          PatientRelation.mother => 'MOTHER',
          PatientRelation.son => 'SON',
          PatientRelation.daughter => 'DAUGHTER',
          PatientRelation.other => 'OTHER',
        };
        final genStr = switch (value.gender.trim().toUpperCase()) {
          'MALE' || 'M' => 'MALE',
          'FEMALE' || 'F' => 'FEMALE',
          'PREFER_NOT_TO_SAY' || 'PREFER NOT TO SAY' => 'PREFER_NOT_TO_SAY',
          _ => 'OTHER',
        };
        final dob = value.dob ??
            DateTime.now().subtract(const Duration(days: 365 * 30));
        await ApiService.addFamilyMember(
          ApiService.currentCustomerId,
          fullName: value.name,
          relation: relStr,
          gender: genStr,
          dateOfBirth: dob.toUtc().toIso8601String(),
        );
        await _refreshBackendData(silent: true);
      }
      return;
    }

    if (current.isSelf) {
      setState(() => _localSelfProfile = value);
      try {
        final notifier = context.read<ProfileNotifier>();
        notifier.update(
          name: value.name,
          phoneNumber: value.phoneNumber.isNotEmpty
              ? value.phoneNumber
              : notifier.phoneNumber,
          email: notifier.email,
          address: notifier.address,
          workAddress: notifier.workAddress,
          parentsAddress: notifier.parentsAddress,
          profileImagePath: notifier.profileImagePath,
        );
      } catch (_) {}
      return;
    }

    setState(() {
      _cachedFamilyMembers = [
        for (final m in _cachedFamilyMembers)
          if (m.id == value.id) value else m,
      ];
    });
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

// ═══════════════════════════════════════════════════════════════════════════════
// HERO CARD — Gradient with stats strip
// ═══════════════════════════════════════════════════════════════════════════════
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.displayName,
    required this.phoneNumber,
    required this.resolvedAddress,
    required this.totalOrders,
    required this.activeRx,
    required this.membersCount,
    required this.onEdit,
    required this.onChangeAddress,
  });

  final String displayName;
  final String phoneNumber;
  final String resolvedAddress;
  final int totalOrders;
  final int activeRx;
  final int membersCount;
  final VoidCallback onEdit;
  final VoidCallback onChangeAddress;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF087F8C), Color(0xFF087F8C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.30),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -28, right: -28,
            child: Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            bottom: -40, left: 20,
            child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // ── Info row ──
                Row(
                  children: [
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
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            phoneNumber.isEmpty
                                ? 'Add phone number'
                                : phoneNumber.startsWith('+')
                                ? phoneNumber
                                : '+91 $phoneNumber',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: onEdit,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_outlined,
                                size: 13, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Edit',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Stats strip ──
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatItem(
                          label: 'Total Orders',
                          value: '$totalOrders',
                        ),
                      ),
                      Container(
                        width: 1, height: 32,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      Expanded(
                        child: _StatItem(
                          label: 'Active Rx',
                          value: '$activeRx',
                        ),
                      ),
                      Container(
                        width: 1, height: 32,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      Expanded(
                        child: _StatItem(
                          label: 'Members',
                          value: '$membersCount',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── Address bar ──
                if (resolvedAddress.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_rounded,
                            size: 14, color: Colors.white),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            'Home: $resolvedAddress',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: onChangeAddress,
                          child: const Text(
                            'CHANGE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFA7F3D0),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stat item inside hero card ────────────────────────────────────────────────
class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.65),
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

class _FamilyPill extends StatelessWidget {
  const _FamilyPill({
    required this.label,
    this.tag,
    this.icon = Icons.people_rounded,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String? tag;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF055A63), Color(0xFF087F8C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF087F8C).withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
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
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppTheme.text,
              ),
            ),
            if (tag != null && tag!.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.2)
                      : AppTheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tag!,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : AppTheme.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.title,
    required this.badge,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.badgeBg,
    required this.badgeFg,
    required this.onTap,
  });

  final String title;
  final String badge;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final Color badgeBg;
  final Color badgeFg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 22, color: iconColor),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: AppTheme.text,
              ),
            ),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badge,
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
}

class _SettingsRowData {
  const _SettingsRowData({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.titleColor,
    this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color? titleColor;
  final VoidCallback? onTap;
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.rows});
  final List<_SettingsRowData> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                indent: 68,
                color: const Color(0xFFF1F5F9),
              ),
            _SettingsRow(data: rows[i]),
          ],
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.data});
  final _SettingsRowData data;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: data.onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: data.iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(data.icon, size: 20, color: data.iconColor),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: data.titleColor ?? AppTheme.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.subtitle,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.mutedText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

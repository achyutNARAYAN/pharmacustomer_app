import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/providers/cart_notifier.dart';
import '../../core/providers/profile_notifier.dart';
import '../prescriptions/providers/prescription_provider.dart';
import '../prescriptions/repositories/prescription_repository.dart';
import '../orders/providers/orders_provider.dart';
import 'home.dart';
import 'search.dart';
import '../prescriptions/prescription_vault.dart';
import '../orders/order_history.dart';
import '../profile/profile_home.dart';
import '../profile/profile_edit.dart';
import '../profile/providers/customer_address_provider.dart';
import '../prescriptions/prescription_review.dart';

class MainNavWrapper extends StatefulWidget {
  final String name;
  final String phoneNumber;
  final String email;
  final String location;
  const MainNavWrapper({
    super.key,
    required this.name,
    this.phoneNumber = '',
    this.email = '',
    this.location = 'Set delivery location',
  });

  @override
  State<MainNavWrapper> createState() => _MainNavWrapperState();
}

class _MainNavWrapperState extends State<MainNavWrapper> {
  int _currentIndex = 0;
  @override
  void initState() {
    super.initState();
    final profile = context.read<ProfileNotifier>();
    final initialLocation = (widget.location.isNotEmpty && widget.location != 'Set delivery location')
        ? widget.location
        : (profile.address != 'Set delivery location' ? profile.address : '');
    profile.initialize(
      name: widget.name,
      phoneNumber: widget.phoneNumber,
      email: widget.email,
      address: initialLocation,
      workAddress: profile.workAddress,
      parentsAddress: profile.parentsAddress,
    );
  }

  Future<void> _editProfile() async {
    final profile = context.read<ProfileNotifier>();
    final updated = await Navigator.push<ProfileDetails>(
      context,
      MaterialPageRoute(builder: (_) => ProfileEdit(details: ProfileDetails(
        name: profile.name,
        phoneNumber: profile.phoneNumber,
        email: profile.email,
        address: profile.address,
        workAddress: profile.workAddress,
        parentsAddress: profile.parentsAddress,
      ))),
    );
    if (updated != null && mounted) {
      context.read<ProfileNotifier>().update(
        name: updated.name,
        phoneNumber: updated.phoneNumber,
        email: updated.email,
        address: updated.address,
        workAddress: updated.workAddress,
        parentsAddress: updated.parentsAddress,
      );
    }
  }

  Future<void> _reviewHomePrescription(PlatformFile file) async {
    final patientName = context.read<ProfileNotifier>().name;
    final pName = patientName.isNotEmpty ? patientName : 'Customer';
    final uploadedRx = await Navigator.of(context).push<Prescription?>(MaterialPageRoute(
      builder: (_) => PrescriptionReview(
        file: file,
        patientName: pName,
      ),
    ));

    if (uploadedRx != null && mounted) {
      setState(() => _currentIndex = 3);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileNotifier>();
    // IndexedStack preserves scroll + state across tab switches
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          Consumer<CustomerAddressProvider>(
            builder: (_, addresses, _) {
              final loc = addresses.defaultAddress?.displayDetails ??
                  (profile.address.isNotEmpty && profile.address != 'Set delivery location'
                      ? profile.address
                      : 'Set delivery location');
              return Home(
                name: profile.name,
                location: loc,
                onPrescriptionUpload: _reviewHomePrescription,
              );
            },
          ),
          Search(onBack: () => setState(() => _currentIndex = 0)),
          OrderHistory(isActiveTab: _currentIndex == 2),
          PrescriptionVault(
            patientName: profile.name,
            onBack: () => setState(() => _currentIndex = 0),
          ),
          ProfileHome(
            name: profile.name,
            phoneNumber: profile.phoneNumber,
            email: profile.email,
            address: profile.address,
            onEdit: _editProfile,
          ),
        ],
      ),
      bottomNavigationBar: Consumer2<CartNotifier, OrdersProvider>(
        builder: (_, cart, orders, _) => CurvedNavigationBar(
          index: _currentIndex,
          height: 62.0,
          color: AppTheme.primary,
          buttonBackgroundColor: AppTheme.primary,
          backgroundColor: AppTheme.background,
          animationCurve: Curves.easeInOut,
          animationDuration: const Duration(milliseconds: 300),
          onTap: (i) {
            setState(() => _currentIndex = i);
            if (i == 4) {
              context.read<OrdersProvider>().syncRemoteOrders(silent: true);
              context.read<PrescriptionProvider>().refresh();
            }
          },
          items: [
            const Icon(Icons.home_rounded, size: 28, color: Colors.white),
            const Icon(Icons.search_rounded, size: 28, color: Colors.white),
            _BadgedIcon(
              icon: Icons.receipt_long_rounded,
              count: orders.activeCount,
              size: 28,
            ),
            const Icon(Icons.description_rounded, size: 28, color: Colors.white),
            const Icon(Icons.person_rounded, size: 28, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _BadgedIcon extends StatelessWidget {
  final IconData icon;
  final int count;
  final double size;

  const _BadgedIcon({
    required this.icon,
    required this.count,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    if (count == 0) return Icon(icon, color: Colors.white, size: size);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, color: Colors.white, size: size),
        Positioned(
          right: -6,
          top: -4,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

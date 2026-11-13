import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/providers/auth_provider.dart';
import '../../core/providers/cart_notifier.dart';
import '../../core/providers/profile_notifier.dart';
import '../../core/services/api_service.dart';
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
  final String? profileImagePath;
  const MainNavWrapper({
    super.key,
    required this.name,
    this.phoneNumber = '',
    this.email = '',
    this.location = 'Set delivery location',
    this.profileImagePath,
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
      profileImagePath: widget.profileImagePath,
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
        profileImagePath: profile.profileImagePath,
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
        profileImagePath: updated.profileImagePath,
      );
    }
  }

  Future<void> _reviewHomePrescription(PlatformFile file) async {
    final patientName = context.read<ProfileNotifier>().name;
    final pName = patientName.isNotEmpty ? patientName : 'Customer';
    final submitted = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => PrescriptionReview(
        file: file,
        patientName: pName,
      ),
    ));

    if (submitted == true && mounted) {
      String rxId = 'rx_${DateTime.now().millisecondsSinceEpoch}';
      try {
        if (ApiService.token != null) {
          final effectiveCustomerId = ApiService.currentCustomerId ??
              (mounted ? context.read<AuthProvider?>()?.userId : null);
          final res = await ApiService.uploadPrescription(
            customerId: effectiveCustomerId,
            patientName: pName,
            prescriptionDate: DateTime.now(),
            documentUrl: file.path ?? 'https://res.cloudinary.com/demo/sample_rx.pdf',
            fileSize: file.size,
            mimeType: file.extension == 'pdf' ? 'application/pdf' : 'image/jpeg',
          );
          if (res != null) {
            final doc = res['prescription'] ?? res['data'] ?? res;
            if (doc is Map && doc['_id'] != null) {
              rxId = doc['_id'].toString();
            } else if (res['_id'] != null) {
              rxId = res['_id'].toString();
            }
          }
        }
      } catch (_) {}

      if (mounted) {
        final rxProvider = context.read<PrescriptionProvider?>();
        rxProvider?.addPrescription(
          Prescription(
            id: rxId,
            source: 'upload',
            status: PrescriptionStatus.approved,
            fileName: file.name,
            mime: file.extension ?? 'image/jpeg',
            sizeBytes: file.size,
            remoteUrl: file.path,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        setState(() => _currentIndex = 3);
      }
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
                profileImagePath: profile.profileImagePath,
                onPrescriptionUpload: _reviewHomePrescription,
              );
            },
          ),
          Search(onBack: () => setState(() => _currentIndex = 0)),
          const OrderHistory(),
          PrescriptionVault(
            patientName: profile.name,
            profileImagePath: profile.profileImagePath,
            onBack: () => setState(() => _currentIndex = 0),
          ),
          ProfileHome(
            name: profile.name,
            phoneNumber: profile.phoneNumber,
            email: profile.email,
            address: profile.address,
            profileImagePath: profile.profileImagePath,
            onEdit: _editProfile,
          ),
        ],
      ),
      bottomNavigationBar: Consumer2<CartNotifier, OrdersProvider>(
        builder: (_, cart, orders, _) => BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.search),
              label: 'Search',
            ),
            BottomNavigationBarItem(
              icon: _BadgedIcon(
                icon: Icons.receipt_long_outlined,
                count: orders.activeCount,
              ),
              label: 'Orders',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.description_outlined),
              label: 'Prescriptions',
            ),
            BottomNavigationBarItem(
              icon: profile.profileImagePath == null
                  ? const Icon(Icons.person_outline)
                  : CircleAvatar(radius: 12, backgroundImage: FileImage(File(profile.profileImagePath!))),
              label: 'Profile',
            ),
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
  const _BadgedIcon({required this.icon, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return Icon(icon);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
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

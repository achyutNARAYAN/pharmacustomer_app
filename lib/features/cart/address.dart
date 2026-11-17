import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/api_service.dart';
import '../../core/theme.dart';
import '../../core/providers/cart_notifier.dart';
import '../../core/providers/profile_notifier.dart';
import '../../core/utils/pincode_validator.dart';
import '../profile/models/customer_address.dart';
import '../profile/widgets/add_edit_address_sheet.dart';
import '../profile/providers/customer_address_provider.dart';
import 'payment.dart';

class Address extends StatefulWidget {
  final bool? popOnSelect;
  const Address({super.key, this.popOnSelect = false});

  @override
  State<Address> createState() => _AddressState();
}

class _AddressState extends State<Address> {
  final List<AddressModel> _addresses = [];
  int _selected = 0;
  bool _allocating = false;

  @override
  void initState() {
    super.initState();
    _populateInitialAddresses();
    _loadRemoteAddresses();
  }

  void _populateInitialAddresses() {
    final cached = ApiService.cachedCustomerProfile;
    if (cached != null) {
      final cust = (cached['customer'] is Map ? cached['customer'] : cached) as Map<String, dynamic>;
      if (cust['addresses'] is List && (cust['addresses'] as List).isNotEmpty) {
        _parseAndSetAddresses(cust['addresses'] as List);
      }
    }
  }

  void _parseAndSetAddresses(List remoteAddrs) {
    if (remoteAddrs.isEmpty) return;
    _addresses.clear();
    for (final a in remoteAddrs) {
      if (a is Map<String, dynamic>) {
        _addresses.add(CustomerAddress.fromJson(a));
      }
    }
    final defIdx = _addresses.indexWhere((a) => a.isDefault);
    if (defIdx != -1) {
      _selected = defIdx;
    }
  }

  Future<void> _loadRemoteAddresses() async {
    try {
      if (ApiService.token != null) {
        final profile = await ApiService.getCustomerProfile(ApiService.currentCustomerId);
        if (profile != null) {
          final cust = (profile['customer'] is Map ? profile['customer'] : profile) as Map<String, dynamic>;
          if (cust['addresses'] is List) {
            final remoteAddrs = cust['addresses'] as List;
            if (remoteAddrs.isNotEmpty && mounted) {
              setState(() {
                _parseAndSetAddresses(remoteAddrs);
              });
            }
          }
        }
      }
    } catch (_) {}
  }

  String get _selectedLabel =>
      _addresses.isNotEmpty ? _addresses[_selected.clamp(0, _addresses.length - 1)].label : 'Address';

  String get _selectedEta =>
      _addresses.isNotEmpty ? _addresses[_selected.clamp(0, _addresses.length - 1)].eta : 'Standard';

  Future<void> _deleteAddress(int index) async {
    if (index >= _addresses.length) return;
    final target = _addresses[index];
    final addrId = target.id;

    setState(() {
      _addresses.removeAt(index);
      if (_selected >= _addresses.length) {
        _selected = (_addresses.length - 1).clamp(0, 999);
      }
    });

    if (addrId.isNotEmpty && ApiService.token != null) {
      try {
        await ApiService.deleteAddress(ApiService.currentCustomerId, addrId);
      } catch (_) {}
    }
  }

  Future<void> _editAddress([int? index]) async {
    final profile = context.read<ProfileNotifier>();
    final initial = index != null && index < _addresses.length ? _addresses[index] : null;

    final picked = await AddEditAddressSheet.show(
      context,
      initialAddress: initial,
      defaultContactName: profile.name,
      defaultContactMobile: profile.phoneNumber,
    );
    if (!mounted || picked == null || picked.addressLine1.isEmpty) {
      return;
    }

    final result = picked;

    setState(() {
      if (index == null) {
        _addresses.add(result);
        _selected = _addresses.length - 1;
      } else {
        _addresses[index] = result;
        _selected = index;
      }
    });

    context.read<ProfileNotifier>().updateAddress(result.label, result.displayDetails);

    // If adding a brand new address (index == null or no ID), persist via backend addAddress API
    if (index == null || result.id.isEmpty) {
      try {
        if (ApiService.token != null) {
          final res = await ApiService.addAddress(
            ApiService.currentCustomerId,
            label: result.label,
            addressLine1: result.addressLine1,
            addressLine2: result.addressLine2.isNotEmpty ? result.addressLine2 : null,
            landmark: result.landmark.isNotEmpty ? result.landmark : null,
            city: result.city,
            state: result.state,
            pincode: result.pincode,
            contactName: result.contactName,
            contactMobile: result.contactMobile,
            latitude: result.latitude,
            longitude: result.longitude,
            isDefault: result.isDefault,
          );
          if (res is Map && res['_id'] != null && mounted) {
            final newId = res['_id'] as String;
            final idx = _addresses.indexOf(result);
            if (idx >= 0) {
              setState(() {
                _addresses[idx] = result.copyWith(id: newId);
              });
            }
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('ValidationFailure: ', '').replaceAll('NetworkFailure: ', '')),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } else {
      // Editing existing address: call PATCH /customers/{customerId}/addresses/{addressId}
      final addressId = result.id;
      if (ApiService.token != null) {
        try {
          await ApiService.updateAddress(
            ApiService.currentCustomerId,
            addressId,
            label: result.label,
            addressLine1: result.addressLine1,
            addressLine2: result.addressLine2.isNotEmpty ? result.addressLine2 : null,
            landmark: result.landmark.isNotEmpty ? result.landmark : null,
            city: result.city,
            state: result.state,
            pincode: result.pincode,
            contactName: result.contactName,
            contactMobile: result.contactMobile,
            latitude: result.latitude,
            longitude: result.longitude,
            isDefault: result.isDefault,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Address updated successfully.'),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(e.toString().replaceAll('ValidationFailure: ', '').replaceAll('NetworkFailure: ', '')),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF0FAFD),
    appBar: AppBar(
      centerTitle: true,
      backgroundColor: Colors.white,
      leading: const BackButton(),
      title: const Text('Select Delivery Address'),
      actions: [
        TextButton.icon(
          onPressed: () => _editAddress(),
          icon: const Icon(Icons.add, size: 20),
          label: const Text('Add new'),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(2, 6, 2, 12),
          child: Text(
            'SAVED ADDRESSES',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: AppTheme.mutedText,
            ),
          ),
        ),
        if (_addresses.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  const Icon(Icons.location_off_outlined, size: 48, color: AppTheme.mutedText),
                  const SizedBox(height: 12),
                  const Text('No addresses saved yet.', style: TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _editAddress(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Address'),
                  ),
                ],
              ),
            ),
          )
        else
          ..._addresses.asMap().entries.map((entry) {
            final index = entry.key;
            final address = entry.value;
            final contact = (address.contactName.isNotEmpty || address.contactMobile.isNotEmpty)
                ? '${address.contactName} • ${address.contactMobile}'
                : null;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AddressCard(
                label: address.label,
                details: address.displayDetails,
                contactInfo: contact,
                eta: address.eta,
                selected: _selected == index,
                isDefault: address.isDefault || index == 0,
                onTap: () => setState(() {
                  _selected = index;
                }),
                onEdit: () => _editAddress(index),
                onDelete: _addresses.length > 1 ? () => _deleteAddress(index) : null,
              ),
            );
          }),
      ],
    ),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.fromLTRB(18, 8, 18, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, size: 18, color: AppTheme.primary),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Delivering to: $_selectedLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(Icons.bolt, size: 17, color: Colors.orange),
              Text(
                ' $_selectedEta',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton(
              onPressed: _allocating
                  ? null
                  : () async {
                      if (_addresses.isNotEmpty && _selected < _addresses.length) {
                        final sel = _addresses[_selected];
                        if (sel.pincode.isNotEmpty && !PincodeValidator.isServiceable(sel.pincode)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('PIN code ${sel.pincode} is not serviceable for delivery. Please select or add a serviceable address.'),
                              backgroundColor: Colors.red.shade800,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }

                        // 1. Update ProfileNotifier with chosen delivery address
                        context.read<ProfileNotifier>().setAddress(sel.displayDetails);

                        // 2. Sync with CustomerAddressProvider
                        try {
                          final cap = Provider.of<CustomerAddressProvider>(context, listen: false);
                          CustomerAddress? matched;
                          for (final a in cap.addresses) {
                            if (a.id == sel.id || a.displayDetails == sel.displayDetails) {
                              matched = a;
                              break;
                            }
                          }
                          if (matched != null) {
                            cap.selectAddress(matched);
                          } else {
                            final newAddr = CustomerAddress(
                              id: sel.id,
                              addressLine1: sel.addressLine1,
                              addressLine2: sel.addressLine2,
                              landmark: sel.landmark,
                              city: sel.city,
                              state: sel.state,
                              pinCode: sel.pincode,
                              contactName: sel.contactName,
                              contactMobile: sel.contactMobile,
                              addressType: AddressType.fromString(sel.label),
                              isDefault: sel.isDefault,
                              latitude: sel.latitude,
                              longitude: sel.longitude,
                              eta: sel.eta,
                            );
                            cap.selectAddress(newAddr);
                          }
                        } catch (_) {}

                        final cart = context.read<CartNotifier>();
                        final addrId = sel.id;
                        if (addrId.isNotEmpty && ApiService.token != null) {
                          setState(() => _allocating = true);
                          final ok = await cart.allocateStore(addrId);
                          if (!context.mounted) return;
                          setState(() => _allocating = false);

                          if (!ok && cart.actionError != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(cart.actionError!),
                                backgroundColor: Colors.red.shade800,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }
                        }
                      }
                      if (!context.mounted) return;
                      final selectedAddressModel = (_addresses.isNotEmpty && _selected < _addresses.length)
                          ? _addresses[_selected]
                          : null;

                      if (widget.popOnSelect == true) {
                        Navigator.pop(context, selectedAddressModel);
                        return;
                      }

                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const Payment(),
                        ),
                      );
                    },
              child: _allocating
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Allocating 4km Pharmacy...'),
                      ],
                    )
                  : const Text('Deliver to this Address  →'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.label,
    required this.details,
    required this.eta,
    required this.selected,
    required this.isDefault,
    required this.onTap,
    required this.onEdit,
    this.onDelete,
    this.contactInfo,
  });

  final String label, details, eta;
  final String? contactInfo;
  final bool selected, isDefault;
  final VoidCallback onTap, onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(22),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? AppTheme.primary : const Color(0xFFD5E8ED),
            width: selected ? 2 : 1.3,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected ? AppTheme.primary : AppTheme.mutedText,
                  size: 23,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (isDefault)
                  const Padding(
                    padding: EdgeInsets.only(right: 2),
                    child: Text(
                      'DEFAULT',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                IconButton(
                  tooltip: 'Edit $label address',
                  onPressed: onEdit,
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 19,
                    color: AppTheme.textSecondary,
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    tooltip: 'Delete $label address',
                    onPressed: onDelete,
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 19,
                      color: Colors.redAccent,
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 37),
              child: Text(
                details,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  height: 1.45,
                ),
              ),
            ),
            if (contactInfo != null && contactInfo!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 37),
                child: Text(
                  contactInfo!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.mutedText,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 37),
              child: Row(
                children: [
                  Icon(
                    eta.contains('Express') ? Icons.bolt : Icons.schedule,
                    size: 16,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    eta,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.primaryDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../../core/services/api_service.dart';
import '../../core/theme.dart';
import '../../core/providers/profile_notifier.dart';
import 'delivery_options.dart';

class AddressModel {
  final String? id;
  final String label; // "HOME", "WORK", "OTHER"
  final String addressLine1;
  final String addressLine2;
  final String landmark;
  final String city;
  final String state;
  final String pincode;
  final String contactName;
  final String contactMobile;
  final double latitude;
  final double longitude;
  final bool isDefault;
  final String eta;

  const AddressModel({
    this.id,
    required this.label,
    required this.addressLine1,
    this.addressLine2 = '',
    this.landmark = '',
    required this.city,
    required this.state,
    required this.pincode,
    required this.contactName,
    required this.contactMobile,
    this.latitude = 12.9270,
    this.longitude = 77.6720,
    this.isDefault = false,
    this.eta = '22 Mins Express',
  });

  String get displayDetails {
    final list = [addressLine1, addressLine2, landmark, city, state, pincode];
    final text = list.where((s) => s.trim().isNotEmpty).join(', ');
    return text.isNotEmpty ? text : addressLine1;
  }
}

class Address extends StatefulWidget {
  const Address({super.key});

  @override
  State<Address> createState() => _AddressState();
}

class _AddressState extends State<Address> {
  final List<AddressModel> _addresses = [];
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    final profile = context.read<ProfileNotifier>();
    _addresses.add(
      AddressModel(
        id: null,
        label: 'HOME',
        addressLine1: profile.address.isNotEmpty ? profile.address : 'My Residence',
        city: '',
        state: '',
        pincode: '',
        contactName: profile.name.isNotEmpty ? profile.name : 'Customer',
        contactMobile: profile.phoneNumber.isNotEmpty ? profile.phoneNumber : '9876543210',
        isDefault: true,
      ),
    );
    _loadRemoteAddresses();
  }

  Future<void> _loadRemoteAddresses() async {
    try {
      if (ApiService.token != null) {
        final profile = await ApiService.getCustomerProfile(ApiService.currentCustomerId);
        if (profile != null && profile['addresses'] is List) {
          final remoteAddrs = profile['addresses'] as List;
          if (remoteAddrs.isNotEmpty && mounted) {
            setState(() {
              _addresses.clear();
              for (final a in remoteAddrs) {
                if (a is Map<String, dynamic>) {
                  final id = a['_id'] as String? ?? a['id'] as String?;
                  final rawLabel = (a['type'] as String? ?? a['label'] as String?)?.toUpperCase() ?? 'HOME';
                  final line1 = a['addressLine1'] as String? ?? '';
                  final line2 = a['addressLine2'] as String? ?? '';
                  final landmark = a['landmark'] as String? ?? '';
                  final city = a['city'] as String? ?? '';
                  final state = a['state'] as String? ?? '';
                  final pincode = a['pinCode'] as String? ?? a['pincode'] as String? ?? '';
                  final contactName = a['contactName'] as String? ?? 'Customer';
                  final contactMobile = a['contactMobile'] as String? ?? '9876543210';
                  final isDef = a['isDefault'] as bool? ?? false;
                  double lat = 12.9270;
                  double lng = 77.6720;
                  if (a['location'] is Map && a['location']['coordinates'] is List) {
                    final coords = a['location']['coordinates'] as List;
                    if (coords.length >= 2) {
                      lng = (coords[0] as num).toDouble();
                      lat = (coords[1] as num).toDouble();
                    }
                  } else if (a['latitude'] != null && a['longitude'] != null) {
                    lat = (a['latitude'] as num).toDouble();
                    lng = (a['longitude'] as num).toDouble();
                  }

                  _addresses.add(AddressModel(
                    id: id,
                    label: rawLabel,
                    addressLine1: line1,
                    addressLine2: line2,
                    landmark: landmark,
                    city: city,
                    state: state,
                    pincode: pincode,
                    contactName: contactName,
                    contactMobile: contactMobile,
                    latitude: lat,
                    longitude: lng,
                    isDefault: isDef,
                  ));
                }
              }
            });
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

    if (addrId != null && addrId.isNotEmpty && ApiService.token != null) {
      try {
        await ApiService.deleteAddress(ApiService.currentCustomerId, addrId);
      } catch (_) {}
    }
  }

  Future<void> _editAddress([int? index]) async {
    final profile = context.read<ProfileNotifier>();
    final initial = index != null && index < _addresses.length ? _addresses[index] : null;

    final result = await showDialog<AddressModel>(
      context: context,
      builder: (_) => _AddressEditorDialog(
        initialItem: initial,
        defaultName: profile.name,
        defaultMobile: profile.phoneNumber,
      ),
    );
    if (!mounted || result == null || result.addressLine1.isEmpty) {
      return;
    }

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
    if (index == null || result.id == null || result.id!.isEmpty) {
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
                _addresses[idx] = AddressModel(
                  id: newId,
                  label: result.label,
                  addressLine1: result.addressLine1,
                  addressLine2: result.addressLine2,
                  landmark: result.landmark,
                  city: result.city,
                  state: result.state,
                  pincode: result.pincode,
                  contactName: result.contactName,
                  contactMobile: result.contactMobile,
                  latitude: result.latitude,
                  longitude: result.longitude,
                  isDefault: result.isDefault,
                  eta: result.eta,
                );
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
      final addressId = result.id!;
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
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const DeliveryOptions(),
                ),
              ),
              child: const Text('Deliver to this Address  →'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _AddressEditorDialog extends StatefulWidget {
  final AddressModel? initialItem;
  final String defaultName;
  final String defaultMobile;

  const _AddressEditorDialog({
    this.initialItem,
    required this.defaultName,
    required this.defaultMobile,
  });

  @override
  State<_AddressEditorDialog> createState() => _AddressEditorDialogState();
}

class _AddressEditorDialogState extends State<_AddressEditorDialog> {
  late String _selectedType;
  late final TextEditingController _addressLine1;
  late final TextEditingController _addressLine2;
  late final TextEditingController _landmark;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _pincode;
  late final TextEditingController _contactName;
  late final TextEditingController _contactMobile;
  late bool _isDefault;
  late double _latitude;
  late double _longitude;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    final rawType = item?.label.toUpperCase() ?? 'HOME';
    _selectedType = (rawType == 'WORK' || rawType == 'OTHER') ? rawType : 'HOME';

    _addressLine1 = TextEditingController(text: item?.addressLine1 ?? '');
    _addressLine2 = TextEditingController(text: item?.addressLine2 ?? '');
    _landmark = TextEditingController(text: item?.landmark ?? '');
    _city = TextEditingController(text: item?.city ?? '');
    _state = TextEditingController(text: item?.state ?? '');
    _pincode = TextEditingController(text: item?.pincode ?? '');
    _contactName = TextEditingController(
      text: item != null && item.contactName.isNotEmpty
          ? item.contactName
          : (widget.defaultName.isNotEmpty ? widget.defaultName : 'Customer'),
    );
    _contactMobile = TextEditingController(
      text: item != null && item.contactMobile.isNotEmpty
          ? item.contactMobile
          : (widget.defaultMobile.isNotEmpty ? widget.defaultMobile : '9876543210'),
    );
    _isDefault = item?.isDefault ?? false;
    _latitude = item?.latitude ?? 12.9270;
    _longitude = item?.longitude ?? 77.6720;
  }

  @override
  void dispose() {
    _addressLine1.dispose();
    _addressLine2.dispose();
    _landmark.dispose();
    _city.dispose();
    _state.dispose();
    _pincode.dispose();
    _contactName.dispose();
    _contactMobile.dispose();
    super.dispose();
  }

  Future<bool> _promptLocationPermission() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE4F7FA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.location_on, color: AppTheme.primary, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Location Permission',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: const Text(
          'Allow PharmaApp to access your device location to automatically detect and fill your delivery address?',
          style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              "Don't Allow",
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Allow'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _locateAndAutoFill() async {
    final allowed = await _promptLocationPermission();
    if (!allowed || !mounted) return;

    setState(() => _isLocating = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Device location (GPS) is turned off. Please enable GPS.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permission denied.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission is permanently denied. Please allow it in settings.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      _latitude = position.latitude;
      _longitude = position.longitude;

      final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty && mounted) {
        final p = placemarks.first;

        final streetParts = <String>[];
        if (p.name != null &&
            p.name!.isNotEmpty &&
            p.name != p.street &&
            p.name != p.locality &&
            p.name != p.subLocality &&
            p.name != p.administrativeArea) {
          streetParts.add(p.name!);
        }
        if (p.subThoroughfare != null && p.subThoroughfare!.isNotEmpty) {
          streetParts.add(p.subThoroughfare!);
        }
        if (p.thoroughfare != null && p.thoroughfare!.isNotEmpty) {
          streetParts.add(p.thoroughfare!);
        } else if (p.street != null && p.street!.isNotEmpty) {
          streetParts.add(p.street!);
        }

        String line1 = streetParts.toSet().join(', ');
        if (line1.isEmpty) {
          if (p.street != null && p.street!.isNotEmpty) {
            line1 = p.street!;
          } else if (p.name != null && p.name!.isNotEmpty) {
            line1 = p.name!;
          }
        }

        final line2Parts = <String>[];
        if (p.subLocality != null && p.subLocality!.isNotEmpty) {
          line2Parts.add(p.subLocality!);
        }
        if (p.subAdministrativeArea != null &&
            p.subAdministrativeArea!.isNotEmpty &&
            p.subAdministrativeArea != p.locality) {
          line2Parts.add(p.subAdministrativeArea!);
        }
        final line2 = line2Parts.toSet().join(', ');

        final cityVal = (p.locality != null && p.locality!.isNotEmpty)
            ? p.locality!
            : ((p.subAdministrativeArea != null && p.subAdministrativeArea!.isNotEmpty)
                ? p.subAdministrativeArea!
                : '');

        final stateVal = p.administrativeArea ?? '';
        final pinVal = p.postalCode ?? '';

        setState(() {
          if (line1.isNotEmpty) {
            _addressLine1.text = line1;
          } else if (_addressLine1.text.trim().isEmpty) {
            _addressLine1.text = [p.street, p.subLocality]
                .where((s) => s != null && s.isNotEmpty)
                .join(', ');
          }
          if (line2.isNotEmpty) {
            _addressLine2.text = line2;
          }
          if (cityVal.isNotEmpty) {
            _city.text = cityVal;
          }
          if (stateVal.isNotEmpty) {
            _state.text = stateVal;
          }
          if (pinVal.isNotEmpty) {
            _pincode.text = pinVal;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Address details filled from current location!'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not fetch location: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  void _onSave() {
    final line1 = _addressLine1.text.trim();
    final cityVal = _city.text.trim();
    final stateVal = _state.text.trim();
    final pinVal = _pincode.text.trim();
    final nameVal = _contactName.text.trim();
    final mobileVal = _contactMobile.text.trim();

    if (line1.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter flat/house no. and building.')),
      );
      return;
    }
    if (cityVal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your city.')),
      );
      return;
    }
    if (stateVal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your state.')),
      );
      return;
    }
    if (pinVal.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 6-digit pincode.')),
      );
      return;
    }

    final item = AddressModel(
      id: widget.initialItem?.id,
      label: _selectedType,
      addressLine1: line1,
      addressLine2: _addressLine2.text.trim(),
      landmark: _landmark.text.trim(),
      city: cityVal,
      state: stateVal,
      pincode: pinVal,
      contactName: nameVal.isNotEmpty ? nameVal : 'Customer',
      contactMobile: mobileVal.isNotEmpty ? mobileVal : '9876543210',
      latitude: _latitude,
      longitude: _longitude,
      isDefault: _isDefault,
    );

    Navigator.pop(context, item);
  }

  InputDecoration _fieldDecoration(String label, IconData icon, {String? hint}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: AppTheme.primary),
        filled: true,
        fillColor: const Color(0xFFF5FAFB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD7E8EC)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD7E8EC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
      );

  Widget _typeChip(String type, String label, IconData icon) {
    final isSel = _selectedType == type;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedType = type),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSel ? AppTheme.primary.withValues(alpha: 0.12) : const Color(0xFFF5FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSel ? AppTheme.primary : const Color(0xFFD7E8EC),
              width: isSel ? 1.8 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSel ? AppTheme.primary : AppTheme.textSecondary),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                  color: isSel ? AppTheme.primary : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.white,
    insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 480,
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE4F7FA),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.location_on_outlined,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.initialItem == null
                          ? 'Add delivery address'
                          : 'Edit delivery address',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.text,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Padding(
                padding: EdgeInsets.only(left: 54, bottom: 14),
                child: Text(
                  'Enter complete address for accurate pharmacy delivery.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.35,
                  ),
                ),
              ),

              // ── Locate Me / Use Current Location Auto-Fill ──────────
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFFE4F7FA),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFBCE7F0)),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _isLocating ? null : _locateAndAutoFill,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: _isLocating
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.primary,
                                    ),
                                  )
                                : const Icon(Icons.my_location, color: AppTheme.primary, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isLocating ? 'Detecting current location...' : 'Use Current Location / Locate Me',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primaryDark,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _isLocating
                                      ? 'Fetching GPS & auto-filling form...'
                                      : 'Auto-fill form using device GPS',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 13, color: AppTheme.primary),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Address Type Chips ──────────────────────────────
              const Text(
                'ADDRESS TYPE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppTheme.mutedText,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _typeChip('HOME', 'Home', Icons.home_outlined),
                  const SizedBox(width: 8),
                  _typeChip('WORK', 'Work', Icons.work_outline),
                  const SizedBox(width: 8),
                  _typeChip('OTHER', 'Other', Icons.place_outlined),
                ],
              ),
              const SizedBox(height: 16),

              // ── Address Line 1 ──────────────────────────────
              TextField(
                controller: _addressLine1,
                textCapitalization: TextCapitalization.words,
                decoration: _fieldDecoration(
                  'House / Flat No., Building Name *',
                  Icons.business_outlined,
                  hint: 'e.g. Flat 202, Sunshine Heights',
                ),
              ),
              const SizedBox(height: 12),

              // ── Address Line 2 ──────────────────────────────
              TextField(
                controller: _addressLine2,
                textCapitalization: TextCapitalization.words,
                decoration: _fieldDecoration(
                  'Road, Area, Sector (Optional)',
                  Icons.map_outlined,
                  hint: 'e.g. Banjara Hills, Road No. 12',
                ),
              ),
              const SizedBox(height: 12),

              // ── Landmark ──────────────────────────────
              TextField(
                controller: _landmark,
                textCapitalization: TextCapitalization.words,
                decoration: _fieldDecoration(
                  'Landmark (Optional)',
                  Icons.tour_outlined,
                  hint: 'e.g. Near Metro Station / Apollo Pharmacy',
                ),
              ),
              const SizedBox(height: 12),

              // ── City & State ──────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _city,
                      textCapitalization: TextCapitalization.words,
                      decoration: _fieldDecoration(
                        'City *',
                        Icons.location_city_outlined,
                        hint: 'e.g. Hyderabad',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _state,
                      textCapitalization: TextCapitalization.words,
                      decoration: _fieldDecoration(
                        'State *',
                        Icons.flag_outlined,
                        hint: 'e.g. Telangana',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Pincode & Mobile ──────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _pincode,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                      decoration: _fieldDecoration(
                        'Pincode *',
                        Icons.pin_drop_outlined,
                        hint: 'e.g. 500016',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _contactMobile,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                      decoration: _fieldDecoration(
                        'Contact Phone *',
                        Icons.phone_outlined,
                        hint: '10 digits',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Contact Name ──────────────────────────────
              TextField(
                controller: _contactName,
                textCapitalization: TextCapitalization.words,
                decoration: _fieldDecoration(
                  'Recipient / Contact Name *',
                  Icons.person_outline,
                  hint: 'Who receives the order',
                ),
              ),
              const SizedBox(height: 10),

              // ── Default Switch ──────────────────────────────
              Row(
                children: [
                  Checkbox(
                    value: _isDefault,
                    activeColor: AppTheme.primary,
                    onChanged: (val) => setState(() => _isDefault = val ?? false),
                  ),
                  const Expanded(
                    child: Text(
                      'Make this my default delivery address',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // ── Submit Button ──────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Save Address',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
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

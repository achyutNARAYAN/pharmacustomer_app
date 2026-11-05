import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../../core/theme.dart';
import '../../../core/utils/pincode_validator.dart';
import '../models/customer_address.dart';

/// Modal sheet or dialog for adding or editing a customer delivery address.
///
/// Features:
/// • Address Type selector: HOME, WORK, OTHER
/// • Full 10-field address capture (Line 1, Line 2, Landmark, City, State, PIN, Contact Name, Contact Phone, Type, Default)
/// • Real-time PIN code serviceability validation with feedback
/// • GPS auto-fill with geocoding
class AddEditAddressSheet extends StatefulWidget {
  final CustomerAddress? initialAddress;
  final String defaultContactName;
  final String defaultContactMobile;

  const AddEditAddressSheet({
    super.key,
    this.initialAddress,
    this.defaultContactName = '',
    this.defaultContactMobile = '',
  });

  static Future<CustomerAddress?> show(
    BuildContext context, {
    CustomerAddress? initialAddress,
    String defaultContactName = '',
    String defaultContactMobile = '',
  }) {
    return showModalBottomSheet<CustomerAddress>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEditAddressSheet(
        initialAddress: initialAddress,
        defaultContactName: defaultContactName,
        defaultContactMobile: defaultContactMobile,
      ),
    );
  }

  @override
  State<AddEditAddressSheet> createState() => _AddEditAddressSheetState();
}

class _AddEditAddressSheetState extends State<AddEditAddressSheet> {
  final _formKey = GlobalKey<FormState>();

  late AddressType _selectedType;
  late final TextEditingController _addressLine1;
  late final TextEditingController _addressLine2;
  late final TextEditingController _landmark;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _pinCode;
  late final TextEditingController _contactName;
  late final TextEditingController _contactMobile;

  late bool _isDefault;
  late double _latitude;
  late double _longitude;
  bool _isLocating = false;
  PincodeValidationResult? _pincodeResult;

  @override
  void initState() {
    super.initState();
    final item = widget.initialAddress;

    _selectedType = item?.addressType ?? AddressType.home;
    _addressLine1 = TextEditingController(text: item?.addressLine1 ?? '');
    _addressLine2 = TextEditingController(text: item?.addressLine2 ?? '');
    _landmark = TextEditingController(text: item?.landmark ?? '');
    _city = TextEditingController(text: item?.city ?? '');
    _state = TextEditingController(text: item?.state ?? '');
    _pinCode = TextEditingController(text: item?.pinCode ?? '');
    _contactName = TextEditingController(
      text: item != null && item.contactName.isNotEmpty
          ? item.contactName
          : (widget.defaultContactName.isNotEmpty ? widget.defaultContactName : 'Customer'),
    );
    _contactMobile = TextEditingController(
      text: item != null && item.contactMobile.isNotEmpty
          ? item.contactMobile
          : (widget.defaultContactMobile.isNotEmpty ? widget.defaultContactMobile : '9876543210'),
    );
    _isDefault = item?.isDefault ?? false;
    _latitude = item?.latitude ?? 17.4156;
    _longitude = item?.longitude ?? 78.4357;

    if (_pinCode.text.isNotEmpty) {
      _pincodeResult = PincodeValidator.validate(_pinCode.text);
    }
  }

  @override
  void dispose() {
    _addressLine1.dispose();
    _addressLine2.dispose();
    _landmark.dispose();
    _city.dispose();
    _state.dispose();
    _pinCode.dispose();
    _contactName.dispose();
    _contactMobile.dispose();
    super.dispose();
  }

  void _onPinCodeChanged(String value) {
    setState(() {
      if (value.trim().length >= 6) {
        _pincodeResult = PincodeValidator.validate(value);
      } else {
        _pincodeResult = null;
      }
    });
  }

  Future<void> _locateAndAutoFill() async {
    setState(() => _isLocating = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable GPS / location service.')),
          );
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied.')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission is permanently denied. Please allow in app settings.')),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );

      _latitude = position.latitude;
      _longitude = position.longitude;

      final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty && mounted) {
        final p = placemarks.first;

        if (_addressLine1.text.isEmpty) {
          final street = [p.name, p.street, p.subThoroughfare, p.thoroughfare]
              .where((s) => s != null && s.trim().isNotEmpty)
              .toSet()
              .join(', ');
          _addressLine1.text = street.isNotEmpty ? street : (p.name ?? '');
        }

        if (_addressLine2.text.isEmpty) {
          final locality = [p.subLocality, p.locality]
              .where((s) => s != null && s.trim().isNotEmpty)
              .toSet()
              .join(', ');
          _addressLine2.text = locality;
        }

        if (p.locality != null && p.locality!.isNotEmpty) {
          _city.text = p.locality!;
        }
        if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty) {
          _state.text = p.administrativeArea!;
        }
        if (p.postalCode != null && p.postalCode!.isNotEmpty) {
          _pinCode.text = p.postalCode!;
          _onPinCodeChanged(p.postalCode!);
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not fetch GPS location. Please enter manually.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  void _onSave() {
    if (!_formKey.currentState!.validate()) return;

    final pinVal = _pinCode.text.trim();
    final result = PincodeValidator.validate(pinVal);
    if (!result.isValidFormat) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 6-digit PIN code.')),
      );
      return;
    }

    final address = CustomerAddress(
      id: widget.initialAddress?.id ?? '',
      addressType: _selectedType,
      addressLine1: _addressLine1.text.trim(),
      addressLine2: _addressLine2.text.trim(),
      landmark: _landmark.text.trim(),
      city: _city.text.trim(),
      state: _state.text.trim(),
      pinCode: pinVal,
      contactName: _contactName.text.trim().isNotEmpty
          ? _contactName.text.trim()
          : (widget.defaultContactName.isNotEmpty ? widget.defaultContactName : 'Customer'),
      contactMobile: _contactMobile.text.trim().isNotEmpty
          ? _contactMobile.text.trim()
          : '9876543210',
      isDefault: _isDefault,
      latitude: _latitude,
      longitude: _longitude,
    );

    Navigator.pop(context, address);
  }

  InputDecoration _fieldDeco(String label, IconData icon, {String? hint, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 20, color: AppTheme.primary),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF7FBFB),
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
        borderSide: const BorderSide(color: AppTheme.primary, width: 1.6),
      ),
    );
  }

  Widget _typeButton(AddressType type) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedType = type),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary.withValues(alpha: 0.12) : const Color(0xFFF7FBFB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppTheme.primary : const BorderSide(color: Color(0xFFD7E8EC)).color,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                type.icon,
                size: 18,
                color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                type.key,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? AppTheme.primary : AppTheme.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = widget.initialAddress != null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isEditing ? Icons.edit_location_alt_outlined : Icons.add_location_alt_outlined,
                          color: AppTheme.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEditing ? 'Edit Delivery Address' : 'Add New Delivery Address',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.text,
                              ),
                            ),
                            const Text(
                              '5. Customer Address Management',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.mutedText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Auto-locate GPS Button
                  OutlinedButton.icon(
                    onPressed: _isLocating ? null : _locateAndAutoFill,
                    icon: _isLocating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location_rounded, size: 18),
                    label: Text(_isLocating ? 'Detecting current GPS...' : 'Use current location'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: const BorderSide(color: AppTheme.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      minimumSize: const Size.fromHeight(42),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Address Type: HOME | WORK | OTHER
                  const Text(
                    'ADDRESS TYPE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppTheme.mutedText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _typeButton(AddressType.home),
                      const SizedBox(width: 8),
                      _typeButton(AddressType.work),
                      const SizedBox(width: 8),
                      _typeButton(AddressType.other),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Address Line 1
                  TextFormField(
                    controller: _addressLine1,
                    textCapitalization: TextCapitalization.words,
                    decoration: _fieldDeco(
                      'Address Line 1 *',
                      Icons.home_outlined,
                      hint: 'Flat / House No., Apartment, Building',
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Address Line 1 is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Address Line 2
                  TextFormField(
                    controller: _addressLine2,
                    textCapitalization: TextCapitalization.words,
                    decoration: _fieldDeco(
                      'Address Line 2',
                      Icons.signpost_outlined,
                      hint: 'Street, Sector, Area',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Landmark
                  TextFormField(
                    controller: _landmark,
                    textCapitalization: TextCapitalization.words,
                    decoration: _fieldDeco(
                      'Landmark',
                      Icons.near_me_outlined,
                      hint: 'Nearby hospital, park, school',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // City & State
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _city,
                          textCapitalization: TextCapitalization.words,
                          decoration: _fieldDeco('City *', Icons.location_city_outlined),
                          validator: (val) => (val == null || val.trim().isEmpty) ? 'City required' : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _state,
                          textCapitalization: TextCapitalization.words,
                          decoration: _fieldDeco('State *', Icons.map_outlined),
                          validator: (val) => (val == null || val.trim().isEmpty) ? 'State required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // PIN Code & Serviceability Feedback
                  TextFormField(
                    controller: _pinCode,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                    decoration: _fieldDeco(
                      'PIN Code *',
                      Icons.pin_drop_outlined,
                      hint: '6-digit PIN code (e.g. 500034)',
                    ),
                    onChanged: _onPinCodeChanged,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'PIN Code is required';
                      if (!PincodeValidator.isValidFormat(val)) return 'Enter a valid 6-digit PIN';
                      return null;
                    },
                  ),

                  // Real-time Serviceability Status Banner
                  if (_pincodeResult != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _pincodeResult!.isServiceable
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _pincodeResult!.isServiceable
                              ? const Color(0xFF81C784)
                              : const Color(0xFFE57373),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _pincodeResult!.isServiceable
                                ? Icons.check_circle_rounded
                                : Icons.error_outline_rounded,
                            size: 18,
                            color: _pincodeResult!.isServiceable
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFFC62828),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _pincodeResult!.isServiceable
                                  ? 'Serviceable: Dark store 22-min delivery available'
                                  : 'Unserviceable PIN: Order placement is restricted',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _pincodeResult!.isServiceable
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFFC62828),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Contact Details
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _contactName,
                          textCapitalization: TextCapitalization.words,
                          decoration: _fieldDeco('Contact Name *', Icons.person_outline),
                          validator: (val) => (val == null || val.trim().isEmpty) ? 'Name required' : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _contactMobile,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                          decoration: _fieldDeco('Contact Mobile *', Icons.phone_outlined, hint: '10 digits'),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Mobile required';
                            if (val.trim().length < 10) return '10-digit number';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Default Address Switch
                  SwitchListTile.adaptive(
                    value: _isDefault,
                    activeTrackColor: AppTheme.primary,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Set as default delivery address',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Used as default for express deliveries & orders',
                      style: TextStyle(fontSize: 12, color: AppTheme.mutedText),
                    ),
                    onChanged: (val) => setState(() => _isDefault = val),
                  ),
                  const SizedBox(height: 16),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _onSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Save Address',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

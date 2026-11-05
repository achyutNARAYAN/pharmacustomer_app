/// PIN code validation and delivery serviceability engine.
///
/// Validates Indian 6-digit postal PIN codes and determines whether the location
/// is serviceable by the pharmacy network / dark stores for order placement.
class PincodeValidator {
  PincodeValidator._();

  /// Known serviceable PIN code prefixes & hub zones.
  /// Major tech hubs, state capitals, and dark store clusters.
  static const Set<String> _serviceablePrefixes = {
    // Hyderabad & Secunderabad (Telangana)
    '500', '501', '502',
    // Bengaluru (Karnataka)
    '560', '561', '562',
    // Mumbai, Navi Mumbai & Thane (Maharashtra)
    '400', '401',
    // Pune (Maharashtra)
    '411', '412',
    // Delhi NCR (Delhi, Gurgaon, Noida, Ghaziabad, Faridabad)
    '110', '122', '201', '121',
    // Chennai (Tamil Nadu)
    '600', '601', '602', '603',
    // Kolkata (West Bengal)
    '700', '701',
    // Ahmedabad (Gujarat)
    '380', '382',
    // Jaipur (Rajasthan)
    '302',
    // Chandigarh, Mohali, Panchkula
    '160',
    // Lucknow (Uttar Pradesh)
    '226',
    // Kochi (Kerala)
    '682',
  };

  /// Explicit set of serviceable PIN codes for exact matches or test overrides.
  static final Set<String> _serviceableOverridePins = {};

  /// Flag to force mock serviceability in test environments if needed.
  static bool? _forceServiceableForTesting;

  /// Configure test override
  static void setMockServiceabilityForTesting(bool? isServiceable) {
    _forceServiceableForTesting = isServiceable;
  }

  /// Add specific PIN to serviceable set
  static void addServiceablePin(String pin) {
    if (isValidFormat(pin)) {
      _serviceableOverridePins.add(pin.trim());
    }
  }

  /// Remove specific PIN from serviceable set
  static void removeServiceablePin(String pin) {
    _serviceableOverridePins.remove(pin.trim());
  }

  /// Validates if [pinCode] follows the Indian 6-digit postal PIN format.
  /// Format: Exactly 6 digits, first digit cannot be 0 (1-9).
  static bool isValidFormat(String? pinCode) {
    if (pinCode == null) return false;
    final cleaned = pinCode.trim();
    if (cleaned.length != 6) return false;
    return RegExp(r'^[1-9][0-9]{5}$').hasMatch(cleaned);
  }

  /// Checks whether [pinCode] is serviceable for doorstep delivery & order placement.
  static bool isServiceable(String? pinCode) {
    if (_forceServiceableForTesting != null) {
      return _forceServiceableForTesting!;
    }
    if (!isValidFormat(pinCode)) return false;

    final cleaned = pinCode!.trim();

    // Check explicit override pins first
    if (_serviceableOverridePins.contains(cleaned)) {
      return true;
    }

    // Check cluster prefixes (first 3 digits)
    final prefix = cleaned.substring(0, 3);
    return _serviceablePrefixes.contains(prefix);
  }

  /// Comprehensive validation returning rich status and user-facing messages.
  static PincodeValidationResult validate(String? pinCode) {
    if (pinCode == null || pinCode.trim().isEmpty) {
      return const PincodeValidationResult(
        isValidFormat: false,
        isServiceable: false,
        message: 'PIN code is required.',
      );
    }

    final cleaned = pinCode.trim();
    if (!isValidFormat(cleaned)) {
      return const PincodeValidationResult(
        isValidFormat: false,
        isServiceable: false,
        message: 'Please enter a valid 6-digit PIN code.',
      );
    }

    final serviceable = isServiceable(cleaned);
    if (serviceable) {
      final zone = _resolveHubName(cleaned);
      return PincodeValidationResult(
        isValidFormat: true,
        isServiceable: true,
        hubName: zone,
        estimatedDeliveryTime: '22-45 mins (Dark store express)',
        message: 'PIN $cleaned is serviceable for express pharmacy delivery.',
      );
    } else {
      return PincodeValidationResult(
        isValidFormat: true,
        isServiceable: false,
        message: 'PIN code $cleaned is currently unserviceable for delivery. We are expanding to your location soon.',
      );
    }
  }

  static String _resolveHubName(String pin) {
    final prefix = pin.substring(0, 3);
    return switch (prefix) {
      '500' || '501' || '502' => 'Hyderabad Hub',
      '560' || '561' || '562' => 'Bengaluru Hub',
      '400' || '401' => 'Mumbai Hub',
      '411' || '412' => 'Pune Hub',
      '110' => 'Delhi Central Hub',
      '122' => 'Gurugram Hub',
      '201' => 'Noida Hub',
      '600' || '601' || '602' || '603' => 'Chennai Hub',
      '700' || '701' => 'Kolkata Hub',
      '380' || '382' => 'Ahmedabad Hub',
      _ => 'Regional Pharmacy Hub',
    };
  }
}

class PincodeValidationResult {
  final bool isValidFormat;
  final bool isServiceable;
  final String message;
  final String? hubName;
  final String? estimatedDeliveryTime;

  const PincodeValidationResult({
    required this.isValidFormat,
    required this.isServiceable,
    required this.message,
    this.hubName,
    this.estimatedDeliveryTime,
  });
}


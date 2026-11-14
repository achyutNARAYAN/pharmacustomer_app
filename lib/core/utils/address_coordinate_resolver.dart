import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Resolves real geographical coordinates for customer delivery addresses,
/// ensuring that Hyderabad addresses (PIN 500xxx, Telangana) NEVER point
/// to Bangalore or any other stale placeholder coordinates.
class AddressCoordinateResolver {
  AddressCoordinateResolver._();

  static const LatLng hyderabadDefault = LatLng(17.4411, 78.4608);

  static Future<LatLng> resolve({
    required String addressText,
    String? pinCode,
    String? city,
    double? latitude,
    double? longitude,
  }) async {
    final lower = addressText.toLowerCase();
    final lowerCity = (city ?? '').toLowerCase();
    final cleanPin = pinCode ?? _extractPin(addressText) ?? '';

    final isHyderabad = cleanPin.startsWith('50') ||
        lower.contains('hyder') ||
        lower.contains('secunderabad') ||
        lower.contains('telangana') ||
        lower.contains('tg') ||
        lowerCity.contains('hyder');

    final isBangalore = cleanPin.startsWith('56') ||
        lower.contains('bangalore') ||
        lower.contains('bengaluru') ||
        lowerCity.contains('bangalore') ||
        lowerCity.contains('bengaluru');

    // ── 1. If address is in Hyderabad / Telangana ─────────────────────────────
    if (isHyderabad) {
      // If coordinates provided are genuinely in Hyderabad region [17.1..17.7, 78.1..78.8]
      if (latitude != null && longitude != null) {
        final isInHyderabadBounds = latitude >= 17.1 &&
            latitude <= 17.7 &&
            longitude >= 78.1 &&
            longitude <= 78.8;
        if (isInHyderabadBounds) {
          return LatLng(latitude, longitude);
        }
      }

      // Check known Hyderabad PIN codes directly for maximum pinpoint accuracy
      if (cleanPin == '500016') return const LatLng(17.4411, 78.4608); // Begumpet / Ameerpet
      if (cleanPin == '500034') return const LatLng(17.4156, 78.4357); // Banjara Hills
      if (cleanPin == '500081') return const LatLng(17.4385, 78.3800); // HITEC City / Madhapur
      if (cleanPin == '500033') return const LatLng(17.4319, 78.4073); // Jubilee Hills
      if (cleanPin == '500003') return const LatLng(17.4399, 78.4983); // Secunderabad
      if (cleanPin == '500072') return const LatLng(17.4933, 78.3914); // Kukatpally
      if (cleanPin == '500084') return const LatLng(17.4722, 78.3567); // Kondapur
      if (cleanPin == '500032') return const LatLng(17.4359, 78.3588); // Gachibowli

      // Try device forward geocoding with 2-second timeout, but strictly validate bounds
      try {
        final query = cleanPin.isNotEmpty
            ? '$cleanPin, Hyderabad, India'
            : '$addressText, Hyderabad, India';
        final locations = await locationFromAddress(query).timeout(const Duration(seconds: 2));
        if (locations.isNotEmpty) {
          final loc = locations.first;
          if (loc.latitude >= 17.1 &&
              loc.latitude <= 17.7 &&
              loc.longitude >= 78.1 &&
              loc.longitude <= 78.8) {
            return LatLng(loc.latitude, loc.longitude);
          }
        }
      } catch (_) {}

      // Fallback for any other Hyderabad address
      return hyderabadDefault;
    }

    // ── 2. If address is in Bangalore / Bengaluru ─────────────────────────────
    if (isBangalore) {
      if (latitude != null && longitude != null) {
        final isInBangaloreBounds = latitude >= 12.7 &&
            latitude <= 13.2 &&
            longitude >= 77.4 &&
            longitude <= 77.8;
        if (isInBangaloreBounds) {
          return LatLng(latitude, longitude);
        }
      }
      return const LatLng(12.9716, 77.5946); // Bangalore Central
    }

    // ── 3. Other known cities / PIN codes ────────────────────────────────────
    if (cleanPin.startsWith('400') || lower.contains('mumbai')) return const LatLng(19.0760, 72.8777);
    if (cleanPin.startsWith('110') || lower.contains('delhi')) return const LatLng(28.6139, 77.2090);
    if (cleanPin.startsWith('600') || lower.contains('chennai')) return const LatLng(13.0827, 80.2707);
    if (cleanPin.startsWith('700') || lower.contains('kolkata')) return const LatLng(22.5726, 88.3639);
    if (cleanPin.startsWith('411') || lower.contains('pune')) return const LatLng(18.5204, 73.8567);

    // ── 4. If arbitrary valid coordinates provided ───────────────────────────
    if (latitude != null && longitude != null && latitude != 0 && longitude != 0) {
      // Ensure we don't accidentally return Bangalore for non-Bangalore addresses
      final isStaleBangalore =
          latitude >= 12.7 && latitude <= 13.2 && longitude >= 77.4 && longitude <= 77.8;
      if (!isStaleBangalore) {
        return LatLng(latitude, longitude);
      }
    }

    // Default fallback to Hyderabad
    return hyderabadDefault;
  }

  static String? _extractPin(String text) {
    final match = RegExp(r'\b[1-9][0-9]{5}\b').firstMatch(text);
    return match?.group(0);
  }
}

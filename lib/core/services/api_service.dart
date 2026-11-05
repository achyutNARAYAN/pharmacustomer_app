import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../errors/failures.dart';
import '../logging/app_logger.dart';

/// Single unified ApiService for all HTTP communication with the MDP backend.
class ApiService {
  static http.Client _client = http.Client();
  static AppLogger? logger;
  static String? _authToken;
  static String? _currentCustomerId;
  static Map<String, dynamic>? _cachedCustomerProfile;

  static void setHttpClient(http.Client client) {
    _client = client;
  }

  static String? _extractBusinessCustomerId([String? tokenToParse]) {
    final t = tokenToParse ?? _authToken;
    if (t == null || t.isEmpty) return null;
    try {
      final parts = t.split('.');
      if (parts.length == 3) {
        final payload = parts[1];
        final normalized = base64Url.normalize(payload);
        final decoded = utf8.decode(base64Url.decode(normalized));
        final data = jsonDecode(decoded) as Map<String, dynamic>;
        final custId = data['customerId'] as String?;
        if (custId != null && custId.isNotEmpty) {
          return custId;
        }
      }
    } catch (_) {}
    return null;
  }

  static void setCustomerId(String? id) {
    if (id != null && id.isNotEmpty && id != 'me' && id != 'u_customer') {
      final bizId = _extractBusinessCustomerId();
      // If we already have a business customer ID (e.g. CUST-2026-0003), do not overwrite it with a 24-hex Mongo ID
      if (bizId != null && RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(id)) {
        _currentCustomerId = bizId;
      } else {
        _currentCustomerId = id;
      }
    }
  }

  static String? get currentCustomerId {
    final bizId = _extractBusinessCustomerId() ?? _cachedCustomerProfile?['customerId'] as String?;
    if (bizId != null && bizId.isNotEmpty) {
      return bizId;
    }
    return _currentCustomerId;
  }

  static Map<String, dynamic>? get cachedCustomerProfile => _cachedCustomerProfile;

  static void setCachedCustomerProfile(Map<String, dynamic>? profile) {
    _cachedCustomerProfile = profile;
    if (profile != null) {
      final custId = profile['customerId'] as String? ?? profile['_id'] as String? ?? profile['id'] as String?;
      if (custId != null && custId.isNotEmpty) {
        setCustomerId(custId);
      }
    }
  }

  static String _resolveCustomerId(String? id) {
    final tokenBizId = _extractBusinessCustomerId();
    final cacheBizId = _cachedCustomerProfile?['customerId'] as String?;
    final canonicalBizId = tokenBizId ?? cacheBizId;

    if (id != null && id.isNotEmpty && id != 'me' && id != 'u_customer') {
      // If a 24-character MongoDB hex ID is passed, but we know the business customerId (CUST-...),
      // use the canonical business customer ID!
      if (canonicalBizId != null && RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(id)) {
        return canonicalBizId;
      }
      return id;
    }

    if (canonicalBizId != null && canonicalBizId.isNotEmpty) {
      return canonicalBizId;
    }

    final cur = _currentCustomerId;
    if (cur != null && cur.isNotEmpty && cur != 'me' && cur != 'u_customer') {
      return cur;
    }
    return '';
  }

  static void setToken(String? token) {
    _authToken = token;
    if (token != null && token.isNotEmpty) {
      final bizId = _extractBusinessCustomerId(token);
      if (bizId != null && bizId.isNotEmpty) {
        _currentCustomerId = bizId;
      } else {
        try {
          final parts = token.split('.');
          if (parts.length == 3) {
            final payload = parts[1];
            final normalized = base64Url.normalize(payload);
            final decoded = utf8.decode(base64Url.decode(normalized));
            final data = jsonDecode(decoded) as Map<String, dynamic>;
            final extractedId = data['customerId'] as String? ??
                data['_id'] as String? ??
                data['id'] as String? ??
                data['userId'] as String? ??
                data['sub'] as String?;
            if (extractedId != null && extractedId.isNotEmpty && extractedId != 'me') {
              _currentCustomerId = extractedId;
            }
          }
        } catch (_) {}
      }
    } else {
      _currentCustomerId = null;
    }
  }

  static String? get token => _authToken;

  static Map<String, String> _headers([Map<String, String>? extra]) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_authToken != null && _authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    if (extra != null) {
      headers.addAll(extra);
    }
    return headers;
  }

  static Uri _uri(String endpoint, [Map<String, dynamic>? queryParameters]) {
    final cleanPath = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    final fullUrl = '${ApiConstants.baseUrl}$cleanPath';
    final uri = Uri.parse(fullUrl);
    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }
    final stringParams = queryParameters.map(
      (k, v) => MapEntry(k, v.toString()),
    );
    return uri.replace(queryParameters: stringParams);
  }

  static dynamic _processResponse(http.Response response) {
    final statusCode = response.statusCode;
    final bodyString = response.body;

    dynamic decoded;
    if (bodyString.isNotEmpty) {
      try {
        decoded = jsonDecode(bodyString);
      } catch (_) {
        decoded = null;
      }
    }

    if (statusCode >= 200 && statusCode < 300) {
      if (decoded is Map<String, dynamic> && decoded.containsKey('data')) {
        return decoded['data'];
      }
      return decoded;
    }

    String message = 'HTTP Request failed with status $statusCode';
    if (decoded is Map<String, dynamic> && decoded['error'] is Map) {
      final errorMap = decoded['error'] as Map<String, dynamic>;
      final baseMsg = errorMap['message']?.toString();
      final details = errorMap['details'];
      if (details is List && details.isNotEmpty) {
        final detailMsgs = <String>[];
        for (final item in details) {
          if (item is Map) {
            final field = item['field']?.toString();
            final fieldMsg = item['message']?.toString();
            if (fieldMsg != null) {
              detailMsgs.add(field != null ? '$field: $fieldMsg' : fieldMsg);
            }
          } else if (item is String && item != 'string' && item.trim().isNotEmpty) {
            detailMsgs.add(item.trim());
          }
        }
        if (detailMsgs.isNotEmpty) {
          message = detailMsgs.join(', ');
        } else if (baseMsg != null && baseMsg.isNotEmpty) {
          message = baseMsg;
        }
      } else if (baseMsg != null && baseMsg.isNotEmpty) {
        message = baseMsg;
      }
    }

    if (statusCode == 400) {
      throw ValidationFailure(message);
    } else if (statusCode == 401 || statusCode == 403) {
      throw AuthFailure(message);
    } else if (statusCode == 404) {
      throw NetworkFailure(message, statusCode: 404);
    } else if (statusCode == 429) {
      throw NetworkFailure(
        message != 'HTTP Request failed with status 429'
            ? message
            : 'Too many requests. Cooldown active, please wait.',
        statusCode: 429,
      );
    } else {
      throw NetworkFailure(message, statusCode: statusCode);
    }
  }

  // ── Terminal API Traffic Logging ──────────────────────────────────────────

  static void _logRequest(String method, Uri uri, {Map<String, String>? headers, dynamic body}) {
    if (kReleaseMode) return;
    final buffer = StringBuffer();
    buffer.writeln('\n==================== [API REQUEST] 🚀 ====================');
    buffer.writeln('Endpoint: $method ${uri.toString()}');
    if (headers != null && headers.isNotEmpty) {
      final safeHeaders = Map<String, String>.from(headers);
      if (safeHeaders.containsKey('Authorization')) {
        final auth = safeHeaders['Authorization']!;
        if (auth.length > 25) {
          safeHeaders['Authorization'] = '${auth.substring(0, 18)}...${auth.substring(auth.length - 4)}';
        }
      }
      buffer.writeln('Headers : $safeHeaders');
    }
    if (body != null) {
      try {
        final formatted = const JsonEncoder.withIndent('  ').convert(body is String ? jsonDecode(body) : body);
        buffer.writeln('Payload :\n$formatted');
      } catch (_) {
        buffer.writeln('Payload : $body');
      }
    } else {
      buffer.writeln('Payload : <none>');
    }
    buffer.write('==========================================================');
    debugPrint(buffer.toString());
  }

  static void _logResponse(String method, Uri uri, http.Response response, {int? durationMs}) {
    if (kReleaseMode) return;
    final buffer = StringBuffer();
    final status = response.statusCode;
    final isSuccess = status >= 200 && status < 300;
    final icon = isSuccess ? '✅ [API RESPONSE]' : '⚠️ [API ERROR RESPONSE]';
    final dur = durationMs != null ? ' (${durationMs}ms)' : '';
    buffer.writeln('\n-------------------- $icon --------------------');
    buffer.writeln('Status  : $status$dur');
    buffer.writeln('Endpoint: $method ${uri.toString()}');
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        final formatted = const JsonEncoder.withIndent('  ').convert(decoded);
        buffer.writeln('Response:\n$formatted');
      } catch (_) {
        buffer.writeln('Response: ${response.body}');
      }
    } else {
      buffer.writeln('Response: <empty body>');
    }
    buffer.write('----------------------------------------------------------');
    debugPrint(buffer.toString());
  }

  static void _logError(String method, Uri uri, Object error, {int? durationMs}) {
    if (kReleaseMode) return;
    final dur = durationMs != null ? ' (${durationMs}ms)' : '';
    debugPrint(
      '\n-------------------- ❌ [API NETWORK ERROR] --------------------\n'
      'Status  : FAILED$dur\n'
      'Endpoint: $method ${uri.toString()}\n'
      'Error   : $error\n'
      '----------------------------------------------------------',
    );
  }

  // ── Raw HTTP Primitives ───────────────────────────────────────────────────

  static Future<dynamic> get(String endpoint, {Map<String, dynamic>? queryParameters}) async {
    final uri = _uri(endpoint, queryParameters);
    final headers = _headers();
    _logRequest('GET', uri, headers: headers);
    final sw = Stopwatch()..start();
    try {
      final response = await _client.get(uri, headers: headers);
      sw.stop();
      _logResponse('GET', uri, response, durationMs: sw.elapsedMilliseconds);
      return _processResponse(response);
    } on SocketException catch (e) {
      sw.stop();
      _logError('GET', uri, e, durationMs: sw.elapsedMilliseconds);
      throw NetworkFailure('No internet connection', cause: e);
    } on Failure {
      rethrow;
    } catch (e) {
      sw.stop();
      _logError('GET', uri, e, durationMs: sw.elapsedMilliseconds);
      throw NetworkFailure('Unexpected network error', cause: e);
    }
  }

  static Future<dynamic> post(String endpoint, {dynamic body}) async {
    final uri = _uri(endpoint);
    final headers = _headers();
    _logRequest('POST', uri, headers: headers, body: body);
    final sw = Stopwatch()..start();
    try {
      final response = await _client.post(
        uri,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );
      sw.stop();
      _logResponse('POST', uri, response, durationMs: sw.elapsedMilliseconds);
      return _processResponse(response);
    } on SocketException catch (e) {
      sw.stop();
      _logError('POST', uri, e, durationMs: sw.elapsedMilliseconds);
      throw NetworkFailure('No internet connection', cause: e);
    } on Failure {
      rethrow;
    } catch (e) {
      sw.stop();
      _logError('POST', uri, e, durationMs: sw.elapsedMilliseconds);
      throw NetworkFailure('Unexpected network error', cause: e);
    }
  }

  static Future<dynamic> patch(String endpoint, {dynamic body}) async {
    final uri = _uri(endpoint);
    final headers = _headers();
    _logRequest('PATCH', uri, headers: headers, body: body);
    final sw = Stopwatch()..start();
    try {
      final response = await _client.patch(
        uri,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );
      sw.stop();
      _logResponse('PATCH', uri, response, durationMs: sw.elapsedMilliseconds);
      return _processResponse(response);
    } on SocketException catch (e) {
      sw.stop();
      _logError('PATCH', uri, e, durationMs: sw.elapsedMilliseconds);
      throw NetworkFailure('No internet connection', cause: e);
    } on Failure {
      rethrow;
    } catch (e) {
      sw.stop();
      _logError('PATCH', uri, e, durationMs: sw.elapsedMilliseconds);
      throw NetworkFailure('Unexpected network error', cause: e);
    }
  }

  static Future<dynamic> delete(String endpoint) async {
    final uri = _uri(endpoint);
    final headers = _headers();
    _logRequest('DELETE', uri, headers: headers);
    final sw = Stopwatch()..start();
    try {
      final response = await _client.delete(uri, headers: headers);
      sw.stop();
      _logResponse('DELETE', uri, response, durationMs: sw.elapsedMilliseconds);
      return _processResponse(response);
    } on SocketException catch (e) {
      sw.stop();
      _logError('DELETE', uri, e, durationMs: sw.elapsedMilliseconds);
      throw NetworkFailure('No internet connection', cause: e);
    } on Failure {
      rethrow;
    } catch (e) {
      sw.stop();
      _logError('DELETE', uri, e, durationMs: sw.elapsedMilliseconds);
      throw NetworkFailure('Unexpected network error', cause: e);
    }
  }

  // ── 1. Auth & OTP Endpoints ───────────────────────────────────────────────

  /// Send 6-digit OTP to Indian mobile number (Redis 5-min TTL, 60s cooldown)
  static Future<Map<String, dynamic>> sendOtp(String mobileNumber) async {
    final res = await post(ApiConstants.sendOtp, body: {'mobileNumber': mobileNumber});
    return res is Map<String, dynamic> ? res : {'mobileNumber': mobileNumber};
  }

  /// Verify OTP and store bearer JWT token
  static Future<Map<String, dynamic>> verifyOtp(String mobileNumber, String otp) async {
    final res = await post(ApiConstants.verifyOtp, body: {'mobileNumber': mobileNumber, 'otp': otp});
    if (res is Map<String, dynamic>) {
      final tokenStr = res['token'] as String?;
      if (tokenStr != null && tokenStr.isNotEmpty) {
        setToken(tokenStr);
      }
      final cust = res['customer'] as Map<String, dynamic>?;
      if (cust != null) {
        setCachedCustomerProfile(cust);
      }
      final custId = cust?['customerId'] as String? ?? cust?['_id'] as String? ?? cust?['id'] as String?;
      if (custId != null && custId.isNotEmpty) {
        setCustomerId(custId);
      }
      return res;
    }
    return {};
  }

  /// Complete profile registration for new customer
  static Future<Map<String, dynamic>> registerCustomer({
    required String mobileNumber,
    required String fullName,
    String? email,
    String? dob,
    String? gender,
    bool termsAccepted = true,
    bool privacyPolicyAccepted = true,
  }) async {
    final body = <String, dynamic>{
      'mobileNumber': mobileNumber,
      'fullName': fullName,
      'termsAccepted': termsAccepted,
      'privacyPolicyAccepted': privacyPolicyAccepted,
    };
    if (email != null && email.isNotEmpty) body['email'] = email;
    if (dob != null && dob.isNotEmpty) body['dob'] = dob;
    if (gender != null && gender.isNotEmpty) body['gender'] = gender.toUpperCase();

    final res = await post(ApiConstants.register, body: body);
    if (res is Map<String, dynamic>) {
      final tokenStr = res['token'] as String?;
      if (tokenStr != null && tokenStr.isNotEmpty) {
        setToken(tokenStr);
      }
      final cust = (res['customer'] is Map
          ? res['customer']
          : (res['data'] is Map ? res['data'] : res)) as Map<String, dynamic>?;
      if (cust != null) {
        setCachedCustomerProfile(cust);
      }
      final custId = cust?['customerId'] as String? ?? cust?['_id'] as String? ?? cust?['id'] as String?;
      if (custId != null && custId.isNotEmpty) {
        setCustomerId(custId);
      }
      return res;
    }
    return {};
  }

  // ── 2. Medicine Catalogue Endpoints ───────────────────────────────────────

  /// Search & filter central medicine catalogue
  static Future<List<Map<String, dynamic>>> searchMedicines({
    String? search,
    String? category,
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'limit': limit,
    };
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (category != null && category.isNotEmpty) params['category'] = category;

    final res = await get(ApiConstants.medicines, queryParameters: params);
    if (res is List) {
      return res.whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }

  /// Get comprehensive details of a single medicine
  static Future<Map<String, dynamic>?> getMedicineById(String id) async {
    final res = await get(ApiConstants.medicineDetail(id));
    return res is Map<String, dynamic> ? res : null;
  }

  // ── 3. Customer Profile & Family Patients ─────────────────────────────────

  /// Get full customer profile (Includes addresses & family members)
  static Future<Map<String, dynamic>?> getCustomerProfile([String? customerId]) async {
    final targetId = _resolveCustomerId(customerId);
    if (targetId.isEmpty) return _cachedCustomerProfile;
    try {
      final res = await get(ApiConstants.customerProfile(targetId));
      if (res is Map<String, dynamic>) {
        final cust = res['customer'] is Map<String, dynamic>
            ? res['customer'] as Map<String, dynamic>
            : (res['data'] is Map<String, dynamic>
                ? (res['data']['customer'] is Map<String, dynamic>
                    ? res['data']['customer'] as Map<String, dynamic>
                    : res['data'] as Map<String, dynamic>)
                : res);
        setCachedCustomerProfile(cust);
        return cust;
      }
    } catch (_) {
      if (_cachedCustomerProfile != null) return _cachedCustomerProfile;
    }
    return _cachedCustomerProfile;
  }

  /// Update primary customer profile
  static Future<dynamic> updateCustomerProfile(String? customerId, {String? fullName, String? email}) async {
    final targetId = _resolveCustomerId(customerId);
    if (targetId.isEmpty) return null;
    final body = <String, dynamic>{};
    if (fullName != null) body['fullName'] = fullName;
    if (email != null) body['email'] = email;
    return await patch(ApiConstants.customerProfile(targetId), body: body);
  }

  /// Add delivery address with GeoJSON coordinates [longitude, latitude]
  static Future<dynamic> addAddress(
    String? customerId, {
    required String label,
    required String addressLine1,
    String? addressLine2,
    String? landmark,
    required String city,
    required String state,
    required String pincode,
    String? contactName,
    String? contactMobile,
    required double longitude,
    required double latitude,
    bool isDefault = false,
  }) async {
    final targetId = _resolveCustomerId(customerId);
    if (targetId.isEmpty) {
      throw const ValidationFailure('Customer ID is required. Please ensure you are logged in.');
    }
    final body = {
      'label': label,
      'addressLine1': addressLine1,
      if (addressLine2 != null && addressLine2.isNotEmpty) 'addressLine2': addressLine2,
      if (landmark != null && landmark.isNotEmpty) 'landmark': landmark,
      'city': city,
      'state': state,
      'pinCode': pincode,
      'pincode': pincode,
      'contactName': contactName ?? 'Customer',
      'contactMobile': contactMobile ?? '9876543210',
      'latitude': latitude,
      'longitude': longitude,
      'location': {
        'type': 'Point',
        'coordinates': [longitude, latitude],
      },
      'isDefault': isDefault,
    };
    return await post(ApiConstants.customerAddresses(targetId), body: body);
  }

  /// Update existing delivery address (PATCH /customers/{customerId}/addresses/{addressId})
  static Future<dynamic> updateAddress(
    String? customerId,
    String addressId, {
    String? label,
    String? addressLine1,
    String? addressLine2,
    String? landmark,
    String? city,
    String? state,
    String? pincode,
    String? contactName,
    String? contactMobile,
    double? longitude,
    double? latitude,
    bool? isDefault,
  }) async {
    final targetId = _resolveCustomerId(customerId);
    if (targetId.isEmpty) {
      throw const ValidationFailure('Customer ID is required. Please ensure you are logged in.');
    }
    final body = <String, dynamic>{};
    if (label != null && label.isNotEmpty) body['label'] = label;
    if (addressLine1 != null && addressLine1.isNotEmpty) body['addressLine1'] = addressLine1;
    if (addressLine2 != null) body['addressLine2'] = addressLine2;
    if (landmark != null) body['landmark'] = landmark;
    if (city != null && city.isNotEmpty) body['city'] = city;
    if (state != null && state.isNotEmpty) body['state'] = state;
    if (pincode != null && pincode.isNotEmpty) {
      body['pinCode'] = pincode;
      body['pincode'] = pincode;
    }
    if (contactName != null && contactName.isNotEmpty) body['contactName'] = contactName;
    if (contactMobile != null && contactMobile.isNotEmpty) body['contactMobile'] = contactMobile;
    if (latitude != null && longitude != null) {
      body['latitude'] = latitude;
      body['longitude'] = longitude;
      body['location'] = {
        'type': 'Point',
        'coordinates': [longitude, latitude],
      };
    }
    if (isDefault != null) body['isDefault'] = isDefault;

    return await patch(ApiConstants.customerAddressDetail(targetId, addressId), body: body);
  }

  /// Delete saved delivery address
  static Future<dynamic> deleteAddress(String? customerId, String addressId) async {
    final targetId = _resolveCustomerId(customerId);
    if (targetId.isEmpty) return null;
    return await delete(ApiConstants.customerAddressDetail(targetId, addressId));
  }

  /// Get all saved delivery addresses for a customer
  static Future<List<Map<String, dynamic>>> getAddresses([String? customerId]) async {
    final targetId = _resolveCustomerId(customerId);
    if (targetId.isNotEmpty) {
      try {
        final res = await get(ApiConstants.customerAddresses(targetId));
        if (res is List) {
          return res.whereType<Map<String, dynamic>>().toList();
        } else if (res is Map && res['addresses'] is List) {
          return (res['addresses'] as List).whereType<Map<String, dynamic>>().toList();
        }
      } catch (_) {}

      try {
        final profile = await getCustomerProfile(targetId);
        if (profile != null) {
          final cust = (profile['customer'] is Map ? profile['customer'] : profile) as Map<String, dynamic>;
          if (cust['addresses'] is List) {
            return (cust['addresses'] as List).whereType<Map<String, dynamic>>().toList();
          }
        }
      } catch (_) {}
    }

    final cached = _cachedCustomerProfile;
    if (cached != null) {
      final cust = (cached['customer'] is Map ? cached['customer'] : cached) as Map<String, dynamic>;
      if (cust['addresses'] is List) {
        return (cust['addresses'] as List).whereType<Map<String, dynamic>>().toList();
      }
    }
    return [];
  }

  /// Add family patient profile for prescription attachment
  static Future<dynamic> addFamilyMember(
    String? customerId, {
    required String fullName,
    String? relation,
    String? relationship,
    String? gender,
    String? dateOfBirth,
    int? age,
  }) async {
    final targetId = _resolveCustomerId(customerId);
    if (targetId.isEmpty) return null;

    final rawRel = (relation ?? relationship ?? 'OTHER').trim().toUpperCase();
    final validRel = switch (rawRel) {
      'SELF' => 'SELF',
      'SPOUSE' => 'SPOUSE',
      'FATHER' => 'FATHER',
      'MOTHER' => 'MOTHER',
      'SON' => 'SON',
      'DAUGHTER' => 'DAUGHTER',
      _ => 'OTHER',
    };

    final rawGen = (gender ?? 'OTHER').trim().toUpperCase();
    final validGen = switch (rawGen) {
      'MALE' || 'M' => 'MALE',
      'FEMALE' || 'F' => 'FEMALE',
      'PREFER_NOT_TO_SAY' => 'PREFER_NOT_TO_SAY',
      _ => 'OTHER',
    };

    String dob = dateOfBirth ?? '';
    if (dob.isEmpty) {
      final yearsAgo = age ?? 30;
      final calcDate = DateTime.now().subtract(Duration(days: 365 * yearsAgo));
      dob = calcDate.toUtc().toIso8601String();
    } else {
      try {
        final parsed = DateTime.parse(dob);
        dob = parsed.toUtc().toIso8601String();
      } catch (_) {}
    }

    final body = {
      'fullName': fullName,
      'relation': validRel,
      'gender': validGen,
      'dateOfBirth': dob,
    };
    return await post(ApiConstants.customerFamilyMembers(targetId), body: body);
  }

  // ── 4. Digital Prescriptions ──────────────────────────────────────────────

  /// Upload digital prescription (Image or PDF <= 5MB)
  static Future<Map<String, dynamic>?> uploadPrescription({
    String? customerId,
    required String patientName,
    int? patientAge,
    String? patientGender,
    String? doctorName,
    String? doctorRegNumber,
    required DateTime prescriptionDate,
    required String documentUrl,
    int? fileSize,
    String? mimeType,
  }) async {
    final targetId = _resolveCustomerId(customerId);
    final body = <String, dynamic>{
      'customerId': targetId,
      'patientName': patientName,
      'prescriptionDate': prescriptionDate.toUtc().toIso8601String(),
      'documentUrl': documentUrl,
    };
    if (patientAge != null) body['patientAge'] = patientAge;
    if (patientGender != null) body['patientGender'] = patientGender;
    if (doctorName != null) body['doctorName'] = doctorName;
    if (doctorRegNumber != null) body['doctorRegNumber'] = doctorRegNumber;
    if (fileSize != null) body['fileSize'] = fileSize;
    if (mimeType != null) body['mimeType'] = mimeType;

    final res = await post(ApiConstants.prescriptions, body: body);
    return res is Map<String, dynamic> ? res : null;
  }

  /// List customer prescriptions
  static Future<List<Map<String, dynamic>>> listPrescriptions({
    String? customerId,
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    final targetId = _resolveCustomerId(customerId);
    final params = <String, dynamic>{'page': page, 'limit': limit};
    if (targetId.isNotEmpty) params['customerId'] = targetId;
    if (status != null && status.isNotEmpty) params['status'] = status;
    final res = await get(ApiConstants.prescriptions, queryParameters: params);
    if (res is List) {
      return res.whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }

  /// Get prescription details and approved medicine quotas
  static Future<Map<String, dynamic>?> getPrescriptionById(String prescriptionId) async {
    final res = await get(ApiConstants.prescriptionDetail(prescriptionId));
    return res is Map<String, dynamic> ? res : null;
  }

  // ── 5. Cart & Pre-Checkout ────────────────────────────────────────────────

  /// Get active customer cart
  static Future<Map<String, dynamic>?> getCart() async {
    try {
      final res = await get(ApiConstants.cart);
      return res is Map<String, dynamic> ? res : null;
    } catch (_) {
      return null;
    }
  }

  /// Add item to cart triggering 4km dark store allocation
  static Future<dynamic> addCartItem(String medicineId, int quantity) async {
    return await post(ApiConstants.cartItems, body: {
      'medicineId': medicineId,
      'quantity': quantity,
    });
  }

  /// Pre-checkout validation & prescription quota freeze
  static Future<dynamic> checkout({
    required String addressId,
    String? prescriptionId,
    String? couponCode,
  }) async {
    final body = <String, dynamic>{'addressId': addressId};
    if (prescriptionId != null) body['prescriptionId'] = prescriptionId;
    if (couponCode != null) body['couponCode'] = couponCode;
    return await post(ApiConstants.cartCheckout, body: body);
  }
}

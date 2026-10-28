import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pharmacustomer_app/core/errors/failures.dart';
import 'package:pharmacustomer_app/core/models/medicine_model.dart';
import 'package:pharmacustomer_app/core/services/api_service.dart';

void main() {
  group('MDP API Service Integration Contract Tests', () {
    test('POST /customers/auth/send-otp succeeds with 200 payload', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/customers/auth/send-otp');
        final body = jsonDecode(request.body);
        expect(body['mobileNumber'], '9876543210');

        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'mobileNumber': '9876543210',
              'expiresInSeconds': 300,
              'cooldownSeconds': 60,
              'message': 'OTP sent successfully',
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      ApiService.setHttpClient(mockClient);

      final res = await ApiService.sendOtp('9876543210');
      expect(res['mobileNumber'], '9876543210');
      expect(res['expiresInSeconds'], 300);
    });

    test('POST /customers/auth/verify-otp sets token and returns valid customer data', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/customers/auth/verify-otp');
        final body = jsonDecode(request.body);
        expect(body['otp'], '123456');

        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'isRegistered': true,
              'customer': {
                '_id': '6adcca5f556072d2d667318e',
                'customerId': 'CUST-2026-0001',
                'fullName': 'Achyut Joshi',
                'mobileNumber': '9876543210',
              },
              'token': 'mock_jwt_token_123',
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      ApiService.setHttpClient(mockClient);

      final res = await ApiService.verifyOtp('9876543210', '123456');
      expect(res['token'], 'mock_jwt_token_123');
      expect(ApiService.token, 'mock_jwt_token_123');
      final customer = res['customer'] as Map<String, dynamic>;
      expect(customer['fullName'], 'Achyut Joshi');
    });

    test('GET /medicines decodes paise prices correctly into Medicine model', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/medicines');
        expect(request.url.queryParameters['search'], 'Dolo');

        return http.Response(
          jsonEncode({
            'success': true,
            'data': [
              {
                '_id': '6acf3184b099d7a0b9820906',
                'medicineCode': 'MED000002',
                'name': 'Dolo 650 Tablet',
                'brand': 'Dolo',
                'genericName': 'Paracetamol',
                'packSize': 'Strip of 15',
                'mrpPaise': 3500,
                'isPrescriptionRequired': false,
                'schedule': 'OTC',
              }
            ],
            'meta': {
              'page': 1,
              'limit': 20,
              'total': 1,
              'totalPages': 1,
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      ApiService.setHttpClient(mockClient);

      final list = await ApiService.searchMedicines(search: 'Dolo');
      expect(list.length, 1);
      final med = Medicine.fromJson(list.first);
      expect(med.name, 'Dolo 650 Tablet');
      expect(med.price, '35.00');
      expect(med.requiresPrescription, false);
    });

    test('POST /customers/:customerId/addresses validates GeoJSON coordinates format', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/customers/cust_123/addresses');
        final body = jsonDecode(request.body);
        expect(body['label'], 'HOME');
        expect(body['pinCode'], '560103');
        expect(body['contactName'], 'Customer');
        expect(body['contactMobile'], '9876543210');
        expect(body['latitude'], 12.9270);
        expect(body['longitude'], 77.6720);
        expect(body['location']['type'], 'Point');
        expect(body['location']['coordinates'], [77.6720, 12.9270]);

        return http.Response(
          jsonEncode({'success': true, 'data': {'_id': 'addr_01'}}),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      ApiService.setHttpClient(mockClient);

      final res = await ApiService.addAddress(
        'cust_123',
        label: 'HOME',
        addressLine1: 'Flat 402, Sunshine Heights',
        city: 'Bengaluru',
        state: 'Karnataka',
        pincode: '560103',
        longitude: 77.6720,
        latitude: 12.9270,
      );
      expect(res, isNotNull);
    });

    test('POST /prescriptions uploads prescription metadata and returns RX code', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/prescriptions');
        final body = jsonDecode(request.body);
        expect(body['customerId'], 'cust_123');
        expect(body['patientName'], 'Ramesh Joshi');

        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              '_id': 'rx_mongo_id',
              'prescriptionId': 'RX-2026-0001',
              'status': 'PENDING_REVIEW',
              'patientName': 'Ramesh Joshi',
              'documentUrl': 'https://res.cloudinary.com/demo/sample.pdf',
            }
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      ApiService.setHttpClient(mockClient);

      final res = await ApiService.uploadPrescription(
        customerId: 'cust_123',
        patientName: 'Ramesh Joshi',
        prescriptionDate: DateTime(2026, 10, 26),
        documentUrl: 'https://res.cloudinary.com/demo/sample.pdf',
      );

      expect(res?['prescriptionId'], 'RX-2026-0001');
      expect(res?['status'], 'PENDING_REVIEW');
    });

    test('Error responses format into proper failures (400 validation error)', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'error': {
              'code': 'VALIDATION_ERROR',
              'message': 'Mobile number must be a valid 10-digit Indian number',
            }
          }),
          400,
          headers: {'content-type': 'application/json'},
        );
      });

      ApiService.setHttpClient(mockClient);

      expect(
        () => ApiService.sendOtp('123'),
        throwsA(isA<ValidationFailure>().having(
          (e) => e.message,
          'message',
          contains('10-digit Indian number'),
        )),
      );
    });

    test('POST /customers/auth/register sends required body and sets session token', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/customers/auth/register');
        final body = jsonDecode(request.body);
        expect(body['mobileNumber'], '9876543210');
        expect(body['fullName'], 'Achyut Joshi');
        expect(body['email'], 'achyut@example.com');
        expect(body['dob'], '1995-04-12');
        expect(body['gender'], 'MALE');
        expect(body['termsAccepted'], true);
        expect(body['privacyPolicyAccepted'], true);

        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'customer': {
                '_id': '6adcca5f556072d2d667318e',
                'customerId': 'CUST-2026-0001',
                'fullName': 'Achyut Joshi',
                'mobileNumber': '9876543210',
                'email': 'achyut@example.com',
                'dob': '1995-04-12',
                'gender': 'MALE',
              },
              'token': 'mock_jwt_registered_token',
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      ApiService.setHttpClient(mockClient);

      final res = await ApiService.registerCustomer(
        mobileNumber: '9876543210',
        fullName: 'Achyut Joshi',
        email: 'achyut@example.com',
        dob: '1995-04-12',
        gender: 'MALE',
      );

      expect(res['token'], 'mock_jwt_registered_token');
      expect(ApiService.token, 'mock_jwt_registered_token');
      final customer = res['customer'] as Map<String, dynamic>;
      expect(customer['fullName'], 'Achyut Joshi');
      expect(customer['gender'], 'MALE');
    });

    test('429 Too Many Requests throws NetworkFailure with cooldown message', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'error': {
              'code': 'VALIDATION_ERROR',
              'message': 'Cooldown active. Please wait 60 seconds.',
            }
          }),
          429,
          headers: {'content-type': 'application/json'},
        );
      });

      ApiService.setHttpClient(mockClient);

      expect(
        () => ApiService.sendOtp('9876543210'),
        throwsA(isA<NetworkFailure>().having(
          (e) => e.statusCode,
          'statusCode',
          429,
        )),
      );
    });

    test('GET /prescriptions/:prescriptionId retrieves clinical details & quotas', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/prescriptions/RX-2026-0001');

        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              '_id': 'rx_mongo_001',
              'prescriptionId': 'RX-2026-0001',
              'status': 'APPROVED',
              'patientName': 'Ramesh Joshi',
              'doctorName': 'Dr. R. K. Sharma',
              'approvedMedicines': [
                {'medicine': 'med_01', 'allowedQuantity': 10, 'balanceQuantity': 10}
              ]
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      ApiService.setHttpClient(mockClient);

      final rx = await ApiService.getPrescriptionById('RX-2026-0001');
      expect(rx?['prescriptionId'], 'RX-2026-0001');
      expect(rx?['status'], 'APPROVED');
      expect((rx?['approvedMedicines'] as List).length, 1);
    });

    test('POST /cart/checkout validates address and locks quota', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/cart/checkout');
        final body = jsonDecode(request.body);
        expect(body['addressId'], 'addr_01');
        expect(body['prescriptionId'], 'RX-2026-0001');

        return http.Response(
          jsonEncode({
            'success': true,
            'data': {'status': 'CHECKOUT_SESSION_LOCKED'}
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      ApiService.setHttpClient(mockClient);

      final res = await ApiService.checkout(
        addressId: 'addr_01',
        prescriptionId: 'RX-2026-0001',
      );
      expect(res, isNotNull);
    });

    test('PATCH /customers/:customerId updates full name and email', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/customers/cust_123');
        final body = jsonDecode(request.body);
        expect(body['fullName'], 'Updated User');

        return http.Response(
          jsonEncode({'success': true, 'data': {'fullName': 'Updated User'}}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      ApiService.setHttpClient(mockClient);

      final res = await ApiService.updateCustomerProfile('cust_123', fullName: 'Updated User');
      expect(res, isNotNull);
    });

    test('DELETE /customers/:customerId/addresses/:addressId deletes saved address', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/customers/cust_123/addresses/addr_01');

        return http.Response(
          jsonEncode({'success': true, 'data': {'deleted': true}}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      ApiService.setHttpClient(mockClient);

      final res = await ApiService.deleteAddress('cust_123', 'addr_01');
      expect(res, isNotNull);
    });
  });
}


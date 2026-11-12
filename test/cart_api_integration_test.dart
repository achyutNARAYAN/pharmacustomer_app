import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pharmacustomer_app/core/models/cart_item.dart';
import 'package:pharmacustomer_app/core/providers/cart_notifier.dart';
import 'package:pharmacustomer_app/core/services/api_service.dart';
import 'package:pharmacustomer_app/core/storage/key_value_store.dart';
import 'package:pharmacustomer_app/core/storage/migrator.dart';
import 'package:pharmacustomer_app/core/storage/user_data_registry.dart';
import 'package:pharmacustomer_app/features/cart/models/cart_models.dart';
import 'package:pharmacustomer_app/features/cart/repositories/cart_repository.dart';

class InMemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> _storage = {};
  @override
  Future<String?> read(String key) async => _storage[key];
  @override
  Future<void> write(String key, String value) async => _storage[key] = value;
  @override
  Future<void> remove(String key) async => _storage.remove(key);
  @override
  Future<Set<String>> keys({String? prefix}) async {
    if (prefix == null) return _storage.keys.toSet();
    return _storage.keys.where((k) => k.startsWith(prefix)).toSet();
  }
}

void main() {
  setUp(() {
    ApiService.setToken('test_jwt_bearer_token');
    ApiService.setCustomerId('CUST-2026-0001');
  });

  group('MDP Shopping Cart & Checkout API (11 Endpoints Contract Tests)', () {
    // ── Endpoint 1: GET /cart ────────────────────────────────────────────────
    test('1. GET /cart retrieves reconciled active cart, summary, and warnings', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/cart');
        expect(request.headers['Authorization'], 'Bearer test_jwt_bearer_token');

        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'cart': {
                '_id': '673200a1b2c3d4e5f6a7b8c9',
                'cartCode': 'CART-2026-0001',
                'customer': '673100a1b2c3d4e5f6a7b8c0',
                'status': 'ACTIVE',
                'allocatedStore': null,
                'deliveryAddress': {},
                'items': [
                  {
                    '_id': '673200a1b2c3d4e5f6a7b8ca',
                    'medicine': {
                      '_id': '673000a1b2c3d4e5f6a7b8b1',
                      'name': 'Dolo 650mg Tablet',
                      'brand': 'Micro Labs',
                      'mrpPaise': 3500,
                      'isPrescriptionRequired': false,
                    },
                    'name': 'Dolo 650mg Tablet',
                    'quantity': 2,
                    'pricePaise': 3000,
                    'mrpPaise': 3500,
                    'isPrescriptionRequired': false,
                  }
                ],
                'itemsTotalPaise': 6000,
                'discountPaise': 0,
                'deliveryFeePaise': 4000,
                'totalPayablePaise': 10000,
                'couponCode': null,
                'prescription': null,
                'createdAt': '2026-11-11T14:00:00.000Z',
                'updatedAt': '2026-11-11T14:05:00.000Z',
              },
              'summary': {
                'itemCount': 2,
                'uniqueMedicinesCount': 1,
                'requiresPrescription': false,
                'hasPrescriptionAttached': false,
              },
              'warnings': [
                {
                  'type': 'PRICE_CHANGED',
                  'itemId': '673200a1b2c3d4e5f6a7b8ca',
                  'name': 'Dolo 650mg Tablet',
                  'oldPricePaise': 3000,
                  'newPricePaise': 3500,
                  'message': 'Price updated from ₹30.00 to ₹35.00',
                }
              ]
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      ApiService.setHttpClient(mockClient);

      final res = await ApiService.getCart();
      expect(res, isNotNull);
      final envelope = GetCartResponse.fromJson(res!);

      expect(envelope.cart.id, '673200a1b2c3d4e5f6a7b8c9');
      expect(envelope.cart.cartCode, 'CART-2026-0001');
      expect(envelope.cart.status, 'ACTIVE');
      expect(envelope.cart.items.length, 1);
      expect(envelope.cart.items.first.medicineId, '673000a1b2c3d4e5f6a7b8b1');
      expect(envelope.cart.items.first.pricePaise, 3000);
      expect(envelope.cart.itemsTotalPaise, 6000);
      expect(envelope.cart.deliveryFeePaise, 4000);
      expect(envelope.cart.totalPayablePaise, 10000);

      expect(envelope.summary.itemCount, 2);
      expect(envelope.summary.uniqueMedicinesCount, 1);
      expect(envelope.summary.requiresPrescription, false);

      expect(envelope.warnings.length, 1);
      expect(envelope.warnings.first.type, 'PRICE_CHANGED');
    });

    // ── Endpoint 2: POST /cart/items ─────────────────────────────────────────
    test('2. POST /cart/items adds medicine line item to active cart', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/cart/items');
        final body = jsonDecode(request.body);
        expect(body['medicineId'], '673000a1b2c3d4e5f6a7b8b1');
        expect(body['quantity'], 1);

        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              '_id': '673200a1b2c3d4e5f6a7b8c9',
              'cartCode': 'CART-2026-0001',
              'status': 'ACTIVE',
              'items': [
                {
                  '_id': '673200a1b2c3d4e5f6a7b8ca',
                  'medicine': '673000a1b2c3d4e5f6a7b8b1',
                  'name': 'Dolo 650mg Tablet',
                  'quantity': 1,
                  'pricePaise': 3500,
                  'mrpPaise': 3500,
                  'isPrescriptionRequired': false,
                }
              ],
              'itemsTotalPaise': 3500,
              'discountPaise': 0,
              'deliveryFeePaise': 4000,
              'totalPayablePaise': 7500,
            }
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      ApiService.setHttpClient(mockClient);

      final res = await ApiService.addCartItem('673000a1b2c3d4e5f6a7b8b1', 1);
      expect(res, isNotNull);
      final cart = CartModel.fromJson(res as Map<String, dynamic>);
      expect(cart.items.length, 1);
      expect(cart.totalPayablePaise, 7500);
      expect(cart.formattedTotalPayable, '₹75');
    });

    // ── Endpoint 3: PATCH /cart/items/{itemId} ───────────────────────────────
    test('3. PATCH /cart/items/{itemId} updates quantity of cart line item', () async {
      const lineItemId = '673200a1b2c3d4e5f6a7b8ca';
      final mockClient = MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, '/api/v1/cart/items/$lineItemId');
        final body = jsonDecode(request.body);
        expect(body['quantity'], 3);

        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              '_id': '673200a1b2c3d4e5f6a7b8c9',
              'cartCode': 'CART-2026-0001',
              'status': 'ACTIVE',
              'items': [
                {
                  '_id': lineItemId,
                  'medicine': '673000a1b2c3d4e5f6a7b8b1',
                  'name': 'Dolo 650mg Tablet',
                  'quantity': 3,
                  'pricePaise': 3500,
                  'mrpPaise': 3500,
                  'isPrescriptionRequired': false,
                }
              ],
              'itemsTotalPaise': 10500,
              'discountPaise': 0,
              'deliveryFeePaise': 4000,
              'totalPayablePaise': 14500,
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      ApiService.setHttpClient(mockClient);

      final res = await ApiService.updateCartItemQuantity(lineItemId, 3);
      final cart = CartModel.fromJson(res as Map<String, dynamic>);
      expect(cart.items.first.quantity, 3);
      expect(cart.itemsTotalPaise, 10500);
      expect(cart.totalPayablePaise, 14500);
    });

    // ── Endpoint 4: DELETE /cart/items/{itemId} ──────────────────────────────
    test('4. DELETE /cart/items/{itemId} removes line item from cart', () async {
      const lineItemId = '673200a1b2c3d4e5f6a7b8ca';
      final mockClient = MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/api/v1/cart/items/$lineItemId');

        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              '_id': '673200a1b2c3d4e5f6a7b8c9',
              'cartCode': 'CART-2026-0001',
              'status': 'ACTIVE',
              'items': [],
              'itemsTotalPaise': 0,
              'discountPaise': 0,
              'deliveryFeePaise': 0,
              'totalPayablePaise': 0,
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      ApiService.setHttpClient(mockClient);

      final res = await ApiService.removeCartItem(lineItemId);
      final cart = CartModel.fromJson(res as Map<String, dynamic>);
      expect(cart.items.isEmpty, true);
      expect(cart.totalPayablePaise, 0);
    });

    // ── Endpoint 5: DELETE /cart ─────────────────────────────────────────────
    test('5. DELETE /cart clears entire cart and resets financial totals to 0', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/api/v1/cart');

        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              '_id': '673200a1b2c3d4e5f6a7b8c9',
              'cartCode': 'CART-2026-0001',
              'status': 'ACTIVE',
              'items': [],
              'itemsTotalPaise': 0,
              'discountPaise': 0,
              'deliveryFeePaise': 0,
              'totalPayablePaise': 0,
              'allocatedStore': null,
              'couponCode': null,
              'prescription': null,
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      ApiService.setHttpClient(mockClient);

      final res = await ApiService.clearCart();
      final cart = CartModel.fromJson(res as Map<String, dynamic>);
      expect(cart.items.isEmpty, true);
      expect(cart.allocatedStore, isNull);
      expect(cart.couponCode, isNull);
    });

    // ── Endpoint 6: POST /cart/allocate ──────────────────────────────────────
    test('6. POST /cart/allocate previews 4km store allocation with FEFO stock check', () async {
      const addressId = '673100a1b2c3d4e5f6a7b8c2';
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/cart/allocate');
        final body = jsonDecode(request.body);
        expect(body['addressId'], addressId);

        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'success': true,
              'message': 'Store allocated successfully within 4km',
              'cart': {
                '_id': '673200a1b2c3d4e5f6a7b8c9',
                'cartCode': 'CART-2026-0001',
                'status': 'ACTIVE',
                'allocatedStore': '673050a1b2c3d4e5f6a7b8e1',
                'deliveryAddress': {
                  'addressId': addressId,
                  'pincode': '500034',
                  'location': {
                    'type': 'Point',
                    'coordinates': [78.4351, 17.4156],
                  }
                },
                'itemsTotalPaise': 6000,
                'discountPaise': 0,
                'deliveryFeePaise': 4000,
                'totalPayablePaise': 10000,
              }
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      ApiService.setHttpClient(mockClient);

      final res = await ApiService.allocateStore(addressId);
      expect(res?['success'], true);
      expect(res?['message'], 'Store allocated successfully within 4km');
      final cart = CartModel.fromJson(res?['cart'] as Map<String, dynamic>);
      expect(cart.allocatedStore, '673050a1b2c3d4e5f6a7b8e1');
      expect(cart.isStoreAllocated, true);
    });

    // ── Endpoint 7: POST /cart/prescription ──────────────────────────────────
    test('7. POST /cart/prescription attaches approved prescription to active cart', () async {
      const rxId = '673150a1b2c3d4e5f6a7b8d5';
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/cart/prescription');
        final body = jsonDecode(request.body);
        expect(body['prescriptionId'], rxId);

        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              '_id': '673200a1b2c3d4e5f6a7b8c9',
              'cartCode': 'CART-2026-0001',
              'status': 'ACTIVE',
              'prescription': rxId,
              'itemsTotalPaise': 6000,
              'discountPaise': 0,
              'deliveryFeePaise': 4000,
              'totalPayablePaise': 10000,
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      ApiService.setHttpClient(mockClient);

      final res = await ApiService.attachCartPrescription(rxId);
      final cart = CartModel.fromJson(res as Map<String, dynamic>);
      expect(cart.prescriptionId, rxId);
      expect(cart.hasPrescription, true);
    });

    // ── Endpoint 8: DELETE /cart/prescription ────────────────────────────────
    test('8. DELETE /cart/prescription removes prescription attachment', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/api/v1/cart/prescription');

        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              '_id': '673200a1b2c3d4e5f6a7b8c9',
              'cartCode': 'CART-2026-0001',
              'status': 'ACTIVE',
              'prescription': null,
              'itemsTotalPaise': 6000,
              'discountPaise': 0,
              'deliveryFeePaise': 4000,
              'totalPayablePaise': 10000,
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      ApiService.setHttpClient(mockClient);

      final res = await ApiService.removeCartPrescription();
      final cart = CartModel.fromJson(res as Map<String, dynamic>);
      expect(cart.prescriptionId, isNull);
      expect(cart.hasPrescription, false);
    });

    // ── Endpoint 9: POST /cart/coupon ────────────────────────────────────────
    test('9. POST /cart/coupon validates and applies coupon WELCOME50', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/cart/coupon');
        final body = jsonDecode(request.body);
        expect(body['couponCode'], 'WELCOME50');

        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              '_id': '673200a1b2c3d4e5f6a7b8c9',
              'cartCode': 'CART-2026-0001',
              'status': 'ACTIVE',
              'itemsTotalPaise': 25000,
              'couponCode': 'WELCOME50',
              'discountPaise': 5000,
              'deliveryFeePaise': 4000,
              'totalPayablePaise': 24000,
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      ApiService.setHttpClient(mockClient);

      final res = await ApiService.applyCoupon('welcome50');
      final cart = CartModel.fromJson(res as Map<String, dynamic>);
      expect(cart.couponCode, 'WELCOME50');
      expect(cart.discountPaise, 5000);
      expect(cart.formattedDiscount, '₹50');
      expect(cart.totalPayablePaise, 24000);
    });

    // ── Endpoint 10: DELETE /cart/coupon ─────────────────────────────────────
    test('10. DELETE /cart/coupon removes coupon and recalculates totals', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/api/v1/cart/coupon');

        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              '_id': '673200a1b2c3d4e5f6a7b8c9',
              'cartCode': 'CART-2026-0001',
              'status': 'ACTIVE',
              'itemsTotalPaise': 25000,
              'couponCode': null,
              'discountPaise': 0,
              'deliveryFeePaise': 4000,
              'totalPayablePaise': 29000,
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      ApiService.setHttpClient(mockClient);

      final res = await ApiService.removeCoupon();
      final cart = CartModel.fromJson(res as Map<String, dynamic>);
      expect(cart.couponCode, isNull);
      expect(cart.discountPaise, 0);
      expect(cart.totalPayablePaise, 29000);
    });

    // ── Endpoint 11: POST /cart/checkout ─────────────────────────────────────
    test('11. POST /cart/checkout locks cart for 15 minutes with stock hold', () async {
      const addressId = '673100a1b2c3d4e5f6a7b8c2';
      const prescriptionId = '673150a1b2c3d4e5f6a7b8d5';
      const couponCode = 'SAVE10';

      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/cart/checkout');
        final body = jsonDecode(request.body);
        expect(body['addressId'], addressId);
        expect(body['prescriptionId'], prescriptionId);
        expect(body['couponCode'], couponCode);

        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              '_id': '673200a1b2c3d4e5f6a7b8c9',
              'cartCode': 'CART-2026-0001',
              'customer': '673100a1b2c3d4e5f6a7b8c0',
              'status': 'LOCKED',
              'allocatedStore': '673050a1b2c3d4e5f6a7b8e1',
              'deliveryAddress': {
                'addressId': addressId,
                'pincode': '500034',
                'location': {'type': 'Point', 'coordinates': [78.4351, 17.4156]},
              },
              'lockedAt': '2026-11-11T14:45:00.000Z',
              'expiresAt': '2026-11-11T15:00:00.000Z',
              'itemsTotalPaise': 30000,
              'discountPaise': 3000,
              'deliveryFeePaise': 4000,
              'totalPayablePaise': 31000,
              'couponCode': couponCode,
              'prescription': prescriptionId,
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      ApiService.setHttpClient(mockClient);

      final res = await ApiService.checkout(
        addressId: addressId,
        prescriptionId: prescriptionId,
        couponCode: couponCode,
      );

      final cart = CartModel.fromJson(res as Map<String, dynamic>);
      expect(cart.status, 'LOCKED');
      expect(cart.isLocked, true);
      expect(cart.allocatedStore, '673050a1b2c3d4e5f6a7b8e1');
      expect(cart.expiresAt, isNotNull);
      expect(cart.totalPayablePaise, 31000);
      expect(cart.formattedTotalPayable, '₹310');
    });

    // ── FinTech Rules & Threshold Verification ──────────────────────────────
    test('FinTech Rule: Free delivery applies when itemsTotalPaise >= 50000', () {
      final cartUnderThreshold = CartModel.fromJson({
        '_id': 'c1',
        'cartCode': 'CART-01',
        'status': 'ACTIVE',
        'items': [{'medicine': 'm1', 'name': 'A', 'quantity': 1, 'pricePaise': 49900}],
        'itemsTotalPaise': 49900,
        'discountPaise': 0,
        'deliveryFeePaise': 4000,
        'totalPayablePaise': 53900,
      });
      expect(cartUnderThreshold.deliveryFeePaise, 4000);
      expect(cartUnderThreshold.formattedDeliveryFee, '₹40');

      final cartAtThreshold = CartModel.fromJson({
        '_id': 'c2',
        'cartCode': 'CART-02',
        'status': 'ACTIVE',
        'items': [{'medicine': 'm1', 'name': 'A', 'quantity': 1, 'pricePaise': 50000}],
        'itemsTotalPaise': 50000,
        'discountPaise': 0,
        'deliveryFeePaise': 0,
        'totalPayablePaise': 50000,
      });
      expect(cartAtThreshold.deliveryFeePaise, 0);
      expect(cartAtThreshold.formattedDeliveryFee, 'FREE');
    });

    // ── CartNotifier Reactive State Flow ─────────────────────────────────────
    test('CartNotifier reacts to API actions and maintains synchronized state', () async {
      final store = InMemoryKeyValueStore();
      final migrator = Migrator();
      final registry = UserDataRegistry();
      final repo = CartRepository(store: store, migrator: migrator, userDataRegistry: registry);

      final notifier = CartNotifier(repo);

      // Mock Add Item
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/cart/items') {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                '_id': 'cart_1',
                'cartCode': 'CART-TEST',
                'status': 'ACTIVE',
                'items': [
                  {
                    '_id': 'item_1',
                    'medicine': 'med_1',
                    'name': 'Paracetamol 500mg',
                    'quantity': 2,
                    'pricePaise': 2500,
                    'mrpPaise': 3000,
                    'isPrescriptionRequired': false,
                  }
                ],
                'itemsTotalPaise': 5000,
                'discountPaise': 0,
                'deliveryFeePaise': 4000,
                'totalPayablePaise': 9000,
              }
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path == '/api/v1/cart/coupon') {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                '_id': 'cart_1',
                'cartCode': 'CART-TEST',
                'status': 'ACTIVE',
                'items': [
                  {
                    '_id': 'item_1',
                    'medicine': 'med_1',
                    'name': 'Paracetamol 500mg',
                    'quantity': 2,
                    'pricePaise': 2500,
                    'mrpPaise': 3000,
                    'isPrescriptionRequired': false,
                  }
                ],
                'itemsTotalPaise': 5000,
                'couponCode': 'WELCOME50',
                'discountPaise': 5000,
                'deliveryFeePaise': 4000,
                'totalPayablePaise': 4000,
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"success": false}', 404);
      });

      ApiService.setHttpClient(mockClient);

      await notifier.addMedicine('med_1', quantity: 2);
      expect(notifier.items.length, 1);
      expect(notifier.totalCount, 2);
      expect(notifier.itemsTotalPaise, 5000);
      expect(notifier.totalPayablePaise, 9000);

      final couponApplied = await notifier.applyCouponCode('WELCOME50');
      expect(couponApplied, true);
      expect(notifier.couponCode, 'WELCOME50');
      expect(notifier.discountPaise, 5000);
      expect(notifier.totalPayablePaise, 4000);

      notifier.dispose();
    });

    test('CartNotifier resolves slugs to MongoDB ObjectId or handles offline fallback gracefully', () async {
      final store = InMemoryKeyValueStore();
      final migrator = Migrator();
      final registry = UserDataRegistry();
      final repo = CartRepository(store: store, migrator: migrator, userDataRegistry: registry);

      final notifier = CartNotifier(repo);

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/cart/items') {
          final body = jsonDecode(request.body);
          // Expect mapped 24-character hexadecimal MongoDB ObjectId
          expect(body['medicineId'], '673000a1b2c3d4e5f6a7b8b2');
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                '_id': 'cart_1',
                'cartCode': 'CART-TEST',
                'status': 'ACTIVE',
                'items': [
                  {
                    '_id': 'item_1',
                    'medicine': '673000a1b2c3d4e5f6a7b8b2',
                    'name': 'Glycomet-GP 2 Forte',
                    'quantity': 1,
                    'pricePaise': 14850,
                    'mrpPaise': 17500,
                  }
                ],
                'itemsTotalPaise': 14850,
                'discountPaise': 0,
                'deliveryFeePaise': 4000,
                'totalPayablePaise': 18850,
              }
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"success": false}', 404);
      });

      ApiService.setHttpClient(mockClient);

      // Add using slug ID
      await notifier.addMedicine(
        'glycomet-gp_2_forte',
        quantity: 1,
        localFallback: CartItem(id: 'glycomet-gp_2_forte', name: 'Glycomet-GP 2 Forte', pack: 'Strip of 15 tablets', price: 148.50),
      );

      expect(notifier.items.length, 1);
      expect(notifier.items.first.name, 'Glycomet-GP 2 Forte');
      expect(notifier.actionError, isNull);

      notifier.dispose();
    });
  });
}

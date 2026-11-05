import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:pharmacustomer_app/core/models/cart_item.dart';
import 'package:pharmacustomer_app/core/providers/cart_notifier.dart';
import 'package:pharmacustomer_app/core/providers/profile_notifier.dart';
import 'package:pharmacustomer_app/core/utils/pincode_validator.dart';
import 'package:pharmacustomer_app/features/cart/order_review.dart';
import 'package:pharmacustomer_app/features/profile/customer_address_screen.dart';
import 'package:pharmacustomer_app/features/profile/models/customer_address.dart';
import 'package:pharmacustomer_app/features/profile/providers/customer_address_provider.dart';
import 'package:pharmacustomer_app/features/profile/repositories/address_repository.dart';

class MockInMemoryAddressRepository implements AddressRepository {
  final List<CustomerAddress> _addresses = [];

  MockInMemoryAddressRepository([List<CustomerAddress>? initial]) {
    if (initial != null) {
      _addresses.addAll(initial);
    }
  }

  @override
  List<CustomerAddress> get cachedAddresses => List.unmodifiable(_addresses);

  @override
  Future<List<CustomerAddress>> getAddresses() async {
    return List.unmodifiable(_addresses);
  }

  @override
  Future<CustomerAddress> addAddress(CustomerAddress address) async {
    final toAdd = address.id.isEmpty
        ? address.copyWith(id: 'addr_${_addresses.length + 1}')
        : address;
    _addresses.add(toAdd);
    return toAdd;
  }

  @override
  Future<CustomerAddress> updateAddress(CustomerAddress address) async {
    final index = _addresses.indexWhere((a) => a.id == address.id);
    if (index >= 0) {
      _addresses[index] = address;
    }
    return address;
  }

  @override
  Future<void> deleteAddress(String addressId) async {
    _addresses.removeWhere((a) => a.id == addressId);
  }

  @override
  Future<void> setDefaultAddress(String addressId) async {
    for (int i = 0; i < _addresses.length; i++) {
      final isDef = _addresses[i].id == addressId;
      _addresses[i] = _addresses[i].copyWith(isDefault: isDef);
    }
  }
}

void main() {
  setUp(() {
    PincodeValidator.setMockServiceabilityForTesting(null);
  });

  group('PincodeValidator Unit Tests', () {
    test('isValidFormat validates 6-digit Indian postal PIN codes', () {
      expect(PincodeValidator.isValidFormat('500034'), isTrue);
      expect(PincodeValidator.isValidFormat('560103'), isTrue);
      expect(PincodeValidator.isValidFormat('110001'), isTrue);

      // Invalid formats
      expect(PincodeValidator.isValidFormat(null), isFalse);
      expect(PincodeValidator.isValidFormat(''), isFalse);
      expect(PincodeValidator.isValidFormat('012345'), isFalse); // Cannot start with 0
      expect(PincodeValidator.isValidFormat('50003'), isFalse); // Only 5 digits
      expect(PincodeValidator.isValidFormat('5000345'), isFalse); // 7 digits
      expect(PincodeValidator.isValidFormat('50003A'), isFalse); // Non-numeric
    });

    test('isServiceable correctly identifies serviceable dark store clusters', () {
      // Hyderabad (500xxx)
      expect(PincodeValidator.isServiceable('500034'), isTrue);
      expect(PincodeValidator.isServiceable('500081'), isTrue);
      // Bengaluru (560xxx)
      expect(PincodeValidator.isServiceable('560038'), isTrue);
      expect(PincodeValidator.isServiceable('560103'), isTrue);
      // Mumbai (400xxx)
      expect(PincodeValidator.isServiceable('400001'), isTrue);
      // Delhi (110xxx)
      expect(PincodeValidator.isServiceable('110001'), isTrue);

      // Unserviceable PIN codes (rural / outside dark store hubs)
      expect(PincodeValidator.isServiceable('999999'), isFalse);
      expect(PincodeValidator.isServiceable('190001'), isFalse);
      expect(PincodeValidator.isServiceable('795001'), isFalse);
    });

    test('PincodeValidator validate() returns rich validation details', () {
      final validResult = PincodeValidator.validate('500081');
      expect(validResult.isValidFormat, isTrue);
      expect(validResult.isServiceable, isTrue);
      expect(validResult.hubName, contains('Hyderabad'));
      expect(validResult.message, contains('serviceable'));

      final unserviceableResult = PincodeValidator.validate('999999');
      expect(unserviceableResult.isValidFormat, isTrue);
      expect(unserviceableResult.isServiceable, isFalse);
      expect(unserviceableResult.message, contains('unserviceable'));

      final invalidResult = PincodeValidator.validate('123');
      expect(invalidResult.isValidFormat, isFalse);
      expect(invalidResult.isServiceable, isFalse);
    });
  });

  group('CustomerAddress Model Unit Tests', () {
    const address = CustomerAddress(
      id: 'addr_101',
      addressType: AddressType.home,
      addressLine1: 'Flat 402, Lotus Residency',
      addressLine2: 'Road No. 12, Banjara Hills',
      landmark: 'Near Care Hospital',
      city: 'Hyderabad',
      state: 'Telangana',
      pinCode: '500034',
      contactName: 'Achyut Joshi',
      contactMobile: '9876543210',
      isDefault: true,
      latitude: 17.4156,
      longitude: 78.4357,
    );

    test('contains all 10 mandatory fields specified by Customer Address Management', () {
      expect(address.id, 'addr_101');
      expect(address.addressLine1, 'Flat 402, Lotus Residency');
      expect(address.addressLine2, 'Road No. 12, Banjara Hills');
      expect(address.landmark, 'Near Care Hospital');
      expect(address.city, 'Hyderabad');
      expect(address.state, 'Telangana');
      expect(address.pinCode, '500034');
      expect(address.contactName, 'Achyut Joshi');
      expect(address.contactMobile, '9876543210');
      expect(address.addressType, AddressType.home);
      expect(address.typeKey, 'HOME');
      expect(address.isDefault, isTrue);
      expect(address.isServiceable, isTrue);
    });

    test('JSON serialization roundtrip preserves all fields and GeoJSON structure', () {
      final json = address.toJson();
      expect(json['id'], 'addr_101');
      expect(json['label'], 'HOME');
      expect(json['pinCode'], '500034');
      expect(json['location']['type'], 'Point');
      expect(json['location']['coordinates'], [78.4357, 17.4156]);

      final restored = CustomerAddress.fromJson(json);
      expect(restored.id, address.id);
      expect(restored.addressLine1, address.addressLine1);
      expect(restored.addressLine2, address.addressLine2);
      expect(restored.landmark, address.landmark);
      expect(restored.city, address.city);
      expect(restored.state, address.state);
      expect(restored.pinCode, address.pinCode);
      expect(restored.contactName, address.contactName);
      expect(restored.contactMobile, address.contactMobile);
      expect(restored.addressType, AddressType.home);
      expect(restored.isDefault, isTrue);
      expect(restored.latitude, closeTo(17.4156, 0.0001));
      expect(restored.longitude, closeTo(78.4357, 0.0001));
    });

    test('copyWith properly modifies fields while preserving immutability', () {
      final modified = address.copyWith(
        addressType: AddressType.work,
        isDefault: false,
        pinCode: '560103',
      );
      expect(modified.addressType, AddressType.work);
      expect(modified.typeKey, 'WORK');
      expect(modified.isDefault, isFalse);
      expect(modified.pinCode, '560103');
      expect(modified.addressLine1, address.addressLine1);
    });
  });

  group('CustomerAddressProvider State & Operations Tests', () {
    late MockInMemoryAddressRepository repo;
    late CustomerAddressProvider provider;

    final addrHome = const CustomerAddress(
      id: 'addr_1',
      addressType: AddressType.home,
      addressLine1: 'Flat 402, Lotus Residency',
      city: 'Hyderabad',
      state: 'Telangana',
      pinCode: '500034',
      contactName: 'Achyut',
      contactMobile: '9876543210',
      isDefault: true,
    );

    final addrWork = const CustomerAddress(
      id: 'addr_2',
      addressType: AddressType.work,
      addressLine1: 'Building 9, Mindspace IT Park',
      city: 'Hyderabad',
      state: 'Telangana',
      pinCode: '500081',
      contactName: 'Achyut',
      contactMobile: '9876543210',
      isDefault: false,
    );

    final addrOther = const CustomerAddress(
      id: 'addr_3',
      addressType: AddressType.other,
      addressLine1: 'House 18, Jubilee Hills',
      city: 'Hyderabad',
      state: 'Telangana',
      pinCode: '500033',
      contactName: 'Achyut',
      contactMobile: '9876543210',
      isDefault: false,
    );

    setUp(() {
      repo = MockInMemoryAddressRepository([addrHome, addrWork, addrOther]);
      provider = CustomerAddressProvider(repo);
    });

    test('initializes with multiple addresses (HOME, WORK, OTHER)', () {
      expect(provider.addresses.length, 3);
      expect(provider.filterByType(AddressType.home).length, 1);
      expect(provider.filterByType(AddressType.work).length, 1);
      expect(provider.filterByType(AddressType.other).length, 1);
      expect(provider.defaultAddress?.id, 'addr_1');
    });

    test('addAddress adds a new address and notifies listeners', () async {
      final newAddr = const CustomerAddress(
        id: 'addr_4',
        addressType: AddressType.work,
        addressLine1: 'Cyber Towers 5th Floor',
        city: 'Hyderabad',
        state: 'Telangana',
        pinCode: '500081',
        contactName: 'Achyut',
        contactMobile: '9876543210',
      );

      final added = await provider.addAddress(newAddr);
      expect(added, isNotNull);
      expect(provider.addresses.length, 4);
      expect(provider.addresses.any((a) => a.id == 'addr_4'), isTrue);
    });

    test('deleteAddress removes the address from the list', () async {
      await provider.deleteAddress('addr_2');
      expect(provider.addresses.length, 2);
      expect(provider.addresses.any((a) => a.id == 'addr_2'), isFalse);
    });

    test('setDefault updates default address flag correctly', () async {
      await provider.setDefault('addr_2');
      final updated = provider.addresses.firstWhere((a) => a.id == 'addr_2');
      expect(updated.isDefault, isTrue);
      expect(provider.defaultAddress?.id, 'addr_2');
    });

    test('validateForOrderPlacement blocks order placement for unserviceable PIN', () {
      final unserviceableAddress = const CustomerAddress(
        id: 'addr_unserviceable',
        addressType: AddressType.other,
        addressLine1: 'Remote Village Road',
        city: 'Remote City',
        state: 'State',
        pinCode: '999999',
        contactName: 'Guest',
        contactMobile: '9876543210',
      );

      final error = provider.validateForOrderPlacement(unserviceableAddress);
      expect(error, isNotNull);
      expect(error, contains('not available for PIN code 999999'));

      // Serviceable address returns null (allowed)
      final allowed = provider.validateForOrderPlacement(addrHome);
      expect(allowed, isNull);
    });
  });

  group('CustomerAddressManagementScreen Widget Tests', () {
    testWidgets('renders all address types (HOME, WORK, OTHER) and filter chips', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final addrHome = const CustomerAddress(
        id: 'addr_home_1',
        addressType: AddressType.home,
        addressLine1: 'Flat 402, Lotus Heights',
        addressLine2: 'Road No. 12',
        city: 'Hyderabad',
        state: 'Telangana',
        pinCode: '500034',
        contactName: 'Achyut Joshi',
        contactMobile: '9876543210',
        isDefault: true,
      );

      final addrWork = const CustomerAddress(
        id: 'addr_work_1',
        addressType: AddressType.work,
        addressLine1: 'Building 9, Mindspace IT Park',
        city: 'Hyderabad',
        state: 'Telangana',
        pinCode: '500081',
        contactName: 'Achyut Joshi',
        contactMobile: '9876543210',
        isDefault: false,
      );

      final addrOther = const CustomerAddress(
        id: 'addr_other_1',
        addressType: AddressType.other,
        addressLine1: 'House 18, Jubilee Hills',
        city: 'Hyderabad',
        state: 'Telangana',
        pinCode: '500033',
        contactName: 'Dr. Ramesh Joshi',
        contactMobile: '9848012345',
        isDefault: false,
      );

      final repo = MockInMemoryAddressRepository([addrHome, addrWork, addrOther]);
      final provider = CustomerAddressProvider(repo);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<CustomerAddressProvider>.value(
            value: provider,
            child: const CustomerAddressManagementScreen(
              userName: 'Achyut Joshi',
              userPhone: '9876543210',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify title & info header
      expect(find.text('Customer Address Management'), findsOneWidget);
      expect(find.text('Verified Doorstep Delivery'), findsOneWidget);

      // Verify filter chips exist
      expect(find.text('All (3)'), findsOneWidget);
      expect(find.text('HOME (1)'), findsOneWidget);
      expect(find.text('WORK (1)'), findsOneWidget);
      expect(find.text('OTHER (1)'), findsOneWidget);

      // Verify address cards are rendered
      expect(find.text('Flat 402, Lotus Heights'), findsOneWidget);
      expect(find.text('Building 9, Mindspace IT Park'), findsOneWidget);
      expect(find.text('House 18, Jubilee Hills'), findsOneWidget);

      // Verify default badge and serviceable indicators
      expect(find.text('DEFAULT'), findsOneWidget);
      expect(find.text('Serviceable'), findsNWidgets(3));

      // Test filtering by WORK
      await tester.tap(find.text('WORK (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Building 9, Mindspace IT Park'), findsOneWidget);
      expect(find.text('Flat 402, Lotus Heights'), findsNothing);
    });
  });

  group('Order Review PIN Code Serviceability Enforcement Tests', () {
    testWidgets('unserviceable PIN code blocks order authorization and shows warning', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final unserviceableAddr = const CustomerAddress(
        id: 'addr_bad',
        addressType: AddressType.home,
        addressLine1: 'Plot 55, Outskirts Village',
        city: 'Distant City',
        state: 'State',
        pinCode: '999999', // Unserviceable PIN code
        contactName: 'Test User',
        contactMobile: '9876543210',
        isDefault: true,
      );

      final repo = MockInMemoryAddressRepository([unserviceableAddr]);
      final addressProvider = CustomerAddressProvider(repo);
      final profileNotifier = ProfileNotifier();
      profileNotifier.setAddress('Plot 55, Distant City - 999999');

      final cartNotifier = CartNotifier()
        ..add(
          CartItem(
            id: 'med_1',
            name: 'Paracetamol',
            price: 50.0,
            quantity: 2,
            pack: '10 tablets',
          ),
        );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CustomerAddressProvider>.value(value: addressProvider),
            ChangeNotifierProvider<ProfileNotifier>.value(value: profileNotifier),
            ChangeNotifierProvider<CartNotifier>.value(value: cartNotifier),
          ],
          child: const MaterialApp(
            home: OrderReview(amount: 100.0, method: 'UPI'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify unserviceable PIN banner is displayed
      expect(find.text('Unserviceable PIN'), findsOneWidget);
      expect(find.textContaining('PIN code 999999 is currently unserviceable'), findsOneWidget);
      expect(find.text('Address Unserviceable'), findsOneWidget);

      // Tap the button - should trigger blocking dialog
      await tester.tap(find.text('Address Unserviceable'));
      await tester.pumpAndSettle();

      // Blocking dialog appears
      expect(find.text('Unserviceable Address'), findsOneWidget);
      expect(find.textContaining('Delivery is not available at PIN code 999999'), findsOneWidget);
      expect(find.text('Change Address'), findsOneWidget);
    });
  });
}

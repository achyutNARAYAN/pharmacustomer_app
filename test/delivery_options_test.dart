import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pharmacustomer_app/core/providers/cart_notifier.dart';
import 'package:pharmacustomer_app/core/providers/profile_notifier.dart';
import 'package:pharmacustomer_app/features/cart/address.dart';
import 'package:pharmacustomer_app/features/cart/delivery_options.dart';

Widget _buildDeliveryOptionsApp({AddressModel? selectedAddress}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ProfileNotifier()),
      ChangeNotifierProvider(create: (_) => CartNotifier()),
    ],
    child: MaterialApp(
      home: DeliveryOptions(selectedAddress: selectedAddress),
    ),
  );
}

void main() {
  testWidgets('DeliveryOptions displays customer delivery location from selected address', (tester) async {
    const address = AddressModel(
      id: 'addr_test',
      label: 'Home',
      addressLine1: 'Flat 101, Green Valley',
      addressLine2: 'Road 5, Jubilee Hills',
      landmark: 'Opp City Hospital',
      city: 'Hyderabad',
      state: 'Telangana',
      pincode: '500033',
      contactName: 'Rahul',
      contactMobile: '9988776655',
    );

    await tester.pumpWidget(_buildDeliveryOptionsApp(selectedAddress: address));
    await tester.pumpAndSettle();

    expect(find.text('Delivery Options'), findsOneWidget);
    expect(find.text('Delivering to: Home'), findsOneWidget);
    expect(find.textContaining('Flat 101, Green Valley'), findsOneWidget);
    expect(find.textContaining('Rahul • 9988776655'), findsOneWidget);
    expect(find.text('Change'), findsOneWidget);
  });
}


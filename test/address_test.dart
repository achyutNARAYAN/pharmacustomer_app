import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pharmacustomer_app/core/providers/profile_notifier.dart';
import 'package:pharmacustomer_app/features/cart/address.dart';

Widget _buildAddressTestApp() {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ProfileNotifier()),
    ],
    child: const MaterialApp(home: Address()),
  );
}

void main() {
  testWidgets('address selection updates the delivery summary', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildAddressTestApp());
    await tester.pumpAndSettle();

    expect(find.text('Select Delivery Address'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Parents’ Home'), findsOneWidget);
    await tester.tap(find.text('Work / Office'));
    await tester.pump();

    expect(find.text('Delivering to: Work / Office'), findsOneWidget);
  });

  testWidgets('saving an address closes its editor without stale controllers', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildAddressTestApp());
    await tester.tap(find.text('Add new'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Clinic');
    await tester.enterText(find.byType(TextField).at(1), '12 Health Street');
    await tester.tap(find.text('Save address'));
    await tester.pumpAndSettle();

    expect(find.text('Clinic'), findsOneWidget);
    expect(find.text('Delivering to: Clinic'), findsOneWidget);
  });

  testWidgets('editing an address uses the same safe dialog close path', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildAddressTestApp());
    await tester.tap(find.byTooltip('Edit Home address'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'My Home');
    await tester.tap(find.text('Save address'));
    await tester.pumpAndSettle();

    expect(find.text('My Home'), findsOneWidget);
    expect(find.text('Delivering to: My Home'), findsOneWidget);
  });
}

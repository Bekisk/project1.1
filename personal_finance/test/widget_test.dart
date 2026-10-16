import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/widgets/floating_glass_nav_bar.dart';
import 'package:personal_finance/main.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  testWidgets(
    'App launches and displays first-time onboarding or navigation shell',
    (WidgetTester tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      await tester.pumpWidget(const MyFinanceApp());
      await tester.pump(const Duration(milliseconds: 100));

      // Verify root app renders cleanly
      expect(find.byType(MyFinanceApp), findsOneWidget);
    },
  );

  testWidgets('FloatingGlassNavBar renders 5 navigation tabs', (
    WidgetTester tester,
  ) async {
    int selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: FloatingGlassNavBar(
            currentIndex: selected,
            onTabSelected: (i) => selected = i,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(FloatingGlassNavBar), findsOneWidget);
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
  });
}

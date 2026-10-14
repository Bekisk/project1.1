import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/widgets/fintech_card.dart';
import 'package:personal_finance/features/settings/providers/app_settings_provider.dart';
import 'package:provider/provider.dart';

Widget _buildAboutCardUnderTest(BuildContext context, AppSettingsProvider settingsProvider) {
  return FintechCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.shield_rounded, size: 26),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Finance Personal Manager',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Version 1.0.0+1 • Offline-first SQLite Architecture',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton(
              onPressed: () {
                showLicensePage(
                  context: context,
                  applicationName: 'My Finance',
                  applicationVersion: '1.0.0+1',
                );
              },
              child: const Text('Open Source Licenses'),
            ),
            TextButton(
              onPressed: () {
                settingsProvider.resetPreferencesToDefaults();
              },
              child: const Text('Reset Preferences', style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ],
    ),
  );
}

void main() {
  group('Responsive Layout & Overflow Regression Tests', () {
    testWidgets('About My Finance card renders without overflow on narrow width (320px)', (tester) async {
      final settingsProvider = AppSettingsProvider();

      // Configure a very narrow screen (e.g., small phones / 320px logical width)
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: ChangeNotifierProvider<AppSettingsProvider>.value(
                  value: settingsProvider,
                  child: Builder(
                    builder: (context) => _buildAboutCardUnderTest(context, settingsProvider),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Verify that both action buttons are rendered and visible
      expect(find.text('Open Source Licenses'), findsOneWidget);
      expect(find.text('Reset Preferences'), findsOneWidget);

      // Verify no exception / overflow was logged
      expect(tester.takeException(), isNull);
    });

    testWidgets('About My Finance card renders on standard phone width (390px)', (tester) async {
      final settingsProvider = AppSettingsProvider();

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 390,
                child: ChangeNotifierProvider<AppSettingsProvider>.value(
                  value: settingsProvider,
                  child: Builder(
                    builder: (context) => _buildAboutCardUnderTest(context, settingsProvider),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Open Source Licenses'), findsOneWidget);
      expect(find.text('Reset Preferences'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('About My Finance card adapts to 1.5x accessibility text scaling without overflow', (tester) async {
      final settingsProvider = AppSettingsProvider();

      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 360,
                  child: ChangeNotifierProvider<AppSettingsProvider>.value(
                    value: settingsProvider,
                    child: Builder(
                      builder: (context) => _buildAboutCardUnderTest(context, settingsProvider),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Open Source Licenses'), findsOneWidget);
      expect(find.text('Reset Preferences'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

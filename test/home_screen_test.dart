import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sarv_authenticator/core/totp.dart';
import 'package:sarv_authenticator/data/account.dart';
import 'package:sarv_authenticator/data/account_store.dart';
import 'package:sarv_authenticator/data/theme_controller.dart';
import 'package:sarv_authenticator/ui/home_screen.dart';
import 'package:sarv_authenticator/ui/scan_screen.dart';
import 'package:sarv_authenticator/ui/settings_screen.dart';
import 'package:sarv_authenticator/ui/theme.dart';

import 'support/settings_harness.dart';

const _github = Account(
  id: 'gh',
  issuer: 'GitHub',
  account: 'ankur.d@sarv.com',
  secretBase32: 'JBSWY3DPEHPK3PXP',
);
const _aws = Account(
  id: 'aws',
  issuer: 'AWS',
  account: 'root',
  secretBase32: 'GEZDGNBVGY3TQOJQ',
  digits: 8,
);

/// Pumps the real home screen over an in-memory store holding [accounts].
Future<AccountStore> _openHome(
  WidgetTester tester, {
  List<Account> accounts = const [_github, _aws],
}) async {
  // Tall enough that the whole setup-key form fits without scrolling.
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  FlutterSecureStorage.setMockInitialValues({});
  final store = AccountStore();
  for (final account in accounts) {
    await store.add(account);
  }
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(AppTokens.light, Brightness.light),
      home: HomeScreen(store: store, lock: FakeLock(), theme: ThemeController()),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

Future<void> _openAddSheet(WidgetTester tester, String option) async {
  await tester.tap(find.text('Add'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('explains what to do when there are no accounts', (tester) async {
    await _openHome(tester, accounts: const []);
    expect(find.text('No accounts yet'), findsOneWidget);
  });

  testWidgets('lists each account with its live code', (tester) async {
    await _openHome(tester);
    expect(find.text('GitHub'), findsOneWidget);
    expect(find.text('AWS'), findsOneWidget);
    // Six-digit codes are grouped "123 456"; eight-digit codes are not.
    expect(find.textContaining(RegExp(r'^\d{3} \d{3}$')), findsOneWidget);
    expect(find.textContaining(RegExp(r'^\d{8}$')), findsOneWidget);

    // The codes and countdown keep ticking.
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('GitHub'), findsOneWidget);
  });

  testWidgets('tapping a row copies its code', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
    await _openHome(tester, accounts: const [_github]);

    await tester.tap(find.text('GitHub'));
    await tester.pump();

    final shown = tester
        .widget<Text>(find.textContaining(RegExp(r'^\d{3} \d{3}$')))
        .data!;
    expect(copied, [shown.replaceAll(' ', '')]);
    expect(find.text('Code copied'), findsOneWidget);
  });

  testWidgets('search filters by issuer or account and can be closed',
      (tester) async {
    await _openHome(tester);

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    expect(find.text('Add'), findsNothing);

    await tester.enterText(find.byType(TextField), 'root');
    await tester.pumpAndSettle();
    expect(find.text('AWS'), findsOneWidget);
    expect(find.text('GitHub'), findsNothing);

    await tester.enterText(find.byType(TextField), 'nothing like this');
    await tester.pumpAndSettle();
    expect(find.text('No accounts match your search.'), findsOneWidget);

    await tester.tap(find.byTooltip('Close search'));
    await tester.pumpAndSettle();
    expect(find.text('GitHub'), findsOneWidget);
    expect(find.text('AWS'), findsOneWidget);
  });

  testWidgets('the long-press menu renames an account', (tester) async {
    final store = await _openHome(tester);

    await tester.longPress(find.text('GitHub'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Issuer'), ' GitLab ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(store.accounts.first.issuer, 'GitLab');
    expect(store.accounts.first.secretBase32, _github.secretBase32);
    expect(find.text('GitLab'), findsOneWidget);
  });

  testWidgets('cancelling a rename changes nothing', (tester) async {
    final store = await _openHome(tester);

    await tester.longPress(find.text('GitHub'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(store.accounts.first.issuer, 'GitHub');
  });

  testWidgets('the long-press menu removes an account after confirming',
      (tester) async {
    final store = await _openHome(tester);

    await tester.longPress(find.text('GitHub'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(find.text('Remove account?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(store.accounts, hasLength(2));

    await tester.longPress(find.text('GitHub'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(store.accounts.map((a) => a.issuer), ['AWS']);
  });

  testWidgets('swiping right removes an account after confirming',
      (tester) async {
    final store = await _openHome(tester);

    await tester.drag(find.text('GitHub'), const Offset(600, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(store.accounts.map((a) => a.issuer), ['AWS']);
    expect(find.text('GitHub'), findsNothing);
  });

  testWidgets('swiping left opens the editor and keeps the row',
      (tester) async {
    final store = await _openHome(tester);

    await tester.drag(find.text('GitHub'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Rename account'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(store.accounts, hasLength(2));
    expect(find.text('GitHub'), findsOneWidget);
  });

  testWidgets('the settings button opens Settings', (tester) async {
    await _openHome(tester);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  group('adding with a setup key', () {
    testWidgets('saves the account with the chosen parameters', (tester) async {
      final store = await _openHome(tester, accounts: const []);
      await _openAddSheet(tester, 'Enter a setup key');

      await tester.enterText(find.widgetWithText(TextField, 'Issuer'), ' Acme ');
      await tester.enterText(find.widgetWithText(TextField, 'Account'), 'bob');
      await tester.enterText(
        find.widgetWithText(TextField, 'Setup key (Base32)'),
        'jbsw y3dp ehpk 3pxp',
      );
      await tester.tap(find.text('SHA256'));
      await tester.tap(find.text('8'));
      await tester.tap(find.text('60'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add account'));
      await tester.pumpAndSettle();

      final added = store.accounts.single;
      expect(added.issuer, 'Acme');
      expect(added.account, 'bob');
      expect(added.secretBase32, 'JBSWY3DPEHPK3PXP');
      expect(added.algorithm, OtpAlgorithm.sha256);
      expect(added.digits, 8);
      expect(added.period, 60);
    });

    testWidgets('asks for a key, then rejects one that is too short',
        (tester) async {
      final store = await _openHome(tester, accounts: const []);
      await _openAddSheet(tester, 'Enter a setup key');

      await tester.tap(find.text('Add account'));
      await tester.pumpAndSettle();
      expect(find.text('Enter the setup key'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Setup key (Base32)'),
        'A',
      );
      await tester.tap(find.text('Add account'));
      await tester.pumpAndSettle();
      expect(find.text('Not a valid Base32 setup key'), findsOneWidget);
      expect(store.accounts, isEmpty);
    });

    testWidgets('backing out adds nothing', (tester) async {
      final store = await _openHome(tester, accounts: const []);
      await _openAddSheet(tester, 'Enter a setup key');

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(store.accounts, isEmpty);
    });
  });

  group('adding by scanning', () {
    MobileScanner scanner(WidgetTester tester) =>
        tester.widget<MobileScanner>(find.byType(MobileScanner));

    void detect(WidgetTester tester, List<Barcode> barcodes) =>
        scanner(tester).onDetect!(BarcodeCapture(barcodes: barcodes));

    testWidgets('saves the first otpauth QR it sees', (tester) async {
      final store = await _openHome(tester, accounts: const []);
      await _openAddSheet(tester, 'Scan a QR code');
      expect(find.byType(ScanScreen), findsOneWidget);

      // Nothing usable yet: no barcode, no value, and a QR that isn't 2FA.
      detect(tester, const []);
      detect(tester, const [Barcode()]);
      detect(tester, const [Barcode(rawValue: 'https://sarv.com')]);
      await tester.pumpAndSettle();
      expect(find.byType(ScanScreen), findsOneWidget);

      detect(tester, const [
        Barcode(rawValue: 'otpauth://totp/Acme:bob?secret=JBSWY3DPEHPK3PXP'),
      ]);
      // A second read of the same frame must not pop twice.
      detect(tester, const [
        Barcode(rawValue: 'otpauth://totp/Acme:eve?secret=JBSWY3DPEHPK3PXP'),
      ]);
      await tester.pumpAndSettle();

      expect(find.byType(ScanScreen), findsNothing);
      expect(store.accounts.single.account, 'bob');
    });

    testWidgets('explains a denied camera and goes back', (tester) async {
      await _openHome(tester, accounts: const []);
      await _openAddSheet(tester, 'Scan a QR code');

      final errorBuilder = scanner(tester).errorBuilder!;
      // A fresh key so the old navigator (still showing the scanner) is dropped.
      await tester.pumpWidget(
        MaterialApp(
          key: UniqueKey(),
          theme: buildAppTheme(AppTokens.light, Brightness.light),
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  Expanded(
                    child: errorBuilder(
                      context,
                      const MobileScannerException(
                        errorCode: MobileScannerErrorCode.permissionDenied,
                      ),
                    ),
                  ),
                  Expanded(
                    child: errorBuilder(
                      context,
                      const MobileScannerException(
                        errorCode: MobileScannerErrorCode.genericError,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.textContaining('Camera access is off'), findsOneWidget);
      expect(find.textContaining('The camera could not start'), findsOneWidget);

      await tester.tap(find.text('Go back').first);
      await tester.pumpAndSettle();
    });

    testWidgets('draws the reticle over the live preview', (tester) async {
      await _openHome(tester, accounts: const []);
      await _openAddSheet(tester, 'Scan a QR code');

      final overlay = scanner(tester).overlayBuilder!;
      // A fresh key so the old navigator (still showing the scanner) is dropped.
      await tester.pumpWidget(
        MaterialApp(
          key: UniqueKey(),
          theme: buildAppTheme(AppTokens.light, Brightness.light),
          home: Builder(
            builder: (context) =>
                overlay(context, const BoxConstraints.tightFor(width: 400, height: 400)),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(Container).last),
        const Size(240, 240),
      );
    });
  });
}

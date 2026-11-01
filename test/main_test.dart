import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarv_authenticator/main.dart' as app;
import 'package:sarv_authenticator/ui/home_screen.dart';

const _secureDisplay = MethodChannel('com.sarv.otp/secure_display');

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('starts on the codes list', (tester) async {
    await app.main();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('on iOS, protects the display and explains blank screenshots',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureDisplay, (call) async {
      calls.add(call);
      return null;
    });

    await app.main();
    await tester.pumpAndSettle();
    expect(calls.single.method, 'enable');
    expect((calls.single.arguments as Map)['cover'], isA<int>());

    // The native side reports a screenshot after iOS has taken it.
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      _secureDisplay.name,
      _secureDisplay.codec.encodeMethodCall(const MethodCall('screenshotTaken')),
      (_) {},
    );
    await tester.pump();
    expect(
      find.text('Screenshots are blocked to protect your codes'),
      findsOneWidget,
    );
    debugDefaultTargetPlatformOverride = null;
  });
}

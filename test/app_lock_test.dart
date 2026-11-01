import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:sarv_authenticator/data/app_lock.dart';

import 'support/throwing_storage.dart';

/// local_auth with scripted answers. A null result makes the call throw, the
/// way the plugin does when the platform has no biometric support.
class _FakeAuth implements LocalAuthentication {
  _FakeAuth({this.supported = false, this.canCheck = false, this.result = true});

  final bool? supported;
  final bool canCheck;
  final bool? result;
  bool promptWasOpen = false;
  late final AppLock lock;

  static final _failure = PlatformException(code: 'NotAvailable');

  @override
  Future<bool> isDeviceSupported() async => supported ?? (throw _failure);

  @override
  Future<bool> get canCheckBiometrics async => canCheck;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<dynamic> authMessages = const [],
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async {
    promptWasOpen = lock.isPrompting;
    return result ?? (throw _failure);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AppLock _lockWith(_FakeAuth auth) => auth.lock = AppLock(auth: auth);

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  group('isAvailable', () {
    test('is true when the device supports a lock or has biometrics', () async {
      expect(await _lockWith(_FakeAuth(supported: true)).isAvailable, isTrue);
      expect(await _lockWith(_FakeAuth(canCheck: true)).isAvailable, isTrue);
      expect(await _lockWith(_FakeAuth()).isAvailable, isFalse);
    });

    test('is false when the platform check fails', () async {
      expect(await _lockWith(_FakeAuth(supported: null)).isAvailable, isFalse);
    });
  });

  group('preferences', () {
    test('default to off and lock immediately', () async {
      final lock = _lockWith(_FakeAuth());
      expect(await lock.isEnabled(), isFalse);
      expect(await lock.autoLockDelay(), Duration.zero);
    });

    test('persist the switch and the auto-lock delay', () async {
      final lock = _lockWith(_FakeAuth());
      await lock.setEnabled(true);
      await lock.setAutoLockDelay(const Duration(seconds: 30));
      expect(await lock.isEnabled(), isTrue);
      expect(await lock.autoLockDelay(), const Duration(seconds: 30));
    });

    test('fall back to safe defaults when storage cannot be read', () async {
      final lock = AppLock(auth: _FakeAuth(), storage: const ThrowingStorage());
      expect(await lock.isEnabled(), isFalse);
      expect(await lock.autoLockDelay(), Duration.zero);
    });

    test('report a failed save to the caller', () async {
      final lock = AppLock(auth: _FakeAuth(), storage: const ThrowingStorage());
      expect(() => lock.setEnabled(true), throwsA(isA<PlatformException>()));
      expect(
        () => lock.setAutoLockDelay(Duration.zero),
        throwsA(isA<PlatformException>()),
      );
    });
  });

  group('authenticate', () {
    test('returns the prompt result and is prompting only meanwhile', () async {
      final auth = _FakeAuth();
      final lock = _lockWith(auth);
      expect(await lock.authenticate(), isTrue);
      expect(auth.promptWasOpen, isTrue);
      expect(lock.isPrompting, isFalse);
    });

    test('treats a failed prompt as not unlocked', () async {
      final lock = _lockWith(_FakeAuth(result: null));
      expect(await lock.authenticate(), isFalse);
      expect(lock.isPrompting, isFalse);
    });
  });
}

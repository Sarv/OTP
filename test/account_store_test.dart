import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarv_authenticator/data/account.dart';
import 'package:sarv_authenticator/data/account_store.dart';

import 'support/throwing_storage.dart';

Account _account(String issuer, {String secret = 'JBSWY3DPEHPK3PXP'}) =>
    Account(id: issuer, issuer: issuer, account: 'me', secretBase32: secret);

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('starts empty when nothing is stored', () async {
    final store = AccountStore();
    await store.load();
    expect(store.accounts, isEmpty);
  });

  test('persists adds so a fresh store loads them back', () async {
    await AccountStore().add(_account('GitHub'));
    final reloaded = AccountStore();
    await reloaded.load();
    expect(reloaded.accounts.single.issuer, 'GitHub');
  });

  test('removes, renames and reorders accounts', () async {
    final store = AccountStore();
    for (final issuer in ['A', 'B', 'C']) {
      await store.add(_account(issuer));
    }

    await store.remove('B');
    expect(store.accounts.map((a) => a.issuer), ['A', 'C']);

    await store.rename('A', issuer: 'Alpha', account: 'alice');
    expect(store.accounts.first.issuer, 'Alpha');
    expect(store.accounts.first.account, 'alice');

    await store.reorder(0, 1);
    expect(store.accounts.map((a) => a.issuer), ['C', 'Alpha']);
  });

  test('imports only accounts it does not already have', () async {
    final store = AccountStore();
    await store.add(_account('GitHub'));

    final added = await store.importAccounts([
      _account('GitHub').copyWith(),
      _account('AWS', secret: 'GEZDGNBVGY3TQOJQ'),
    ]);
    expect(added, 1);
    expect(store.accounts.map((a) => a.issuer), ['GitHub', 'AWS']);

    expect(await store.importAccounts([_account('AWS', secret: 'GEZDGNBVGY3TQOJQ')]), 0);
  });

  test('keeps an empty list when the stored data cannot be read', () async {
    final store = AccountStore(storage: const ThrowingStorage());
    await store.load();
    expect(store.accounts, isEmpty);
  });

  test('surfaces a failed write to the caller', () async {
    final store = AccountStore(storage: const ThrowingStorage());
    expect(() => store.add(_account('GitHub')), throwsA(anything));
  });
}

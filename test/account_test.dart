import 'package:flutter_test/flutter_test.dart';
import 'package:sarv_authenticator/core/otpauth_uri.dart';
import 'package:sarv_authenticator/core/totp.dart';
import 'package:sarv_authenticator/data/account.dart';

void main() {
  const github = Account(
    id: 'gh',
    issuer: 'GitHub',
    account: 'ankur.d@sarv.com',
    secretBase32: 'JBSWY3DPEHPK3PXP',
    digits: 8,
    period: 60,
    algorithm: OtpAlgorithm.sha256,
  );

  group('initial', () {
    test('uses the issuer, then the account, then a placeholder', () {
      expect(github.initial, 'G');
      expect(github.copyWith(issuer: '').initial, 'A');
      expect(
        const Account(id: 'x', issuer: '', account: '', secretBase32: 'A')
            .initial,
        '?',
      );
    });
  });

  test('copyWith changes only the display text', () {
    final renamed = github.copyWith(issuer: 'GitHub Enterprise');
    expect(renamed.issuer, 'GitHub Enterprise');
    expect(renamed.account, github.account);
    expect(renamed.id, github.id);
    expect(renamed.secretBase32, github.secretBase32);
    expect(renamed.digits, 8);
    expect(renamed.period, 60);
    expect(renamed.algorithm, OtpAlgorithm.sha256);
    expect(github.copyWith(account: 'other').account, 'other');
  });

  test('create gives each account a fresh id', () {
    final first =
        Account.create(issuer: 'AWS', account: 'root', secretBase32: 'GEZDGNBV');
    expect(first.id, startsWith('AWS:root:'));
    expect(first.digits, 6);
    expect(first.period, 30);
    expect(first.algorithm, OtpAlgorithm.sha1);
  });

  test('fromOtpauth carries every parameter over', () {
    final account = Account.fromOtpauth(
      parseOtpauthUri(
        'otpauth://totp/Acme:bob?secret=JBSWY3DPEHPK3PXP&digits=8&period=60&algorithm=SHA512',
      ),
    );
    expect(account.issuer, 'Acme');
    expect(account.account, 'bob');
    expect(account.digits, 8);
    expect(account.period, 60);
    expect(account.algorithm, OtpAlgorithm.sha512);
  });

  group('JSON', () {
    test('round-trips a list of accounts', () {
      final restored = decodeAccounts(encodeAccounts([github]));
      expect(restored.single.toJson(), github.toJson());
    });

    test('fills defaults for fields an older version did not write', () {
      final account = Account.fromJson({'id': 'old', 'secret': 'JBSWY3DP'});
      expect(account.issuer, '');
      expect(account.account, '');
      expect(account.digits, 6);
      expect(account.period, 30);
      expect(account.algorithm, OtpAlgorithm.sha1);
    });

    test('falls back to SHA1 for an unknown algorithm', () {
      final account = Account.fromJson(
        {'id': 'x', 'secret': 'JBSWY3DP', 'algorithm': 'md5'},
      );
      expect(account.algorithm, OtpAlgorithm.sha1);
    });
  });
}

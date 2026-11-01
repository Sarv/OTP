import 'package:flutter_test/flutter_test.dart';
import 'package:sarv_authenticator/core/backup.dart';
import 'package:sarv_authenticator/data/account.dart';

void main() {
  final accounts = [
    const Account(
      id: '1',
      issuer: 'GitHub',
      account: 'ankur.d@sarv.com',
      secretBase32: 'JBSWY3DPEHPK3PXP',
    ),
    const Account(
      id: '2',
      issuer: 'AWS',
      account: 'root',
      secretBase32: 'GEZDGNBVGY3TQOJQ',
    ),
  ];

  group('encrypted backup', () {
    test('round-trips accounts with the correct passphrase', () async {
      final envelope = await encryptBackup(accounts, 'correct horse battery');
      final restored = await decryptBackup(envelope, 'correct horse battery');

      expect(restored.length, accounts.length);
      expect(restored[0].issuer, 'GitHub');
      expect(restored[0].secretBase32, 'JBSWY3DPEHPK3PXP');
      expect(restored[1].account, 'root');
    });

    test('produces different ciphertext each time (random salt/nonce)', () async {
      final a = await encryptBackup(accounts, 'pw');
      final b = await encryptBackup(accounts, 'pw');
      expect(a, isNot(equals(b)));
    });

    test('fails loudly on a wrong passphrase', () async {
      final envelope = await encryptBackup(accounts, 'right');
      expect(
        () => decryptBackup(envelope, 'wrong'),
        throwsA(isA<BackupDecryptException>()),
      );
    });

    test('rejects a non-backup file', () async {
      expect(
        () => decryptBackup('{"hello":"world"}', 'pw'),
        throwsA(isA<BackupDecryptException>()),
      );
    });

    test('rejects a file that is not JSON', () async {
      expect(
        () => decryptBackup('not json', 'pw'),
        throwsA(isA<BackupDecryptException>()),
      );
    });

    test('rejects a backup from an unsupported version', () async {
      expect(
        () => decryptBackup(
          '{"format":"sarv-authenticator-backup","version":99}',
          'pw',
        ),
        throwsA(
          isA<BackupDecryptException>()
              .having((e) => e.message, 'message', contains('99')),
        ),
      );
    });

    test('rejects a backup with missing fields', () async {
      expect(
        () => decryptBackup(
          '{"format":"sarv-authenticator-backup","version":1}',
          'pw',
        ),
        throwsA(isA<BackupDecryptException>()),
      );
    });

    test('refuses to encrypt without a passphrase', () async {
      expect(() => encryptBackup(accounts, ''), throwsArgumentError);
    });

    test('describes itself when printed', () {
      expect(
        const BackupDecryptException('bad').toString(),
        'BackupDecryptException: bad',
      );
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:sarv_authenticator/core/base32.dart';
import 'package:sarv_authenticator/core/otpauth_uri.dart';
import 'package:sarv_authenticator/core/totp.dart';

void main() {
  group('TOTP — RFC 6238 Appendix B test vectors', () {
    // RFC 6238 seed "12345678901234567890" (ASCII), Base32-encoded.
    final secret = base32Decode('GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ');

    String codeAt(int unixSeconds) => generateTotp(
          secret: secret,
          atUtc: DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000,
              isUtc: true,),
          digits: 8,
        );

    test('matches every published SHA1 vector', () {
      expect(codeAt(59), '94287082');
      expect(codeAt(1111111109), '07081804');
      expect(codeAt(1111111111), '14050471');
      expect(codeAt(1234567890), '89005924');
      expect(codeAt(2000000000), '69279037');
      expect(codeAt(20000000000), '65353130');
    });
  });

  group('TOTP — RFC 6238 Appendix B, SHA256 and SHA512', () {
    // The RFC uses a 32-byte seed for SHA256 and a 64-byte seed for SHA512.
    final seed256 = '12345678901234567890123456789012'.codeUnits;
    final seed512 =
        '1234567890123456789012345678901234567890123456789012345678901234'
            .codeUnits;

    String codeAt(List<int> secret, OtpAlgorithm algorithm, int unixSeconds) =>
        generateTotp(
          secret: secret,
          atUtc: DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000,
              isUtc: true,),
          digits: 8,
          algorithm: algorithm,
        );

    test('matches the published SHA256 vectors', () {
      expect(codeAt(seed256, OtpAlgorithm.sha256, 59), '46119246');
      expect(codeAt(seed256, OtpAlgorithm.sha256, 1111111109), '68084774');
      expect(codeAt(seed256, OtpAlgorithm.sha256, 20000000000), '77737706');
    });

    test('matches the published SHA512 vectors', () {
      expect(codeAt(seed512, OtpAlgorithm.sha512, 59), '90693936');
      expect(codeAt(seed512, OtpAlgorithm.sha512, 1111111109), '25091201');
      expect(codeAt(seed512, OtpAlgorithm.sha512, 20000000000), '47863826');
    });
  });

  group('secondsRemaining', () {
    DateTime at(int unixSeconds) =>
        DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000, isUtc: true);

    test('counts down to the end of the window', () {
      expect(secondsRemaining(atUtc: at(0)), 30);
      expect(secondsRemaining(atUtc: at(29)), 1);
      expect(secondsRemaining(atUtc: at(30)), 30);
      expect(secondsRemaining(atUtc: at(45), period: 60), 15);
    });
  });

  group('Base32', () {
    test('rejects characters outside the alphabet', () {
      expect(() => base32Decode('JBSW1'), throwsFormatException);
    });
  });

  group('HOTP — RFC 4226 Appendix D test vectors', () {
    final secret = base32Decode('GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ');

    test('matches the published 6-digit counter sequence', () {
      final expected = [
        '755224', '287082', '359152', '969429', '338314',
        '254676', '287922', '162583', '399871', '520489',
      ];
      for (var counter = 0; counter < expected.length; counter++) {
        expect(generateHotp(secret: secret, counter: counter), expected[counter]);
      }
    });
  });

  group('otpauth URI parsing', () {
    test('extracts issuer, account and params', () {
      final data = parseOtpauthUri(
        'otpauth://totp/GitHub:ankur.d@sarv.com?secret=JBSWY3DPEHPK3PXP&issuer=GitHub&digits=6&period=30&algorithm=SHA1',
      );
      expect(data.issuer, 'GitHub');
      expect(data.account, 'ankur.d@sarv.com');
      expect(data.secretBase32, 'JBSWY3DPEHPK3PXP');
      expect(data.digits, 6);
      expect(data.period, 30);
      expect(data.algorithm, OtpAlgorithm.sha1);
    });

    test('throws when the secret is missing', () {
      expect(
        () => parseOtpauthUri('otpauth://totp/Acme:bob?issuer=Acme'),
        throwsFormatException,
      );
    });

    test('rejects a URI that is not otpauth', () {
      expect(
        () => parseOtpauthUri('https://example.com/?secret=JBSWY3DPEHPK3PXP'),
        throwsFormatException,
      );
    });

    test('takes the issuer from the label when there is no issuer param', () {
      final data =
          parseOtpauthUri('otpauth://totp/Acme:bob?secret=JBSWY3DPEHPK3PXP');
      expect(data.issuer, 'Acme');
      expect(data.account, 'bob');
    });

    test('leaves the issuer empty for a bare account label', () {
      final data = parseOtpauthUri('otpauth://totp/bob?secret=JBSWY3DPEHPK3PXP');
      expect(data.issuer, '');
      expect(data.account, 'bob');
    });
  });
}

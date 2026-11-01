import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sarv_authenticator/core/backup.dart';
import 'package:sarv_authenticator/data/account.dart';
import 'package:sarv_authenticator/data/backup_service.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

class _FakePaths extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _FakePaths(this.temp);
  final Directory temp;

  @override
  Future<String?> getTemporaryPath() async => temp.path;
}

class _FakeShare extends SharePlatform with MockPlatformInterfaceMixin {
  List<XFile>? files;
  Rect? origin;

  @override
  Future<ShareResult> shareXFiles(
    List<XFile> files, {
    String? subject,
    String? text,
    Rect? sharePositionOrigin,
    List<String>? fileNameOverrides,
  }) async {
    this.files = files;
    origin = sharePositionOrigin;
    return const ShareResult('done', ShareResultStatus.success);
  }
}

class _FakePicker extends FilePicker with MockPlatformInterfaceMixin {
  _FakePicker(this.result);
  final FilePickerResult? result;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async =>
      result;
}

void main() {
  const service = BackupService();
  const accounts = [
    Account(id: '1', issuer: 'GitHub', account: 'me', secretBase32: 'JBSWY3DP'),
  ];
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('sarv-otp-backup-test');
    PathProviderPlatform.instance = _FakePaths(temp);
  });
  tearDown(() => temp.deleteSync(recursive: true));

  test('writes an encrypted backup that decrypts back to the accounts', () async {
    final path = await service.writeEncryptedBackup(
      accounts: accounts,
      passphrase: 'pw',
    );
    expect(path, startsWith('${temp.path}/sarv-otp-'));
    expect(path, endsWith('.sauthbackup'));
    expect(path, isNot(contains(':')));

    final restored = await service.decrypt(
      contents: File(path).readAsStringSync(),
      passphrase: 'pw',
    );
    expect(restored.single.issuer, 'GitHub');
  });

  test('shares the file anchored to the control that opened the sheet', () async {
    final share = _FakeShare();
    SharePlatform.instance = share;
    const origin = Rect.fromLTWH(10, 20, 30, 40);

    await service.share('${temp.path}/backup.sauthbackup', origin: origin);

    expect(share.files!.single.path, '${temp.path}/backup.sauthbackup');
    expect(share.origin, origin);
  });

  group('pickBackup', () {
    test('returns null when the picker is cancelled', () async {
      FilePicker.platform = _FakePicker(null);
      expect(await service.pickBackup(), isNull);
      FilePicker.platform = _FakePicker(const FilePickerResult([]));
      expect(await service.pickBackup(), isNull);
    });

    test('reads the picked file from memory', () async {
      FilePicker.platform = _FakePicker(
        FilePickerResult([
          PlatformFile(name: 'a', size: 2, bytes: '{}'.codeUnits.toUint8List()),
        ]),
      );
      expect(await service.pickBackup(), '{}');
    });

    test('reads the picked file from disk when no bytes come back', () async {
      final file = File('${temp.path}/picked.sauthbackup')..writeAsStringSync('[]');
      FilePicker.platform = _FakePicker(
        FilePickerResult([PlatformFile(name: 'p', size: 2, path: file.path)]),
      );
      expect(await service.pickBackup(), '[]');
    });

    test('fails when the picked file cannot be read', () async {
      FilePicker.platform = _FakePicker(
        FilePickerResult([PlatformFile(name: 'x', size: 0)]),
      );
      expect(service.pickBackup, throwsA(isA<BackupDecryptException>()));
    });
  });
}

extension on List<int> {
  Uint8List toUint8List() => Uint8List.fromList(this);
}

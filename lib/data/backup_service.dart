import 'dart:io';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/backup.dart';
import 'account.dart';

/// File-level glue for encrypted backups: turns the [encryptBackup] /
/// [decryptBackup] core into "write and share a file" and "pick and decrypt a
/// file" operations. All disk / platform I/O lives here, at the edge.
///
/// The steps are separate so the UI can show a loader around the slow part —
/// the PBKDF2 key derivation takes a couple of seconds — without the loader
/// covering the share sheet or the file picker.
class BackupService {
  const BackupService();

  static const _extension = 'sauthbackup';

  /// Encrypts [accounts] with [passphrase] and writes the envelope to a
  /// timestamped file. Returns the file's path.
  Future<String> writeEncryptedBackup({
    required List<Account> accounts,
    required String passphrase,
  }) async {
    final envelope = await encryptBackup(accounts, passphrase);

    // UTC timestamp in the filename so backups sort correctly everywhere.
    final stamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/sarv-otp-$stamp.$_extension');
    await file.writeAsString(envelope, flush: true);
    return file.path;
  }

  /// Opens the system share sheet for the backup file at [path] so the user
  /// can save or send it. [origin] is the global rect of the control that
  /// opened it: iOS anchors the sheet there and rejects the share without it.
  /// Returns false only when the user dismissed the sheet without choosing a
  /// destination.
  Future<bool> share(String path, {required Rect origin}) async {
    final result = await Share.shareXFiles(
      [XFile(path, mimeType: 'application/json')],
      subject: 'Sarv OTP backup',
      sharePositionOrigin: origin,
    );
    return result.status != ShareResultStatus.dismissed;
  }

  /// Lets the user pick a backup file and returns its contents, or null if the
  /// user cancels the picker.
  Future<String?> pickBackup() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return null;

    final picked = result.files.single;
    final bytes = picked.bytes ??
        (picked.path != null ? await File(picked.path!).readAsBytes() : null);
    if (bytes == null) {
      throw const BackupDecryptException('Could not read the selected file');
    }
    return String.fromCharCodes(bytes);
  }

  /// Decrypts a backup's [contents] with [passphrase].
  Future<List<Account>> decrypt({
    required String contents,
    required String passphrase,
  }) =>
      decryptBackup(contents, passphrase);
}

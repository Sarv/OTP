import 'package:flutter/material.dart';
import '../core/backup.dart';
import '../data/account_store.dart';
import '../data/app_lock.dart';
import '../data/backup_service.dart';
import '../data/theme_controller.dart';
import 'passphrase_dialog.dart';
import 'progress_dialog.dart';
import 'theme.dart';

/// App settings: the biometric app-lock toggle and encrypted backup/restore,
/// laid out as Sarv cards. Rows are disabled (with an explanation) when the
/// device can't support them.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.lock,
    required this.store,
    required this.theme,
    this.backup = const BackupService(),
  });

  final AppLock lock;
  final AccountStore store;
  final ThemeController theme;
  final BackupService backup;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loading = true;
  bool _available = false;
  bool _enabled = false;
  bool _saving = false;
  int _delaySeconds = 0;
  // Locates the export row on screen; the iOS share sheet is anchored to it.
  final _exportRowKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final available = await widget.lock.isAvailable;
    final enabled = await widget.lock.isEnabled();
    final delay = await widget.lock.autoLockDelay();
    if (!mounted) return;
    setState(() {
      _available = available;
      _enabled = enabled && available;
      _delaySeconds = delay.inSeconds;
      _loading = false;
    });
  }

  Future<void> _setDelay(int seconds) async {
    setState(() => _delaySeconds = seconds);
    await widget.lock.setAutoLockDelay(Duration(seconds: seconds));
  }

  Future<void> _toggle(bool value) async {
    // Authenticate both ways: turning the lock ON proves the credential works,
    // so the user can't lock themselves out; turning it OFF proves it is the
    // owner, so someone holding an unlocked phone can't remove the protection.
    setState(() => _saving = true);
    final ok = await widget.lock.authenticate();
    if (!ok) {
      if (mounted) setState(() => _saving = false);
      return;
    }
    await widget.lock.setEnabled(value);
    if (!mounted) return;
    setState(() {
      _enabled = value;
      _saving = false;
    });
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _export() async {
    if (widget.store.accounts.isEmpty) {
      _toast('No accounts to export yet');
      return;
    }
    final passphrase = await showPassphraseDialog(
      context,
      title: 'Encrypt backup',
      message: 'Choose a passphrase. You will need it to restore — it is never '
          'stored and cannot be recovered.',
      confirm: true,
    );
    if (passphrase == null || !mounted) return;
    try {
      // The loader covers encrypting and writing the file, then closes before
      // the share sheet opens (sharing waits until the sheet is dismissed).
      final path = await runWithProgress(
        context,
        message: 'Encrypting backup…',
        task: () => widget.backup.writeEncryptedBackup(
          accounts: widget.store.accounts,
          passphrase: passphrase,
        ),
      );
      final shared =
          await widget.backup.share(path, origin: _globalRect(_exportRowKey));
      // Without this, returning from Drive or Files left Settings exactly as it
      // was, with no sign the export had worked.
      if (shared) _toast('Backup exported. Keep your passphrase safe.');
    } catch (error) {
      _toast('Export failed: $error');
    }
  }

  Future<void> _import() async {
    final passphrase = await showPassphraseDialog(
      context,
      title: 'Restore backup',
      message: 'Enter the passphrase for the backup file you select.',
      confirm: false,
    );
    if (passphrase == null) return;
    try {
      final contents = await widget.backup.pickBackup();
      if (contents == null || !mounted) return; // user cancelled the picker
      // The loader covers decrypting and saving, up to the result toast.
      final added = await runWithProgress(
        context,
        message: 'Importing backup…',
        task: () async {
          final accounts = await widget.backup.decrypt(
            contents: contents,
            passphrase: passphrase,
          );
          return widget.store.importAccounts(accounts);
        },
      );
      _toast(
        added == 0
            ? 'Nothing new to import — all accounts already present'
            : 'Imported $added account${added == 1 ? '' : 's'}',
      );
    } on BackupDecryptException catch (error) {
      _toast(error.message);
    } catch (error) {
      _toast('Import failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: tokens.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        title: Text(
          'Settings',
          style: TextStyle(
            fontFamily: AppTokens.fontSans,
            fontWeight: FontWeight.w700,
            color: tokens.ink,
            fontSize: 18,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppTokens.space4),
              children: [
                const _SectionLabel('Appearance'),
                _SettingsCard(
                  child: AnimatedBuilder(
                    animation: widget.theme,
                    builder: (context, _) => _ThemeRow(
                      mode: widget.theme.mode,
                      onChanged: widget.theme.setMode,
                    ),
                  ),
                ),
                const SizedBox(height: AppTokens.space6),
                const _SectionLabel('Security'),
                _SettingsCard(
                  child: Column(
                    children: [
                      _LockRow(
                        available: _available,
                        enabled: _enabled,
                        saving: _saving,
                        onChanged: _toggle,
                      ),
                      if (_enabled) ...[
                        Divider(height: AppTokens.space6, color: tokens.border),
                        _AutoLockRow(
                          delaySeconds: _delaySeconds,
                          onChanged: _setDelay,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppTokens.space6),
                const _SectionLabel('Backup & restore'),
                _SettingsCard(
                  child: Column(
                    children: [
                      _ActionRow(
                        key: _exportRowKey,
                        icon: Icons.ios_share,
                        title: 'Export encrypted backup',
                        subtitle:
                            'Save a passphrase-protected copy of your accounts.',
                        onTap: _export,
                      ),
                      Divider(height: AppTokens.space6, color: tokens.border),
                      _ActionRow(
                        icon: Icons.download_outlined,
                        title: 'Import backup',
                        subtitle: 'Restore accounts from a backup file.',
                        onTap: _import,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _LockRow extends StatelessWidget {
  const _LockRow({
    required this.available,
    required this.enabled,
    required this.saving,
    required this.onChanged,
  });

  final bool available;
  final bool enabled;
  final bool saving;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final subtitle = !available
        ? 'Set up a fingerprint, face unlock or screen lock on this device to enable.'
        : 'Require biometrics or your device PIN to open the app.';

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tokens.brandSoft,
            borderRadius: BorderRadius.circular(AppTokens.rMd),
          ),
          child: Icon(Icons.fingerprint, color: tokens.brand, size: 22),
        ),
        const SizedBox(width: AppTokens.space4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'App lock',
                style: TextStyle(
                  fontFamily: AppTokens.fontSans,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: tokens.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: AppTokens.fontSans,
                  fontSize: 12,
                  color: tokens.muted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppTokens.space3),
        if (saving)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Switch(
            value: enabled,
            activeThumbColor: tokens.brand,
            onChanged: available ? onChanged : null,
          ),
      ],
    );
  }
}

class _ThemeRow extends StatelessWidget {
  const _ThemeRow({required this.mode, required this.onChanged});

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  static const _options = <ThemeMode, String>{
    ThemeMode.system: 'System',
    ThemeMode.light: 'Light',
    ThemeMode.dark: 'Dark',
  };

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tokens.brandSoft,
                borderRadius: BorderRadius.circular(AppTokens.rMd),
              ),
              child: Icon(
                Icons.brightness_6_outlined,
                color: tokens.brand,
                size: 20,
              ),
            ),
            const SizedBox(width: AppTokens.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Theme',
                    style: TextStyle(
                      fontFamily: AppTokens.fontSans,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tokens.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Match the system, or force light or dark.',
                    style: TextStyle(
                      fontFamily: AppTokens.fontSans,
                      fontSize: 12,
                      color: tokens.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTokens.space3),
        SegmentedButton<ThemeMode>(
          segments: [
            for (final entry in _options.entries)
              ButtonSegment(
                value: entry.key,
                label: Text(entry.value, maxLines: 1, softWrap: false),
              ),
          ],
          selected: {mode},
          showSelectedIcon: false,
          onSelectionChanged: (selection) => onChanged(selection.first),
        ),
      ],
    );
  }
}

class _AutoLockRow extends StatelessWidget {
  const _AutoLockRow({required this.delaySeconds, required this.onChanged});

  final int delaySeconds;
  final ValueChanged<int> onChanged;

  static const _options = <int, String>{
    0: 'Instant',
    30: '30s',
    60: '1m',
  };

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tokens.brandSoft,
                borderRadius: BorderRadius.circular(AppTokens.rMd),
              ),
              child: Icon(Icons.lock_clock, color: tokens.brand, size: 20),
            ),
            const SizedBox(width: AppTokens.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Auto-lock',
                    style: TextStyle(
                      fontFamily: AppTokens.fontSans,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tokens.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Re-lock after leaving the app.',
                    style: TextStyle(
                      fontFamily: AppTokens.fontSans,
                      fontSize: 12,
                      color: tokens.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTokens.space3),
        SegmentedButton<int>(
          segments: [
            for (final entry in _options.entries)
              ButtonSegment(
                value: entry.key,
                label: Text(entry.value, maxLines: 1, softWrap: false),
              ),
          ],
          selected: {delaySeconds},
          showSelectedIcon: false,
          onSelectionChanged: (selection) => onChanged(selection.first),
        ),
      ],
    );
  }
}

/// The on-screen rect of the widget holding [key], in global coordinates.
Rect _globalRect(GlobalKey key) {
  final box = key.currentContext!.findRenderObject()! as RenderBox;
  return box.localToGlobal(Offset.zero) & box.size;
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.rMd),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tokens.brandSoft,
              borderRadius: BorderRadius.circular(AppTokens.rMd),
            ),
            child: Icon(icon, color: tokens.brand, size: 20),
          ),
          const SizedBox(width: AppTokens.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppTokens.fontSans,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: tokens.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: AppTokens.fontSans,
                    fontSize: 12,
                    color: tokens.muted,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: tokens.muted, size: 20),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(
        left: AppTokens.space1,
        bottom: AppTokens.space2,
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontFamily: AppTokens.fontSans,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: tokens.muted,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(AppTokens.space4),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(AppTokens.rLg),
        border: Border.all(color: tokens.border),
      ),
      child: child,
    );
  }
}

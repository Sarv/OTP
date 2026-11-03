# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Sarv OTP is now on [Google Play](https://play.google.com/store/apps/details?id=com.sarv.otp). The website and README link to it; the signed APK from GitHub releases is still available for sideloading.
- Sarv OTP is now on the [App Store](https://apps.apple.com/app/sarv-otp/id6826185824) for iPhone and iPad. The website and README link to it, replacing the earlier TestFlight-only route.
- Automated tests now cover 98% of the app's code (up from about 52%): the code generator, encrypted backups, account storage, app lock, and the main screens and flows. A Tests workflow runs them on every push and pull request, and the README shows the current coverage.

### Fixed
- Exporting a backup now confirms it worked: after you send the file to Drive, Files or another app, Settings shows "Backup exported". Before, you came back to an unchanged screen with no sign the export had succeeded. Closing the share sheet without choosing anywhere still shows nothing.
- "Go back" on the scanner's camera-unavailable screen now works; the QR frame was drawn over the button and swallowed the tap.
- Exporting an encrypted backup now shows a loader while the backup is encrypted, instead of a pause with no feedback before the share sheet opens.
- Importing a backup now shows a loader while it is decrypted and saved, until the result or an error appears.
- Exporting a backup on iOS no longer fails with "sharePositionOrigin: argument must be set"; the share sheet is now anchored to the export row.

### Security
- iOS now blocks screenshots and screen recordings of codes, matching Android: captures come out black, the app explains why after a screenshot, and codes are hidden in the app switcher. Previously iOS had no capture protection at all.
- Turning the app lock off now requires fingerprint, face or device PIN, just like turning it on, so someone holding an unlocked phone can't remove the protection.
- On iOS, returning from the App Switcher now asks to unlock again, the same as returning from the home screen. Before, the app came back unlocked even with "Immediately" auto-lock selected. Android already behaved this way.
- The lock screen now also covers Settings, the scanner and open dialogs. Before, if the app re-locked while one of those was open, it stayed usable and backup export could be reached without unlocking.

## [0.1.2] - 2026-10-26

### Changed
- Release CI now builds a signed Android App Bundle (AAB) alongside the APK and, when a Google Play service account is configured, uploads it to the Play internal testing track.

### Added
- README section explaining how codes are generated entirely offline, with a diagram of the enrollment, per-period and verification flow.

## [0.1.1] - 2026-10-23

### Added
- Clean-room TOTP (RFC 6238) and HOTP (RFC 4226) engine with SHA-1/256/512 and 6- or 8-digit codes.
- QR-code enrollment (`otpauth://` Key URI parsing) and manual setup-key entry with algorithm, digit-count and period selection.
- Biometric / device-credential app lock, on by default when the device supports it.
- Configurable auto-lock delay (immediately / after 30s / after 1m) when the lock is enabled.
- Blurred lock overlay that hides codes while the unlock prompt is showing.
- Encrypted backup export and import: AES-GCM-256 with PBKDF2-HMAC-SHA256 (600k iterations), passphrase-protected.
- Search/filter across accounts by issuer or label.
- Drag-to-reorder accounts, with the order persisted.
- Rename an account's issuer and label without touching its secret.
- Confirmation dialog before removing an account.
- FLAG_SECURE / screenshot protection so codes do not leak into screenshots or the app switcher.
- Sarv-themed UI (design-system tokens) with light and dark app icons.

### Security
- Secrets are stored only in the OS-backed keystore (Android Keystore / iOS Keychain) — never in plain preferences, files, or over the network.
- Backup passphrases are never stored and cannot be recovered.

[Unreleased]: https://github.com/Sarv/OTP/compare/v0.1.2...HEAD
[0.1.2]: https://github.com/Sarv/OTP/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/Sarv/OTP/releases/tag/v0.1.1

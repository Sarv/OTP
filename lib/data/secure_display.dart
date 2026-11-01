import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('com.sarv.otp/secure_display');

/// Screenshot / screen-recording protection so live 2FA codes can't leak.
///
/// On Android this is enforced natively and unconditionally: `MainActivity`
/// sets `FLAG_SECURE` in `onCreate` (see android/.../MainActivity.kt), which
/// makes the system refuse screenshots and recordings and blanks the recents
/// preview. Nothing needs to happen here.
///
/// iOS has no equivalent switch — the system always takes the screenshot and
/// only tells the app afterwards. So `SecureDisplay` (ios/Runner/AppDelegate.swift)
/// draws the app inside a secure layer, which iOS leaves out of screenshots,
/// recordings and mirroring (the capture comes out blank), covers the
/// app-switcher snapshot with [switcherCover], and [onScreenshot] fires after
/// each screenshot so the user can be told why it is blank.
Future<void> enableSecureDisplay({
  required Color switcherCover,
  required void Function() onScreenshot,
}) async {
  if (defaultTargetPlatform != TargetPlatform.iOS) return;
  _channel.setMethodCallHandler((call) async {
    if (call.method == 'screenshotTaken') onScreenshot();
  });
  await _channel.invokeMethod('enable', {'cover': switcherCover.toARGB32()});
}

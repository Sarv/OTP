import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarv_authenticator/ui/theme.dart';

void main() {
  const light = AppTokens.light;
  const dark = AppTokens.dark;

  test('copyWith replaces only the given tokens', () {
    final changed = light.copyWith(brand: dark.brand);
    expect(changed.brand, dark.brand);
    expect(changed.surface, light.surface);
    expect(changed.danger, light.danger);

    final all = light.copyWith(
      bg: dark.bg,
      surface: dark.surface,
      surface2: dark.surface2,
      border: dark.border,
      ink: dark.ink,
      muted: dark.muted,
      brand: dark.brand,
      brandSoft: dark.brandSoft,
      accent: dark.accent,
      success: dark.success,
      danger: dark.danger,
    );
    expect(all.lerp(dark, 0).ink, dark.ink);
  });

  test('lerp blends between the light and dark tokens', () {
    expect(light.lerp(dark, 0).bg, light.bg);
    expect(light.lerp(dark, 1).bg, dark.bg);
    expect(light.lerp(dark, 0.5).brand, Color.lerp(light.brand, dark.brand, 0.5));
  });

  test('lerp ignores a theme extension of another type', () {
    expect(light.lerp(null, 0.5), same(light));
  });
}

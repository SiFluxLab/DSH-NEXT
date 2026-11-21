import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ui/theme/surface_palette.dart';

/// 表面配色（黑曜 / 暖炭）。强调色是另一件事，见 `accentProvider`。
class SurfacePaletteController extends Notifier<SurfacePalette> {
  static const key = 'appearance.surfacePalette';

  @override
  SurfacePalette build() {
    unawaited(_load());
    return SurfacePalette.obsidian;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(key);
      final palette = SurfacePalette.values.asNameMap()[saved];
      if (palette != null) state = palette;
    } catch (_) {}
  }

  Future<void> set(SurfacePalette palette) async {
    state = palette;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, palette.name);
    } catch (_) {}
  }
}

final surfacePaletteProvider = NotifierProvider<SurfacePaletteController, SurfacePalette>(
  SurfacePaletteController.new,
);

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ui/theme/optics.dart';

/// 光感档位：`设置 › 外观 › 光感与动效` 的三选一，默认 [OpticsPreset.focus]。
///
/// 只存用户的档位；系统偏好（移除动画 / 高对比 / 省电模式）在渲染时叠加，
/// 不写回这里——否则用户改回系统设置后我们还得记着"当初为什么关掉"。
class OpticsPresetController extends Notifier<OpticsPreset> {
  static const key = 'optics.preset';

  @override
  OpticsPreset build() {
    unawaited(_load());
    return OpticsPreset.focus;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(key);
      final preset = OpticsPreset.values.asNameMap()[saved];
      if (preset != null) state = preset;
    } catch (_) {
      // 没有偏好后端（测试）或存储读不出来：保持默认档。
    }
  }

  Future<void> set(OpticsPreset preset) async {
    state = preset;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, preset.name);
    } catch (_) {}
  }
}

final opticsPresetProvider = NotifierProvider<OpticsPresetController, OpticsPreset>(
  OpticsPresetController.new,
);

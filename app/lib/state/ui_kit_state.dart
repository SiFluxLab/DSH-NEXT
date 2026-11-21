import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 两枚从 obsidian-prism 抄来的页签控件，各自独立可关。
///
/// 默认值照它的原始行为：
/// - [segmented]（三枚小胶囊）对应 `homeLayout: studio` → **默认开**；
/// - [dualToggle]（双极滑块）对应 `sidebarStudio` → **默认关**（它在上游是 Beta）。
class UiKitPrefs {
  const UiKitPrefs({this.segmented = true, this.dualToggle = false, this.loaded = false});

  final bool segmented;
  final bool dualToggle;
  final bool loaded;
}

class UiKitController extends Notifier<UiKitPrefs> {
  static const _segmentedKey = 'ui.tabStrip';
  static const _dualKey = 'ui.dualToggle';

  @override
  UiKitPrefs build() {
    unawaited(_load());
    return const UiKitPrefs();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = UiKitPrefs(
        segmented: prefs.getBool(_segmentedKey) ?? true,
        dualToggle: prefs.getBool(_dualKey) ?? false,
        loaded: true,
      );
    } catch (_) {}
  }

  Future<void> setSegmented(bool value) async {
    state = UiKitPrefs(segmented: value, dualToggle: state.dualToggle, loaded: true);
    try {
      await (await SharedPreferences.getInstance()).setBool(_segmentedKey, value);
    } catch (_) {}
  }

  Future<void> setDualToggle(bool value) async {
    state = UiKitPrefs(segmented: state.segmented, dualToggle: value, loaded: true);
    try {
      await (await SharedPreferences.getInstance()).setBool(_dualKey, value);
    } catch (_) {}
  }
}

final uiKitProvider = NotifierProvider<UiKitController, UiKitPrefs>(UiKitController.new);

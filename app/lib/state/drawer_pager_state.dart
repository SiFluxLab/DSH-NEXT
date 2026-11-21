import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ui/shell/drawer/pager.dart';

/// 侧边栏现在是翻页器（页签栏 + 手势翻页），还是原来的一屏到底。
///
/// 小屏上有人就喜欢一屏到底，所以这个是可以关的；关掉之后布局回到原样，
/// 数据与操作完全不受影响。
class DrawerPagerEnabled extends Notifier<bool> {
  static const key = 'drawer.pager';

  @override
  bool build() {
    unawaited(_load());
    return true;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(key);
      if (saved != null) state = saved;
    } catch (_) {}
  }

  Future<void> set(bool value) async {
    state = value;
    try {
      await (await SharedPreferences.getInstance()).setBool(key, value);
    } catch (_) {}
  }
}

final drawerPagerEnabledProvider = NotifierProvider<DrawerPagerEnabled, bool>(DrawerPagerEnabled.new);

/// 上次停在哪一页（会话 / 文件）。关掉翻页器时这个值仍然保留，
/// 下次打开还是那一页——和 pi-web 的 `lib/sidebar-prefs.ts` 一样按端记住。
class DrawerTabController extends Notifier<DrawerTab> {
  static const key = 'drawer.tab';

  @override
  DrawerTab build() {
    unawaited(_load());
    return DrawerTab.sessions;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(key);
      final tab = DrawerTab.values.asNameMap()[saved];
      if (tab != null) state = tab;
    } catch (_) {}
  }

  Future<void> set(DrawerTab tab) async {
    if (state == tab) return;
    state = tab;
    try {
      await (await SharedPreferences.getInstance()).setString(key, tab.name);
    } catch (_) {}
  }
}

final drawerTabProvider = NotifierProvider<DrawerTabController, DrawerTab>(DrawerTabController.new);

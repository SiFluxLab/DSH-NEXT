// 内置插件: the three big features of this app (酒馆, 创意工坊, 伙伴小屋) can
// each be switched off, so a build can stay lean or a person can hide what they
// never use.
//
// Off hides every entry — the 模式 sheet, page links, the 创意工坊 rows inside
// 伙伴/桌宠, the startup mode — and a page reached another way (a deep link, a
// home-screen widget) shows a notice instead. Nothing is deleted: cards,
// chats, packages and settings stay where they are, and switching a plugin
// back on brings all of it back.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The features that can be turned off. [workshop] ships inside 伙伴 and 桌宠
/// as their content store; it can still be off while they are on.
enum BuiltinPlugin { tavern, workshop, companion }

class BuiltinPluginState {
  const BuiltinPluginState({this.disabled = const <BuiltinPlugin>{}, this.loaded = false});

  final Set<BuiltinPlugin> disabled;
  final bool loaded;

  bool enabled(BuiltinPlugin plugin) => !disabled.contains(plugin);
}

class BuiltinPluginController extends Notifier<BuiltinPluginState> {
  static String keyOf(BuiltinPlugin plugin) => 'builtin_plugins.${plugin.name}';

  @override
  BuiltinPluginState build() {
    unawaited(_load());
    return const BuiltinPluginState();
  }

  Future<void> _load() async {
    final disabled = <BuiltinPlugin>{};
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final plugin in BuiltinPlugin.values) {
        // Absent means on: an upgraded install keeps everything it had.
        if (prefs.getBool(keyOf(plugin)) == false) disabled.add(plugin);
      }
    } catch (_) {
      // No preferences backend (tests) or an unreadable store: everything on.
    }
    // A choice made while reading back wins over the stored value.
    if (!state.loaded) state = BuiltinPluginState(disabled: disabled, loaded: true);
  }

  Future<void> setEnabled(BuiltinPlugin plugin, bool enabled) async {
    final disabled = {...state.disabled};
    if (enabled) {
      disabled.remove(plugin);
    } else {
      disabled.add(plugin);
    }
    state = BuiltinPluginState(disabled: disabled, loaded: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyOf(plugin), enabled);
    } catch (_) {}
  }

  /// Back to the build's own choice: everything on.
  Future<void> reset() async {
    state = const BuiltinPluginState(loaded: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final plugin in BuiltinPlugin.values) {
        await prefs.remove(keyOf(plugin));
      }
    } catch (_) {}
  }
}

final builtinPluginsProvider = NotifierProvider<BuiltinPluginController, BuiltinPluginState>(
  BuiltinPluginController.new,
);

/// Whether [plugin] is on. Until the stored choice has been read it counts as
/// on, so a launch never flashes a hidden entry.
final builtinPluginEnabledProvider = Provider.family<bool, BuiltinPlugin>(
  (ref, plugin) => ref.watch(builtinPluginsProvider.select((s) => s.enabled(plugin))),
);

/// Whether any mode page can be opened (工作 is always there).
final anyModePluginEnabledProvider = Provider<bool>(
  (ref) =>
      ref.watch(builtinPluginEnabledProvider(BuiltinPlugin.companion)) ||
      ref.watch(builtinPluginEnabledProvider(BuiltinPlugin.tavern)),
);

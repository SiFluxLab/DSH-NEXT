// 内置插件: switch 酒馆 / 创意工坊 / 伙伴小屋 on or off
// (state/builtin_plugins_state.dart). Turning one off hides its entries and
// leaves its data alone.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/builtin_plugins_state.dart';
import '../shell/page_frame.dart';
import '../theme/app_icons.dart';
import 'settings_widgets.dart';

String builtinPluginName(L10n l10n, BuiltinPlugin plugin) => switch (plugin) {
  BuiltinPlugin.tavern => l10n.tavernTitle,
  BuiltinPlugin.workshop => l10n.workshopTitle,
  BuiltinPlugin.companion => l10n.companionTitle,
};

String builtinPluginHint(L10n l10n, BuiltinPlugin plugin) => switch (plugin) {
  BuiltinPlugin.tavern => l10n.builtinPluginTavernHint,
  BuiltinPlugin.workshop => l10n.builtinPluginWorkshopHint,
  BuiltinPlugin.companion => l10n.builtinPluginCompanionHint,
};

IconData builtinPluginIcon(BuiltinPlugin plugin) => switch (plugin) {
  BuiltinPlugin.tavern => AppIcons.tavern,
  BuiltinPlugin.workshop => AppIcons.plugin,
  BuiltinPlugin.companion => AppIcons.pet,
};

/// The row on 设置 that opens this page.
class BuiltinPluginsTile extends ConsumerWidget {
  const BuiltinPluginsTile({super.key, this.tint = 0});
  final int tint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(builtinPluginsProvider);
    final on = state.disabled.isEmpty;
    return SettingsTile(
      key: const ValueKey('settings-builtin-plugins'),
      icon: AppIcons.plugin,
      tint: tint,
      spot: SettingsIndex.entry(SettingsPageId.builtinPlugins),
      value: Text(on ? l10n.builtinPluginsAllOn : l10n.builtinPluginsSomeOff),
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const BuiltinPluginsPage())),
    );
  }
}

class BuiltinPluginsPage extends ConsumerWidget {
  const BuiltinPluginsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(builtinPluginsProvider);
    final notifier = ref.read(builtinPluginsProvider.notifier);
    return AppPage.list(
      title: l10n.builtinPluginsTitle,
      subtitle: Text(l10n.builtinPluginsIntro),
      children: [
        SettingsSection(
          footer: Text(l10n.builtinPluginKeepData),
          children: [
            for (final plugin in BuiltinPlugin.values)
              SettingsSwitchTile(
                key: ValueKey('builtin-plugin-${plugin.name}'),
                icon: builtinPluginIcon(plugin),
                title: builtinPluginName(l10n, plugin),
                subtitle: builtinPluginHint(l10n, plugin),
                value: state.enabled(plugin),
                onChanged: (value) => unawaited(notifier.setEnabled(plugin, value)),
              ),
          ],
        ),
        if (state.disabled.isNotEmpty)
          SettingsSection(
            children: [
              SettingsTile(
                key: const ValueKey('builtin-plugins-reset'),
                title: l10n.builtinPluginsReset,
                chevron: false,
                onTap: () => unawaited(notifier.reset()),
              ),
            ],
          ),
        const SizedBox(height: 72),
      ],
    );
  }
}

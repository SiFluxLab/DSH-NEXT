// A page of a built-in plugin that is switched off (state/builtin_plugins_state.dart):
// rather than hiding a page that a link or a home-screen widget can still ask
// for, it says the plugin is off and offers the way back.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/builtin_plugins_state.dart';
import '../settings/index/settings_pages.dart';
import '../settings/settings_widgets.dart';
import '../shell/page_frame.dart';
import '../theme/app_icons.dart';

/// [child] unless [plugin] is off, in which case the notice.
class BuiltinPluginGate extends ConsumerWidget {
  const BuiltinPluginGate({super.key, required this.plugin, required this.title, required this.child});

  final BuiltinPlugin plugin;

  /// The notice's title (the plugin's own name).
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(builtinPluginEnabledProvider(plugin))) return child;
    final l10n = context.l10n;
    return AppPage.list(
      key: ValueKey('builtin-plugin-off-${plugin.name}'),
      title: title,
      children: [
        SettingsSection(
          footer: Text(l10n.builtinPluginKeepData),
          children: [
            SettingsTile(
              icon: AppIcons.power,
              title: l10n.builtinPluginOffAction,
              subtitle: l10n.builtinPluginOffMessage,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => settingsPage(SettingsPageId.builtinPlugins)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 72),
      ],
    );
  }
}

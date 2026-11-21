// 外观 › 一键设置：完整光效 / 专注 / 静默省电。
//
// 三档把「光感 + 动画 + 玻璃 + 刷新率」一起改，下面每一项仍然可以单独调；
// 调过之后这里显示"自定义"，不再假装还在某一档上。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../state/scene_preset.dart';
import '../../theme/app_icons.dart';
import '../index/spots.dart';
import '../settings_widgets.dart';

String sceneLabel(L10n l10n, ScenePreset scene) => switch (scene) {
  ScenePreset.fullLight => l10n.sceneFull,
  ScenePreset.focusCoding => l10n.sceneFocus,
  ScenePreset.quietPower => l10n.sceneQuiet,
};

String sceneHint(L10n l10n, ScenePreset scene) => switch (scene) {
  ScenePreset.fullLight => l10n.sceneFullHint,
  ScenePreset.focusCoding => l10n.sceneFocusHint,
  ScenePreset.quietPower => l10n.sceneQuietHint,
};

IconData sceneIcon(ScenePreset scene) => switch (scene) {
  ScenePreset.fullLight => AppIcons.generating,
  ScenePreset.focusCoding => AppIcons.preview,
  ScenePreset.quietPower => AppIcons.keepAlive,
};

class ScenePresetSection extends ConsumerWidget {
  const ScenePresetSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final current = ref.watch(scenePresetProvider);
    return SettingsSection(
      spot: Spots.scene,
      title: l10n.sceneTitle,
      footer: Text(current == null ? l10n.sceneCustomFooter : l10n.sceneFooter),
      children: [
        for (final scene in ScenePreset.values)
          SettingsTile(
            key: ValueKey('scene-${scene.name}'),
            leading: Icon(sceneIcon(scene), size: 22),
            title: sceneLabel(l10n, scene),
            subtitle: sceneHint(l10n, scene),
            trailing: Icon(
              current == scene ? AppIcons.radioOn : AppIcons.radioOff,
              size: 24,
              color: current == scene ? Theme.of(context).colorScheme.primary : null,
            ),
            onTap: () => applyScenePreset(ref, scene),
          ),
      ],
    );
  }
}

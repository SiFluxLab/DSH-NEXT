// 外观 › 光感与动效：三档预设 + 一条实时预览。
//
// 只暴露"整体选一档"，不把六个数值散成六个开关：用户想的是"要多少光"，
// 不是"镜面高光系数调到 0.06"。系统偏好（移除动画、关闭玻璃模糊、省电模式）
// 依旧在渲染层叠加，见 Optics.resolve。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../state/optics_state.dart';
import '../../../ui/theme/optics.dart';
import '../../../ui/theme/theme.dart';
import '../../common/light_blade.dart';
import '../settings_widgets.dart';

String opticsPresetLabel(L10n l10n, OpticsPreset preset) => switch (preset) {
  OpticsPreset.full => l10n.opticsFull,
  OpticsPreset.focus => l10n.opticsFocus,
  OpticsPreset.silent => l10n.opticsSilent,
};

String opticsPresetHint(L10n l10n, OpticsPreset preset) => switch (preset) {
  OpticsPreset.full => l10n.opticsFullHint,
  OpticsPreset.focus => l10n.opticsFocusHint,
  OpticsPreset.silent => l10n.opticsSilentHint,
};

class OpticsSection extends ConsumerWidget {
  const OpticsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final preset = ref.watch(opticsPresetProvider);
    final optics = Optics.of(context);
    return SettingsSection(
      title: l10n.opticsTitle,
      footer: Text(l10n.opticsFooter),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: _BladePreview(optics: optics),
        ),
        SettingsSegmentTile<OpticsPreset>(
          key: const ValueKey('optics-preset'),
          title: l10n.opticsPreset,
          segments: [
            for (final p in OpticsPreset.values) PillSegment(p, opticsPresetLabel(l10n, p)),
          ],
          selected: preset,
          onChanged: (value) => ref.read(opticsPresetProvider.notifier).set(value),
        ),
        SettingsTile(
          title: l10n.opticsPreset,
          subtitle: opticsPresetHint(l10n, preset),
          chevron: false,
          onTap: null,
        ),
      ],
    );
  }
}

/// 一格小预览：把光刃放在一块玻璃上，让人当场看出档位差别。
class _BladePreview extends StatelessWidget {
  const _BladePreview({required this.optics});

  final Optics optics;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 56,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [scheme.surfaceContainerHighest, scheme.surfaceContainerLow],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              top: 1,
              child: LightBlade(state: BladeState.streaming, radius: 14, color: scheme.primary),
            ),
            Center(
              child: Text(
                optics.preset.name,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

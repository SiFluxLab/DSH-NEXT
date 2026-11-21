import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../performance/performance_policy.dart';
import '../performance/performance_state.dart';
import '../ui/theme/optics.dart';
import 'optics_state.dart';

/// 场景预设：一次把「光感 / 动画 / 玻璃 / 刷新率」调成同一档。
///
/// 参考 obsidian-prism 的三档场景预设（完整光效 · 专注编码 · 静默省电）。它的价值
/// 在于——用户不需要懂"镜面系数"和"模糊 sigma"，只需要回答"我现在想让它多漂亮 /
/// 多省电"。细项仍然可以在下面单独改，改完就不再算"某一档"。
enum ScenePreset { fullLight, focusCoding, quietPower }

/// 当前配置离哪一档最近。用来把三选一画成"当前选中"。
///
/// 判据取三项最影响体感的：光感档位、玻璃模糊、灵动动画。三项全对才算命中。
ScenePreset? sceneOf(OpticsPreset optics, bool blur, bool fluid) {
  if (optics == OpticsPreset.full && blur && fluid) return ScenePreset.fullLight;
  if (optics == OpticsPreset.focus && blur && !fluid) return ScenePreset.focusCoding;
  if (optics == OpticsPreset.silent && !blur && !fluid) return ScenePreset.quietPower;
  return null;
}

/// 应用一档。这里刻意逐项写清楚而不是"套一个配置对象"：
/// 每一项都对应一个用户能单独看到的开关，写死映射比抽象更不容易漂移。
Future<void> applyScenePreset(WidgetRef ref, ScenePreset scene) async {
  final optics = ref.read(opticsPrefsProvider.notifier);
  final perf = ref.read(performancePrefsProvider.notifier);
  switch (scene) {
    case ScenePreset.fullLight:
      await optics.setPreset(OpticsPreset.full);
      await perf.setBlur(true);
      await perf.setAnimations(true);
      await perf.setFluid(true);
      await perf.setMode(PerformanceMode.full);
      await perf.setRefreshRate(RefreshRateMode.max);
    case ScenePreset.focusCoding:
      await optics.setPreset(OpticsPreset.focus);
      await perf.setBlur(true);
      await perf.setAnimations(true);
      await perf.setFluid(false);
      await perf.setMode(PerformanceMode.auto);
      await perf.setRefreshRate(RefreshRateMode.auto);
    case ScenePreset.quietPower:
      await optics.setPreset(OpticsPreset.silent);
      await perf.setBlur(false);
      await perf.setAnimations(false);
      await perf.setFluid(false);
      await perf.setMode(PerformanceMode.light);
      await perf.setRefreshRate(RefreshRateMode.system);
  }
}

/// 当前场景（null = 用户改过细项，不在任何一档上）。
final scenePresetProvider = Provider<ScenePreset?>((ref) {
  final optics = ref.watch(opticsPrefsProvider);
  final perf = ref.watch(performancePrefsProvider);
  // 只看"有效值"：用户没显式设过的项，走默认（模糊开、灵动跟随设备）。
  return sceneOf(optics.preset, perf.blur ?? true, perf.fluid ?? false);
});

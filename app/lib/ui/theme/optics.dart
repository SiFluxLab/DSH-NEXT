// 光感 token：这一层的存在是为了让"玻璃"有光学依据，而不是一层模糊。
//
// 参考 obsidian-prism 的做法（workbench/design-tokens.json）：把光学强度做成可调
// 数值——镜面高光、纸纹颗粒、棱镜边缘、模糊半径——而不是散落在各个 widget 里的
// 魔法数字。三档预设对应三种使用场景，也是唯一的用户入口：
//
//   完整光感 full    玻璃 + 光刃 + 颗粒 + 棱镜边缘，动画齐全
//   专注     focus   玻璃减弱、光刃只跟状态、没有颗粒
//   静默省电 silent  只有最必要的描边与淡入，模糊关掉
//
// 系统开了"移除动画"或"降低透明度"时，对应维度自动归零（见 [Optics.resolve]），
// 不靠调用方记得判断。
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// 光感强度档位。存进 prefs 的值就是这里的 name。
enum OpticsPreset {
  /// 玻璃 + 光刃 + 颗粒 + 棱镜边缘，动画齐全。
  full,

  /// 玻璃弱一点、光刃只反映状态、不要颗粒。默认档。
  focus,

  /// 只留必要的描边与淡入：模糊、颗粒、光刃、余晖全关。
  silent,
}

@immutable
class Optics extends ThemeExtension<Optics> {
  const Optics({
    required this.preset,
    required this.specular,
    required this.grain,
    required this.blade,
    required this.prism,
    required this.blurSigma,
    required this.anticipation,
    required this.afterglow,
    required this.inkFade,
  });

  final OpticsPreset preset;

  /// 玻璃上沿的镜面高光强度（0–1）。
  final double specular;

  /// 纸纹颗粒强度（0–1）。0 表示不绘制。
  final double grain;

  /// 签名元素「光刃」的强度（0–1）。
  final double blade;

  /// 棱镜色散边缘强度（0–1）。
  final double prism;

  /// 背景模糊的 sigma（0 表示不做 BackdropFilter）。
  final double blurSigma;

  /// 预见性动画：目标页面的骨架与转场在数据到达前先就位。
  final bool anticipation;

  /// 三态边缘余晖：等待你决定 / 异常中止 / 后台任务完成。
  final bool afterglow;

  /// 流式文字的五级水墨淡入。
  final bool inkFade;

  /// 完全不装饰的档位：调用方可以用它跳过整段绘制。
  bool get plain => blade == 0 && grain == 0 && specular == 0 && blurSigma == 0;

  /// 给定档位与系统偏好得到一套光感。系统偏好永远赢过用户的档位：
  /// 移除动画把动效类关掉，降低透明度把玻璃类关掉。
  static Optics resolve(
    OpticsPreset preset, {
    required bool reduceMotion,
    required bool reduceTransparency,
    required bool lowPower,
  }) {
    final base = switch (preset) {
      OpticsPreset.full => const Optics(
        preset: OpticsPreset.full,
        specular: 0.095,
        grain: 0.022,
        blade: 1,
        prism: 1,
        blurSigma: 20,
        anticipation: true,
        afterglow: true,
        inkFade: true,
      ),
      OpticsPreset.focus => const Optics(
        preset: OpticsPreset.focus,
        specular: 0.06,
        grain: 0,
        blade: 0.6,
        prism: 0.35,
        blurSigma: 12,
        anticipation: true,
        afterglow: true,
        inkFade: true,
      ),
      OpticsPreset.silent => const Optics(
        preset: OpticsPreset.silent,
        specular: 0,
        grain: 0,
        blade: 0,
        prism: 0,
        blurSigma: 0,
        anticipation: false,
        afterglow: false,
        inkFade: false,
      ),
    };
    if (!reduceMotion && !reduceTransparency && !lowPower) return base;
    return Optics(
      preset: base.preset,
      specular: reduceTransparency ? 0 : base.specular,
      grain: reduceTransparency || lowPower ? 0 : base.grain,
      blade: reduceMotion ? 0 : base.blade,
      prism: reduceTransparency || lowPower ? 0 : base.prism,
      blurSigma: reduceTransparency || lowPower ? 0 : base.blurSigma,
      anticipation: !reduceMotion && base.anticipation,
      afterglow: !reduceMotion && base.afterglow,
      inkFade: !reduceMotion && base.inkFade,
    );
  }

  /// 当前生效的一套光感：先看最近的 [OpticsScope]（可随设置与系统偏好实时变化），
  /// 再退回主题扩展，最后是一套静态默认值（单测与独立预览用）。
  static Optics of(BuildContext context) =>
      OpticsScope.maybeOf(context) ??
      Theme.of(context).extension<Optics>() ??
      Optics.resolve(OpticsPreset.focus, reduceMotion: false, reduceTransparency: false, lowPower: false);

  @override
  Optics copyWith({
    OpticsPreset? preset,
    double? specular,
    double? grain,
    double? blade,
    double? prism,
    double? blurSigma,
    bool? anticipation,
    bool? afterglow,
    bool? inkFade,
  }) => Optics(
    preset: preset ?? this.preset,
    specular: specular ?? this.specular,
    grain: grain ?? this.grain,
    blade: blade ?? this.blade,
    prism: prism ?? this.prism,
    blurSigma: blurSigma ?? this.blurSigma,
    anticipation: anticipation ?? this.anticipation,
    afterglow: afterglow ?? this.afterglow,
    inkFade: inkFade ?? this.inkFade,
  );

  @override
  bool operator ==(Object other) =>
      other is Optics &&
      other.preset == preset &&
      other.specular == specular &&
      other.grain == grain &&
      other.blade == blade &&
      other.prism == prism &&
      other.blurSigma == blurSigma &&
      other.anticipation == anticipation &&
      other.afterglow == afterglow &&
      other.inkFade == inkFade;

  @override
  int get hashCode =>
      Object.hash(preset, specular, grain, blade, prism, blurSigma, anticipation, afterglow, inkFade);

  @override
  Optics lerp(covariant Optics? other, double t) {
    if (other == null) return this;
    // 档位是离散的：动画过程中保持目标档位，数值连续插值。
    return Optics(
      preset: t < 0.5 ? preset : other.preset,
      specular: lerpDouble(specular, other.specular, t)!,
      grain: lerpDouble(grain, other.grain, t)!,
      blade: lerpDouble(blade, other.blade, t)!,
      prism: lerpDouble(prism, other.prism, t)!,
      blurSigma: lerpDouble(blurSigma, other.blurSigma, t)!,
      anticipation: t < 0.5 ? anticipation : other.anticipation,
      afterglow: t < 0.5 ? afterglow : other.afterglow,
      inkFade: t < 0.5 ? inkFade : other.inkFade,
    );
  }
}

/// 把当前 [Optics] 交给子树。放在 App 根附近，主题本身不必为光感重建。
class OpticsScope extends InheritedWidget {
  const OpticsScope({super.key, required this.optics, required super.child});

  final Optics optics;

  static Optics? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OpticsScope>()?.optics;

  @override
  bool updateShouldNotify(OpticsScope oldWidget) => oldWidget.optics != optics;
}

/// 光刃的四种状态：它只反映引擎真实在做什么，不做装饰。
enum BladeState {
  /// 引擎在跑、没有在生成：缓慢呼吸（一个 2.4s 周期）。
  idle,

  /// 正在流式接收：光刃沿上沿从左往右走。
  streaming,

  /// 有工具在跑：光刃在中段来回，节奏跟工具行一致。
  working,

  /// 等待你决定（审批、提问、选项）：停在一半并轻微脉动。
  waiting,
}

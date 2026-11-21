import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ui/theme/optics.dart';

/// 光感档位：`设置 › 外观 › 光感与动效` 的三选一，默认 [OpticsPreset.focus]。
///
/// 档位是"宏观选择"；下面四个开关是"单项否决"，用来关掉自己不喜欢的那一项。
/// 换档位会清掉这些否决，回到该档位的样子——否则用户记不住"现在是档位还是开关"。
class OpticsPrefs {
  const OpticsPrefs({
    this.preset = OpticsPreset.focus,
    this.blade,
    this.prism,
    this.anticipation,
    this.afterglow,
    this.inkFade,
    this.loaded = false,
  });

  final OpticsPreset preset;

  /// null = 跟随档位；true / false = 用户显式开或关。
  final bool? blade;
  final bool? prism;
  final bool? anticipation;
  final bool? afterglow;
  final bool? inkFade;

  final bool loaded;

  bool get hasOverrides =>
      blade != null || prism != null || anticipation != null || afterglow != null || inkFade != null;

  /// 档位 + 用户否决 + 系统偏好，得到真正用于渲染的一套值。
  Optics resolve({required bool reduceMotion, required bool reduceTransparency, required bool lowPower}) {
    final base = Optics.resolve(
      preset,
      reduceMotion: reduceMotion,
      reduceTransparency: reduceTransparency,
      lowPower: lowPower,
    );
    if (!hasOverrides) return base;
    // 单项开关只能"往下压"，不能把系统偏好已经关掉的东西重新打开：
    // 移除动画、降低透明度永远赢过用户的单项选择。
    return Optics(
      preset: base.preset,
      specular: base.specular,
      grain: base.grain,
      blade: blade == false ? 0 : base.blade,
      prism: prism == false ? 0 : base.prism,
      blurSigma: base.blurSigma,
      anticipation: anticipation == false ? false : base.anticipation,
      afterglow: afterglow == false ? false : base.afterglow,
      inkFade: inkFade == false ? false : base.inkFade,
    );
  }
}

class OpticsController extends Notifier<OpticsPrefs> {
  static const _presetKey = 'optics.preset';
  static const _bladeKey = 'optics.blade';
  static const _prismKey = 'optics.prism';
  static const _anticipationKey = 'optics.anticipation';
  static const _afterglowKey = 'optics.afterglow';
  static const _inkFadeKey = 'optics.inkFade';

  @override
  OpticsPrefs build() {
    unawaited(_load());
    return const OpticsPrefs();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final preset = OpticsPreset.values.asNameMap()[prefs.getString(_presetKey)] ?? OpticsPrefs().preset;
      state = OpticsPrefs(
        preset: preset,
        blade: prefs.getBool(_bladeKey),
        prism: prefs.getBool(_prismKey),
        anticipation: prefs.getBool(_anticipationKey),
        afterglow: prefs.getBool(_afterglowKey),
        inkFade: prefs.getBool(_inkFadeKey),
        loaded: true,
      );
    } catch (_) {
      // 没有偏好后端（测试）或读不出来：默认档、无否决。
    }
  }

  /// 换档位：同时清掉所有单项否决，回到该档位本来的样子。
  Future<void> setPreset(OpticsPreset preset) async {
    state = OpticsPrefs(preset: preset, loaded: true);
    await _write({_presetKey: preset.name, _bladeKey: null, _prismKey: null,
      _anticipationKey: null, _afterglowKey: null, _inkFadeKey: null});
  }

  Future<void> setBlade(bool value) async {
    state = _copy(blade: value);
    await _write({_bladeKey: value});
  }

  Future<void> setPrism(bool value) async {
    state = _copy(prism: value);
    await _write({_prismKey: value});
  }

  Future<void> setAnticipation(bool value) async {
    state = _copy(anticipation: value);
    await _write({_anticipationKey: value});
  }

  Future<void> setAfterglow(bool value) async {
    state = _copy(afterglow: value);
    await _write({_afterglowKey: value});
  }

  Future<void> setInkFade(bool value) async {
    state = _copy(inkFade: value);
    await _write({_inkFadeKey: value});
  }

  /// 把四个开关全部交还给档位。
  Future<void> followPreset() async {
    state = OpticsPrefs(preset: state.preset, loaded: true);
    await _write({_bladeKey: null, _prismKey: null, _anticipationKey: null,
      _afterglowKey: null, _inkFadeKey: null});
  }

  OpticsPrefs _copy({bool? blade, bool? prism, bool? anticipation, bool? afterglow, bool? inkFade}) => OpticsPrefs(
    preset: state.preset,
    blade: blade ?? state.blade,
    prism: prism ?? state.prism,
    anticipation: anticipation ?? state.anticipation,
    afterglow: afterglow ?? state.afterglow,
    inkFade: inkFade ?? state.inkFade,
    loaded: true,
  );

  Future<void> _write(Map<String, Object?> values) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final entry in values.entries) {
        final value = entry.value;
        if (value == null) {
          await prefs.remove(entry.key);
        } else if (value is bool) {
          await prefs.setBool(entry.key, value);
        } else {
          await prefs.setString(entry.key, value.toString());
        }
      }
    } catch (_) {}
  }
}

final opticsPrefsProvider = NotifierProvider<OpticsController, OpticsPrefs>(OpticsController.new);

/// 兼容旧调用点：只要档位。
final opticsPresetProvider = Provider<OpticsPreset>((ref) => ref.watch(opticsPrefsProvider).preset);

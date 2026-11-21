import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'companion/companion_initiative_owner.dart' show companionInitiativeProvider;
import 'l10n/l10n.dart';
import 'performance/performance_state.dart';
import 'performance/refresh_rate.dart';
import 'state/app_info.dart';
import 'state/appearance_state.dart';
import 'state/locale_state.dart';
import 'state/optics_state.dart';
import 'state/surface_palette_state.dart';
import 'state/star_prompt.dart' show starPromptGateProvider, starPromptProvider;
import 'state/tile_style_state.dart';
import 'ui/chat/dsh_ui/dsh_ui_model.dart' show DshUiAppAccent;
import 'ui/common/app_blade.dart';
import 'ui/common/ui_trace.dart';
import 'ui/common/keyboard_motion.dart';
import 'ui/common/side_insets.dart';
import 'ui/launch/launch_overlay.dart';
import 'ui/shell/root_gate.dart';
import 'ui/theme/theme.dart';
import 'ui_config/ui_config_state.dart';
import 'usage/usage_stats.dart';

class DshApp extends ConsumerStatefulWidget {
  const DshApp({super.key, this.home});

  /// Replaces the root gate (widget tests).
  final Widget? home;

  @override
  ConsumerState<DshApp> createState() => _DshAppState();
}

class _DshAppState extends ConsumerState<DshApp> with WidgetsBindingObserver {
  /// Themes of the palette last built: rebuilt only when the palette or the
  /// language changes.
  AppAccent? _accent;
  SurfacePalette? _palette;
  bool? _english;
  bool? _glassBlur;
  bool? _instantPages;
  bool? _fluid;
  late ThemeData _light;
  late ThemeData _dark;

  /// The language last shown; a change after the first frame rebuilds the
  /// whole tree (text read through `appL10n` has no dependency to notify).
  Locale? _shown;

  /// The stored palette arrives a moment after launch; that first switch
  /// lands without a cross-fade, later ones fade (切换配色).
  bool _settled = false;

  /// Reduced motion as of the last build. Switching it changes the theme's page transitions,
  /// and that lands at once rather than half a cross-fade later (减少动画).
  bool? _reducedBefore;

  /// MaterialApp builds Theme for AnimationStyle.noAnimation and AnimatedTheme for anything else,
  /// so the cross-fade coming on or off replaces everything above the builder. The navigator has a
  /// global key to survive that; what the builder holds needs one too, or the launch screen and
  /// the theme reveal start again from nothing, and a launch screen waiting for its motion to end
  /// never leaves.
  final _layers = GlobalKey(debugLabel: 'app layers');

  @override
  void initState() {
    super.initState();
    // Start loading the stored tile style now, so 全部功能 opens in it rather
    // than flashing the default first.
    ref.read(tileStyleProvider);
    // Anonymous usage statistics live as long as the app, in either 界面
    // (release builds: today is noted, and earlier days go out).
    ref.read(usageStatsProvider);
    // 公测版: the star prompt counts time in front from launch, in either 界面.
    if (ref.read(starPromptGateProvider)) ref.read(starPromptProvider);
    // 伙伴小屋: her invitation ledger is read now, so it is known before the room opens.
    ref.read(companionInitiativeProvider);
    // 刷新率: some systems cap third-party apps at 60 Hz and then show their per-app
    // switch as an in-app setting; the app answers frames to run at the fastest rate
    // while it is actually drawing (see RefreshRateService).
    RefreshRateService.instance.start();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 跟随系统: the system language changed while the app was open.
  @override
  void didChangeLocales(List<Locale>? locales) {
    if (ref.read(appLanguageProvider) == AppLanguage.system) setState(() {});
  }

  /// The system's remove-animations setting changed while the app was open: page
  /// transitions are chosen in [build], so they would keep the old answer.
  @override
  void didChangeAccessibilityFeatures() => setState(() {});

  void _themesFor(AppAccent accent, SurfacePalette palette, bool english, bool glassBlur, bool instantPages, bool fluid) {
    if (accent == _accent &&
        palette == _palette &&
        english == _english &&
        glassBlur == _glassBlur &&
        instantPages == _instantPages &&
        fluid == _fluid) {
      return;
    }
    _accent = accent;
    _palette = palette;
    _english = english;
    _glassBlur = glassBlur;
    _instantPages = instantPages;
    _fluid = fluid;
    // Plugin views that ask for `accent: "app"` follow the palette.
    DshUiAppAccent.set(accent.seed.toARGB32());
    // English UI still shows Chinese content: keep its glyphs Chinese.
    final glyphs = english ? AppLocale.zhCN : null;
    _light = buildLightTheme(
      accent: accent,
      palette: palette,
      glyphLocale: glyphs,
      glassBlur: glassBlur,
      instantPages: instantPages,
      fluid: fluid,
    );
    _dark = buildDarkTheme(
      accent: accent,
      glyphLocale: glyphs,
      glassBlur: glassBlur,
      instantPages: instantPages,
      fluid: fluid,
    );
  }

  Locale _resolveLocale() {
    final locale = AppLocale.resolve(
      ref.watch(appLanguageProvider).locale,
      WidgetsBinding.instance.platformDispatcher.locales,
    );
    if (locale != _shown) {
      final first = _shown == null;
      _shown = locale;
      AppLocale.use(locale);
      if (!first) WidgetsBinding.instance.addPostFrameCallback((_) => _rebuildAll());
    }
    return locale;
  }

  void _rebuildAll() {
    void mark(Element e) {
      e.markNeedsBuild();
      e.visitChildren(mark);
    }

    if (mounted) (context as Element).visitChildren(mark);
  }

  @override
  Widget build(BuildContext context) {
    // 刷新率设置改动时告诉原生;setMode 对同一个值不做任何事。
    unawaited(RefreshRateService.instance.setMode(ref.watch(performancePrefsProvider.select((p) => p.refreshRate))));
    final themeMode = ref.watch(uiThemeModeProvider.select((s) => s.value));
    final appearance = ref.watch(appearanceProvider);
    final waiting =
        !appearance.loaded ||
        (appearance.source == AccentSource.wallpaper && ref.watch(wallpaperAccentProvider).isLoading);
    final locale = _resolveLocale();
    final performance = ref.watch(performanceDefaultsProvider);
    final reduced =
        performance.reduceMotion || WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    final fluid = performance.fluidMotion && !reduced;
    // 光感：用户档位 × 系统偏好 × 省电模式。系统偏好永远赢（见 Optics.resolve）。
    final optics = ref
        .watch(opticsPrefsProvider)
        .resolve(
          reduceMotion: reduced,
          reduceTransparency: !performance.blur,
          // 低端机 / 发热 / 用户选了省电：三种来源已经由 PerformanceDefaults 合成。
          // 但用户**显式**选过光感档位时不再自动降档——否则他会以为开关坏了。
          lowPower: performance.lightweight && !ref.watch(opticsPrefsProvider).explicit,
        );
    FrameClock.instance.enabled = fluid;
    // 诊断里能看到当前光感档位：用户报"卡"时，这一行决定了我们从哪儿查。
    uiTrace('optics', 'resolve', {
      'preset': optics.preset.name,
      'blade': optics.blade,
      'blur': optics.blurSigma,
      'anticipation': optics.anticipation,
      'lowPower': performance.lightweight,
    });
    _themesFor(
      ref.watch(accentProvider),
      ref.watch(surfacePaletteProvider),
      locale.languageCode == 'en',
      performance.blur,
      reduced,
      fluid,
    );
    if (!waiting && !_settled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _settled = true);
    }
    final reducedChanged = _reducedBefore != null && _reducedBefore != reduced;
    _reducedBefore = reduced;
    return MaterialApp(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      theme: _light,
      darkTheme: _dark,
      themeMode: themeMode,
      // Palette and light / dark changes cross-fade the whole app (AppMotion).
      // A reveal from the finger brings the new colours in itself.
      // Never AnimationStyle.noAnimation: MaterialApp then swaps AnimatedTheme for Theme, and
      // everything under builder (the launch screen mid-motion too) is built anew.
      themeAnimationStyle: _settled && !reduced && !reducedChanged && !ThemeRevealHost.active
          ? AnimationStyle(duration: AppMotion.standard, curve: AppMotion.std)
          : AnimationStyle(duration: Duration.zero),
      // zh_CN, not bare zh: otherwise CJK falls back to Japanese glyph shapes
      // on non-Chinese system locales. English keeps Chinese glyphs through
      // the theme's text locale (_themesFor).
      locale: locale,
      supportedLocales: AppLocale.supported,
      localizationsDelegates: const [L10n.delegate, ...GlobalMaterialLocalizations.delegates],
      // A phone on its side: the cutout's inset on both sides (side_insets). Over everything,
      // the launch screen of a cold start (启动画面).
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          key: _layers,
          data: media.copyWith(disableAnimations: media.disableAnimations || performance.reduceMotion),
          child: AppMotionScope(
            fluid: fluid,
            child: OpticsScope(
              optics: optics,
              child: ThemeRevealHost(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  LaunchUnder(
                    child: Platform.operatingSystem == 'ohos'
                        ? EasedKeyboardInset(child: MirroredSideInsets(child: child!))
                        : MirroredSideInsets(child: child!),
                  ),
                  // 光刃：全 App 只有一条，画在根 Stack 最上层——它表达的是"引擎在干什么"，
                  // 与当前是哪一页无关。之前放在页面内容之下，被顶栏和内容整块盖住了，
                  // 这就是"光刃没生效"的真正原因。
                  Positioned(
                    left: 10,
                    right: 10,
                    top: media.padding.top + 2,
                    child: const AppBlade(),
                  ),
                  const Positioned.fill(child: IgnorePointer(child: EdgeAfterglow())),
                  const LaunchLayer(),
                ],
                ),
              ),
            ),
          ),
        );
      },
      home: widget.home ?? const RootGate(),
    );
  }
}

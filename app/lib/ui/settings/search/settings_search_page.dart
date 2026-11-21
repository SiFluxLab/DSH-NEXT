// 搜索设置: the field on top; before typing, a few common words and the last
// searches; then results in two groups (设置, 功能), each a title and the way
// there; with none, 「问 AI」 with the question as typed. A result opens its
// page straight over this one — back comes here — with the row lit.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../l10n/l10n.dart';
import '../../../performance/performance_state.dart';
import '../../../state/android_features.dart';
import '../../../state/ask_ai.dart' show askAiAvailableProvider;
import '../../../state/engine_settings_state.dart';
import '../../../state/hosts_state.dart';
import '../../../state/phone_state.dart';
import '../../../state/plugin_config/plugin_config_state.dart';
import '../../../state/plugins_state.dart';
import '../../../state/sessions_state.dart';
import '../../../state/workshop_dependencies.dart' show workshopOriginProvider;
import '../../common/app_sheet.dart' show groupTitleStyle;
import '../../common/ask_ai.dart';
import '../../common/capsule_chip.dart';
import '../../common/list_page_row.dart';
import '../../common/overview_card.dart' show OverviewChevron;
import '../../common/search_capsule.dart';
import '../../features/all_features_page.dart' show dshWebOpenerProvider;
import '../../features/feature_catalog.dart';
import '../../engine_settings/engine_settings_page.dart' show isPluginForm, namespaceTitle;
import '../../features/feature_widgets.dart' show FeatureMessage;
import '../../kit/kit.dart';
import '../../plugins/config/plugin_config_entries.dart';
import '../../shell/page_frame.dart';
import '../../theme/app_icons.dart';
import '../../theme/theme.dart';
import '../index/settings_pages.dart';
import '../settings_polish.dart' show HitText;
import 'settings_search.dart';

/// The last searches that led somewhere, newest first ([limit] at most), kept
/// in `settings_search.recent`.
class RecentSearches extends Notifier<List<String>> {
  static const key = 'settings_search.recent';
  static const limit = 5;

  @override
  List<String> build() {
    unawaited(_load());
    return const [];
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(key);
    if (stored != null && state.isEmpty) state = stored.take(limit).toList();
  }

  Future<void> add(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    state = [q, ...state.where((s) => s != q)].take(limit).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, state);
  }
}

final recentSearchesProvider = NotifierProvider<RecentSearches, List<String>>(RecentSearches.new);

/// Why [condition] keeps an entry from showing right now; null when it shows.
String? unavailableReason(WidgetRef ref, SpotCondition? condition, L10n l10n) {
  final met = switch (condition) {
    null => true,
    SpotCondition.localHost => ref.watch(activeHostProvider).isLocal,
    SpotCondition.phoneControlOn => ref.watch(phoneProvider.select((s) => !s.loaded || s.status.enabled)),
    SpotCondition.nativeUi => ref.watch(askAiAvailableProvider),
    SpotCondition.openChat => ref.watch(currentSessionProvider) != null,
    SpotCondition.workshopBuilt => ref.watch(workshopOriginProvider) != null,
    SpotCondition.animationsOn =>
      !ref.watch(performanceDefaultsProvider.select((d) => d.reduceMotion)) &&
          !WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations,
    // Unknown until the host answers; the page says so itself.
    SpotCondition.engineField => true,
  };
  return met ? null : condition!.label(l10n);
}

class SettingsSearchPage extends ConsumerStatefulWidget {
  const SettingsSearchPage({super.key});

  static Route<void> route() => MaterialPageRoute<void>(builder: (_) => const SettingsSearchPage());

  /// The few words offered before anything is typed.
  static List<String> suggestions(L10n l10n) => [
    l10n.searchSuggestDark,
    l10n.searchSuggestBackground,
    l10n.searchSuggestPermission,
    l10n.searchSuggestTextSize,
  ];

  @override
  ConsumerState<SettingsSearchPage> createState() => _SettingsSearchPageState();
}

class _SettingsSearchPageState extends ConsumerState<SettingsSearchPage> {
  final _field = TextEditingController();
  final _focus = FocusNode();
  static final _zh = lookupL10n(AppLocale.zhCN);
  static final _en = lookupL10n(AppLocale.en);

  /// 回车要打开的那一条(就是这一帧的第一条结果)。在 build 里算,因为可用性
  /// 判断要 `ref.watch`;回调只负责执行。
  VoidCallback? _enter;

  @override
  void dispose() {
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _fill(String text) {
    _field.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    setState(() {});
  }

  void _clear() {
    _field.clear();
    setState(() {});
    _focus.requestFocus();
  }

  void _remember() => unawaited(ref.read(recentSearchesProvider.notifier).add(_field.text));

  void _openSpot(SettingSpot spot, {required bool available}) {
    _remember();
    final session = ref.read(currentSessionProvider);
    if (available) {
      unawaited(openSpot(context, spot, sessionId: session));
      return;
    }
    // Not there right now: the page it would be on, which says why.
    final page = spot.isEntry ? SettingsIndex.page(spot.opens!).parent ?? SettingsPageId.hub : spot.page;
    unawaited(
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => settingsPage(page, sessionId: session))),
    );
  }

  void _openFeature(FeatureItem item) {
    _remember();
    final session = ref.read(currentSessionProvider);
    if (item.native case final page?) {
      unawaited(Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page(session))));
    } else if (item.action case final action?) {
      unawaited(Future.sync(() => action(context, ref, session)));
    } else if (item.webFor(session) case final target?) {
      ref.read(dshWebOpenerProvider)(context, ref, target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final query = _field.text;
    final extra = ref.watch(_pluginSpotsProvider);
    final androidFeatures = ref.watch(androidSystemFeaturesProvider);
    List<SearchHit> search({required bool androidFeatures}) => searchSettings(
      query,
      spots: [...SettingsIndex.spots, ...extra],
      features: ref.watch(featureSectionsProvider),
      zh: _zh,
      en: _en,
      androidFeatures: androidFeatures,
      ios: ref.watch(operatingSystemProvider) == 'ios',
    );
    final hits = query.trim().isEmpty ? const <SearchHit>[] : search(androidFeatures: androidFeatures);
    final session = ref.watch(currentSessionProvider);
    // 回车直达:按下的那一下应当等于点第一条。这里顺手把"第一条为什么打不开"
    // 也一起算好(和结果行显示的原因同一份判断),免得两处说法不一致。
    String? reasonFor(SettingSpot spot) =>
        unavailableReason(ref, spot.condition, l10n) ??
        (spot.isEntry ? null : unavailableReason(ref, SettingsIndex.page(spot.page).condition, l10n));
    final first = hits.isEmpty ? null : hits.first;
    if (first == null) {
      _enter = null;
    } else {
      final spot = first.spot;
      _enter = spot != null
          ? () => _openSpot(spot, available: reasonFor(spot) == null)
          : () => _openFeature(first.feature!);
    }
    return AppPage(
      title: l10n.searchSettingsHint,
      hero: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
        // 硬键盘(平板、桌面预览、外接键盘)的回车由这一层接住:焦点还在输入框里,
        // 键事件会从它往上冒到这里。输入法的「搜索」键走的是 EditableText 的
        // onSubmitted,而 SearchCapsule 没有暴露它 —— 见报告里的未做项。
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            final key = event.logicalKey;
            if (key != LogicalKeyboardKey.enter && key != LogicalKeyboardKey.numpadEnter) {
              return KeyEventResult.ignored;
            }
            final enter = _enter;
            if (enter == null) return KeyEventResult.ignored;
            enter();
            return KeyEventResult.handled;
          },
          child: SearchCapsule(
            key: const ValueKey('settings-search-field'),
            controller: _field,
            focusNode: _focus,
            autofocus: true,
            hint: l10n.searchSettingsHint,
            onChanged: (_) => setState(() {}),
            onClear: _clear,
          ),
        ),
      ),
      slivers: [
        SliverList.list(
          children: [
            if (query.trim().isEmpty)
              ..._idle(context)
            else if (hits.isEmpty)
              _NoResults(query: query.trim(), notHere: !androidFeatures && search(androidFeatures: true).isNotEmpty)
            else ...[
              for (final (title, group) in [
                (l10n.commonSettings, hits.where((h) => !h.isFeature).toList()),
                (l10n.searchFeatures, hits.where((h) => h.isFeature).toList()),
              ])
                if (group.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: ListPageCard(
                      title: title,
                      children: [
                        for (final hit in group)
                          if (hit.spot case final spot?)
                            _SpotResult(hit: hit, spot: spot, query: query, onOpen: _openSpot)
                          else
                            _HitRow(
                              title: hit.feature!.title,
                              query: query,
                              subtitle: [l10n.hubSettingsAllFeatures, hit.section!.title].join(' › '),
                              onTap: hit.feature!.needsSession && session == null
                                  ? null
                                  : () => _openFeature(hit.feature!),
                            ),
                      ],
                    ),
                  ),
            ],
          ],
        ),
      ],
    );
  }

  List<Widget> _idle(BuildContext context) {
    final l10n = context.l10n;
    final recent = ref.watch(recentSearchesProvider);
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        child: Semantics(header: true, child: Text(l10n.searchCommon, style: groupTitleStyle(context))),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final word in SettingsSearchPage.suggestions(l10n))
              CapsuleChoiceChip(label: word, selected: false, onSelected: () => _fill(word)),
          ],
        ),
      ),
      if (recent.isNotEmpty)
        ListPageCard(
          title: l10n.searchRecent,
          children: [
            for (final q in recent)
              ListPageRow(icon: AppIcons.history, title: q, chevron: false, onTap: () => _fill(q)),
          ],
        ),
    ];
  }
}

/// A plugin's own settings form, found once the host has said it has one,
/// under the name 设置 › 引擎参数 › 插件 lists it by (in both languages).
/// Only when the host's settings were read already: opening search doesn't
/// ask the host for them.
final _pluginSpotsProvider = Provider.autoDispose<List<SettingSpot>>((ref) {
  if (ref.exists(pluginConfigProvider)) {
    if (ref.watch(pluginConfigProvider).value case final config?) {
      final bundles = ref.watch(installedPluginsProvider.select((s) => s.value));
      return [
        for (final ns in pluginConfigEntries(config))
          pluginFormSpot(ns, (l) => pluginConfigTitle(ns, bundles, state: config, l10n: l)),
      ];
    }
  }
  if (!ref.exists(engineSettingsProvider)) return const [];
  final settings = ref.watch(engineSettingsProvider).value;
  if (settings == null) return const [];
  // Plugins only (PluginConfigScope), so only once the plugin list was read.
  if (!ref.exists(installedPluginsProvider)) return const [];
  final scope = ref.watch(pluginConfigScopeProvider);
  return [
    for (final view in settings.namespaces.values)
      if (isPluginForm(view) && scope.allows(view.ns)) pluginFormSpot(view.ns, (_) => namespaceTitle(view.ns)),
  ];
});

class _SpotResult extends ConsumerWidget {
  const _SpotResult({required this.hit, required this.spot, required this.query, required this.onOpen});

  final SearchHit hit;
  final SettingSpot spot;

  /// 用户打的那几个字:标题里命中的一段要标出来。
  final String query;
  final void Function(SettingSpot spot, {required bool available}) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // An entry is there when its page is; a row when it and its page are.
    final reason =
        unavailableReason(ref, spot.condition, l10n) ??
        (spot.isEntry ? null : unavailableReason(ref, SettingsIndex.page(spot.page).condition, l10n));
    return _HitRow(
      title: spot.titleOn(harmony: ref.watch(operatingSystemProvider) == 'ohos')(l10n),
      query: query,
      note: hit.synonym,
      subtitle: reason ?? SettingsIndex.path(spot, l10n).join(' › '),
      onTap: () => onOpen(spot, available: reason == null),
    );
  }
}

/// 一条结果:**命中处高亮**。
///
/// 为什么不用 `ListPageRow`:它的标题是一整段字符串,而这里要把用户打的那几个
/// 字单独染一下色。行高、左缘 16、右缘箭头、12/70% 的副标题一律照搬列表页的
/// 规格,所以看起来仍是同一张卡里的同一种行 —— 只是标题里多了一处强调。
class _HitRow extends StatelessWidget {
  const _HitRow({required this.title, required this.query, required this.subtitle, this.note, this.onTap});

  final String title;
  final String query;
  final String subtitle;

  /// 命中的同义词,跟在标题后面(三级色)。
  final String? note;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = DshColors.of(context);
    final two = subtitle.isNotEmpty;
    final chevron = onTap != null;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: two ? Kit.rowHeightTwo : Kit.rowHeight),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            ListPageRow.horizontal,
            10,
            chevron ? ListPageRow.trailingPad : ListPageRow.horizontal,
            10,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    HitText(
                      title,
                      query: query,
                      suffix: note,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontSize: 14,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    if (two) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          height: 1.4,
                          color: colors.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (chevron) ...[const SizedBox(width: 4), const OverviewChevron()],
            ],
          ),
        ),
      ),
    );
  }
}

/// No settings matched: the question, as typed, for 问 AI (not in 网页模式,
/// where there is no native chat to take it).
class _NoResults extends ConsumerWidget {
  const _NoResults({required this.query, required this.notHere});

  final String query;

  /// Android's version would have found it: a feature this one lacks, not a typo.
  final bool notHere;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FeatureMessage(icon: AppIcons.noResults, title: notHere ? l10n.harmonySearchUnavailable : l10n.searchNoResults),
        if (ref.watch(askAiAvailableProvider))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: AskAiLink(label: l10n.searchAskAi(query), onPressed: () => unawaited(askAiQuestion(context, query))),
          ),
      ],
    );
  }
}

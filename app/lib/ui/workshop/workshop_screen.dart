// 创意工坊: pets and companions other people made (发现), what came from
// there onto this phone (已安装), and what this person sent in (我的投稿).
//
// A list page with a detail sheet, like the plugin market
// (docs/design/page-design.md §1 C, §3 插件). Every state it shows comes from
// lib/state/workshop_*.dart; nothing here decides what may be installed,
// removed or sent (docs/design/workshop-app.md).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/workshop_catalog_state.dart';
import '../../state/builtin_plugins_state.dart';
import '../../state/workshop_dependencies.dart';
import '../../state/workshop_installed_state.dart';
import '../../workshop/workshop_models.dart';
import '../../kit/kit.dart';
import '../../state/ui_kit_state.dart';
import '../common/segmented_pill.dart';
import '../shell/page_frame.dart';
import '../theme/app_icons.dart';
import 'workshop_browse.dart';
import 'workshop_installed.dart';
import 'workshop_mine.dart';
import 'workshop_report_sheet.dart';

enum WorkshopTab { browse, installed, mine }

/// Whether this build knows a workshop to talk to. Entries to the page are
/// only shown when it does.
/// Whether 创意工坊 can be opened at all: this build has a Worker, and the
/// 内置插件 switch for it is on (state/builtin_plugins_state.dart).
final workshopAvailableProvider = Provider<bool>(
  (ref) => ref.watch(workshopOriginProvider) != null && ref.watch(builtinPluginEnabledProvider(BuiltinPlugin.workshop)),
);

class WorkshopScreen extends ConsumerStatefulWidget {
  const WorkshopScreen({super.key, this.initialTab = WorkshopTab.browse});

  final WorkshopTab initialTab;

  @override
  ConsumerState<WorkshopScreen> createState() => _WorkshopScreenState();
}

class _WorkshopScreenState extends ConsumerState<WorkshopScreen> {
  late WorkshopTab _tab = widget.initialTab;
  bool _refreshing = false;

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      // Each controller keeps its own failure (shown in place); a pull just
      // asks the tab on screen to read again.
      switch (_tab) {
        case WorkshopTab.browse:
          await ref.read(workshopCatalogProvider.notifier).refresh();
        case WorkshopTab.installed:
          // The result on screen when the pull began; one that arrives during
          // it is news and stays.
          final shown = ref.read(workshopInstalledProvider).removal;
          // Updates and withdrawals come from the catalogue: ask it first, then
          // have the rows take what it brought.
          await ref.read(workshopCatalogProvider.notifier).refresh();
          if (!mounted) return;
          await ref.read(workshopInstalledProvider.notifier).refresh();
          if (!mounted) return;
          // The pull read the phone again. If that worked, what the rows say
          // is current and the last uninstall's result has nothing to add.
          final now = ref.read(workshopInstalledProvider);
          if (now.loadError == null && identical(now.removal, shown)) {
            ref.read(workshopInstalledProvider.notifier).acknowledgeRemoval();
          }
        case WorkshopTab.mine:
          await refreshWorkshopMine(ref);
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _report(WorkshopEntry entry) => unawaited(showWorkshopReportSheet(context, entry));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scroll = ScrollConfiguration.of(context);
    // Pull down to read again, however short the list.
    return ScrollConfiguration(
      behavior: scroll.copyWith(physics: AlwaysScrollableScrollPhysics(parent: scroll.getScrollPhysics(context))),
      child: RefreshIndicator(
        onRefresh: _refresh,
        edgeOffset: MediaQuery.paddingOf(context).top + 56,
        child: AppPage(
          title: l10n.workshopTitle,
          subtitle: Text(l10n.workshopSubtitle),
          actions: [
            GlassIconButton(
              icon: AppIcons.refresh,
              tooltip: l10n.workshopRefresh,
              onPressed: _refreshing ? null : () => unawaited(_refresh()),
            ),
          ],
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                // 三格视图切换。开着「页签胶囊」时用 prism 那套（每枚自带底、120ms 点亮），
                // 关掉就退回原来的分段胶囊——它是可选功能，不是替换。
                child: ref.watch(uiKitProvider).segmented
                    ? Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: KitSegmented<WorkshopTab>(
                          items: [
                            (WorkshopTab.browse, l10n.workshopTabBrowse),
                            (WorkshopTab.installed, l10n.commonInstalled),
                            (WorkshopTab.mine, l10n.workshopTabMine),
                          ],
                          value: _tab,
                          onChanged: (t) => setState(() => _tab = t),
                        ),
                      )
                    : SegmentedPill<WorkshopTab>(
                        segments: [
                          PillSegment(WorkshopTab.browse, l10n.workshopTabBrowse),
                          PillSegment(WorkshopTab.installed, l10n.commonInstalled),
                          PillSegment(WorkshopTab.mine, l10n.workshopTabMine),
                        ],
                        selected: _tab,
                        onChanged: (t) => setState(() => _tab = t),
                      ),
              ),
            ),
            switch (_tab) {
              WorkshopTab.browse => WorkshopBrowseSliver(
                onSubmit: () => setState(() => _tab = WorkshopTab.mine),
                onReport: _report,
              ),
              WorkshopTab.installed => WorkshopInstalledSliver(
                onBrowse: () => setState(() => _tab = WorkshopTab.browse),
              ),
              WorkshopTab.mine => const WorkshopMineSliver(),
            },
          ],
        ),
      ),
    );
  }
}

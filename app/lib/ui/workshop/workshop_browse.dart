// 「发现」: the public catalogue as an app-store list (search, kind chips,
// rows), with the cached content up first and a refresh that never takes the
// old rows away (docs/design/workshop-app.md).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/attachments.dart' show formatBytes;
import '../../state/workshop_catalog_state.dart';
import '../../state/workshop_install_state.dart';
import '../../workshop/workshop_models.dart';
import '../../workshop/workshop_repository.dart';
import '../common/capsule_chip.dart';
import '../common/empty_view.dart';
import '../common/fade_in.dart';
import '../common/search_capsule.dart';
import '../plugins/list_chrome.dart';
import '../theme/app_icons.dart';
import 'workshop_item_sheet.dart';
import 'workshop_text.dart';
import 'workshop_widgets.dart';

/// The slivers of the 发现 tab. [onSubmit] is offered when the catalogue is
/// empty; [onReport] is passed on to the detail sheet.
class WorkshopBrowseSliver extends ConsumerStatefulWidget {
  const WorkshopBrowseSliver({super.key, this.onSubmit, this.onReport});

  final VoidCallback? onSubmit;
  final ValueChanged<WorkshopEntry>? onReport;

  @override
  ConsumerState<WorkshopBrowseSliver> createState() => _WorkshopBrowseSliverState();
}

class _WorkshopBrowseSliverState extends ConsumerState<WorkshopBrowseSliver> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    // Made here, not on first use: a page that never showed the field (no
    // catalogue yet) must not reach for providers while it is torn down.
    _search = TextEditingController(text: ref.read(workshopCatalogProvider).query);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clear() {
    _search.clear();
    ref.read(workshopCatalogProvider.notifier).setQuery('');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(workshopCatalogProvider);
    final controller = ref.read(workshopCatalogProvider.notifier);
    final items = state.visibleItems;
    final snapshot = state.snapshot;
    final filtering = state.query.trim().isNotEmpty || state.kind != WorkshopKindFilter.all;
    // 组标题就是当前筛的那一类：列表里看到什么，标题就说什么，不另起一个"全部作品"。
    final groupTitle = switch (state.kind) {
      WorkshopKindFilter.all => l10n.workshopKindAll,
      WorkshopKindFilter.pet => l10n.workshopKindPet,
      WorkshopKindFilter.companion => l10n.workshopKindCompanion,
    };

    // Nothing to draw yet, and nothing cached: six cards where the list will be.
    // 骨架而不是转圈：列表到位时是"填满"，版面不跳（见 [ListSkeleton]）。
    if (state.loading && snapshot == null) {
      return SliverToBoxAdapter(
        child: ListSkeleton(
          rows: 6,
          avatar: 40,
          lines: 3,
          trailing: 84,
          label: l10n.remoteLoading,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        ),
      );
    }
    // No catalogue at all: say why, offer one retry.
    if (snapshot == null) {
      final unconfigured = state.refreshError == 'workshop_unconfigured';
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 40),
          child: EmptyView(
            icon: unconfigured ? AppIcons.workshop : AppIcons.offline,
            title: unconfigured ? l10n.workshopNotOpenTitle : l10n.workshopUnavailableTitle,
            message: unconfigured ? l10n.workshopNotOpenMessage : workshopErrorText(l10n, state.refreshError),
            actionLabel: unconfigured ? null : l10n.commonRetry,
            onAction: unconfigured || state.refreshing ? null : () => unawaited(controller.refresh()),
          ),
        ),
      );
    }

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: SearchCapsule(
              controller: _search,
              hint: l10n.workshopSearchHint,
              onChanged: controller.setQuery,
              onClear: _clear,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              children: [
                for (final (kind, label) in [
                  (WorkshopKindFilter.all, l10n.workshopKindAll),
                  (WorkshopKindFilter.pet, l10n.workshopKindPet),
                  (WorkshopKindFilter.companion, l10n.workshopKindCompanion),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: CapsuleChoiceChip(
                      label: label,
                      selected: state.kind == kind,
                      onSelected: () => controller.setKind(kind),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (state.refreshError case final code?)
          SliverToBoxAdapter(
            child: WorkshopNote(
              '${l10n.workshopShowingOlder(l10n.monthDay(snapshot.fetchedAt.toLocal()))} ${workshopErrorLine(l10n, code)}',
              actionLabel: l10n.commonRetry,
              onAction: state.refreshing ? null : () => unawaited(controller.refresh()),
            ),
          ),
        if (!state.localStateKnown) SliverToBoxAdapter(child: WorkshopNote(l10n.workshopLocalUnknown)),
        if (items.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 24),
              child: filtering
                  ? EmptyView(icon: AppIcons.search, title: l10n.workshopNoMatchTitle, message: l10n.workshopNoMatchMessage)
                  : EmptyView(
                      icon: AppIcons.workshop,
                      title: l10n.workshopEmptyTitle,
                      message: l10n.workshopEmptyMessage,
                      // 空态只给一个动作，而且它会在停留 3s 后自己"呼吸"一次
                      // （[EmptyAction]）——一个安静的画面里，唯一的出口值得被注意到一次。
                      action: widget.onSubmit == null ? null : EmptyAction(
                        label: l10n.workshopTabMine,
                        onPressed: widget.onSubmit,
                      ),
                    ),
            ),
          )
        else ...[
          // 组标题 + 右侧计数：计数在后台变了会滚一次（不是直接换字）。
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              child: WorkshopGroupHeader(title: groupTitle, count: items.length),
            ),
          ),
          SliverList.builder(
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              // 一张作品一张卡，卡与卡之间 12（卡自己带 margin）；点击进详情，
              // 长按抬升 2px 只是"我按住的是这一张"的确认，不带菜单。
              return FadeSlideIn(
                index: i,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: WorkshopItemRow(
                    key: ValueKey(item.entry.metadata.identity),
                    item: item,
                    onReport: widget.onReport,
                  ),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
        ],
      ],
    );
  }
}

/// One catalogue card: square · title 13.5/600 · 作者 · description (two lines)
/// · 标签行 · 右下角版本与大小 · the capsule.
class WorkshopItemRow extends ConsumerWidget {
  const WorkshopItemRow({super.key, required this.item, this.onReport});

  final WorkshopItemState item;
  final ValueChanged<WorkshopEntry>? onReport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final meta = item.entry.metadata;
    final locale = Localizations.localeOf(context).languageCode;
    final running = ref.watch(
      workshopInstallProvider.select((s) => s.busy && s.entry?.metadata.identity == meta.identity),
    );
    final description = meta.description.trim();
    void open() => unawaited(showWorkshopItemSheet(context, item, onReport: onReport));
    return WorkshopCard(
      avatar: WorkshopEntryAvatar(item.entry, size: 40),
      title: workshopTitleOf(meta, locale),
      line: l10n.workshopByAuthor(meta.author),
      description: description.isEmpty ? null : description,
      chips: workshopTagChips(context, meta),
      // 元信息只写**真实存在**的两件事：发行版本与包大小（同一份 metadata 给的）。
      // 不写"下载量""评分"——工坊没有这两个数，编一个出来就是假数据。
      meta: '${meta.version} · ${formatBytes(meta.size)}',
      trailing: WorkshopGetButton(
        state: running
            ? WorkshopGetState.running
            : item.updateAvailable
            ? WorkshopGetState.update
            : item.installed != null
            ? WorkshopGetState.installed
            : WorkshopGetState.get,
        onPressed: open,
      ),
      onTap: open,
    );
  }
}

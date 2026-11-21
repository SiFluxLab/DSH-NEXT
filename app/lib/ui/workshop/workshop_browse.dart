// 「发现」: the public catalogue as an app-store list (search, kind chips,
// rows), with the cached content up first and a refresh that never takes the
// old rows away (docs/design/workshop-app.md).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/workshop_catalog_state.dart';
import '../../state/workshop_install_state.dart';
import '../../workshop/workshop_models.dart';
import '../../workshop/workshop_repository.dart';
import '../common/capsule_chip.dart';
import '../common/empty_view.dart';
import '../common/fade_in.dart';
import '../common/search_capsule.dart';
import '../kit/kit_list.dart';
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

    // Nothing to draw yet, and nothing cached: one quiet ring.
    if (state.loading && snapshot == null) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.only(top: 64),
          child: Center(child: SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2))),
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
                      actionLabel: widget.onSubmit == null ? null : l10n.workshopTabMine,
                      onAction: widget.onSubmit,
                    ),
            ),
          )
        else
          SliverList.builder(
            itemCount: items.length,
            itemBuilder: (context, i) {
              final first = i == 0;
              final last = i == items.length - 1;
              final item = items[i];
              return FadeSlideIn(
                index: i,
                // 目录是一张连续的分组卡：首末行圆角 12、行间 0.5px、外缘 1px 实线
                // （规格 page-composition §2.2 与 theme-ui §3.2）。整张卡不能在懒加载
                // 里一次画出来，所以按行拼。
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: KitRowSurface(
                    position: items.length == 1
                        ? KitRowPosition.single
                        : first
                        ? KitRowPosition.first
                        : last
                        ? KitRowPosition.last
                        : KitRowPosition.middle,
                    child: WorkshopItemRow(
                      key: ValueKey(item.entry.metadata.identity),
                      item: item,
                      onReport: widget.onReport,
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// One catalogue row: square · title / author · one line · the capsule.
class WorkshopItemRow extends ConsumerWidget {
  const WorkshopItemRow({super.key, required this.item, this.onReport});

  final WorkshopItemState item;
  final ValueChanged<WorkshopEntry>? onReport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = item.entry.metadata;
    final locale = Localizations.localeOf(context).languageCode;
    final running = ref.watch(
      workshopInstallProvider.select((s) => s.busy && s.entry?.metadata.identity == meta.identity),
    );
    final description = meta.description.trim();
    void open() => unawaited(showWorkshopItemSheet(context, item, onReport: onReport));
    // 14/500 标题 + 12/70% 说明 + 32 的条目方块 + 行尾 field 控件：一行就是一条
    // 列表行（规格 theme-ui §3.1 / page-composition §7.8）。
    return KitRow(
      leading: WorkshopEntryAvatar(item.entry, size: 32),
      title: workshopTitleOf(meta, locale),
      note: [meta.author, if (description.isNotEmpty) description.split('\n').first].join(' · '),
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

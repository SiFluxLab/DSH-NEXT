// 状态筛选：从"一排胶囊"收成"一枚胶囊 + 弹出面板"。
//
// 参考 open-vetta 的 `AbilityFilterPopover`：筛选条件不常改，却常年占着一行；
// 收进一枚显示"当前条件 + 命中数"的胶囊，点开才展开全部选项。省下的那一行
// 直接还给了会话列表。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../state/drawer_view_state.dart';
import '../../../state/session_attention_state.dart';
import '../../common/list_page_row.dart';
import '../../common/app_sheet.dart';
import '../../common/capsule_chip.dart';
import '../../common/read_list_status.dart';
import '../../theme/app_icons.dart';
import '../../theme/theme.dart';

class DrawerFilterCapsule extends ConsumerWidget {
  const DrawerFilterCapsule({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final filter = ref.watch(drawerFilterProvider);
    final scope = ref.watch(drawerScopeProvider);
    if (scope == null || (scope.sessions.isEmpty && filter == DrawerFilter.all)) {
      return const SizedBox.shrink();
    }
    final counts = _counts(ref, scope);
    final active = counts[filter] ?? 0;
    final label = filter == DrawerFilter.all ? l10n.stateDrawerAll : filter.label;
    return Semantics(
      button: true,
      label: l10n.shellFilterLabel(label),
      child: CapsuleChoiceChip(
        // 非"全部"时把命中数直接写在胶囊上：不用点开就知道现在看到几条。
        label: filter == DrawerFilter.all ? label : '$label $active',
        selected: filter != DrawerFilter.all,
        icon: AppIcons.configure,
        onSelected: () => showAppSheet<void>(
          context,
          builder: (_) => _FilterSheet(initial: filter),
        ),
      ),
    );
  }
}

/// 每种筛选各自命中多少：面板里用它显示计数徽章。
Map<DrawerFilter, int> _counts(WidgetRef ref, DrawerScope scope) {
  final listed = {for (final s in scope.sessions) s.sessionId};
  final pending = scope.readOnly ? 0 : ref.watch(pendingInteractionsProvider).keys.where(listed.contains).length;
  final unread = scope.readOnly ? 0 : ref.watch(unreadSessionIdsProvider).where(listed.contains).length;
  return {
    DrawerFilter.all: scope.sessions.length,
    DrawerFilter.running: scope.sessions.where((s) => s.running).length,
    DrawerFilter.pending: pending,
    DrawerFilter.unread: unread,
  };
}

class _FilterSheet extends ConsumerWidget {
  const _FilterSheet({required this.initial});

  final DrawerFilter initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scope = ref.watch(drawerScopeProvider);
    final counts = scope == null ? const <DrawerFilter, int>{} : _counts(ref, scope);
    final current = ref.watch(drawerFilterProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Text(l10n.stateDrawerFilterTitle, style: Theme.of(context).textTheme.titleMedium),
        ),
        for (final f in DrawerFilter.values)
          ListPageRow(
            key: ValueKey('drawer-filter-${f.name}'),
            title: f == DrawerFilter.all ? l10n.stateDrawerAll : f.label,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if ((counts[f] ?? 0) > 0)
                  Text('${counts[f]}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                if (f == current) ...[
                  const SizedBox(width: 8),
                  Icon(AppIcons.done, size: 18, color: Theme.of(context).colorScheme.primary),
                ],
              ],
            ),
            onTap: () {
              ref.read(drawerFilterProvider.notifier).set(f);
              Navigator.of(context).maybePop();
            },
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

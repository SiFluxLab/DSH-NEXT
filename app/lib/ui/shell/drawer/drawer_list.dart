// The drawer's conversation list once it has loaded:
// DS Bot's row, 置顶, the folders (opening and closing in place), then the
// rest by day; or, under a status filter, just the matches. Loading, error
// and empty-host states stay with the drawer (sessions_drawer.dart).

import 'dart:async';

import 'package:dsh_client/dsh_client.dart' show SessionSummary;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../state/drawer_view_state.dart';
import '../../../state/session_attention_state.dart';
import '../../../state/session_created_state.dart';
import '../../../state/sessions_state.dart';
import '../../../state/workspaces_state.dart';
import '../../common/empty_view.dart';
import '../../kit/kit.dart';
import '../../theme/app_icons.dart';
import '../../theme/motion.dart';
import '../sessions_drawer.dart' show sessionTitle;
import 'drawer_actions.dart';
import 'entrance.dart';
import 'folder_header.dart';
import 'session_tile.dart';

class DrawerConversationList extends ConsumerStatefulWidget {
  const DrawerConversationList({
    super.key,
    required this.onOpen,
    required this.onLongPress,
    this.onNewChat,
    this.leading,
    this.now,
    this.readOnly = false,
  });

  /// Opens a conversation (and closes the drawer).
  final ValueChanged<String> onOpen;

  /// Closes the drawer after choosing a folder for a new conversation.
  final VoidCallback? onNewChat;

  /// A conversation's actions.
  final void Function(SessionSummary session) onLongPress;

  /// Above everything when nothing is filtered or chosen (DS Bot's row).
  final Widget? leading;

  /// Clock override for the day groups (tests).
  final DateTime? now;
  final bool readOnly;

  /// The list's padding: rows' edges on the drawer's 10 line.
  static const padding = EdgeInsets.fromLTRB(10, 4, 10, 16);

  @override
  ConsumerState<DrawerConversationList> createState() => _DrawerConversationListState();
}

class _DrawerConversationListState extends ConsumerState<DrawerConversationList> {
  /// 列表正在滚动：分组标题在这个期间收紧字距（见 [DrawerEyebrow]）。
  /// 只按"开始 / 结束"翻转，不跟每一帧走——跟帧就要每帧重建整列。
  bool _scrolling = false;

  /// 刚落地的那一行（[SessionTile.landed]），播完 [landing] 就撤。
  String? _landed;
  Timer? _landedTimer;

  /// 上一帧见过的会话 id：用来认出"这一行是刚出现的"。
  /// 抽屉关着的时候照样记（只是不闪），于是"打开抽屉"本身不会被当成新会话。
  Set<String>? _known;

  /// 落地高光留多久：比它自己那 320ms 稍长一点，够它亮完并停在 0，
  /// 之后这一行就不再挂着动画了。
  static const landing = Duration(milliseconds: 400);

  @override
  void dispose() {
    _landedTimer?.cancel();
    super.dispose();
  }

  void _setScrolling(bool value) {
    if (_scrolling == value) return;
    // 滚动通知可能来自布局中的更正（收起文件夹后列表变短），
    // 那时直接 setState 会撞上"build 期间又标脏"；推到帧末再翻这个开关。
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrolling != value) setState(() => _scrolling = value);
    });
  }

  /// 一排 id 里只多出一条、而且它是排在最前的那条 → 那就是"刚落地的新对话"。
  /// 换工作区、换筛选会一次多出好几条，那不算落地，不闪。
  void _noteArrivals(List<String> ids) {
    final known = _known;
    if (known != null && known.length == ids.length && ids.every(known.contains)) {
      // 没变：不重建集合（列表每次因为未读、待确认重建时都会走到这里）。
      return;
    }
    _known = ids.toSet();
    if (known == null) return;
    final fresh = [
      for (final id in ids)
        if (!known.contains(id)) id,
    ];
    if (fresh.length != 1 || ids.first != fresh.single) return;
    final id = fresh.single;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // 关着的时候不播（看不见的不该有动画），减少动画时也不播。
      // TickerMode.of 在 3.35 起被弃用：新 API 同时给出 enabled 与 forceFrames，
      // 我们只需要前者（"关着就不播"）。
      if (!TickerMode.valuesOf(context).enabled || !KitMotion.choreography(context)) return;
      setState(() => _landed = id);
      _landedTimer?.cancel();
      _landedTimer = Timer(landing, () {
        if (mounted) setState(() => _landed = null);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final readOnly = widget.readOnly;
    final blocks = watchDrawerBlocks(ref, now: widget.now);
    if (blocks == null) return const SizedBox.shrink();
    _noteArrivals([
      for (final block in blocks)
        for (final s in block.items) s.sessionId,
    ]);
    final selection = ref.watch(drawerSelectionProvider);
    final selecting = !readOnly && selection != null;
    final filter = ref.watch(drawerFilterProvider);
    final current = ref.watch(currentSessionProvider);
    final pending = ref.watch(pendingInteractionsProvider);
    final unread = ref.watch(unreadSessionIdsProvider);
    final pinned = ref.watch(workspacesProvider.select((s) => s.pinnedSessionIds)).toSet();
    final sort = ref.watch(drawerViewProvider.select((v) => v.sort));
    if (!readOnly && sort == DrawerSort.created) {
      final ids = [
        for (final block in blocks)
          for (final s in block.items) s.sessionId,
      ];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) ref.read(sessionCreatedProvider.notifier).ensure(ids);
      });
    }
    final selectionNotifier = ref.read(drawerSelectionProvider.notifier);

    Widget tile(SessionSummary s, {bool inFolder = false}) {
      final id = s.sessionId;
      return SessionTile(
        key: ValueKey('session-$id'),
        title: sessionTitle(s),
        running: s.running,
        current: id == current,
        pending: readOnly ? null : pending[id],
        unread: !readOnly && unread.contains(id),
        pinned: inFolder && pinned.contains(id),
        indent: inFolder ? SessionTile.folderIndent : 0,
        selecting: selecting,
        selected: selection?.contains(id) ?? false,
        landed: id == _landed,
        onTap: selecting ? () => selectionNotifier.toggle(id) : () => widget.onOpen(id),
        onLongPress: readOnly
            ? null
            : selecting
            ? () => selectionNotifier.toggle(id)
            : () => widget.onLongPress(s),
      );
    }

    // Keep only builders for off-screen rows: preparing a title and a tile for
    // every conversation makes even a selection change scale with the history.
    final rows = <({Key key, WidgetBuilder builder})>[];
    void add(Key key, WidgetBuilder builder) => rows.add((key: key, builder: builder));
    void addSessions(List<SessionSummary> items) {
      for (final s in items) {
        add(ValueKey('session-${s.sessionId}'), (_) => tile(s));
      }
    }

    final showLeading = widget.leading != null && filter == DrawerFilter.all && !selecting;
    if (showLeading) {
      const key = ValueKey('leading');
      add(key, (_) => KeyedSubtree(key: key, child: widget.leading!));
    }
    var foldersLabelled = false;
    for (final block in blocks) {
      switch (block) {
        case FilteredBlock(filter: final matching, :final items) when items.isEmpty:
          const key = ValueKey('filter-empty');
          add(key, (_) => _FilterEmpty(matching, key: key));
        case FilteredBlock(:final items):
          addSessions(items);
        case PinnedBlock(:final items):
          const key = ValueKey('pinned-label');
          add(key, (_) => DrawerEyebrow(l10n.commonPin, key: key, scrolling: _scrolling));
          addSessions(items);
        case FolderBlock(:final folder, :final items):
          if (!foldersLabelled) {
            foldersLabelled = true;
            const key = ValueKey('folders-label');
            add(key, (_) => DrawerEyebrow(l10n.shellFolders, key: key, scrolling: _scrolling));
          }
          final headerKey = ValueKey('folder-${folder.id}');
          add(
            headerKey,
            (_) => DrawerFolderHeader(
              key: headerKey,
              folder: folder,
              count: items.length,
              onTap: () => ref.read(drawerViewProvider.notifier).toggleCollapsed(folder.id),
              onLongPress: () {
                if (!readOnly) folderActionsFlow(context, ref, folder, onNewChat: widget.onNewChat);
              },
            ),
          );
          final bodyKey = ValueKey('folder-body-${folder.id}');
          add(
            bodyKey,
            (_) => DrawerFolderBody(
              key: bodyKey,
              open: !folder.collapsed,
              childrenBuilder: () => [for (final s in items) tile(s, inFolder: true)],
            ),
          );
        case DayBlock(:final day, :final items):
          final key = ValueKey('day-${day.name}');
          // 时间分组比结构分组轻一档：一个是"你排的"，一个是"日子排的"。
          add(key, (_) => DrawerEyebrow(sessionDayLabels[day]!, key: key, quiet: true, scrolling: _scrolling));
          addSessions(items);
      }
    }
    // Preserve keyed row/folder state when pinning, sorting or hiding the
    // leading row changes indices. A new filter still starts at the top.
    final indices = {for (var i = 0; i < rows.length; i++) rows[i].key: i};
    return NotificationListener<ScrollNotification>(
      // 滚动开始 / 结束各翻一次开关：分组标题在动的时候收紧字距，
      // 停下再放开（见 [DrawerEyebrow]）。不跟每一帧，空闲不留帧。
      onNotification: (notification) {
        if (notification is ScrollStartNotification && notification.dragDetails != null) {
          _setScrolling(true);
        } else if (notification is ScrollEndNotification) {
          _setScrolling(false);
        }
        return false;
      },
      child: ListView.builder(
        key: ValueKey(filter),
        physics: AppMotion.scrollPhysics(context),
        padding: DrawerConversationList.padding,
        itemCount: rows.length,
        // 每一行按自己的序号参与抽屉打开时的错峰入场（首屏 8 项）。
        itemBuilder: (context, index) =>
            DrawerStagger(key: rows[index].key, index: index, child: rows[index].builder(context)),
        findChildIndexCallback: (key) => indices[key],
      ),
    );
  }
}

/// A status filter with no matches.
class _FilterEmpty extends StatelessWidget {
  const _FilterEmpty(this.filter, {super.key});

  final DrawerFilter filter;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (icon, title) = switch (filter) {
      DrawerFilter.running => (AppIcons.running, l10n.shellNoRunningChats),
      DrawerFilter.pending => (AppIcons.toConfirm, l10n.shellNoPendingChats),
      DrawerFilter.unread => (AppIcons.allRead, l10n.shellNoUnreadChats),
      DrawerFilter.all => (AppIcons.chat, l10n.shellNoChatsYet),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 56),
      child: EmptyView(compact: true, icon: icon, title: title),
    );
  }
}

// 侧边栏翻页器：页签栏 + 可翻页的内容。
//
// 页签栏照 `agegr/pi-web`（Pi 的 Web UI，8300★）的 `components/SessionSidebar.tsx`
// 与 `app/sidebar.css` 的实测量复刻：那些页签是**一排单元格**，格间 1px 分隔线，
// 选中格是"顶部 2px 强调线 + 选中底色 + 字重 500"，图标 13px、间距 6px、
// 左右内边距 12px、行高 44。它在切换页时统一用 180ms 的过渡，开了"减少动态效果"
// 就一步到位——这两点我们都照做。
//
// 手势：pi-web 本身只点不滑；这里按我们的需要加了横向翻页（吸附 + 页间 180ms），
// 并在第 0 页继续向右拉时把位移交给抽屉自己收回（[onPullClose]）。
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/theme.dart';

/// 抽屉的页。顺序就是页签栏的顺序，也是可以左右翻的顺序。
enum DrawerTab {
  sessions,
  files;

  String label(L10n l10n) => switch (this) {
    DrawerTab.sessions => l10n.drawerTabSessions,
    DrawerTab.files => l10n.drawerTabFiles,
  };

  IconData get icon => switch (this) {
    DrawerTab.sessions => AppIcons.chat,
    DrawerTab.files => AppIcons.folder,
  };
}

/// 页签栏。高度 [height]，格与格之间一条 1px 线，选中格顶部一条 2px 主色线。
class DrawerTabBar extends StatelessWidget {
  const DrawerTabBar({super.key, required this.selected, required this.onSelect});

  final DrawerTab selected;
  final ValueChanged<DrawerTab> onSelect;

  /// 44 = 触控最小尺寸，也是 pi-web 那排单元格的实际行高。
  static const height = 44.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, tab) in DrawerTab.values.indexed) ...[
            if (index > 0) VerticalDivider(width: 1, thickness: 1, color: scheme.outlineVariant),
            Expanded(
              child: _TabCell(tab: tab, selected: tab == selected, onTap: () => onSelect(tab)),
            ),
          ],
        ],
      ),
    );
  }
}

class _TabCell extends StatelessWidget {
  const _TabCell({required this.tab, required this.selected, required this.onTap});

  final DrawerTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final foreground = selected ? scheme.onSurface : scheme.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: tab.label(l10n),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? scheme.surfaceContainerHigh : Colors.transparent,
            // 顶部那条线才是"当前页"的标记：它和光刃是同一套语言（光在顶沿）。
            border: Border(
              top: BorderSide(color: selected ? scheme.primary : Colors.transparent, width: 2),
            ),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(tab.icon, size: 13, color: foreground),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    tab.label(l10n),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.2,
                      fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 页签栏下面的翻页区。
///
/// [onPullClose] 只在第 0 页继续向右拉时被调用，参数是这一下已经拉出的像素；
/// 抽屉据此 1:1 跟手收回。第 1 页向右是翻回第 0 页，不触发关闭。
class DrawerPager extends StatefulWidget {
  const DrawerPager({
    super.key,
    required this.tab,
    required this.onTabChanged,
    required this.sessions,
    required this.files,
    this.onPullClose,
    this.onPullRelease,
  });

  final DrawerTab tab;
  final ValueChanged<DrawerTab> onTabChanged;
  final Widget sessions;
  final Widget files;

  /// 拉出抽屉的位移（正数，像素）。
  final ValueChanged<double>? onPullClose;

  /// 松手时的速度（正数 = 向右/向外）。
  final ValueChanged<double>? onPullRelease;

  @override
  State<DrawerPager> createState() => _DrawerPagerState();
}

class _DrawerPagerState extends State<DrawerPager> {
  late final PageController _controller = PageController(initialPage: widget.tab.index);

  @override
  void didUpdateWidget(DrawerPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 点页签（或设置里换了页）时把翻页器带过去，用同一段 180ms。
    if (oldWidget.tab != widget.tab && _controller.hasClients) {
      _controller.animateToPage(
        widget.tab.index,
        duration: _flip(context),
        curve: AppMotion.swift,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 180ms；"减少动态效果"或关掉"预见性动画"时是 0（直接切换）。
  Duration _flip(BuildContext context) {
    final optics = Optics.of(context);
    if (!optics.anticipation || AppMotion.reduced(context)) return Duration.zero;
    return AppMotion.flip;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is OverscrollNotification && notification.dragDetails != null) {
          // 第 0 页继续向右（负的 overscroll）才是"要关抽屉"。
          if (notification.metrics.pixels <= 0 && notification.overscroll < 0) {
            widget.onPullClose?.call(-notification.overscroll);
          }
        } else if (notification is ScrollEndNotification) {
          widget.onPullRelease?.call(0);
        }
        return false;
      },
      child: PageView(
        controller: _controller,
        // Clamping 而不是 Bouncing：我们需要越界事件来接管抽屉，而不是回弹动画。
        physics: const ClampingScrollPhysics(),
        onPageChanged: (index) => widget.onTabChanged(DrawerTab.values[index]),
        children: [
          _Keep(tab: DrawerTab.sessions, child: widget.sessions),
          _Keep(tab: DrawerTab.files, child: widget.files),
        ],
      ),
    );
  }
}

/// 每页各自记住滚动位置：翻回来还在原处。
class _Keep extends StatefulWidget {
  const _Keep({required this.tab, required this.child});

  final DrawerTab tab;
  final Widget child;

  @override
  State<_Keep> createState() => _KeepState();
}

class _KeepState extends State<_Keep> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return KeyedSubtree(key: PageStorageKey(widget.tab.name), child: widget.child);
  }
}

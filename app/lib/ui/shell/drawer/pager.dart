// 侧边栏翻页器：页签栏 + 可翻页的内容。
//
// 页签栏照 `agegr/pi-web`（Pi 的 Web UI，8300★）的 `components/SessionSidebar.tsx`
// 与 `app/sidebar.css` 的实测量复刻：一行 44、图标 13–15px、图标与字之间 6px、
// 切换页统一 180ms，开了"减少动态效果"就一步到位——这几点照做。
//
// 手势：pi-web 本身只点不滑；这里按我们的需要加了横向翻页（吸附 + 页间 180ms），
// 并在第 0 页继续向右拉时把位移交给抽屉自己收回（[onPullClose]）。
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../kit/kit.dart';
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

/// 页签栏：一条**分段控件**（iOS/App Store 那种），不是两枚各自上色的格子。
///
/// 之前的做法是"选中的格子填 12% 主色"——在玻璃抽屉里它读成一块贴上去的色块，
/// 与周围的材质不是同一种东西（用户原话："底下的色块跟项目一点都不搭"）。
/// 分段控件的做法是：一条 5% 前景的轨道 + 一枚会滑动的高光片，两格共用一个控件体，
/// 于是它读作"一个开关"，而不是"两个染色的格子"。
///
/// 三段递进里的第一段（[top] = 8 接搜索框、[bottom] = 12 接列表 4 = 16）：
/// 控件的边线与列表、搜索框、身份栏同一条 10 的线（[edge]）。
class DrawerTabBar extends StatelessWidget {
  const DrawerTabBar({super.key, required this.selected, required this.onSelect});

  final DrawerTab selected;
  final ValueChanged<DrawerTab> onSelect;

  /// 与列表行、搜索胶囊、身份栏同一条 10 的边线。
  static const edge = 10.0;

  /// 轨道上下各 [top] / [bottom]：抽屉四段节奏的 8 / 16 两档（16 = 12 + 列表
  /// 自己的 4）。两片之间只差一档 4，节奏才读作"递进"而不是"到处都是 12"。
  static const top = 8.0;
  static const bottom = 12.0;

  /// 整段占的高度（含上下留白），仍然是原来那行 44 的位置。
  static const height = top + track + bottom;

  /// 轨道高度：34 的槽 + 3 的内缩 → 高光片 28，比 44 的行矮一档，
  /// 于是它读成"行里的一枚控件"，而不是"和行一样高的一格"。
  static const track = 34.0;
  static const _inset = 3.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 暗色下"凸起来"是"更亮"，不是"更白"：轨道和片都按这一条选色。
    final dark = scheme.brightness == Brightness.dark;
    final index = DrawerTab.values.indexOf(selected);
    return Padding(
      padding: const EdgeInsets.fromLTRB(edge, top, edge, bottom),
      child: SizedBox(
        height: track,
        child: LayoutBuilder(
          builder: (context, box) {
            final cellWidth = box.maxWidth / DrawerTab.values.length;
            return Stack(
              children: [
                // 轨道。取色和全站的 [SegmentedPill] 同一套（暗色 7% 白、浅色 6% 前景）：
                // 同一个控件在抽屉里和在设置里不该是两种灰。
                // 半像素的内缘是"凹槽"的全部来源：只有一层浅底的时候，浅色主题里它
                // 读成"一块更浅的区域"，加了内缘才读成"下陷的一条槽"。
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: dark
                          ? Colors.white.withValues(alpha: 0.07)
                          : scheme.onSurface.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(AppShape.sm),
                      border: Border.all(
                        color: dark
                            ? Colors.white.withValues(alpha: 0.04)
                            : scheme.onSurface.withValues(alpha: 0.045),
                        width: 0.5,
                      ),
                    ),
                  ),
                ),
                // 高光片：滑动，而不是两格各自变色。
                AnimatedPositioned(
                  duration: KitMotion.of(context, AppMotion.flip),
                  curve: AppMotion.swift,
                  left: cellWidth * index + _inset,
                  top: _inset,
                  bottom: _inset,
                  width: cellWidth - _inset * 2,
                  child: _Thumb(dark: dark),
                ),
                // 两格的可点区域与文字
                Positioned.fill(
                  child: Row(
                    children: [
                      for (final tab in DrawerTab.values)
                        Expanded(
                          child: _TabCell(tab: tab, selected: tab == selected, onTap: () => onSelect(tab)),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 会滑动的那片高光：浮起来的键，不是一块填色。
///
/// 它比轨道亮一档（surface 对 5% 前景），带一道 0.5 的外缘和两层很轻的落影；
/// 顶沿再压一条 5% 的**内阴影**——真机上"片是凸的、槽是凹的"全靠这两下，
/// 少了任何一条，两格就又会读成两块平涂的色块。
class _Thumb extends StatelessWidget {
  const _Thumb({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppShape.sm - 3);
    return DecoratedBox(
      decoration: BoxDecoration(
        // 浅色：一片白（比 6% 的轨道亮一档）。暗色：20% 白（[SegmentedPill] 的同一档）。
        color: dark ? Colors.white.withValues(alpha: 0.20) : Colors.white,
        borderRadius: radius,
        border: Border.all(
          color: dark ? Colors.white.withValues(alpha: 0.06) : scheme.onSurface.withValues(alpha: 0.05),
          width: 0.5,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 3, offset: Offset(0, 1)),
          BoxShadow(color: Color(0x0A000000), blurRadius: 9, offset: Offset(0, 2), spreadRadius: -2),
        ],
      ),
      child: DecoratedBox(
        // 内阴影：只压顶沿到 35%，越往下越透明——它同时替高光片做了"上亮下暗"。
        // 暗色下这片比轨道亮，压深一档才像"陷进去的顶沿"，压白会变成高光。
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              if (dark) ...[
                Colors.black.withValues(alpha: 0.22),
                Colors.black.withValues(alpha: 0),
              ] else ...[
                scheme.onSurface.withValues(alpha: 0.05),
                scheme.onSurface.withValues(alpha: 0),
              ],
            ],
            stops: const [0, 0.35],
          ),
        ),
      ),
    );
  }
}

class _TabCell extends StatefulWidget {
  const _TabCell({required this.tab, required this.selected, required this.onTap});

  final DrawerTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_TabCell> createState() => _TabCellState();
}

class _TabCellState extends State<_TabCell> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final selected = widget.selected;
    final foreground = selected ? scheme.onSurface : scheme.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: widget.tab.label(l10n),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        // 按下反馈只给"按到了"这一层薄雾：不缩放（缩放是会话行长按的语义），
        // 也不出声——页签是导航，不是提交。
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        child: Stack(
          alignment: Alignment.center,
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: AnimatedOpacity(
                opacity: _down ? 1 : 0,
                duration: KitMotion.of(context, AppMotion.quick),
                curve: AppMotion.std,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
              ),
            ),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(widget.tab.icon, size: 15, color: foreground),
                  const SizedBox(width: 6),
                  Flexible(
                    // 字重与字距一起走 160ms：选中那一格"收紧一点、压实一点"，
                    // 不是啪地换一套字。两条隐式动画都只跑一次，停下就不再有帧。
                    child: AnimatedDefaultTextStyle(
                      duration: KitMotion.of(context, AppMotion.quick),
                      curve: AppMotion.std,
                      style: TextStyle(
                        fontSize: 13.5,
                        // 行高 1.35：两格的文字基线与图标同一条中线，中文才不显得吊着。
                        height: 1.35,
                        letterSpacing: selected ? -0.15 : 0.1,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                        color: foreground,
                      ),
                      child: Text(
                        widget.tab.label(l10n),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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

  /// 松手：由外壳按当前开合程度决定收回还是回弹。
  final VoidCallback? onPullRelease;

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
      _controller.animateToPage(widget.tab.index, duration: _flip(context), curve: AppMotion.swift);
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
          widget.onPullRelease?.call();
        }
        return false;
      },
      child: PageView(
        controller: _controller,
        // Clamping 而不是 Bouncing：我们需要越界事件来接管抽屉，而不是回弹动画。
        physics: const ClampingScrollPhysics(),
        onPageChanged: (index) => widget.onTabChanged(DrawerTab.values[index]),
        children: [
          _Reveal(
            active: widget.tab == DrawerTab.sessions,
            child: _Keep(tab: DrawerTab.sessions, child: widget.sessions),
          ),
          _Reveal(
            active: widget.tab == DrawerTab.files,
            child: _Keep(tab: DrawerTab.files, child: widget.files),
          ),
        ],
      ),
    );
  }
}

/// 切到这一页时，页内容**先等 60ms 再淡进来**。
///
/// 层次感来自顺序：高光片先滑过去（180ms），目标页的内容晚 60ms 起来、160ms 落定，
/// 于是眼睛先看到"选择过去了"，再看到"内容在那儿"，而不是整块一起换。
/// 只播一次、只朝"切进来"的方向播；减少动画时这段归零，页面立刻在位。
class _Reveal extends StatefulWidget {
  const _Reveal({required this.active, required this.child});

  final bool active;
  final Widget child;

  /// 高光片先走的这一小段。
  static const lead = Duration(milliseconds: 60);

  /// 淡入的起点：不是 0（那会读成页面闪了一下），只差 14%。
  static const from = 0.86;

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(vsync: this, duration: AppMotion.quick, value: 1);
  Timer? _lead;

  @override
  void didUpdateWidget(_Reveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) _play();
  }

  void _play() {
    _lead?.cancel();
    if (KitMotion.of(context, AppMotion.quick) == Duration.zero) return;
    _fade.value = 0;
    _lead = Timer(KitMotion.of(context, _Reveal.lead), () {
      if (mounted) _fade.forward();
    });
  }

  @override
  void dispose() {
    _lead?.cancel();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade.drive(
        Tween(begin: _Reveal.from, end: 1.0).chain(CurveTween(curve: AppMotion.swift)),
      ),
      // 淡入的那 160ms 里读屏也要看得见这一页。
      alwaysIncludeSemantics: true,
      child: widget.child,
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

import 'package:flutter/material.dart';

import 'kit.dart';

/// 骨架屏：加载中的占位灰条。**静态微光，不循环、不扫光、不呼吸。**
///
/// 为什么不做 shimmer：一圈扫光或呼吸是屏幕上一块**永远在动**的区域，用户盯着它
/// 等加载的几百毫秒里，它比真内容还显眼；而且列表里同时挂两块就是两个循环动画
/// 一直吃帧（本仓 `docs/` 下的动静原则：静止画面必须停帧）。这里换成"纸面受光"：
/// 每条灰条自带一层极淡的竖向渐变（上亮下暗，和玻璃的 `rim` 同一方向），
/// 光感来自静止的明暗差，不来自运动。
///
/// 唯一的一次动画是**首次出现**的 400ms 淡入（[KitMotion.skeletonIn]）：直接"啪"
/// 出现一块灰会像闪了一下，淡入让"占位"读起来是"正在铺开"。之后无论怎么重建
/// 都停在完全不透明的静止帧。
///
/// ```dart
/// KitRowCard(children: [Padding(padding: EdgeInsets.all(14), child: KitSkeleton(rows: 4, semanticLabel: '正在加载会话'))])
/// ```
///
/// 语义：[semanticLabel] 会念给读屏（"正在加载…"）；不传则整块当装饰处理，
/// 免得读屏把一串空灰条念成内容。
class KitSkeleton extends StatefulWidget {
  const KitSkeleton({
    super.key,
    this.rows = 3,
    this.semanticLabel,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    this.rowHeight = Kit.rowHeight,
  });

  /// 占位行数。
  final int rows;

  /// 读屏用的说明（"正在加载…"）。不传就整块当装饰。
  final String? semanticLabel;

  /// 每行内部的留白；默认与 `KitRow.contentPadding` 的 14/12 对齐，
  /// 这样骨架换成真行时文字左缘不跳。
  final EdgeInsetsGeometry padding;

  /// 每行的最低高度；默认 [Kit.rowHeight]（48），两行式的行传 [Kit.rowHeightTwo]。
  final double rowHeight;

  /// 图形位的宽，与 `KitRow.iconSlot` 同一个数（32）：骨架换真行时左缘不跳。
  /// 这里不 import kit_list.dart 是为了不制造 kit 内部的循环 import。
  static const leadingSlot = 32.0;

  @override
  State<KitSkeleton> createState() => _KitSkeletonState();
}

class _KitSkeletonState extends State<KitSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(vsync: this, duration: KitMotion.skeletonIn);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // 闸门：系统关动画时时长为 0，forward 一步到位（直接是不透明的静止帧）。
    _fade.duration = KitMotion.of(context, KitMotion.skeletonIn);
    _fade.forward();
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 每行：32 的图形位 + 两条灰条 + 右侧一枚动作块，和 `KitRow` 的骨架一致。
    // 宽度按行号轮换，是为了让"这一块是列表"立刻读得出来（全都等宽会读成表格）。
    const titleWidths = [0.92, 0.68, 0.80, 0.56];
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < widget.rows; i++)
          Padding(
            padding: widget.padding,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: widget.rowHeight),
              child: Row(
                children: [
                  const KitSkeletonBar(width: KitSkeleton.leadingSlot, height: KitSkeleton.leadingSlot, radius: 8),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FractionallySizedBox(
                          widthFactor: titleWidths[i % titleWidths.length],
                          child: const KitSkeletonBar(height: 12),
                        ),
                        const SizedBox(height: 6),
                        // 用比例而不是固定 96：放进窄弹层时不会顶出溢出条纹。
                        const FractionallySizedBox(widthFactor: 0.45, child: KitSkeletonBar(height: 9)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const KitSkeletonBar(width: 40, height: 18, radius: 9),
                ],
              ),
            ),
          ),
      ],
    );
    final label = widget.semanticLabel;
    return FadeTransition(
      opacity: _fade,
      child: label == null
          ? ExcludeSemantics(child: body)
          : Semantics(label: label, container: true, child: ExcludeSemantics(child: body)),
    );
  }
}

/// 骨架里的一条灰条：静态微光（上亮下暗的竖向渐变），不循环。
///
/// [width] 为 null 时撑满可用宽度（放在 `Expanded` / `FractionallySizedBox` 里）。
class KitSkeletonBar extends StatelessWidget {
  const KitSkeletonBar({super.key, this.width, this.height = 12, this.radius});

  final double? width;
  final double height;

  /// 圆角；不传就取 `height / 2`（胶囊），图标砖这类方块自己传 8。
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    // 两层都来自 onSurface：换主题、换配色时自动跟着走，不会留下一块固定的灰。
    // 深色下要更亮一点才看得见（近黑底上的灰会被压没）。
    final top = scheme.onSurface.withValues(alpha: dark ? 0.10 : 0.07);
    final bottom = scheme.onSurface.withValues(alpha: dark ? 0.06 : 0.045);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius ?? height / 2),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ),
      ),
    );
  }
}

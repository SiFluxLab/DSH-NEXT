import 'package:flutter/services.dart';

/// 触感的唯一出口。
///
/// 为什么不各处直接 `HapticFeedback.xxx()`：调用点现在散在二十多个文件里，各自挑
/// 强度（selectionClick / lightImpact / mediumImpact / heavyImpact 都出现过），
/// 同一个"发送成功"在不同页面震的力度不一样，触感就不再是信号，只是噪音。
///
/// 规则只有两条，按**动作的性质**分，不按"页面重要程度"分：
///
/// | 场景 | 用哪个 | 例子 |
/// |---|---|---|
/// | 提交 / 完成 / 落定 | [commit]（mediumImpact） | 发送、保存、确认删除、装好一个插件 |
/// | 选择 / 切换 / 落格 | [selection]（selectionClick） | 选中一个选项、拨动开关、滑块吸附 |
///
/// **不是每次点击都震**：普通按钮、行、导航、"再来一次"这些不需要——一次界面
/// 操作如果震两下以上，用户就会开始忽略它。
///
/// 平台通道的返回值是"发到了没"，界面不该等它，也不该因为它失败而报错，
/// 所以这两个方法都是发完就返回（与 `common/pressable.dart` 的写法一致）。
abstract final class Haptics {
  /// 提交类动作落定：发送发出去了、设置保存了、删除确认了。
  ///
  /// 用 mediumImpact 而不是 heavyImpact：heavy 是"系统级警告"的份量（来电、
  /// 强提醒），一个提交按钮用 heavy，真正的危险提醒就没有余量了。
  static void commit() {
    HapticFeedback.mediumImpact();
  }

  /// 选择类动作：选中、切换、落格。最轻的一档，连点也不会烦。
  static void selection() {
    HapticFeedback.selectionClick();
  }
}

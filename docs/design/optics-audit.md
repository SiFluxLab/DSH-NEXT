# 光感层静态预算检查

由 `tool/optics_audit.py` 生成。数的是**绘制层**，不是观感。

| 项 | 总数 | 说明 |
| --- | ---: | --- |
| BackdropFilter | 6 | 每屏常驻预算 ≤ 3（silent 档为 0） |
| 其中 grouped | 1 | 分组共享一次采样，比逐层便宜 |
| ShaderMask | 12 | 每处开一个 saveLayer |
| MaskFilter.blur | 6 | 逐帧重画的高斯，最贵 |
| ImageFilter.blur | 16 | 同上，走引擎 |
| RepaintBoundary | 34 | 重绘隔离的覆盖面 |

## 最贵的十个文件

| 文件 | 行数 | Backdrop | grouped | ShaderMask | MaskBlur | ImageBlur | Repaint |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `app/lib/ui/fx/voice_glow/voice_painter.dart` | 531 | 0 | 0 | 0 | 1 | 4 | 0 |
| `app/lib/ui/companion/companion_log.dart` | 483 | 1 | 0 | 1 | 0 | 1 | 0 |
| `app/lib/ui/fx/beam/beam_painter.dart` | 764 | 0 | 0 | 0 | 1 | 1 | 0 |
| `app/lib/ui/share/share_card.dart` | 1129 | 1 | 0 | 0 | 0 | 1 | 0 |
| `app/lib/ui/speech/call/call_parts.dart` | 531 | 1 | 0 | 1 | 0 | 1 | 0 |
| `app/lib/ui/speech/voice_call_page.dart` | 863 | 1 | 0 | 0 | 0 | 1 | 0 |
| `app/lib/ui/theme/glass.dart` | 399 | 2 | 1 | 0 | 0 | 0 | 0 |
| `app/lib/ui/common/light_blade.dart` | 202 | 0 | 0 | 0 | 1 | 0 | 1 |
| `app/lib/ui/fx/gooey/liquid.dart` | 621 | 0 | 0 | 0 | 0 | 1 | 1 |
| `app/lib/ui/fx/metal/metal_badge.dart` | 358 | 0 | 0 | 0 | 1 | 0 | 1 |

## 超预算的文件

没有文件超过预算。

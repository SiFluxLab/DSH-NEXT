#!/usr/bin/env python3
"""光感层的静态预算检查。

不需要真机就能回答三个问题：
  1. 哪些文件里的模糊层（BackdropFilter）最多——每屏常驻预算 <= 3；
  2. 哪些文件在做 MaskFilter.blur（逐帧重画的高斯，最贵的一类绘制）;
  3. 重绘隔离（RepaintBoundary）够不够覆盖这些贵操作。

用法：python3 tool/optics_audit.py [--write docs/design/optics-audit.md]
"""
import argparse
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent / 'app' / 'lib'
PATTERNS = {
    'backdrop': re.compile(r'\bBackdropFilter\b'),
    'grouped': re.compile(r'BackdropFilter\.grouped'),
    'shaderMask': re.compile(r'\bShaderMask\b'),
    'maskBlur': re.compile(r'\bMaskFilter\.blur\b'),
    'imageFilter': re.compile(r'\bImageFilter\.blur\b'),
    'repaint': re.compile(r'\bRepaintBoundary\b'),
}
BUDGET = 3


COMMENT_BLOCK = re.compile(r'/\*.*?\*/', re.S)
COMMENT_LINE = re.compile(r'//[^\n]*')


def strip_comments(text):
    """注释里提到 BackdropFilter 不算一层模糊——数错了会误导优化方向。"""
    return COMMENT_LINE.sub('', COMMENT_BLOCK.sub('', text))


def scan():
    rows = []
    for path in sorted(ROOT.rglob('*.dart')):
        text = path.read_text(encoding='utf-8', errors='replace')
        text = strip_comments(text)
        counts = {name: len(rx.findall(text)) for name, rx in PATTERNS.items()}
        if not any(counts.values()):
            continue
        counts['rel'] = str(path.relative_to(ROOT.parent.parent))
        counts['lines'] = text.count('\n') + 1
        rows.append(counts)
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--write')
    args = ap.parse_args()
    rows = scan()
    total = {k: sum(r[k] for r in rows) for k in PATTERNS}
    rows.sort(key=lambda r: (r['backdrop'] + r['maskBlur'] + r['imageFilter']), reverse=True)

    out = ['# 光感层静态预算检查', '',
           '由 `tool/optics_audit.py` 生成。数的是**绘制层**，不是观感。', '',
           '| 项 | 总数 | 说明 |', '| --- | ---: | --- |',
           f"| BackdropFilter | {total['backdrop']} | 每屏常驻预算 ≤ {BUDGET}（silent 档为 0） |",
           f"| 其中 grouped | {total['grouped']} | 分组共享一次采样，比逐层便宜 |",
           f"| ShaderMask | {total['shaderMask']} | 每处开一个 saveLayer |",
           f"| MaskFilter.blur | {total['maskBlur']} | 逐帧重画的高斯，最贵 |",
           f"| ImageFilter.blur | {total['imageFilter']} | 同上，走引擎 |",
           f"| RepaintBoundary | {total['repaint']} | 重绘隔离的覆盖面 |", '',
           '## 最贵的十个文件', '',
           '| 文件 | 行数 | Backdrop | grouped | ShaderMask | MaskBlur | ImageBlur | Repaint |',
           '| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |']
    for r in rows[:10]:
        out.append(f"| `{r['rel']}` | {r['lines']} | {r['backdrop']} | {r['grouped']} | "
                   f"{r['shaderMask']} | {r['maskBlur']} | {r['imageFilter']} | {r['repaint']} |")
    over = [r for r in rows if r['backdrop'] > BUDGET]
    out += ['', '## 超预算的文件', '']
    if over:
        out.append(f'BackdropFilter 出现次数超过 {BUDGET} 的文件（不保证同屏，但值得逐个确认）：')
        out.append('')
        out += [f"- `{r['rel']}`：{r['backdrop']} 处" for r in over]
    else:
        out.append('没有文件超过预算。')
    text = '\n'.join(out) + '\n'
    if args.write:
        pathlib.Path(args.write).write_text(text, encoding='utf-8')
        print(f'wrote {args.write}')
    print(text)
    return 0


if __name__ == '__main__':
    sys.exit(main())

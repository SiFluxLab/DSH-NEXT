#!/usr/bin/env python3
"""统计 ui/ 下圆角、时长、透明度的分布，对照 docs/design/consistency.md。

用法：python3 tool/design_audit.py [--strict]
--strict 时，出现表外值就返回 1（可以挂进 CI）。
"""
import collections
import pathlib
import re
import sys

ALLOWED_RADII = {"0", "2", "4", "6", "8", "12", "16", "999", "99"}
ALLOWED_DURATIONS = {"0", "60", "80", "120", "160", "180", "200", "240", "320", "400"}
EFFECT_DURATIONS = {"900", "1600", "2400"}  # 光效周期，允许但必须停帧


def main() -> int:
    root = pathlib.Path(__file__).resolve().parents[1] / "app" / "lib" / "ui"
    radii, durations, alphas = collections.Counter(), collections.Counter(), collections.Counter()
    for path in root.rglob("*.dart"):
        text = path.read_text()
        for match in re.finditer(r"Radius\.circular\(\s*([\d.]+)\s*\)", text):
            radii[match.group(1)] += 1
        for match in re.finditer(r"Duration\(milliseconds:\s*(\d+)\)", text):
            durations[match.group(1)] += 1
        for match in re.finditer(r"withValues\(alpha:\s*(0?\.\d+)\)", text):
            alphas[match.group(1)] += 1

    def report(title: str, counter: collections.Counter, allowed: set[str]) -> list[str]:
        line = ", ".join(f"{value}×{count}" for value, count in counter.most_common(12))
        print(f"{title}: {line}")
        return [value for value in counter if value not in allowed]

    off_radius = report("半径", radii, ALLOWED_RADII)
    off_duration = report("时长", durations, ALLOWED_DURATIONS | EFFECT_DURATIONS)
    report("透明度", alphas, set(alphas))  # 只展示，不判罚：颜色来自主题

    if off_radius:
        print(f"！表外圆角：{sorted(off_radius)}")
    if off_duration:
        print(f"！表外时长：{sorted(off_duration)}")
    if "--strict" in sys.argv and (off_radius or off_duration):
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

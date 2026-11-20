# 应龙（YingLong）/ Zero-Trap 运行层的来源与许可

本目录随镜像进入 `/opt/yinglong/`：

| 文件 | 作用 |
|---|---|
| `ld-linux-aarch64.so.1` | 打过 Zero-Trap 补丁的 glibc 动态加载器（arm64） |
| `libc.so.6` | 打过 Zero-Trap 补丁的 glibc 2.39（arm64） |

Zero-Trap 是应龙项目的机制名：它在 libc 的 syscall wrapper 层做路径翻译，取代 PRoot 的
ptrace 拦截。补丁与上游源码见应龙项目（`zero-trap-glibc.patch`，约 60 个文件）。

## 许可

这两个文件是 **GNU C Library（glibc）2.39 的修改版**，按 LGPL-2.1-or-later 分发：

- glibc 源码：https://sourceware.org/git/?p=glibc.git;a=tag;h=glibc-2.39
- 本项目对 glibc 的修改：应龙项目的 `zero-trap-glibc.patch`（含应用顺序与构建脚本）。
  该补丁的副本需随二进制一起提供；如本仓库未包含，请在分发前补上，或向用户提供获取地址。
- 许可全文：https://www.gnu.org/licenses/old-licenses/lgpl-2.1.txt

按 LGPL 的要求，用户有权替换这两个库：它们位于镜像的 `/opt/yinglong/`，与 App 的其它
代码分离，替换该目录下的同名文件即可改用自建版本。

## 运行方式

App 以加载器 + `--library-path` 的方式显式启动引擎（`YinglongLaunch.kt`），不替换镜像里的
`/lib`：`execve` 时内核按 PT_INTERP 找解释器，那一步不经过路径翻译，替换镜像里的 libc
是无效的。

## 回退

`ZT_ROOT` 等变量只在这次启动的进程树里生效。App 侧在应龙启动失败时会记为
「该运行时不可用」并自动回到 PRoot，下一次启动不再尝试；在设置里重新打开即可再试。

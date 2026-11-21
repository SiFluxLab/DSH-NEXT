# DSH NEXT：本 fork 的改动与配置

本文只写与上游 dsh-go 不同、以及需要你自己配置的部分。其余设计见
[docs/architecture.md](architecture.md) 与各 `docs/design/*.md`（内容仍是上游的，除品牌与链接外未改动）。

## 1. 品牌

| 项目 | 取值 |
|---|---|
| 应用名 | DSH NEXT（`app/lib/state/app_info.dart`、Android 的 `android:label`、iOS 的 `CFBundleDisplayName`、鸿蒙 `string.json`） |
| 包名 / applicationId | `dev.sifluxlab.dshnext`（Kotlin 源码目录已随之移动） |
| 深链 scheme | `dshnext://`（`app/lib/links/app_links.dart` 的 `appLinkScheme`，Android Manifest 与 iOS `Info.plist` 已同步） |
| 更新来源 | 本仓库 `SiFluxLab/dsh-next` 的 GitHub Release |

**故意没有改名的内部标识**：`runtime/bridge/dsh-go-bridge`、guest 里的 `/opt/dsh-go`、
`dsh-go-companion-full` 预设、原生插件协议里的 `dshGo` 服务名。它们被引擎补丁
（`runtime/patches/`）、运行时布局和已发布插件写死，改名会直接让引擎起不来。

## 2. 上游服务已全部断开

上游作者的服务地址都换成了保留域名 `dshnext.invalid`（永远不解析，失败快、
不会把流量发给第三方）：

| 原来的东西 | 位置 | 现状 |
|---|---|---|
| 更新镜像 / 更新清单 / beta 通道 | `app/lib/update/update_config.dart` | 走本仓库 GitHub Release；镜像与 beta 关闭 |
| DSH Remote 中继 | `app/lib/state/hosts_state.dart` 的 `defaultRelayServer` | 占位；自建中继后改这里 |
| 论坛 | `app/lib/forum/forum_config.dart` | 占位；可填自建 Discourse |
| 创意工坊 Worker | `app/lib/state/workshop_dependencies.dart`（`DSH_WORKSHOP_ORIGIN`） | 默认空 = 工坊不可用；填自己的 Worker 即可 |
| 插件市场索引 | `app/lib/state/plugins/plugin_market.dart` | 占位；指向自己的目录 JSON |
| 分享托管 / 短链 | `app/lib/share_hosted/hosted_config.dart` | 占位；需自建 `services/share-worker` |
| 用量统计上报 | `app/lib/usage/usage_net.dart` | 占位；不填就没有任何上报 |

要把某个功能接回来，最干净的方式是编译期传值，而不是改常量：

```bash
flutter build apk --flavor arm64 \
  --dart-define=DSH_WORKSHOP_ORIGIN=https://your-worker.example \
  --dart-define=DSH_UPDATE_MIRROR=https://your-dl.example
```

`services/share-worker/` 是完整的 Cloudflare Worker 实现（分享、下载、插件目录、
创意工坊、统计）。它需要 R2 桶、KV、Durable Objects、Analytics Engine 和一个
GitHub OAuth App；部署步骤见 `services/share-worker/docs/`。

## 3. 内置插件开关

`app/lib/state/builtin_plugins_state.dart` 是唯一的事实源：

- `BuiltinPlugin { tavern, workshop, companion }`，值存 `SharedPreferences`
  的 `builtin_plugins.<name>`；缺省 = 开。
- 界面：设置 › 内置插件（`app/lib/ui/settings/builtin_plugins_page.dart`）。
- 拦截点：
  - `ui/modes/mode_switch.dart`：模式列表、启动模式、`appModePage`；
  - `links/page_links.dart`、`main.dart`：深链页面；
  - `ui/remote/host_switcher.dart`：伙伴入口；
  - `ui/workshop/workshop_screen.dart` 的 `workshopAvailableProvider`：工坊入口。
- 页面被直接打开（深链、桌面小组件）而插件已关时，显示
  `ui/common/builtin_plugin_gate.dart` 的提示，并给出跳转到设置的按钮。

新增第四个插件时：加枚举值 → 在三个 `switch` 里补名字/图标/说明 →
挑一个拦截点。

## 4. 构建

`.github/workflows/build-apk.yml`：`workflow_dispatch` 或 `v*` 标签触发，
先按 ABI 构建运行时，再出 `arm64` / `x64` 两个 APK，可挂到 Release。
签名用仓库 Secrets（见 README），没有则退回 debug 签名。

上游留下的 `ci.yml`、`goldens.yml`、`ios-*`、`ohos-compile.yml`、`pr-gate.yml`、
`runtime.yml` 已删除：它们依赖 macOS / 鸿蒙 runner、真机、上游的发布脚本与
密钥，在本 fork 里跑不通。需要时可以从上游仓库取回。

## 5. 还没做的（下一步）

- 仓库里的品牌美术（`docs/assets/`、`app/assets/brand/`、鲸鱼娘素材等）仍是上游
  作者的版权素材，按 `ASSETS.md` 不属于 AGPL。对外分发前要换成自己的图。
- `market/` 目录里的插件条目是上游作者的 npm 包，已不再适用，可整体删除或换成
  自己的目录。
- iOS 与鸿蒙工程只做了包名/名称替换，没有在真机上验证。

## 6. 运行时：应龙（Zero-Trap）替代 PRoot

本 fork 在 **arm64-v8a** 上默认用应龙（YingLong）启动引擎，不再经过 PRoot：
路径翻译在打过补丁的 glibc 里完成，PTrace 那一层没有了。

### 6.1 装了什么

| 位置 | 内容 |
|---|---|
| `runtime/yinglong/` | 仓库里：应龙提供的 `ld-linux-aarch64.so.1` + `libc.so.6`（glibc 2.39 + Zero-Trap 补丁，LGPL-2.1，见该目录的 `NOTICE.md`） |
| 镜像 `/opt/yinglong/` | 构建时由 `rtbuild assemble --yinglong` 拷进去；只对 arm64-v8a 生效 |
| App 侧 | `YinglongLaunch.kt`：把 PRoot 的 argv 改写成「加载器 + `--library-path` + `env -i` + `/bin/sh -c`」，并注入 `ZT_*` |

启动形状：

```
opt/yinglong/ld-linux-aarch64.so.1 --library-path <opt/yinglong>:<镜像 lib> \
  <镜像>/opt/node/bin/node --import=<boot-cache> <镜像>/opt/dsh/.../bin.js web --patch … --host … --port …
```

进程环境里带 `ZT_ROOT / ZT_FAKE_ROOT / ZT_LD / ZT_LIBPATH / ZT_BIND`。**没有 `/bin/sh`、没有
`/usr/bin/env`**：它们各自都要再 exec 一次 guest 二进制，每一次 exec 都是一个可能被跳过翻译的环节。

三条容易踩的规则（都在 `YinglongLaunch` 的注释里）：

1. 加载器用**宿主路径**且必须绝对；它后面的东西都是 **guest 路径**，由补丁 libc 翻译。
2. `env -i` 会清环境，所以 `ZT_ROOT` / `ZT_BIND` / `ZT_FAKE_ROOT` / `ZT_LD` / `ZT_LIBPATH`
   必须作为 `env -i` 的参数传下去，否则子进程全部退回系统 libc。
3. **链路上不要留任何 shell 或 `env`**：`/usr/local/bin/dsh` 是 `#!/bin/sh` shim，shebang 由内核
   解析、不经过翻译，会落到 Android 自带的 bionic sh 上并以 127 退出（`libc.so: cannot open
   shared object file`）。`YinglongLaunch` 读 shim，直接按「加载器 → node `--import=… bin.js`
   `web …`」启动，环境由 `ProcessBuilder` 设；`/tmp/dsh-web.pid` 由启动器自己写。
4. 不要把镜像里的 `/lib/libc.so.6` 换掉：`execve` 时内核按 PT_INTERP 找解释器，那一步
   不经过翻译，换了也无效。

### 6.2 没有启用索引

当前只做路径翻译（不设 `ZT_CACHE` / `ZT_DIRTY`），因为索引要在镜像构建期生成、
并配一个长期存活的 `ztwatch` 维护脏页。这一步留到下一版；现在的好处是**没有任何
缓存过期的风险**，行为与 PRoot 等价而更快。

### 6.3 性能预期（来自应龙自己的实测，非本仓库测量）

| 场景 | PRoot | 应龙 | 说明 |
|---|---:|---:|---|
| 4 线程 `stat` 循环 | 4157 ms | 38 ms | ptrace 消失，109× |
| 模拟装包（解包+chmod） | 6911 ms | 182 ms | 38× |
| `tar` 解 3000 文件 | 4895 ms | 161 ms | 30× |
| `du -sh` 5000 文件 | 934 ms | 209 ms | 4.5×（含索引） |
| 引擎启动（`dsh --version`） | 212 ms | 175 ms | −17.5%（含索引；仅翻译时收益更小） |
| 64 MB 顺序读写 | 68 ms | 63 ms | 持平（按 fd 走，翻译层不介入） |

**诚实结论**：真正的大头是「每次 syscall 不再 ptrace」。凡是免不了大量 syscall 的操作
（装包、解包、遍历）收益最大；大文件 IO 没有变化；引擎启动省 20–45 ms。

### 6.4 失败与回退

- 引擎起不来 → `K_ZT_FAILED` 记下该运行时版本 → 下一次启动直接走 PRoot，不再尝试；
  换运行时（升级）后自动重试。`launchDiagnostics` 会显示实际用的方法。
- 安全模式一律走 PRoot。
- x86_64 没有对应 libc 构建，仍用 PRoot。
- 手动切换的开关还没做（下一步），目前靠「失败自动回退 + 安全模式」兜底。

### 6.5 待办

1. 设置页加「应龙」开关（`RuntimeController.setZtEngine` 已就绪，缺 Dart 侧字段与 UI）。
2. 构建期生成索引 + `ztwatch` 生命周期，把引擎启动的 17% 全部拿到。
3. 真机验证清单：`launch method: yinglong` 是否出现、`/tmp` `/dev` `/proc` 是否正常、
   `npm i` / 插件安装是否可用、伙伴 Live2D 与手机操控是否受影响。

### 已知差异：应龙路径不写客人 pid 文件

PRoot 路径的启动脚本里有 `echo $$ > /tmp/dsh-web.pid`；应龙路径直接 exec node，没有 shell，
Kotlin 侧也补不上这个文件——`Process.pid()` 是 Java 9+ / Android API 26 的 API，本模块的
`compileOptions` 是 Java 8，符号不可见（用了会 Kotlin 编译失败）。

影响面很小：`captureGuestRecord()` 读不到这个文件时返回 null，只跳过"结束进程前再核对一次
PID 归属"这道额外的安全检查；真正结束用的仍是自己持有的 `Process` 对象。**不要**为了补这个文件
去开 Java 9 的 desugar 或反射。


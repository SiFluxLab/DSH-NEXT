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

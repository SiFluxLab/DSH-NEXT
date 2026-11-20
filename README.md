# DSH NEXT

DeepSeek Harness 的手机应用（Android 优先），在上游 dsh-go 的基础上改为自有品牌，并把三个大功能做成了**可开关的内置插件**。

- 许可：AGPL-3.0（README 末尾说明），上游署名见 [NOTICE](NOTICE)。
- 架构：Flutter 原生界面 + 纯 Dart 客户端 + PRoot 里的 `dsh web` 引擎，详见 [docs/architecture.md](docs/architecture.md)。
- 本 fork 的差异与配置：[docs/dsh-next.md](docs/dsh-next.md)。

## 内置插件

设置 › 内置插件 里可以分别开关：

| 插件 | 关掉之后 |
|---|---|
| 酒馆（角色扮演，SillyTavern 兼容） | 模式列表、深链、入口消失；卡与对话数据保留 |
| 创意工坊（桌宠 / 伙伴包的下载与投稿） | 伙伴页与桌宠设置里的入口消失 |
| 伙伴小屋（Live2D 舞台 + 长期角色） | 模式与主页入口消失；素材与记忆保留 |

关掉只影响界面显示，不删任何数据；重新打开后原样恢复。

## 构建

GitHub Actions 上直接构建（Actions → **Build APK** → Run workflow）：

1. 生成 Linux 运行时（`runtime/build-runtime.sh`，按 ABI 各一份）；
2. 构建 APK：`arm64`（真机）与 `x64`（模拟器）；
3. 可选：勾选 `release` 或推送 `v*` 标签，APK 会挂到 Release 上。

需要配置的仓库 Secrets（签名用，全部可选）：

| Secret | 内容 |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `keytool` 生成的 JKS 的 base64 |
| `ANDROID_KEYSTORE_PASSWORD` | keystore 口令 |
| `ANDROID_KEY_ALIAS` | 密钥别名 |
| `ANDROID_KEY_PASSWORD` | 密钥口令 |

没有这些 Secrets 时 Gradle 会退回 debug 签名：能装、能试，但不要对外分发。

## 本机开发

```bash
(cd app && flutter pub get && flutter analyze && flutter test)
tooling/build-apk.sh --build-name 1.0.0 --no-companion
```

运行时需要先构建一次：`runtime/build-runtime.sh arm64-v8a`。

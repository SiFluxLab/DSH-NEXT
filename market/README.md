# 插件目录（空模板）

这是 DSH NEXT 的插件市场目录源码：一个 JSON 条目对应一个已发布到 npm 的 DSH 插件包，
`scripts/build.mjs` 扫描这些条目、核对 tarball 与许可、生成 `index.json` / `dsh-go.json` /
`audit.json`，再由 `services/share-worker` 对外提供。

**目录目前是空的**：上游 dsh-go 的作者插件条目已全部删除，因为它们指向别人的 npm 包，
和本 fork 无关。要开始维护自己的目录：

1. 在 `plugins/` 下加一个 JSON（非 scoped 包用 `<包名>.json`，`@scope/name` 用
   `@scope__name.json`）：

```json
{
  "name": "@you/dsh-weather",
  "version": "1.2.0",
  "title": {"zh": "天气", "en": "Weather"},
  "summary": {"zh": "查看天气预报", "en": "Weather forecasts"},
  "category": "tools",
  "screenshots": [],
  "homepage": "https://github.com/you/dsh-weather"
}
```

标题和简介必须有英文 `en`，可附中文 `zh`；截图只收 HTTPS 链接（最多四张）；
分类为 `tools`、`media`、`productivity`、`communication`、`other`。
不要写 `tier`、risk、integrity 或审核结论——那些由检查结果生成。

2. 本地校验与生成（需要 Node.js 22 以上）：

```sh
npm ci --ignore-scripts
npm test          # 离线测试
npm run check     # 在线实扫
npm run build     # 生成 dist/ 下的三个文件
```

3. 官方身份只认 `policy.json.officialPackages`；被禁版本记在
   `policy.json.blockedVersions`。作者不能自己宣布官方身份。

目录由谁托管由你决定：改 `services/share-worker` 的 `market.ts` 指向自己的 R2/KV 即可，
App 侧把插件市场地址换成你的域名（`app/lib/state/plugins/plugin_market.dart`，
或用 `--dart-define`）。

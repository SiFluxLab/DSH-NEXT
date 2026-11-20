# DSH NEXT

The DeepSeek Harness phone app (Android first), rebranded from the upstream dsh-go project, with its three big features turned into **built-in plugins you can switch off**.

- Licence: AGPL-3.0 (see the note below); upstream attribution in [NOTICE](NOTICE).
- Architecture: Flutter native UI + a pure-Dart client + `dsh web` inside PRoot — [docs/architecture.md](docs/architecture.md).
- What this fork changes, and how to configure it: [docs/dsh-next.md](docs/dsh-next.md).

## Built-in plugins

设置 › 内置插件 (Settings › Built-in plugins) switches each one:

| Plugin | When off |
|---|---|
| Tavern (SillyTavern-compatible role play) | its mode, links and entries disappear; cards and chats stay |
| Workshop (download and publish pet / companion packs) | its entries in the companion and pet screens disappear |
| Companion (Live2D room and long-lived character) | its mode and entries disappear; material and memory stay |

Switching one off only changes what is shown; nothing is deleted, and turning it back on restores everything.

## Building

Build on GitHub Actions (Actions → **Build APK** → Run workflow):

1. build the Linux runtime (`runtime/build-runtime.sh`, one per ABI);
2. build the APKs: `arm64` (phones) and `x64` (emulators);
3. optionally tick `release`, or push a `v*` tag, to attach them to a release.

Optional repository secrets for signing:

| Secret | Contents |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | base64 of a JKS made with `keytool` |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_ALIAS` | key alias |
| `ANDROID_KEY_PASSWORD` | key password |

Without them Gradle falls back to the debug key: installable for testing, not for distribution.

## Local development

```bash
(cd app && flutter pub get && flutter analyze && flutter test)
tooling/build-apk.sh --build-name 1.0.0 --no-companion
```

Build the runtime once first: `runtime/build-runtime.sh arm64-v8a`.

## Licence

This program is free software under the GNU Affero General Public License v3.0
(see [LICENSE](LICENSE)). It is a modified version of dsh-go, so it must stay
under that licence, and each distributed build must offer its complete
corresponding source to its users.

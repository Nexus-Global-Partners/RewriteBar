<p align="center">
  <img src="BrandAssets/infinity-app-icon.svg" width="112" alt="RewriteBar icon">
</p>

<h1 align="center">RewriteBar</h1>

<p align="center">A private, native macOS menu bar app that rewrites clipboard text with a local model.</p>

<p align="center">
  <a href="#install">
    <img src="https://img.shields.io/badge/Install_RewriteBar-macOS-111111?style=for-the-badge&logo=apple&logoColor=white" alt="Install RewriteBar for macOS">
  </a>
</p>

<p align="center">
  <a href="https://github.com/Nexus-Global-Partners/RewriteBar/actions/workflows/ci.yml"><img src="https://github.com/Nexus-Global-Partners/RewriteBar/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://github.com/Nexus-Global-Partners/RewriteBar/releases/latest"><img src="https://img.shields.io/github/v/release/Nexus-Global-Partners/RewriteBar" alt="Latest release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-black" alt="MIT License"></a>
</p>

RewriteBar reads plain text from the clipboard only when you press Rewrite. Everything runs on your Mac through MLX. There is no account, API key, server, telemetry, or analytics.

## Install

Requires an Apple Silicon Mac with macOS 14 or newer.

The recommended installation verifies the release checksum and avoids the browser quarantine warning applied to direct downloads:

```sh
curl -fsSL https://raw.githubusercontent.com/Nexus-Global-Partners/RewriteBar/main/Scripts/install-release.sh | zsh
```

You can also download `RewriteBar.zip` from the [latest release](https://github.com/Nexus-Global-Partners/RewriteBar/releases/latest), expand it, and move the app to Applications. Browser downloads are quarantined by macOS.

The public build is ad hoc signed, not notarized with an Apple Developer ID. If macOS blocks a manually downloaded copy, open System Settings, choose Privacy & Security, then select Open Anyway for RewriteBar. Only do this for the checksum verified release from this repository.

## Update

Rerun the same verified command whenever a new release is available:

```sh
curl -fsSL https://raw.githubusercontent.com/Nexus-Global-Partners/RewriteBar/main/Scripts/install-release.sh | zsh
```

It replaces the existing copy in `~/Applications`, verifies the signature, and opens the current release. RewriteBar performs no background update checks, so the running app remains fully local and network free.

## Use

1. Copy text in any app.
2. Click the infinity icon in the menu bar.
3. Choose an intensity from 0 through 10.
4. Press Rewrite.
5. The finished rewrite is copied automatically, then the popover closes.

The slider becomes a minimal progress rail while RewriteBar works. Preparation occupies only the beginning of the rail. Once generation starts, progress follows the text actually produced by the model. When the rewrite is copied, the button briefly confirms Copied to Clipboard with a checkmark. A subtle curved arrow lets you restore the previous clipboard entry until you copy something else.

The slider controls how much RewriteBar changes:

* 0 preserves the original almost exactly and fixes clear mistakes.
* 3 is the default for a light, natural cleanup.
* 5 improves structure and clarity while preserving the writer's voice.
* 10 allows the strongest restructuring without changing facts or intent.

## Privacy

The Qwen3 1.7B model is bundled inside each release and runs in process with MLX. Clipboard text is never sent over the network, displayed in the app, logged, or saved. RewriteBar stores only the selected intensity.

## Build from source

```sh
git clone https://github.com/Nexus-Global-Partners/RewriteBar.git
cd RewriteBar
./Scripts/download-model.sh
./Scripts/install.sh
```

`download-model.sh` downloads the exact model files used by the release and verifies every checksum before installation. Model weights and generated app bundles are intentionally excluded from Git. The small Apple Silicon MLX runtime library is pinned and checksum verified in the repository so clean release builds are reproducible.

Useful development commands:

```sh
swift build
swift run RewriteCoreChecks
./Scripts/build-app.sh
./Scripts/package-release.sh
```

## Try it

### Light cleanup at level 3

```text
hey sorry i didnt reply sooner ive been busy moving and everything took longer then i expected. i should be able to send the files tomorrow morning but if not it will be around lunch, hope thats okay and thanks for being patient
```

### Team update at level 5

```text
Hey everyone, just wanted to touch base on the launch because we still dont have a final date. Some folks think Friday while others think next week. The onboarding flow looks better but the permissions screen is still confusing support got 18 questions yesterday. Maybe we should delay but im not totally sure. Please send your status and blockers by 4pm so we can decide today.
```

### Technical note at level 8

```text
API latency went from 180 ms to 640 ms between 09:10 and 09:35 UTC only in eu west 1. we dont know the cause yet but connection pool exhaustion after version 2.4.1 is the strongest guess because rolling back three instances reduced p95 latency around 38%. errors stayed below 0.7%, no data loss was found, and the US region wasnt affected. next we need to compare pool saturation before deciding if the remaining instances should be rolled back.
```

## Architecture

* `RewriteCore` handles validation, prompt construction, and safe output cleanup.
* `LocalModelService` loads the bundled model, generates text, and supports cancellation.
* `RewriteViewModel` owns rewrite, progress, automatic copy, restore, and failure states.
* AppKit owns the persistent menu bar item and popover lifecycle. SwiftUI provides the compact content, keyboard access, VoiceOver labels, and adaptive materials.

RewriteBar is designed for messages, emails, and short passages. Inputs longer than 2,000 visible characters are rejected immediately so the menu bar interaction stays responsive and predictable. Accepted generation is deterministic, bounded to 18 seconds, and configured with thinking disabled.

## Contribute

Bug reports, feature ideas, and pull requests are welcome. Read [AGENTS.md](AGENTS.md) for the product contract and [CONTRIBUTING.md](CONTRIBUTING.md) for the shortest path to a useful pull request. Use [GitHub Issues](https://github.com/Nexus-Global-Partners/RewriteBar/issues) for actionable reports and [GitHub Discussions](https://github.com/Nexus-Global-Partners/RewriteBar/discussions) for questions and early ideas.

Maintainers can follow [RELEASING.md](RELEASING.md) to validate, tag, publish, and verify an update with one guarded command.

Please report security concerns using the private process in [SECURITY.md](SECURITY.md).

## License

RewriteBar source is available under the [MIT License](LICENSE). Qwen3 model weights are distributed under Apache 2.0. MLX Swift and MLX Swift LM retain their upstream MIT licenses.

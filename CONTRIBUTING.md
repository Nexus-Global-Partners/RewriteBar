# Contributing to RewriteBar

Read [AGENTS.md](AGENTS.md) for the product contract and architecture. Open an issue before adding a new control, workflow, provider, dependency, or permission. Focused fixes can go straight to a pull request.

## Develop

Requires Apple Silicon, macOS 14+, and Swift 6.1+. No model weights or third-party Swift dependencies.

```sh
git clone https://github.com/Nexus-Global-Partners/RewriteBar.git
cd RewriteBar
./Scripts/check-project.sh
./Scripts/install.sh
```

The installer builds, signs, installs to `~/Applications`, and opens the app. Use a current official Codex app and connect a ChatGPT account in RewriteBar Settings for live rewrites.

## Verify

Add focused tests for behavior changes and a model-free check in `RewriteCoreChecks` when applicable. `check-project.sh` builds the app, runs the test suite, and runs the core checks.

For interface changes, inspect both appearances and keyboard control. For shortcut changes, test successful replacement, changed focus and selection, unsupported editors, secure fields, and permission denial in several applications. Opening or adjusting the menu slider must never read text or generate a rewrite.

For Codex changes, preserve isolated sign-in and all process restrictions. Fixture tests exercise malformed output, unexpected tools, cancellation, usage limits, and missing account/model behavior. After connecting the app, include the opt-in live check:

```sh
REWRITEBAR_RUN_LIVE_CODEX_TEST=1 ./Scripts/test.sh
```

For the broader eight-case English/French quality and latency check at levels 0, 3, 5, and 10, run `REWRITEBAR_RUN_LIVE_QUALITY_TEST=1 ./Scripts/test.sh`.

Use invented text only. Never reuse the developer's Codex home. Report measured latency rather than promising instant results. See [SECURITY.md](SECURITY.md).

## Pull requests

Describe the user effect, the reason for the change, test evidence, and remaining limitations. Include a screenshot for visible changes. Preserve the one-slider interface and put lasting preferences in Settings. Do not commit app bundles, archives, private content, credentials, or generated local reports. Public product images belong in `BrandAssets`.

Maintainers release after review and merge using [RELEASING.md](RELEASING.md).

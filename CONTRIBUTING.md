# Contributing to RewriteBar

Thanks for helping improve RewriteBar.

You can work directly or with a coding agent. In either case, [AGENTS.md](AGENTS.md) is the single source of product and architecture context. Give an agent the repository URL, tell it to read that file completely, and require `./Scripts/check-project.sh` before accepting a change.

## Before you start

Read [AGENTS.md](AGENTS.md), then search existing Issues and Discussions. Open an issue before a new control, workflow, writing style, model, online processing behavior, dependency, permission, or architecture change so product direction is agreed before implementation.

Small bug fixes, accessibility improvements, tests, and documentation corrections can go directly to a focused pull request.

## Start a branch

1. Fork the repository.
2. Create a branch from the latest `main`.
3. Make the smallest coherent change that solves the reported problem.

The fast development path does not need model weights:

```sh
git clone https://github.com/YOUR_ACCOUNT/RewriteBar.git
cd RewriteBar
./Scripts/check-project.sh
```

Add or update a check in `Sources/RewriteCoreChecks` when behavior can be tested without the model.
Add focused unit or integration coverage in `Tests/RewriteBarTests` for concurrency, settings, shortcut, or cross component behavior.

For a complete local app update, an agent can use this sequence after making and checking the change:

```sh
./Scripts/download-model.sh
./Scripts/install.sh
```

The first command is only needed when the pinned model is not already available. The second builds, signs, and installs the local app. Open the installed app once from Finder.

## Test the complete app

Interface and model runtime changes also require the pinned local model:

```sh
./Scripts/download-model.sh
./Scripts/build-app.sh
codesign --verify --deep --strict dist/RewriteBar.app
```

Open the built app and test the complete menu bar flow with invented text. Check levels 0, 3, 5, and 10 when prompt or generation behavior changes. Never paste private clipboard content into an issue, test, log, screenshot, or pull request.

Prompt, policy, or model runtime changes should also run the opt in benchmark against the pinned local model and, for online changes, Codex Luna. Set `REWRITE_BENCHMARK_PROVIDER=codexLuna` for an isolated no-fallback Luna run; the default is `local`. Luna benchmarking uses RewriteBar's isolated Application Support Codex home by default. `REWRITE_BENCHMARK_CODEX_HOME` may point to a different dedicated test home, but never to the developer's normal Codex home. The benchmark supports focused case and intensity arguments plus environment controls for writing styles, repetitions, custom instructions, source protection, Luna effort, temperature, cache behavior, and quantized key value storage. Compare requested/actual provider, model identifier, errors, score, median/p95/max latency, provider fallback, source-fidelity fallback, check pass rates, and intensity contrast. Do not commit its generated reports.

Codex App Server changes also require fixture-backed protocol tests and an opt-in live check using an invented source. After connecting RewriteBar's isolated account in the app, run `REWRITEBAR_RUN_LIVE_CODEX_TEST=1 ./Scripts/test.sh` to include the live persistent-runtime check. Verify disconnected, missing-runtime, offline, usage-limit, malformed-response, unexpected-tool, timeout, cancellation, and automatic local-fallback behavior. Never reuse or copy a developer's normal Codex credentials or configuration for a test, and never commit RewriteBar's isolated Codex support directory.

Shortcut and Accessibility changes also require manual checks in several host applications:

1. Confirm the shortcut registers and updates after recording a new combination.
2. Confirm permission is requested only when needed.
3. Rewrite a selection in a native text field and verify the result is also copied.
4. Move focus or change the selection during generation and verify the original text is not replaced.
5. Verify secure fields and unsupported editors fail without reading, replacing, or pasting text.
6. Confirm the menu bar path still works without Accessibility permission.

## Open the pull request

The pull request should state:

* what changes for the user
* why the change fits a private-by-default, fast, minimal menu bar tool
* the exact checks and manual flow you ran
* a screenshot for visible interface changes

CI runs `./Scripts/check-project.sh` on every pull request. A maintainer will review product fit, privacy, failure behavior, accessibility, and whether the change adds permanent interface or maintenance cost.

Keep commits focused and do not include generated files. Maintainers handle versioning and releases after merge using [RELEASING.md](RELEASING.md).

Never commit model weights, app bundles, release archives, benchmark output, clipboard content, or credentials.

## Product principles

RewriteBar should remain private by default, fast, focused, accessible, and visually restrained. On-device processing is the default; optional online processing must be explicit, isolated, bounded, and safely recover to local generation. New controls must justify their permanent cost in a tiny menu bar interface. Preserve the single slider and single action flow. Put durable personalization and processing choices in the native Settings window, not in the popover, unless an issue explicitly changes that product direction.

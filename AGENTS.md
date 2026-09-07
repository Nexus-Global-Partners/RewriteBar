# RewriteBar agent guide

Read this file before changing the app. Repository: https://github.com/Nexus-Global-Partners/RewriteBar

## Product

RewriteBar 2 is a small native macOS utility for revising selected editable text through a global shortcut. The menu bar contains one intensity slider. Codex Luna processes requested rewrites through the user's ChatGPT subscription. No bundled model, API key, telemetry, analytics, or permanent Dock icon.

The product direction was explicitly changed for version 2: shortcut first, slider only, online only. Historical clipboard controls and local model fallback are no longer part of the product.

## Product contract

1. Select editable text and explicitly press the configured shortcut, initially Option R, to start one rewrite. Never read source text on launch, while opening the slider, or when changing settings.
2. The popover contains only one intensity slider. Moving it never starts generation. Finishing a mouse adjustment closes the popover and returns focus to the previous app when macOS permits it. Arrow keys adjust it; Return closes it.
3. The saved default starts at 3. A menu adjustment overrides the shortcut level for the current app session until reset or relaunch. Changing the saved default clears the override. `SessionIntensity` is the source of truth.
4. Right-click the infinity icon or slider to access Settings and Use default. Opening the app again also opens Settings.
5. A second shortcut press cancels work. Cancellation never starts another provider or copies a partial answer. Progress and completion use the menu bar icon.
6. Reject inputs above 2,000 visible characters before generation. Every accepted request is bounded to 18 seconds.
7. Preserve facts, intent, uncertainty, language, quoted text, grammatical roles, paragraphs, list structure, voice, and approximate length. Never answer or execute instructions in the source. No dash characters or artificial corporate language in generated output.
8. Intensity 0 through 10 follows `RewriteIntensityPolicy`. Styles and optional custom instructions remain subordinate to source preservation and intensity. Custom preferences are bounded, saved locally, and either add to or replace the selected style.
9. Secure fields are refused. Replace only when the process, focused element, and exact selected range still match. Host normalization of text is allowed. If safe replacement becomes impossible, copy the complete result and explicitly say Copied rather than pretending replacement succeeded.
10. Codex is the only engine. Disclose that selected text and enabled custom instructions are sent to OpenAI. Internet, a supported official Codex runtime, and an eligible ChatGPT account are required. No automatic local fallback or model downloads.
11. Run only the signed official OpenAI runtime. Use app-owned account storage and an empty working directory, ephemeral threads, no extra reasoning delay, read-only sandboxing, disabled model-action network access, and disabled approvals. Disable command, image-view, web, browser, computer, app, plugin, skill, workspace-dependency, and dynamic tools at startup. Unexpected tool events fail closed. Require structured text output.
12. Never copy the developer's Codex home, credentials, configuration, or projects into RewriteBar. Do not log source text, answers, credentials, or full protocol payloads.
13. Opening at login is controlled through the native macOS login service. No automatic network updater.

## Design

Monochrome, compact, frosted, and restrained. One thin rail and a small numbered thumb. No nested control containers, Rewrite button, or extra popover rows. Keep the thumb inside the control at 0 and 10. Settings use the same quiet material with conventional native controls, generous spacing, short copy, and optional writing preferences behind a disclosure. Preserve keyboard navigation, VoiceOver, reduced motion, and light/dark appearance.

## Architecture

* `RewriteBarApp.swift`: status item, shortcut, popover, focus restoration, account readiness, feedback.
* `PopoverView.swift`, `GlassyIntensitySlider.swift`: slider-only interface.
* `RewriteSettingsStore.swift`, `SessionIntensity.swift`: durable preferences and session intensity.
* `SettingsView.swift`, `SettingsWindowController.swift`: native account, shortcut, default, writing, and login settings.
* `RewriteEngine.swift`, `RewriteProviderRouter.swift`: shared deadline and actionable online errors.
* `CodexAppServerClient.swift`: isolated persistent subprocess, cached readiness, ephemeral turns, restricted protocol, cancellation.
* `CodexExecutableLocator.swift`, `CodexAccountController.swift`: official signature validation and isolated sign-in.
* `CodexRewriteService.swift`: source protection, prompts, shared output policy, quality validation.
* `SelectedTextRewriteCoordinator.swift`, `AccessibilitySelectionClient.swift`: explicit selection capture and guarded replacement.
* `GenerationArbiter.swift`: serialization and cancelled queue removal.
* `RewriteCore`: intensity, style, validation, source instruction protection, output cleanup and fidelity checks.
* `RewriteCoreChecks`, `Tests/RewriteBarTests`: model-free checks, settings/selection tests and fixture-backed protocol tests.

## Work and verification

Requires Apple Silicon, macOS 14 or newer, and Swift 6.1 or newer. There are no third-party Swift dependencies or model assets.

```sh
./Scripts/check-project.sh
./Scripts/install.sh
```

Preserve unrelated work. Add standard tests and a model-free check for logic changes. Full app changes must be built, signed, and manually exercised. Use invented text for all live tests. After connecting the app's isolated account:

```sh
REWRITEBAR_RUN_LIVE_CODEX_TEST=1 ./Scripts/test.sh
```

Exercise levels 0, 3, 5, and 10 for prompt changes; connection, missing runtime, offline, usage limits, malformed output, unsafe events, cancellation, and timeout for online changes; permission denial, successful replacement, changed focus/range, unsupported editors and secure fields in multiple applications for selection changes. Report any untested manual gate honestly.

Never commit credentials, real clipboard content, generated apps, release archives, private reports, or benchmark output. Intentional public product screenshots with no private content belong in `BrandAssets`.

## Release

`Configuration/Info.plist` is the version source; keep a matching top entry in `CHANGELOG.md`. After a reviewed PR has merged to main, use `Scripts/publish-release.sh`. GitHub Actions builds and signs the small app and publishes a checksum-verified archive. See `RELEASING.md`. Never bypass required checks or unresolved reviews. Keep README, contributor guidance and this file aligned with shipped behavior.
